module Provider::Concepts::StockPrice
  extend ActiveSupport::Concern

  Price = Data.define(:symbol, :price, :currency, :timestamp)

  def fetch_stock_price(symbol:, to_currency: "EUR")
    raise NotImplementedError, "Subclasses must implement #fetch_stock_price"
  end
end


