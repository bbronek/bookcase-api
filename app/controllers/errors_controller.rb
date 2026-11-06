class ErrorsController < ApplicationController
  ROUTABLE_METHODS = %w[ GET POST PUT PATCH DELETE ].freeze

  def unmatched_route
    allowed = allowed_methods
    return render_problem(:not_found, detail: "No route matches #{request.method} #{request.path}") if allowed.empty?

    response.set_header("Allow", allowed.join(", "))
    return head(:no_content) if request.options?

    render_problem(:method_not_allowed, detail: "#{request.method} is not allowed on #{request.path}")
  end

  private

  def allowed_methods
    methods = ROUTABLE_METHODS.select { |method| routable?(method) }
    methods = methods.flat_map { |method| method == "GET" ? %w[ GET HEAD ] : method }
    methods.empty? ? methods : [ *methods, "OPTIONS" ]
  end

  def routable?(method) = Rails.application.routes.recognize_path(request.path, method:)[:controller] != "errors"
end
