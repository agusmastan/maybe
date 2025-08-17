# Opción para deshabilitar temporalmente la importación de datos históricos
# Modificar ImportMarketDataJob para saltear securities si no hay provider premium

# En app/jobs/import_market_data_job.rb
class ImportMarketDataJob < ApplicationJob
  queue_as :scheduled

  def perform(opts)
    return if Rails.env.development?

    opts = opts.symbolize_keys
    mode = opts.fetch(:mode, :full)
    clear_cache = opts.fetch(:clear_cache, false)

    # Solo importar exchange rates, saltear securities por limitaciones de Finnhub free
    importer = MarketDataImporter.new(mode: mode, clear_cache: clear_cache)
    
    # Solo importar tipos de cambio
    importer.import_exchange_rates
    
    # Saltear securities hasta tener plan premium o provider alternativo
    Rails.logger.info("Skipping security prices import due to Finnhub free plan limitations")
  end
end

# O modificar MarketDataImporter para manejar la limitación
class MarketDataImporter
  def import_security_prices
    unless Security.provider
      Rails.logger.warn("No provider configured for MarketDataImporter.import_security_prices, skipping sync")
      return
    end

    # Verificar si tenemos capacidad para datos históricos
    if Security.provider.is_a?(Provider::Finnhub) && !finnhub_premium?
      Rails.logger.warn("Finnhub free plan detected, skipping historical data import")
      return
    end

    # Continuar con importación normal...
    Security.online.find_each do |security|
      security.import_provider_prices(
        start_date: get_first_required_price_date(security),
        end_date: end_date,
        clear_cache: clear_cache
      )

      security.import_provider_details(clear_cache: clear_cache)
    end
  end

  private

  def finnhub_premium?
    # Podrías añadir lógica para detectar si tienes plan premium
    # Por ejemplo, variable de entorno o setting
    ENV['FINNHUB_PREMIUM'] == 'true' || Setting.finnhub_premium == true
  end
end
