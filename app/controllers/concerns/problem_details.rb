module ProblemDetails
  extend ActiveSupport::Concern

  DATABASE_DOWN = [ ActiveRecord::ConnectionNotEstablished ].freeze
  DATABASE_BUSY = [
    ActiveRecord::ConnectionTimeoutError, ActiveRecord::LockWaitTimeout, ActiveRecord::QueryCanceled, ActiveRecord::Deadlocked
  ].freeze

  included do
    rescue_from ActionController::BadRequest, with: :render_bad_request
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_malformed_json
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from DomainError::Invalid, with: :render_invalid_attribute
    rescue_from DomainError::Conflict, with: :render_conflict
    rescue_from(*DATABASE_DOWN, with: :render_database_down)
    rescue_from(*DATABASE_BUSY, with: :render_database_busy)
  end

  private

  def render_bad_request(error) = render_problem(:bad_request, detail: error.message)

  def render_malformed_json = render_problem(:bad_request, detail: "Request body is not valid JSON")

  def render_not_found(error) = render_problem(:not_found, detail: "#{error.model} not found")

  def render_record_invalid(error)
    render_validation_problem(error.record.errors.map { |failure| [ failure.attribute, failure.message ] })
  end

  def render_invalid_attribute(error) = render_validation_problem([ [ error.attribute, error.message ] ])

  def render_conflict(error) = render_problem(:conflict, type: error.problem_type, detail: error.message)

  def render_database_down(error) = render_database_error(error, "The database is unavailable; retry shortly")

  def render_database_busy(error) = render_database_error(error, "The database is busy; retry shortly")

  def render_database_error(error, detail)
    Rails.logger.error("Database error: #{error.class}: #{error.message}")
    response.set_header("Retry-After", "5")
    render_problem(:service_unavailable, detail:)
  end

  def render_validation_problem(failures)
    render_problem :unprocessable_content,
      type: DomainError::Invalid.problem_type,
      detail: "The request has invalid attributes",
      errors: failures.map { |attribute, message| { pointer: "#/#{attribute}", detail: message } }
  end

  def render_problem(status, type: nil, detail: nil, errors: nil)
    code = Rack::Utils.status_code(status)
    problem = Problem.document(
      status: code, type:, detail:, errors:, instance: request.path, request_id: request.request_id
    )
    render json: problem, status: code, content_type: Problem::MEDIA_TYPE
  end
end
