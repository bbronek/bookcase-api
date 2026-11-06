module Problem
  MEDIA_TYPE = "application/problem+json".freeze

  def self.document(status:, type: nil, detail: nil, errors: nil)
    {
      type: type ? "/problems##{type}" : "about:blank",
      title: type ? type.tr("-", " ").capitalize : Rack::Utils::HTTP_STATUS_CODES.fetch(status),
      status:,
      detail:,
      errors:
    }.compact
  end

  def self.rack_response(status, detail: nil)
    [ status, { "content-type" => MEDIA_TYPE }, [ JSON.generate(document(status:, detail:)) ] ]
  end

  def self.exceptions_app = ->(env) { rack_response(env["PATH_INFO"].delete_prefix("/").to_i) }
end
