class UpdateUsdToEurJob < ApplicationJob
  queue_as :scheduled

  def perform
    Rails.logger.info("Starting USD to EUR exchange rate update")

    begin
      # Forzar actualización del tipo de cambio USD a EUR usando AlphaVantage
      rate = ExchangeRate.update_usd_to_eur_rate!

      if rate.present?
        Rails.logger.info("Successfully updated USD to EUR rate: #{rate.rate} for date #{rate.date}")
      else
        Rails.logger.error("Failed to fetch USD to EUR exchange rate - provider may not be configured")
      end
    rescue Provider::Error => e
      Rails.logger.error("Provider error updating USD to EUR exchange rate: #{e.message}")
      # No re-raise provider errors to avoid job failure
    rescue StandardError => e
      Rails.logger.error("Error updating USD to EUR exchange rate: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise e
    end
  end
end
