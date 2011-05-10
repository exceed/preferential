require 'preferential/error'
require 'preferential/helpers'
require 'preferential/definition'
require 'preferential/configuration'
require 'preferential/association_extensions'

module Exceed
  module Preferential
    def self.included(base)
      base.send :extend, ClassMethods
    end

    # Make methods available to ActiveRecord in the class context
    module ClassMethods
      def has_numerous(preferential = nil, options = {})
        send :include, InstanceMethods

        preferential = Helpers.normalize(preferential)

        # Create accessor methods to our configuration info
        class << self
          attr_accessor :preferential_configuration unless method_defined?(:preferential_configuration)
        end

        # Initialize the configuration to an empty hash
        self.preferential_configuration = {} if self.preferential_configuration.nil?

        # Redefining a preference configuration once defined should not be allowed
        raise ArgumentError, "#{self} class already has_numerous :#{preferential} defined" if self.preferential_configuration.has_key?(preferential)

        configuration = Configuration.new(self, preferential, options)
        yield configuration
        configuration.create_preferential_methods
        preferential_configuration[preferential] = configuration
      end
    end

    # Make methods available to ActiveRecord models in the instance context
    module InstanceMethods
      def set_preferential(preferential, name, value, do_preprocess = false)
        preferential = Helpers.normalize(preferential)
        name    = Helpers.normalize(name)

        # Check to make sure the preferential exists
        raise ArgumentError, "Preferential #{preferential} is not defined for class #{self.class}" \
          unless self.class.preferential_configuration.has_key?(preferential)
        configuration = self.class.preferential_configuration[preferential]

        # Check to make sure the name of the pref exists
        raise ArgumentError, "'#{name}' not defined for :#{preferential} in class #{self.class}" \
          unless configuration.definitions.has_key?(name)
        definition = configuration.definitions[name]

        # Do preprocess here, type_check and validate can be done as AR validation in
        value = definition.preprocess.call(value) if do_preprocess and definition.has_preprocess

        # Invoke the association
        prefs = send(preferential)

        # If pref already exists, update it, otherwise add a new one
        pref = prefs.detect { |pref| pref.name == name }

        if pref.blank?
          pref = Preference.new  :context  => preferential,
                                 :name     => name,
                                 :value    => value
          pref.set_model_target(self) # for the bug regarding pref's validation trying to invoke the 'model' assocation when self is a new record
          send("#{preferential}").send("<<", pref)
        else
          pref.value = value
        end
        pref.value
      end

      def get_preferential(preferential, name, do_postprocess = false)
        preferential = Helpers.normalize(preferential)
        name         = Helpers.normalize(name)

        # Check to make sure the preferential exists
        raise ArgumentError, "Preferential #{preferential} not defined for class #{self.class}" \
          unless self.class.preferential_configuration.has_key?(preferential)
        configuration = self.class.preferential_configuration[preferential]

        # Check to make sure the name of the pref exists
        raise ArgumentError, "#{name} not defined for #{preferential} in class #{self.class}" \
          unless configuration.definitions.has_key?(name)
        definition = configuration.definitions[name]

        # Invoke the association
        prefs = send(preferential)

        # Try to find what they are looking for
        pref = prefs.detect{ |pref| pref.name == name }

        # If the pref isn't found, try to fallback on a default
        if pref.blank?
          # TODO break all these nested if statements out into helper methods, i like prettier code
          # TODO raise an exception if we don't respond to default_through or the resulting object doesn't respond to the preferential
          if definition.has_default_through and respond_to?(definition.default_through) and (through = send(definition.default_through)).blank? == false
            value = through.send(preferential)[name]
          elsif definition.has_default_dynamic
            if definition.default_dynamic.instance_of?(Proc)
              value = definition.default_dynamic.call(self)
            else
              # TODO raise an exception if we don't respond to default_dynamic
              value = send(definition.default_dynamic)
            end
          elsif definition.has_default
            value = Marshal::load(Marshal.dump(definition.default)) # BUGFIX deep cloning default values
          else
            value = nil
          end
        else
          value = pref.value
        end

        value = definition.postprocess.call(value) if do_postprocess and definition.has_postprocess
        value
      end
    end
  end
end

ActiveRecord::Base.send :include, Exceed::Preferential