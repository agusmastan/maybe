# Redis configuration (optional - only used if REDIS_URL is set)
# For NAS/low-memory deployments, Solid Cache replaces Redis for caching

if ENV["REDIS_URL"].present?
  require "redis"
  
  redis_url = ENV["REDIS_URL"]

  # Skip connectivity check during asset precompilation
  skip_connectivity_check = ENV["SECRET_KEY_BASE_DUMMY"].present? ||
    ENV["SKIP_REDIS_CHECK"] == "1" ||
    (defined?(Rake) && Rake.respond_to?(:application) &&
      Rake.application.top_level_tasks.any? { |t| t.to_s.start_with?("assets:") })

  unless skip_connectivity_check
    begin
      redis = Redis.new(url: redis_url)
      redis.ping
      Rails.logger.info "Connected to Redis at #{redis_url}"
    rescue Redis::CannotConnectError => e
      Rails.logger.error "Could not connect to Redis at #{redis_url}: #{e.message}"
      raise e
    end
  end

  # Use Redis for caching when available
  Rails.application.config.cache_store = :redis_cache_store, { url: redis_url }
else
  Rails.logger.info "Redis not configured - using Solid Cache"
end