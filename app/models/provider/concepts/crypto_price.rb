module Provider::Concepts::CryptoPrice
  extend ActiveSupport::Concern

  Price = Data.define(:symbol, :price, :currency, :timestamp)

  def fetch_crypto_price(symbol:, currency: "USD", date: Date.current)
    raise NotImplementedError, "Subclasses must implement #fetch_crypto_price"
  end
end 