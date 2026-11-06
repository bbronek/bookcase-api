require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

require_relative "../lib/problem"
require_relative "../lib/reject_invalid_utf8_body"

module Bookcase
  class Application < Rails::Application
    config.load_defaults 8.1

    config.api_only = true
    config.time_zone = "Europe/Warsaw"
    config.generators { |generate| generate.orm :active_record, primary_key_type: :uuid }
    config.action_mailer.default_options = { from: "Library <library@example.com>" }
    config.action_mailer.preview_paths = [ root.join("spec/mailers/previews").to_s ]

    config.middleware.insert_after ActionDispatch::RequestId, RejectInvalidUtf8Body
    config.action_dispatch.rescue_responses["ActionDispatch::Http::MimeNegotiation::InvalidType"] = :bad_request
    config.exceptions_app = Problem.exceptions_app
    config.host_authorization = {
      exclude: ->(request) { request.path == "/health" },
      response_app: ->(_env) { Problem.rack_response(403, detail: "Host not allowed") }
    }
  end
end
