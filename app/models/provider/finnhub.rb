class Provider::Finnhub < Provider
  include Provider::Concepts::CryptoPrice
  include Provider::Concepts::StockPrice

  Error = Class.new(Provider::Error)

  def initialize(api_key)
    @api_key = api_key
  end

  # REST fallback to get last price (Finnhub provides quote endpoints). For WS, un job se encargará de cachear.
  def fetch_stock_price(symbol:, to_currency: "EUR")
    with_provider_response do
      last_price = fetch_quote_price(symbol)

      currency = to_currency.upcase
      price = if currency == "USD"
        last_price
      else
        # Convertir usando Alpha Vantage si está disponible; si no, retorna USD
        convert_usd_to(currency, last_price)
      end

      Provider::Concepts::StockPrice::Price.new(
        symbol: symbol.upcase,
        price: price,
        currency: currency == "USD" ? "USD" : currency,
        timestamp: Time.current
      )
    end
  end

  def fetch_crypto_price(symbol:, currency: "EUR", date: Date.current)
    with_provider_response do
      # Usar BINANCE:SYMBOLUSDT por defecto si no hay prefijo
      mapped = symbol.include?(":") ? symbol : "BINANCE:#{symbol.upcase}USDT"
      last_price = fetch_quote_price(mapped)

      target_currency = currency.upcase
      price = if target_currency == "USD"
        last_price
      else
        convert_usd_to(target_currency, last_price)
      end

      Provider::Concepts::CryptoPrice::Price.new(
        symbol: symbol.upcase,
        price: price,
        currency: target_currency == "USD" ? "USD" : target_currency,
        timestamp: Time.current
      )
    end
  end

  private
    attr_reader :api_key

    def rest_base
      "https://finnhub.io/api/v1"
    end

    def fetch_quote_price(symbol)
      # GET /quote?symbol=AAPL
      resp = Faraday.get("#{rest_base}/quote", { symbol: symbol, token: api_key })
      data = JSON.parse(resp.body)
      # Finnhub /quote devuelve:
      # c: Current price
      # pc: Previous close
      price = data["c"].to_f
      raise Error, "No price for #{symbol}" if price <= 0
      price
    end

    def convert_usd_to(to_currency, amount)
      return amount if to_currency == "USD"
      alpha = Provider::Registry.get_provider(:alpha_vantage)
      raise Error, "No FX provider available" unless alpha
      fx = alpha.send(:parse_fx_rate, Faraday.get("https://www.alphavantage.co/query", {
        function: "CURRENCY_EXCHANGE_RATE",
        from_currency: "USD",
        to_currency: to_currency,
        apikey: alpha.send(:api_key)
      }).body)
      amount * fx
    end

    # Eliminado: resolución multi-exchange; usamos BINANCE por defecto para evitar 0.0
end


