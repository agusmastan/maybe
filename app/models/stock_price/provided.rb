module StockPrice::Provided
  extend ActiveSupport::Concern

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:securities)
      preferred = (ENV["PRICE_PROVIDER_STOCKS"] || "").presence&.to_sym
      if preferred.present?
        return registry.get_provider(preferred)
      end
      # Por defecto Alpha Vantage
      registry.get_provider(:alpha_vantage)
    end

    def current_price(symbol:, currency: "EUR")
      return nil unless provider.present?

      Rails.cache.fetch("stock_price_#{symbol}_#{currency}", expires_in: 5.minutes) do
        response = provider.fetch_stock_price(symbol: symbol, to_currency: currency)

        if response.success?
          response.data
        else
          Rails.logger.warn("Failed to fetch stock price for #{symbol}: #{response.error.message}")
          nil
        end
      end
    end
  end
end


