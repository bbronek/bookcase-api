class RequestBodyLimit
  MAX_BYTES = 1_048_576

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if env["CONTENT_LENGTH"].to_i <= MAX_BYTES

    Problem.rack_response(env, 413, detail: "Request bodies are limited to #{MAX_BYTES} bytes")
  end
end
