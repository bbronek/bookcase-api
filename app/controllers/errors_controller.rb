class ErrorsController < ApplicationController
  ROUTED_METHODS = %w[ GET POST PUT PATCH DELETE ].freeze

  def unmatched_route
    allowed = ROUTED_METHODS.select { |method| routed?(method) }
    return render_problem(:not_found, detail: "No route matches #{request.method} #{request.path}") if allowed.empty?

    response.set_header("Allow", allowed.flat_map { |method| method == "GET" ? %w[ GET HEAD ] : method }.join(", "))
    render_problem(:method_not_allowed, detail: "#{request.method} is not allowed on #{request.path}")
  end

  private

  def routed?(method) = Rails.application.routes.recognize_path(request.path, method:)[:controller] != "errors"
end
