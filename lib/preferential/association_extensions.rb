module Exceed
  module Preferential
    module AssociationExtensions
      def save
        do_save(false)
      end

      def save!
        do_save(true)
      end

      def []=(name, value)
        proxy_owner.set_preferential(proxy_reflection.name, name, value)
      end

      def [](name)
        proxy_owner.get_preferential(proxy_reflection.name, name)
      end

      def valid?
        valid = true
        proxy_target.each do |thing|
          thing.model_cache = proxy_owner
          unless thing.valid?
            thing.errors.each{ |attr, msg| proxy_owner.errors.add(proxy_reflection.name, msg) }
            valid = false
          end
        end
        valid
      end

      # Private Methods
      private
        def do_save(with_bang)
          success = true
          proxy_target.each do |thing|
            thing.model_cache = proxy_owner
            if with_bang
              thing.save!
            elsif thing.save == false
              # Delegate the errors to the proxy owner
              thing.errors.each { |attr,msg| proxy_owner.errors.add(proxy_reflection.name, msg) }
              success = false
            end
          end
          success
        end
    end
  end
end
