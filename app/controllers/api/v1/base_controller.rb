module Api
  module V1
    class BaseController < ApplicationController
      class NonStringAttributes < StandardError
        attr_reader :attributes

        def initialize(attributes)
          super("Attributes must be strings: #{attributes.join(', ')}")
          @attributes = attributes
        end
      end

      before_action :ensure_json_body, :reject_null_bytes

      rescue_from NonStringAttributes do |error|
        render_validation_problem(error.attributes.map { |attribute| [ attribute, "must be a string" ] })
      end

      private

      def ensure_json_body
        return if request.raw_post.blank? || request.media_type == "application/json"

        render_problem(:unsupported_media_type, detail: "Request bodies must be application/json")
      end

      def reject_null_bytes
        return unless null_byte?([ request.path_parameters, request.query_parameters, request.request_parameters ])

        render_problem(:bad_request, detail: "Parameters must not contain NUL bytes")
      end

      def null_byte?(value)
        case value
        when Hash then value.any? { |key, nested| key.to_s.include?("\0") || null_byte?(nested) }
        when Array then value.any? { |nested| null_byte?(nested) }
        else value.to_s.include?("\0")
        end
      end

      def path_parameter(name) = request.path_parameters.fetch(name)

      def query_parameter(name)
        value = request.query_parameters[name.to_s]
        return value if value.nil? || value.is_a?(String)

        raise ActionController::BadRequest, "#{name} must be a single value"
      end

      def body_attributes(*names)
        body = request.request_parameters
        raise ActionController::BadRequest, "Request body must be a JSON object" if body.key?("_json")

        non_strings = names.select { |name| body.key?(name.to_s) && !body[name.to_s].is_a?(String) }
        raise NonStringAttributes, non_strings if non_strings.any?

        permitted = ActionController::Parameters.new(body).permit(*names)
        names.index_with { |name| permitted[name] }
      end

      def render_resource(resource, with:, status: :ok)
        render json: with.new.serialize_to_json(resource), status:
      end

      def render_created(record, with:, location:)
        response.set_header("Location", location)
        render_resource record, with:, status: :created
      end
    end
  end
end
