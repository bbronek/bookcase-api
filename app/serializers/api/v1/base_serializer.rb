module Api
  module V1
    class BaseSerializer
      include Alba::Resource

      def self.timestamp(*names)
        names.each { |name| attribute(name) { |record| record.public_send(name)&.utc&.iso8601(3) } }
      end
    end
  end
end
