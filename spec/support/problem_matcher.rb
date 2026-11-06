RSpec::Matchers.define :be_problem do |status, type: nil, detail: nil, errors: nil|
  match do |response|
    @problem = JSON.parse(response.body, symbolize_names: true)
    expected = { type: type ? "/problems##{type}" : "about:blank", status: Rack::Utils.status_code(status),
                 detail:, errors: }.compact

    response.media_type == Problem::MEDIA_TYPE && values_match?(include(expected), @problem)
  end

  failure_message do |response|
    "expected a #{status} #{type || 'about:blank'} problem#{" with detail #{detail.inspect}" if detail}, " \
      "got #{response.status} #{response.media_type}: #{response.body}"
  end
end
