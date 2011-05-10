module Exceed
  module Preferential
    module Helpers
      # Converts give symbol to string and downcases it
      def self.normalize(symbol)
        symbol.to_s.downcase
      end
    end
  end
end
