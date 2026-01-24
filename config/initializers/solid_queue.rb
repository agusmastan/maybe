# Solid Queue configuration (replaces Sidekiq)
# Mission Control provides the web UI for monitoring jobs at /jobs

Rails.application.configure do
  # Configure Solid Queue to use the queue database
  config.solid_queue.connects_to = { database: { writing: :queue } }
end
