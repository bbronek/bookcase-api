class HealthController < ApplicationController
  before_action { response.set_header("Cache-Control", "no-store") }

  def show
    ActiveRecord::Base.with_connection { |connection| connection.select_value("SELECT 1") }
    render json: { status: "ok" }
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.error("Health check failed: #{error.class}: #{error.message}")
    response.set_header("Retry-After", "5")
    render json: { status: "unavailable" }, status: :service_unavailable
  end
end
