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

  private

  def refresh_spot_price
    return unless symbol.present?

    currency = account&.family&.currency || "USD"
    price_data = CryptoPrice.current_price(symbol: symbol, currency: currency)
    
    if price_data
      update_columns(
        spot_price_cents: (price_data.price * 100).to_i,
        spot_price_currency: price_data.currency
      )
    end
  rescue Provider::Error => e
    Rails.logger.error("Crypto price error for #{symbol}: #{e.message}")
  end
end
