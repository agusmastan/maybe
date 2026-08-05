# frozen_string_literal: true

# No-op Sentry stub for when sentry-ruby gem is not loaded.
# Prevents NameError in the many places the app calls Sentry.capture_exception, etc.
unless defined?(Sentry)
  module Sentry
    def self.capture_exception(_error, **_opts)
      yield self if block_given?
      nil
    end

    def self.capture_message(_message, **_opts)
      nil
    end

    def self.set_user(_hash)
      nil
    end

    def self.set_tags(_hash)
      nil
    end

    def self.configure_scope
      yield self if block_given?
    end

    def self.with_scope
      yield self if block_given?
    end
  end
end
