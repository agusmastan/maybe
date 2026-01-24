# Mission Control Jobs configuration
# Web UI for monitoring Solid Queue background jobs at /jobs

Rails.application.configure do
  # Protect the Mission Control dashboard with HTTP Basic Auth in production
  config.mission_control.jobs.http_basic_auth_enabled = Rails.env.production?
  config.mission_control.jobs.http_basic_auth_user = ENV.fetch("JOBS_WEB_USERNAME", "maybe")
  config.mission_control.jobs.http_basic_auth_password = ENV.fetch("JOBS_WEB_PASSWORD", "maybe")
end
