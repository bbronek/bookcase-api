class RejectInvalidUtf8Body
  def initialize(app)
    @app = app
  end

  def call(env)
    body = env["rack.input"]&.read.to_s
    env["rack.input"] = StringIO.new(body)
    return @app.call(env) if body.dup.force_encoding(Encoding::UTF_8).valid_encoding?

    Problem.rack_response(400, detail: "Request body must be valid UTF-8")
  end
end
