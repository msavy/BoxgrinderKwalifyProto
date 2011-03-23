require 'rubygems'
require 'kwalify'
require 'appliance_validator'

class SpecificationParser

  public
  attr_reader :schemas
  attr_reader :specifications

  def initialize()
    @schemas = {}
    @specifications = {}
  end

  def load_schema( schema_name, schema_content )
    @schemas[schema_name]=validate_schema(schema_name,schema_content)
  end

  def load_schema_files( *schema_paths )
    parse_paths(schema_paths) do |name, data|
      @schemas[name]=validate_schema(name,data)
    end
  end

  def load_specification( specification_name, specification_content )
    @schemas[specification_name]=validate_schema(specification_name,specification_content)
  end

  def load_specification_files( *specification_paths )
    parse_paths(specification_paths) do |name, data|
      @specifications[p]= validate_specification(name,data)
    end
  end

  private

  # TODO catch Kwalify::SyntaxError?
  def validate_specification( specification_name, specification_yaml )
    sorted_schemas = @schemas.sort
    head_schema = sorted_schemas.pop() #Try the highest version schema first.
    head_errors = [] #If all schemas fail only return errors for the head spec
    specification_document = _validate_specification(head_schema[1],specification_yaml){|errors| head_errors=errors}

    #Attempt other schemas if head fails
    until sorted_schemas.empty? or head_errors.empty?
      schema = sorted_schemas.pop()
      schema_errors = []
      specification_document = _validate_specification(schema[1],specification_yaml){|errors| schema_errors=errors}
      if schema_errors.empty?
        head_errors.clear()
        break #If succeeded in validating against an old schema
      end
    end 

    err_flag = parse_errors(head_errors) do |linenum, column, path, message|
     p "[ln #{linenum}, col #{column}] [#{path}] #{message}\n" # kwalify own parser
    end 

    raise %(The appliance specification "#{specification_name}" was invalid according to schema "#{head_schema[0]}") if err_flag
    specification_document
  end

  def _validate_specification( schema_document, specification_yaml )
    validator = ApplianceValidator.new( schema_document )
    parser = Kwalify::Yaml::Parser.new( validator )
    document = parser.parse( specification_yaml )
    yield parser.errors()
    document
  end

  def validate_schema( schema_name, schema_yaml )
    #Special validator bound to the kwalify meta schema
    meta_validator = Kwalify::MetaValidator.instance()
    # validate schema definition
    document = Kwalify::Yaml.load( schema_yaml )
    #Do _NOT_ use the Kwalify parser for Meta-parsing! Parser for the meta is buggy and does not work as documented!
    #The CLI app seems to unintentionally work around the issue. Only validate using older/less useful method
    errors = meta_validator.validate( document )

    errors = parse_errors(errors) do |linenum, column, path, message|
      p "[#{path}] #{message}"#Internal parser has no linenum/col support
    end

    raise "Unable to continue due to invalid schema #{schema_name}" if errors
    document
  end

  def parse_errors( errors )
    p_errs=false
    if errors && !errors.empty? #Then there was a problem
      errors.each do |err|
        yield err.linenum, err.column, err.path, err.message
      end
      p_errs=true
    end
    p_errs
  end

  def parse_paths( paths=[] )
    paths.each do |p|
      raise "The expected file #{p} does not exist." if not File.exist?(p)
      yield File.basename(p), File.read(p)
    end
  end

end

e = SpecificationParser.new()
e.load_schema_files("schemas/appliance-schema-0.9.x.yaml")
e.load_schema_files("schemas/appliance-schema-0.8.x.yaml")
p "0.9.x spec validates!" if e.load_specification_files("appliances/0.9.x.appl")
p "0.8.x spec validates!"  if e.load_specification_files("appliances/0.8.x.appl")
e.load_specification_files("appliances/0.9.x-invalid.appl")