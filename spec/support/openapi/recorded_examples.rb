module RecordedExamples
  UUID = /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/
  REQUEST_ID = "5b0e3c6a-9a87-4a8e-b43c-2f1f1d6f8a10".freeze

  def self.stable(body)
    stable_ids = Hash.new { |ids, uuid| ids[uuid] = format("019a0000-0000-7000-8000-%012d", ids.size + 1) }
    document = JSON.parse(body)
    document["request_id"] = REQUEST_ID if document.is_a?(Hash) && document.key?("request_id")
    JSON.parse(JSON.generate(document).gsub(UUID) { |uuid| uuid == REQUEST_ID ? uuid : stable_ids[uuid] })
  end
end

RSpec.configure do |config|
  config.after(:each, type: :request) do |example|
    next unless example.metadata[:response] && response&.body.present?

    example.metadata[:response][:content] = { "application/json" => { example: RecordedExamples.stable(response.body) } }
  end
end
