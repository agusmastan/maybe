# Solución híbrida: Finnhub + AlphaVantage
# Usar Finnhub para info/búsqueda, AlphaVantage para precios históricos

# En app/models/security/provided.rb - añadir método para provider híbrido
module Security::Provided
  extend ActiveSupport::Concern

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:securities)
      registry.get_provider(:finnhub)
    end

    # Nuevo método para datos históricos
    def historical_price_provider
      registry = Provider::Registry.for_concept(:securities)
      # Intentar AlphaVantage primero, fallback a Finnhub
      registry.get_provider(:alpha_vantage) || registry.get_provider(:finnhub)
    end
  end

  # Modificar import_provider_prices para usar provider híbrido
  def import_provider_prices(start_date:, end_date:, clear_cache: false)
    # Usar AlphaVantage para datos históricos si está disponible
    price_provider = self.class.historical_price_provider
    
    unless price_provider.present?
      Rails.logger.warn("No provider configured for Security.import_provider_prices")
      return 0
    end

    Security::Price::Importer.new(
      security: self,
      security_provider: price_provider,
      start_date: start_date,
      end_date: end_date,
      clear_cache: clear_cache
    ).import_provider_prices
  end
end
