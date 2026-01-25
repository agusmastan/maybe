# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

rails_env = ENV.fetch("RAILS_ENV", "development")

# =============================================================================
# LOW-MEMORY OPTIMIZATION (NAS / Self-Hosting)
# =============================================================================
# For personal use on low-memory devices (1GB RAM NAS):
# - Set WEB_CONCURRENCY=0 (no forked workers, single process)
# - Set RAILS_MAX_THREADS=3 (minimal threads)
# - Set SOLID_QUEUE_IN_PUMA=true (run background jobs in same process)
#
# This reduces memory from ~600-800MB to ~300-350MB
# =============================================================================

# Thread configuration
# For low-memory: use fewer threads (3)
# For high-traffic: increase threads (5-10)
max_threads = ENV.fetch("RAILS_MAX_THREADS") { 3 }
min_threads = ENV.fetch("RAILS_MIN_THREADS") { max_threads }
threads min_threads, max_threads

if rails_env == "production"
  # Worker processes (WEB_CONCURRENCY)
  # Set to 0 for single-process mode (low-memory NAS)
  # Set to number of CPU cores for high-traffic deployments
  workers_count = Integer(ENV.fetch("WEB_CONCURRENCY") { 0 })
  workers workers_count if workers_count > 0

  # Preload app for faster worker spawning (only if using workers)
  preload_app! if workers_count > 0

  # Run Solid Queue inside Puma for low-memory deployments
  # This eliminates the need for a separate worker process
  if ENV["SOLID_QUEUE_IN_PUMA"] == "true"
    plugin :solid_queue
  end
end

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment rails_env

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

if rails_env == "development"
  # Specifies a very generous `worker_timeout` so that the worker
  # isn't killed by Puma when suspended by a debugger.
  worker_timeout 3600
end
