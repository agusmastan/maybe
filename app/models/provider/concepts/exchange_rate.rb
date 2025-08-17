module Provider::Concepts::ExchangeRate
  extend ActiveSupport::Concern

  Rate = Data.define(:from, :to, :rate, :date)

  def fetch_exchange_rate(from:, to:, date: Date.current)
    raise NotImplementedError, "Subclasses must implement #fetch_exchange_rate"
  end
end
