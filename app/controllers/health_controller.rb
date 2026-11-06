class HealthController < ApplicationController
  before_action { response.set_header("Cache-Control", "no-store") }

  def live
    render json: { status: "ok" }
  end

  def ready
    database = database_status
    healthy = database == "ok"
    response.set_header("Retry-After", "5") unless healthy

    render json: { status: healthy ? "ok" : "unavailable", uptime:, checks: { database: } },
           status: healthy ? :ok : :service_unavailable
  end

  private

  def database_status
    ActiveRecord::Base.with_connection { |connection| connection.select_value("SELECT 1") }
    "ok"
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.error("Readiness check failed: database: #{error.class}: #{error.message}")
    "error"
  end

  def uptime = (Time.current - Rails.configuration.x.booted_at).round(1)
end
