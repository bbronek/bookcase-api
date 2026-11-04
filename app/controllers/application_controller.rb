class ApplicationController < ActionController::API
  rescue_from ActionController::ParameterMissing do |error|
    render_error :bad_request, error.message
  end

  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error :not_found, "#{error.model} not found"
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error :unprocessable_content, "Validation failed", details: error.record.errors.to_hash
  end

  rescue_from ActiveRecord::RecordNotDestroyed do |error|
    render_error :conflict, error.record.errors.full_messages.to_sentence
  end

  rescue_from Book::InvalidTransition do |error|
    render_error :conflict, error.message
  end

  private

  def render_error(status, message, details: nil)
    render json: { error: message, details: }.compact, status:
  end
end
