module Problem
  MEDIA_TYPE = "application/problem+json".freeze

  def self.document(status:, instance:, request_id:, type: nil, detail: nil, errors: nil)
    {
      type: type ? "/problems##{type}" : "about:blank",
      title: type ? type.tr("-", " ").capitalize : Rack::Utils::HTTP_STATUS_CODES.fetch(status),
      status:,
      detail:,
      instance:,
      request_id:,
      errors:
    }.compact
  end

  def self.rack_response(env, status, detail: nil, headers: {})
    instance = env["action_dispatch.original_path"] || env["PATH_INFO"]
    body = document(status:, detail:, instance:, request_id: env["action_dispatch.request_id"])
    [ status, { "content-type" => MEDIA_TYPE, **headers }, [ JSON.generate(body) ] ]
  end

  def self.exceptions_app = ->(env) { rack_response(env, env["PATH_INFO"].delete_prefix("/").to_i) }
end
