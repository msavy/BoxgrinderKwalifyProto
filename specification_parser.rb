require 'rubygems'
require 'kwalify'

class SpecificationParser

  private
  attr_writer :schemas

  public
  attr_reader :schemas

  def initialize()
    @schemas = {}
    @specifications = {}
  end

  def load_schema(schema_name, yaml_content)
    @schemas[schema_name]=yaml_content if validate_schema(schema_name,yaml_content)
  end

  def load_schema_files( *schema_paths )
    parse_paths(schema_paths) do |name, data|
      @schemas[name]=data if validate_schema(name,data)
    end
  end

  def load_specification( specification_name, specification_content )
    #
  end

  def load_specification_files( *specification_paths )
    parse_paths(specification_paths) do |name, data|
      @specifications[p]=data if validate_specification(name,data)
    end
  end

  private

  def validate_specification( specification_name, specification_yaml )

  end

  def validate_schema( schema_name, schema_yaml )
    #Special validator bound to the kwalify meta schema
    meta_validator = Kwalify::MetaValidator.instance
    parser = Kwalify::Yaml::Parser.new(meta_validator)
    errors = parser.parse(schema_yaml) 

    status = parse_errors(meta_validator, errors) do |linenum, column, path, message|
      p "#{linenum}:#{column} [#{path}] #{message}" # default kwalify style for now
    end
    raise "Unable to continue due to invalid schema #{schema_name}" unless status
    status
  end


  def validate( validator, name, yaml )
    #validator = Kwalify::Validator.new( schema )
    errors = validator.validate( document )
   end

  def parse_errors( validator, errors )
    return_status=true
    if validator && !errors.empty?#Then there was a problem
      errors.each do |err|
        yield err.linenum, err.column, err.path, err.message
      end
      return_status=false
    end
    return_status
  end

  def parse_paths( paths=[] )
    paths.each do |p|
      raise "The expected file #{p} does not exist." if not File.exist?(p)
      yield File.extname(p), File.read(p)
    end
  end

  def add_schema( )

  end

  def add_spec(key_name, yaml_cont)
    doc = Kwalify::Yaml.load( yaml_cont )

   # validate()

    data_store[key_name]=doc
  end


end

e = SpecificationParser.new()
e.load_schema_files("/home/msavy/work/boxgrinder-appliances/schemas/appliance-schema-0.9.x.yaml")
p e.schemas