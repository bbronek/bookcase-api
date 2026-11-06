module OpenAPIDSL
  def serial_number_parameter(name = :serial_number)
    parameter name:, in: :path, required: true, schema: OpenAPISchemas::SERIAL_NUMBER
  end

  def page_parameters
    sizes = KeysetPagination::PAGE_SIZES
    parameter name: :limit, in: :query, required: false, description: "Page size.",
              schema: { type: :integer, minimum: sizes.min, maximum: sizes.max, default: KeysetPagination::DEFAULT_PAGE_SIZE }
    parameter name: :after, in: :query, required: false, schema: { type: :string },
              description: "Cursor from the `Link: rel=\"next\"` header of the previous page."
  end

  def json_body(schema)
    consumes "application/json"
    parameter name: :body, in: :body, required: true, schema: OpenAPISchemas.ref(schema)
  end

  def problem_response(status, description, detail:, type: nil, errors: nil, &setup)
    response(status, description) do
      schema OpenAPISchemas.ref(:Problem)
      instance_exec(&setup) if setup

      run_test! { expect(response).to be_problem(status.to_i, type:, detail:, errors:) }
    end
  end
end

RSpec.configure { |config| config.extend OpenAPIDSL, type: :request }
