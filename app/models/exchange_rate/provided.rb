module ExchangeRate::Provided
  extend ActiveSupport::Concern

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:exchange_rates)
      registry.get_provider(:alpha_vantage)
    end

    def find_or_fetch_rate(from:, to:, date: Date.current, cache: true)
      # Primero buscar en la tabla local
      rate = find_by(from_currency: from, to_currency: to, date: date)
      return rate if rate.present?

      # Para USD -> EUR, también buscar tasas recientes si no hay una para la fecha exacta
      if from.upcase == "USD" && to.upcase == "EUR"
        recent_rate = where(from_currency: from, to_currency: to)
                     .where("date >= ?", 7.days.ago)
                     .order(date: :desc)
                     .first
        
        if recent_rate.present?
          Rails.logger.info("Using recent USD->EUR rate from #{recent_rate.date} (#{recent_rate.rate}) for date #{date}")
          return recent_rate
        end
      end

      return nil unless provider.present? # No provider configured (some self-hosted apps)

      response = provider.fetch_exchange_rate(from: from, to: to, date: date)

      return nil unless response.success? # Provider error

      rate_data = response.data
      rate = ExchangeRate.find_or_create_by!(
        from_currency: rate_data.from,
        to_currency: rate_data.to,
        date: rate_data.date,
        rate: rate_data.rate
      ) if cache
      
      rate || rate_data
    end

    # @return [Integer] The number of exchange rates synced
    def import_provider_rates(from:, to:, start_date:, end_date:, clear_cache: false)
      unless provider.present?
        Rails.logger.warn("No provider configured for ExchangeRate.import_provider_rates")
        return 0
      end

      ExchangeRate::Importer.new(
        exchange_rate_provider: provider,
        from: from,
        to: to,
        start_date: start_date,
        end_date: end_date,
        clear_cache: clear_cache
      ).import_provider_rates
    end

    # Método específico para actualizar USD->EUR
    def update_usd_to_eur_rate!
      return nil unless provider.present?

      Rails.logger.info("Forcing update of USD to EUR exchange rate")
      
      response = provider.fetch_exchange_rate(from: "USD", to: "EUR", date: Date.current)
      
      return nil unless response.success?

      rate_data = response.data
      rate = ExchangeRate.find_or_create_by!(
        from_currency: rate_data.from,
        to_currency: rate_data.to,
        date: rate_data.date
      ) do |new_rate|
        new_rate.rate = rate_data.rate
      end

      # Actualizar si ya existe pero con diferente tasa
      if rate.persisted? && rate.rate != rate_data.rate
        rate.update!(rate: rate_data.rate)
        Rails.logger.info("Updated existing USD->EUR rate for #{rate_data.date}: #{rate_data.rate}")
      end

      rate
    end
  end
end
