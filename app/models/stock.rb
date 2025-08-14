class Stock < ApplicationRecord
  include Accountable, Monetizable
  include StockPrice::Provided

  monetize :spot_price_cents, with_currency: :spot_price_currency, allow_nil: true

  validates :ticker, presence: true, if: -> { ticker.present? }

  after_commit :refresh_spot_price, on: :create

  class << self
    def color
      "#0ea5e9"
    end

    def classification
      "asset"
    end

    def icon
      "chart-candlestick"
    end

    def display_name
      "Stocks"
    end
  end

  def current_spot_price_money
    return nil unless spot_price_cents.present? && spot_price_currency.present?
    Money.new(spot_price_cents, spot_price_currency)
  end

  # Public wrapper to refresh current spot price on-demand
  def refresh_spot_price_now!
    refresh_spot_price
  end

  private
    def refresh_spot_price
      return unless ticker.present?

      to_currency = account&.family&.currency || "EUR"
      Rails.logger.info("Refreshing stock price for #{ticker} in #{to_currency}")

      price_data = StockPrice.current_price(symbol: ticker, currency: to_currency)

      if price_data
        Rails.logger.info("Got price for #{ticker}: #{price_data.price} #{price_data.currency}")
        update!(
          spot_price_cents: (price_data.price * 100).to_i,
          spot_price_currency: price_data.currency
        )
      else
        Rails.logger.warn("No price data returned for #{ticker}")
      end
    rescue Provider::Error => e
      Rails.logger.error("Stock price error for #{ticker}: #{e.message}")
    rescue => e
      Rails.logger.error("Unexpected error refreshing stock price for #{ticker}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
end


