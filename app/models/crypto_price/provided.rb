module CryptoPrice::Provided
  extend ActiveSupport::Concern

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:crypto_prices)
      registry.get_provider(:alpha_vantage)
    end

    def current_price(symbol:, currency: "EUR")
      return nil unless provider.present? # No provider configured (some self-hosted apps)

      # Cache for 5 minutes to avoid excessive API calls
      Rails.cache.fetch("crypto_price_#{symbol}_#{currency}", expires_in: 5.minutes) do
        response = provider.fetch_crypto_price(symbol: symbol, currency: currency)

        if response.success?
          response.data
        else
          Rails.logger.warn("Failed to fetch crypto price for #{symbol}: #{response.error.message}")
          nil
        end
      end
    end
  end
end 