Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.headers = { "cache-control" => "public, max-age=300" }

  config.assume_ssl = true
  config.force_ssl = true
  config.hosts = ENV.fetch("APP_HOSTS").split(",")

  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_tags = [ :request_id ]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/health"
  config.action_dispatch.log_rescued_responses = false

  config.active_job.queue_adapter = :solid_queue
  config.action_mailer.logger = ActiveSupport::Logger.new(STDOUT, level: :warn)
  config.action_mailer.default_options = { from: ENV.fetch("MAILER_FROM") }
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true,
    open_timeout: 5,
    read_timeout: 10
  }.compact

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
  config.active_support.report_deprecations = false
end
