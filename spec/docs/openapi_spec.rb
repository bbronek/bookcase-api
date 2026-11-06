require "rails_helper"

RSpec.describe "OpenAPI document" do
  let(:document) { YAML.safe_load_file(Rails.public_path.join("openapi/v1.yaml")) }
  let(:openapi) { JSONSchemer.openapi(document) }

  it "is a valid OpenAPI 3.1 document" do
    expect(openapi.validate.pluck("error")).to be_empty
  end

  it "documents every route of the API and nothing else" do
    routes = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next unless path.start_with?("/api/v1", "/health")

      [ route.verb.downcase, path.gsub(/:\w+/, "{}") ]
    end
    documented = document["paths"].flat_map do |path, operations|
      operations.keys.excluding("parameters").map { |verb| [ verb, path.gsub(/\{\w+\}/, "{}") ] }
    end

    expect(documented).to match_array(routes)
  end

  it "gives every operation a unique id, a tag and an answer for unexpected failures" do
    operations = document["paths"].flat_map { |path, item| item.except("parameters").map { |_, operation| [ path, operation ] } }

    expect(operations.map { it.last["operationId"] }.tally.values).to all(eq(1))
    expect(operations.map { it.last }).to all(include("tags"))
    expect(operations.select { |path, _| path.start_with?("/api/v1") }.map(&:last)).to all(include("responses" => include("default")))
  end

  it "has examples that validate against their own schemas" do
    examples = document["paths"].flat_map do |path, item|
      item.except("parameters").flat_map do |verb, operation|
        operation["responses"].filter_map do |status, response|
          media_type, content = response["content"]&.first
          next unless content&.key?("example")

          pointer = "#/paths/#{path.gsub('/', '~1')}/#{verb}/responses/#{status}/content/#{media_type.gsub('/', '~1')}/schema"
          [ "#{verb.upcase} #{path} #{status}", openapi.ref(pointer.gsub("{", "%7B").gsub("}", "%7D").gsub("+", "%2B")), content["example"] ]
        end
      end
    end

    expect(examples.size).to be > 25
    examples.each do |name, schema, example|
      expect(schema.validate(example).map { it["error"] }).to be_empty, name
    end
  end
end
