module Exceed
  module Preferential
    class Configuration
      attr_accessor :definitions

      def initialize(klass, preferential, options)
        @klass        = klass
        @preferential = preferential
        @definitions  = {}
      end

      def define(preferential, options = {})
        preferential = Helpers.normalize(preferential)
        raise ArgumentError, "#{@klass} already defines has_numerous :#{preferential}" if @definitions.has_key?(preferential)
        @definitions[preferential] = Definition.new(preferential, options)
      end

      def create_preferential_methods
        preferential_accessors, object_accessors = [], []
        @definitions.values.each do |definition|

          preferential_accessors << <<-end_eval
            def #{@preferential}_#{definition.name}=(value)
              set_preferential('#{@preferential}', '#{definition.name}', value, true)
            end
            def #{@preferential}_#{definition.name}
              get_preferential('#{@preferential}', '#{definition.name}', true)
            end
            def #{@preferential}_#{definition.name}?
              !!get_preferential('#{@preferential}', '#{definition.name}', true)
            end
          end_eval

          object_accessors << <<-end_eval
            def #{definition.name}=(value)
              proxy_owner.set_preferential('#{@preferential}', '#{definition.name}', value)
            end
            def #{definition.name}
              proxy_owner.get_preferential('#{@preferential}', '#{definition.name}')
            end
            def #{definition.name}?
              !!proxy_owner.get_preferential('#{@preferential}', '#{definition.name}')
            end
          end_eval
        end

        @klass.class_eval <<-end_eval
          # Define the has_many relationship
          has_many :#{@preferential}, :class_name => 'Preference',
                                      :as         => :model,
                                      :extend     => AssociationExtensions,
                                      :dependent  => :destroy do
            #{object_accessors.join("\n")}
          end

          # Define the preferential accessors
          #{preferential_accessors.join("\n")}
        end_eval
      end
    end
  end
end