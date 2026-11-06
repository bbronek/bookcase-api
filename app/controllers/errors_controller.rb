class ErrorsController < ApplicationController
  def unmatched_route
    render_problem(:not_found, detail: "No route matches #{request.method} #{request.path}")
  end
end
