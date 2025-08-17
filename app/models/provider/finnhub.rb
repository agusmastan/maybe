class Provider::Finnhub < Provider
  include Provider::Concepts::CryptoPrice
  include Provider::Concepts::StockPrice
  include Provider::SecurityConcept

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

  # ================================
  # SECURITIES METHODS (for hybrid solution) - PUBLIC METHODS
  # ================================

  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      # Finnhub doesn't have a direct search endpoint, but we can use symbol lookup
      # We'll use the stock symbol endpoint to find US stocks primarily
      exchange = exchange_operating_mic || "US"
      
      response = client.get("#{rest_base}/stock/symbol") do |req|
        req.params["exchange"] = exchange
        req.params["token"] = api_key
      end
      
      data = JSON.parse(response.body)
      
      if data.is_a?(Hash) && data["error"]
        raise Error.new("Finnhub error: #{data['error']}")
      end
      
      # Filter symbols that match our search
      matching_symbols = data.select do |stock|
        stock["symbol"]&.downcase&.include?(symbol.downcase) ||
        stock["description"]&.downcase&.include?(symbol.downcase)
      end
      
      matching_symbols.first(25).map do |stock|
        Provider::SecurityConcept::Security.new(
          symbol: stock["symbol"],
          name: stock["description"],
          logo_url: nil,
          exchange_operating_mic: exchange_operating_mic || "XNAS",
          country_code: country_code || "US"
        )
      end
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      # Use Finnhub company profile endpoint
      response = client.get("#{rest_base}/stock/profile2") do |req|
        req.params["symbol"] = symbol
        req.params["token"] = api_key
      end
      
      data = JSON.parse(response.body)
      
      if data.is_a?(Hash) && data["error"]
        raise Error.new("Finnhub error: #{data['error']}")
      end
      
      if data.empty? || data["name"].blank?
        raise Error.new("No company info found for #{symbol}")
      end
      
      Provider::SecurityConcept::SecurityInfo.new(
        symbol: symbol,
        name: data["name"],
        links: { website: data["weburl"] },
        logo_url: data["logo"],
        description: nil, # Finnhub doesn't provide description in profile2
        kind: "stock",
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic:, date:)
    with_provider_response do
      # Finnhub /quote solo proporciona precios actuales
      # Para fechas pasadas, debería usar AlphaVantage (datos históricos)
      if date < Date.current
        Rails.logger.warn("Finnhub /quote only provides current prices. For historical prices (#{date}), use AlphaVantage provider.")
        raise Error, "Finnhub /quote only provides current prices. For date #{date}, use AlphaVantage provider."
      end
      
      # Use current quote endpoint for latest price
      response = client.get("#{rest_base}/quote") do |req|
        req.params["symbol"] = symbol
        req.params["token"] = api_key
      end
      
      data = JSON.parse(response.body)
      
      if data.is_a?(Hash) && data["error"]
        raise Error.new("Finnhub error: #{data['error']}")
      end
      
      if data["c"].nil?
        raise Error.new("No price data found for #{symbol}")
      end
      
      Provider::SecurityConcept::Price.new(
        symbol: symbol,
        date: Date.current, # Finnhub quote is always current (today)
        price: data["c"].to_f,
        currency: "USD",
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic:, start_date:, end_date:)
    with_provider_response do
      # ⚠️ LIMITACIÓN: /stock/candle requiere plan premium en Finnhub
      # En solución híbrida, este método no se usará - AlphaVantage maneja datos históricos
      Rails.logger.warn("Finnhub /stock/candle requires premium plan. In hybrid solution, use AlphaVantage for historical data.")
      raise Error, "Finnhub historical data requires premium plan. Use AlphaVantage provider for historical prices."
    end
  end

  private
    attr_reader :api_key

    def rest_base
      "https://finnhub.io/api/v1"
    end

      def fetch_quote_price(symbol)
    # GET /quote?symbol=AAPL
    resp = client.get("#{rest_base}/quote") do |req|
      req.params["symbol"] = symbol
      req.params["token"] = api_key
    end
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

    def client
      @client ||= Faraday.new do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })
        faraday.response :raise_error
      end
    end
end


