class Preference < ActiveRecord::Base
  attr_accessor     :model_cache,
                    :definition,
                    :value_cache

  belongs_to        :model,
                    :polymorphic => true
  before_validation :get_definition
  validate          :validate_type_check,
                    :validate_validate

  def get_definition
    self.model_cache = model if model_cache.blank?
    self.definition = model_cache.class.preferential_configuration[self.context].definitions[self.name] if self.definition.blank?
  end

  def validate_type_check
    return unless definition.has_type_check
    self.errors.add(:value, "type check failed for '#{self.name}'") unless definition.type_check.include?(value.class)
  end

  def validate_validate
    return unless definition.has_validate
    success = true

    if definition.validate.instance_of?(Array) and definition.validate.include?(value) == false
      success = false
    elsif definition.validate.instance_of?(Symbol)
      success = model_cache.send(definition.validate, value)
    elsif definition.validate.instance_of?(Proc)
      begin
        success = definition.validate.call(value)
      rescue Preferential::ValidationError
        success = false
      end
    end

    if success == false
      self.errors.add_to_base("validation failed for '#{self.name}'")
    elsif success.instance_of?(Array)
      success.each{ |message| self.errors.add_to_base(message) }
    end
  end

  def value=(v)
    method_missing(:value=, v.to_yaml)
    self.value_cache = v
  end

  def value
    self.value_cache ||= YAML.load(method_missing(:value))
  end
end