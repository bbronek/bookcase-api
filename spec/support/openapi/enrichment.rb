module OpenAPIEnrichment
  REQUEST_ID = { "X-Request-Id" => { "$ref" => "#/components/headers/X-Request-Id" } }.freeze
  PROBLEM = {
    "headers" => REQUEST_ID,
    "content" => { "application/problem+json" => { "schema" => { "$ref" => "#/components/schemas/Problem" } } }
  }.freeze

  RESPONSES = {
    "BadRequest" => PROBLEM.merge("description" => "Malformed request: invalid JSON, parameters or encoding"),
    "ContentTooLarge" => PROBLEM.merge("description" => "The body is larger than 1 MB"),
    "UnsupportedMediaType" => PROBLEM.merge("description" => "The body is not `application/json`"),
    "Unexpected" => PROBLEM.merge("description" => "`500` for an unexpected failure, `503` with `Retry-After` while the database is unavailable or a lock wait times out")
  }.freeze

  HEADERS = {
    "X-Request-Id" => { "description" => "Identifies the request in logs and in problem documents.", "schema" => { "type" => "string" } }
  }.freeze

  private

  def pretty_generate(document) = super(enrich(document.deep_stringify_keys))

  def enrich(document)
    document["components"].merge!("responses" => RESPONSES, "headers" => HEADERS)
    document["paths"].each do |path, path_item|
      path_item.each_value do |operation|
        next unless operation.is_a?(Hash) && operation.key?("responses")

        operation.delete("parameters") if operation["parameters"] == []
        add_shared_responses(operation) if path.start_with?("/api/v1")
        operation["responses"].each_value { |response| describe_response(response) }
      end
    end
    document
  end

  def add_shared_responses(operation)
    responses = operation["responses"]
    responses["400"] ||= { "$ref" => "#/components/responses/BadRequest" }
    if operation.key?("requestBody")
      responses["413"] ||= { "$ref" => "#/components/responses/ContentTooLarge" }
      responses["415"] ||= { "$ref" => "#/components/responses/UnsupportedMediaType" }
    end
    responses["default"] = { "$ref" => "#/components/responses/Unexpected" }
    operation["responses"] = responses.sort_by { |code, _| code == "default" ? "999" : code }.to_h
  end

  def describe_response(response)
    return if response.key?("$ref")

    json = response.dig("content", "application/json")
    response["content"] = { "application/problem+json" => json } if json&.dig("schema", "$ref")&.end_with?("/Problem")
    response["headers"] = REQUEST_ID.merge(response.fetch("headers", {}))
  end
end
