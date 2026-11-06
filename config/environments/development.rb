Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = false
  config.server_timing = true

  config.action_mailer.delivery_method = :file
  config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false

  config.active_job.queue_adapter = :solid_queue
  config.active_job.verbose_enqueue_logs = true

  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true

  config.active_support.deprecation = :log
  config.action_dispatch.verbose_redirect_logs = true
  config.action_controller.raise_on_missing_callback_actions = true

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "debug")
  config.silence_healthcheck_path = "/health"

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    config.logger = ActiveSupport::Logger.new($stdout).tap { |logger| logger.formatter = Logger::Formatter.new }
  end
end
