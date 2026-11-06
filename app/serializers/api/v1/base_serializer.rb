module Api
  module V1
    class BaseSerializer < Panko::Serializer
      def self.timestamp(*names)
        attributes(*names)
        names.each { |name| define_method(name) { object.public_send(name)&.utc&.iso8601(3) } }
      end
    end
  end
end
