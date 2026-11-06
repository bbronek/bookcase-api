module RecordedExamples
  UUID = /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/

  def self.stable(body)
    stable_ids = Hash.new { |ids, uuid| ids[uuid] = format("019a0000-0000-7000-8000-%012d", ids.size + 1) }
    JSON.parse(body.gsub(UUID) { |uuid| stable_ids[uuid] })
  end
end

RSpec.configure do |config|
  config.after(:each, type: :request) do |example|
    next unless example.metadata[:response] && response&.body.present?

    example.metadata[:response][:content] = { response.media_type => { example: RecordedExamples.stable(response.body) } }
  end
end
