require "redis"

redis_url = ENV.fetch("REDIS_URL", "redis://redis:6379/1")

# Skip connectivity check during asset precompilation or when explicitly disabled.
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

# Configure Redis as the cache store
Rails.application.config.cache_store = :redis_cache_store, { url: redis_url }