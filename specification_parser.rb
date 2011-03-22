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

  def load_schema(schema_name, schema_content)
    @schemas[schema_name]=schema_content if validate_schema(schema_name,schema_content)
  end

  def load_schema_files( *schema_paths )
    parse_paths(schema_paths) do |name, data|
      @schemas[name]=data if validate_schema(name,data)
    end
  end

  def load_specification( specification_name, specification_content )
    @schemas[specification_name]=specification_content if validate_schema(specification_name,specification_content)
  end

  def load_specification_files( *specification_paths )
    parse_paths(specification_paths) do |name, data|
      @specifications[p]=data if validate_specification(name,data)
    end
  end

  private

  def validate_specification( specification_name, specification_yaml )
    #Try to identify which schema to use, we can't just try each one, because if they are all wrong
    #then it is unclear which set of error messages to print. So we must come up with some signatures
    #to determine if the schema it is attempting to use. OR if all are wrong default to a certain schema.
    #need to discuss what option is best
    schema = @schemas["appliance-schema-0.9.x"]

    validator = Kwalify::Validator( schema ) #Fixed schema for now
    parser = Kwalify::Yaml::Parser.new( validator )
    errors = parser.parse( specification_yaml )
    readable = ""

    status = parse_errors(validator, errors) do |linenum, column, path, message|
      readable += "#{linenum}:#{column} [#{path}] #{message}\n" # default kwalify style for now
    end

    raise "The specification #{specification_name} was invalid according to schema #{schema}: #{readable}" unless status
    status
  end

  def validate_schema( schema_name, schema_yaml )
    #Special validator bound to the kwalify meta schema
    meta_validator = Kwalify::MetaValidator.instance()
    parser = Kwalify::Yaml::Parser.new( meta_validator )
    errors = parser.parse( schema_yaml, :filename => schema_name )

    status = parse_errors(meta_validator, errors) do |linenum, column, path, message|
      p "#{linenum}:#{column} [#{path}] #{message}" # default kwalify style for now
    end
    raise "Unable to continue due to invalid schema #{schema_name}" unless status
    status
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
      yield File.extname(p), Kwalify::Yaml.load_file(p)
    end
  end

end

#e = SpecificationParser.new()
#e.load_schema_files("/home/msavy/schema_test/dumb.yaml")
#p e.schemas
#

validator = Kwalify::MetaValidator.instance()

# validate schema definition
#parser = Kwalify::Yaml::Parser.new(validator)
#parser.preceding_alias = true
input = Kwalify::Yaml.load_file('/home/msavy/schema_test/dumb.yaml')

#Do _not_ use the kwalify parser for meta-parsing
#Parser for the meta is buggy and does not work as documented!
#The CLI app seems to unintentionally work around the issue.
#Only validate using older method

errors = validator.validate(input)

for e in errors
  puts "[#{e.path}] #{e.message}"
end if errors && !errors.empty?

schema = Kwalify::Yaml.load_file('/home/msavy/work/boxgrinder-appliances/schemas/appliance-schema-0.9.x.yaml')
val_2 = Kwalify::Validator.new(schema)
parser = Kwalify::Yaml::Parser.new(val_2)
document = parser.parse_file('/home/msavy/work/boxgrinder-appliances/testing-appliances/schema/0.9.x-invalid.appl')

errors = parser.errors()
if errors && !errors.empty?
  for e in errors
    puts "#{e.linenum}:#{e.column} [#{e.path}] #{e.message}"
  end
end


