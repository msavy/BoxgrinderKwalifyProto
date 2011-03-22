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

  def validate_specification( specification_name, specification_yaml )
    #Try to identify which schema to use, we can't just try each one, because if they are all wrong
    #then it is unclear which set of error messages to print. So we must come up with some signatures
    #to determine the schema it is attempting to use. OR if all are wrong default to a certain schema?
    #need to discuss what option is best
    schema_name = "appliance-schema-0.9.x.yaml"
    schema = @schemas[schema_name]
    validator = Kwalify::Validator.new( schema ) #Fixed schema for now
    parser = Kwalify::Yaml::Parser.new( validator )
    document = parser.parse( specification_yaml )
    errors = parser.errors()
    status = parse_errors(validator, errors) do |linenum, column, path, message|
      p "ln #{linenum}: col#{column} [#{path}] #{message}\n" # default kwalify style for now
    end
    raise %(The appliance specification "#{specification_name}" was invalid according to schema "#{schema_name}") unless status
    document
  end

  def validate_schema( schema_name, schema_yaml )
    #Special validator bound to the kwalify meta schema
    meta_validator = Kwalify::MetaValidator.instance()
    # validate schema definition
    document = Kwalify::Yaml.load( schema_yaml )
    #Do _NOT_ use the Kwalify parser for Meta-parsing!
    #Parser for the meta is buggy and does not work as documented!
    #The CLI app seems to unintentionally work around the issue.
    #Only validate using older/less useful method
    errors = meta_validator.validate( document )
    status = parse_errors(meta_validator, errors) do |linenum, column, path, message|
      p "[#{path}] #{message}"
    end
    raise "Unable to continue due to invalid schema #{schema_name}" unless status
    document
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
      yield File.basename(p), File.read(p)
    end
  end

end

e = SpecificationParser.new()
e.load_schema_files("/home/msavy/work/boxgrinder-appliances/schemas/appliance-schema-0.9.x.yaml")
e.load_specification_files("/home/msavy/work/boxgrinder-appliances/testing-appliances/schema/0.9.x-invalid.appl")



#p e.schemas

=begin
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
=end


