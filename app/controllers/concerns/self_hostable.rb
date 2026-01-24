module SelfHostable
  extend ActiveSupport::Concern

  included do
    helper_method :self_hosted?, :self_hosted_first_login?

    # Redis verification is optional - only needed when using Redis
    # NAS deployments use Solid Stack (PostgreSQL) instead of Redis
    prepend_before_action :verify_self_host_config, if: -> { redis_required? }
  end

  private
    def self_hosted?
      Rails.configuration.app_mode.self_hosted?
    end

    def self_hosted_first_login?
      self_hosted? && User.count.zero?
    end

    # Redis is only required if REDIS_URL is configured
    # When using Solid Stack, Redis is not needed
    def redis_required?
      self_hosted? && ENV["REDIS_URL"].present?
    end

    def verify_self_host_config
      unless redis_connected?
        redirect_to redis_configuration_error_path
      end
    end

    def redis_connected?
      return true unless defined?(Redis)
      Redis.new(url: ENV["REDIS_URL"]).ping
      true
    rescue Redis::CannotConnectError
      false
    rescue => e
      Rails.logger.warn("Redis connection check failed: #{e.message}")
      false
    end
end
