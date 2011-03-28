require 'rubygems'
require 'kwalify'
require 'appliance_validator'
require 'appliance_transformer'

class SpecificationParser

  public
  attr_reader :schemas
  attr_reader :specifications
  attr_reader :messages

  @@messages = {
      :pattern_unmatch => "'%s' not a valid pattern for '%s'"
  }

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
      @specifications[p]=validate_specification(name,data)
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
      if schema_errors.empty? #If succeeded in validating against an old schema
        #We're not at head, call for transformation to latest style, schema[0] is name
        return TransformHelper.new().transform( schema[0], specification_document)
      end
    end 
    #If all schemas fail then we assume they are using the latest schema..
    err_flag = parse_errors(head_errors) do |linenum, column, path, message|
      puts "[line #{linenum}, col #{column}] [#{path}] #{message}" # kwalify own parser
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

    err_flag = parse_errors(errors) do |linenum, column, path, message|
      puts "[#{path}] #{message}"#Internal parser has no linenum/col support
    end
    raise "Unable to continue due to invalid schema #{schema_name}" if err_flag
    document
  end

  def resolve_name( _path )
    path=_path.split("/")
    return path unless path.is_a?(Array)
    path.reverse_each do |elem|
      unless elem =~ /[\d]+/ #unless integer
        return elem
      end
    end
    "ROOT"
  end

  def parse_errors( errors )
    p_errs=false
    if errors && !errors.empty? #Then there was a problem
      errors.each do |err|

      case err.error_symbol
        when :pattern_unmatch then
        message = sprintf(@@messages[:pattern_unmatch],err.value,resolve_name(err.path))
        else
        message = err.message
      end

      yield err.linenum, err.column, err.path, message
      p_errs=true
      end
    end
    p_errs
  end

  def parse_paths( paths=[] )
    paths.each do |p|
      raise "The expected file #{p} does not exist." if not File.exist?(p)
      #Get rid of file extension from name blah.yaml => blah, fred.xml => fred
      yield File.basename(p).gsub(/\.[^\.]+$/,''), File.read(p)
    end
  end

  public

  class TransformHelper
    include ApplianceTransformers
    
    def method_name( name )
      name.gsub(/[-\.]/,'_')
    end

    def transform(name, doc)
      begin
        self.send(self.method_name(name),doc)
      rescue #Can get rid of this and assume there is no transform?
        puts "No transformation existed for #{name}.."
        raise
      end
    end

    def method_missing(sym, *args, &block) #Print trace message
      puts "No document conversion method found for '#{sym}'. Available conversion methods: [#{ApplianceTransformers::instance_methods(false).sort.join(", ")}]"
    end
  end
end

e = SpecificationParser.new()
e.load_schema_files("schemas/appliance_schema_0.9.1.yaml")
e.load_schema_files("schemas/appliance_schema_0.8.x.yaml")
puts "0.9.x spec validates!" if e.load_specification_files("appliances/0.9.x.appl")
puts "0.8.x spec validates!" if e.load_specification_files("appliances/0.8.x.appl")
begin
  e.load_specification_files("appliances/0.9.x-invalid.appl")
rescue RuntimeError => f
  puts "#{f.message}\n#{f.backtrace.join("\n")} "
end