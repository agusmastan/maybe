class Crypto < ApplicationRecord
  include Accountable, Monetizable
  include CryptoPrice::Provided

  monetize :spot_price_cents, with_currency: :spot_price_currency, allow_nil: true

  validates :symbol, presence: true, if: -> { symbol.present? }

  after_commit :refresh_spot_price, on: :create

  class << self
    def color
      "#737373"
    end

    def classification
      "asset"
    end

    def icon
      "bitcoin"
    end

    def display_name
      "Crypto"
    end
  end

  def current_spot_price_money
    return nil unless spot_price_cents.present? && spot_price_currency.present?
    Money.new(spot_price_cents, spot_price_currency)
  end

  # Public wrapper to refresh current spot price on-demand (e.g., via UI refresh button)
  def refresh_spot_price_now!
    refresh_spot_price
  end

  private

  def refresh_spot_price
    return unless symbol.present?

    currency = account&.family&.currency || "USD"
    Rails.logger.info("Refreshing crypto price for #{symbol} in #{currency}")
    
    price_data = CryptoPrice.current_price(symbol: symbol, currency: currency)
    
    if price_data
      Rails.logger.info("Got price for #{symbol}: #{price_data.price} #{price_data.currency}")
      update!(
        spot_price_cents: (price_data.price * 100).to_i,
        spot_price_currency: price_data.currency
      )
    else
      Rails.logger.warn("No price data returned for #{symbol}")
    end
  rescue Provider::Error => e
    Rails.logger.error("Crypto price error for #{symbol}: #{e.message}")
    # No lanzar el error para permitir que la creación continúe
  rescue => e
    Rails.logger.error("Unexpected error refreshing crypto price for #{symbol}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end
