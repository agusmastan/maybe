module Security::Provided
  extend ActiveSupport::Concern

  SecurityInfoMissingError = Class.new(StandardError)

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:securities)
      registry.get_provider(:finnhub)
    end

    # Provider híbrido: AlphaVantage para datos históricos, fallback a Finnhub
    def historical_price_provider
      registry = Provider::Registry.for_concept(:securities)
      # Intentar AlphaVantage primero (tiene datos históricos gratuitos)
      registry.get_provider(:alpha_vantage) || registry.get_provider(:finnhub)
    end

    # Provider para precios ACTUALES: Finnhub primero (mejor rate limit: 60/min vs 25/día)
    def current_price_provider
      registry = Provider::Registry.for_concept(:securities)
      # Finnhub: 60 requests/minuto vs AlphaVantage: 25 requests/día
      registry.get_provider(:finnhub) || registry.get_provider(:alpha_vantage)
    end

    # Provider para información: Finnhub primero, fallback a AlphaVantage
    def info_provider
      registry = Provider::Registry.for_concept(:securities)
      # Finnhub tiene mejor info de empresas
      registry.get_provider(:finnhub) || registry.get_provider(:alpha_vantage)
    end

    def search_provider(symbol, country_code: nil, exchange_operating_mic: nil)
      return [] if provider.nil? || symbol.blank?

      params = {
        country_code: country_code,
        exchange_operating_mic: exchange_operating_mic
      }.compact_blank

      response = provider.search_securities(symbol, **params)

      if response.success?
        response.data.map do |provider_security|
          # Need to map to domain model so Combobox can display via to_combobox_option
          Security.new(
            ticker: provider_security.symbol,
            name: provider_security.name,
            logo_url: provider_security.logo_url,
            exchange_operating_mic: provider_security.exchange_operating_mic,
            country_code: provider_security.country_code
          )
        end
      else
        []
      end
    end
  end

  def find_or_fetch_price(date: Date.current, cache: true)
    price = prices.find_by(date: date)

    return price if price.present?

    # ⚠️ SOLO permitir fetch de precios ACTUALES para ahorrar tokens de API
    is_current_price = date >= Date.current
    
    unless is_current_price
      Rails.logger.info("⏭️  Historical price fetch DISABLED for #{ticker} on #{date} to save API tokens")
      return nil # No hacer llamada histórica
    end
    
    # Solo para precios actuales, usar Finnhub (mejor rate limit: 60/min vs 25/día)
    price_provider = self.class.current_price_provider
    
    return nil unless price_provider.present?

    Rails.logger.info("Using #{price_provider.class.name} for CURRENT price: #{ticker} on #{date}")
    
    response = price_provider.fetch_security_price(
      symbol: ticker,
      exchange_operating_mic: exchange_operating_mic,
      date: date
    )

    return nil unless response.success? # Provider error

    price = response.data
    
    if cache
      # Buscar o crear el registro, actualizando el precio si ya existe
      db_price = Security::Price.find_or_initialize_by(
        security_id: self.id,
        date: price.date
      )
      
      # Actualizar el precio y moneda (tanto si es nuevo como si ya existe)
      db_price.price = price.price
      db_price.currency = price.currency
      db_price.save!
      
      Rails.logger.info("💾 Saved price for #{ticker}: #{price.price} #{price.currency} on #{price.date}")
    end
    
    price
  end

  def import_provider_details(clear_cache: false)
    # Usar info_provider (Finnhub primero, fallback AlphaVantage)
    provider = self.class.info_provider
    
    unless provider.present?
      Rails.logger.warn("No provider configured for Security.import_provider_details")
      return
    end

    if self.name.present? && self.logo_url.present? && !clear_cache
      return
    end

    Rails.logger.info("Using #{provider.class.name} for security info: #{ticker}")
    
    response = provider.fetch_security_info(
      symbol: ticker,
      exchange_operating_mic: exchange_operating_mic
    )

    if response.success?
      update(
        name: response.data.name,
        logo_url: response.data.logo_url,
      )
    else
      Rails.logger.warn("Failed to fetch security info for #{ticker} from #{provider.class.name}: #{response.error.message}")
      Sentry.capture_exception(SecurityInfoMissingError.new("Failed to get security info"), level: :warning) do |scope|
        scope.set_tags(security_id: self.id)
        scope.set_context("security", { id: self.id, provider_error: response.error.message })
      end
    end
  end

  def import_provider_prices(start_date:, end_date:, clear_cache: false)
    # ⚠️ DESACTIVADO: Importación histórica deshabilitada para ahorrar tokens de API
    Rails.logger.info("⏭️  Historical price import DISABLED for #{ticker} to save API tokens")
    return 0
    
    # CÓDIGO ORIGINAL (comentado):
    # price_provider = self.class.historical_price_provider
    # 
    # unless price_provider.present?
    #   Rails.logger.warn("No provider configured for Security.import_provider_prices")
    #   return 0
    # end
    #
    # Rails.logger.info("Using #{price_provider.class.name} for historical prices: #{ticker}")
    #
    # Security::Price::Importer.new(
    #   security: self,
    #   security_provider: price_provider,
    #   start_date: start_date,
    #   end_date: end_date,
    #   clear_cache: clear_cache
    # ).import_provider_prices
  end

  private
    def provider
      self.class.provider
    end
end
