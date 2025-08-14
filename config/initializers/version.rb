module Maybe
  class << self
    def version
      Semver.new(semver)
    end

    def commit_sha
      # Use BUILD_COMMIT_SHA if available, otherwise try git
      if ENV["BUILD_COMMIT_SHA"].present?
        ENV["BUILD_COMMIT_SHA"]
      else
        begin
          `git rev-parse HEAD 2>/dev/null`.chomp if system("which git > /dev/null 2>&1")
        rescue => e
          Rails.logger.warn "Could not determine git commit SHA: #{e.message}"
          nil
        end
      end
    end

    private
      def semver
        "0.6.0"
      end
  end
end
