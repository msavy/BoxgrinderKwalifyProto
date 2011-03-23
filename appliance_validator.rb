require 'kwalify'

class ApplianceValidator < Kwalify::Validator

  def initialize( schema )
    super(schema)#Super constructor
  end

  def validate_hook(value, rule, path, errors)
    case rule.name
      when 'Repository' #enforce baseurl xor mirrorlist
        unless value['baseurl'].nil? ^ value['mirrorlist'].nil?
          errors << Kwalify::ValidationError.new("must specify a baseurl xor a mirrorlist", path)
        end
    end
  end
end