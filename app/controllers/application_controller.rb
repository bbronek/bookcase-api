class ApplicationController < ActionController::API
  include ProblemDetails

  wrap_parameters false
end
