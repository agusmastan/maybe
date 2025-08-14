class Provider::AlphaVantage < Provider
  include Provider::Concepts::CryptoPrice
  include Provider::Concepts::StockPrice
  
  # Subclass so errors caught in this provider are raised as Provider::AlphaVantage::Error
  Error = Class.new(Provider::Error)
  InvalidCryptoPriceError = Class.new(Error)
  RateLimitError = Class.new(Error)
  
  def initialize(api_key)
    @api_key = api_key
  end
  
  def healthy?
    with_provider_response do
      # Hacer una llamada de prueba para verificar conectividad
      fetch_crypto_price(symbol: "BTC", currency: "EUR")
      true
    end
  end
  
  # Implementar método requerido por CryptoPrice concept
  def fetch_crypto_price(symbol:, currency: "EUR", date: Date.current)
    with_provider_response do
      response = client.get(base_url) do |req|
        req.params["function"] = "CURRENCY_EXCHANGE_RATE"
        req.params["from_currency"] = symbol.upcase
        req.params["to_currency"] = currency.upcase
        req.params["apikey"] = api_key
      end
      
      parse_crypto_response(response.body, symbol, currency)
    end
  end

  # Stocks: fetch latest close in USD from TIME_SERIES_DAILY, then convert to desired currency using CURRENCY_EXCHANGE_RATE
  def fetch_stock_price(symbol:, to_currency: "EUR")
    with_provider_response do
      # 1) Get daily series (USD)
      daily_resp = client.get(base_url) do |req|
        req.params["function"] = "TIME_SERIES_DAILY"
        req.params["symbol"] = symbol.upcase
        req.params["apikey"] = api_key
      end

      usd_price, date = parse_stock_daily_close(daily_resp.body)

      # 2) Convert USD->to_currency if needed
      final_price = usd_price
      final_currency = "USD"
      if to_currency.upcase != "USD"
        fx_resp = client.get(base_url) do |req|
          req.params["function"] = "CURRENCY_EXCHANGE_RATE"
          req.params["from_currency"] = "USD"
          req.params["to_currency"] = to_currency.upcase
          req.params["apikey"] = api_key
        end
        rate = parse_fx_rate(fx_resp.body)
        final_price = usd_price * rate
        final_currency = to_currency.upcase
      end

      StockPrice::Price.new(
        symbol: symbol.upcase,
        price: final_price,
        currency: final_currency,
        timestamp: date
      )
    end
  end
  
  private
  
  attr_reader :api_key
  
  def base_url
    "https://www.alphavantage.co/query"
  end
  
  def client
    @client ||= Faraday.new(url: base_url) do |faraday|
      faraday.request(:retry, {
        max: 2,
        interval: 0.05,
        interval_randomness: 0.5,
        backoff_factor: 2
      })
      faraday.response :raise_error
    end
  end
  
  def parse_crypto_response(body, symbol, currency)
    data = JSON.parse(body)

    # Verificar errores específicos de Alpha Vantage
    if data.key?("Error Message")
      raise InvalidCryptoPriceError.new("Alpha Vantage error: #{data['Error Message']}")
    end

    if data.key?("Note")
      # Alpha Vantage retorna "Note" cuando se alcanza el rate limit
      raise RateLimitError.new("Alpha Vantage rate limit exceeded: #{data['Note']}")
    end

    if data.key?("Information")
      # Otro tipo de mensaje informativo que puede indicar problemas
      raise InvalidCryptoPriceError.new("Alpha Vantage info: #{data['Information']}")
    end

    # Formato de CURRENCY_EXCHANGE_RATE
    rate_block = data.dig("Realtime Currency Exchange Rate")
    unless rate_block.is_a?(Hash)
      raise InvalidCryptoPriceError.new("No exchange rate data found for #{symbol} in #{currency}")
    end

    price_str = rate_block["5. Exchange Rate"]
    timestamp = rate_block["6. Last Refreshed"]

    if price_str.nil? || price_str.to_s.strip.empty?
      raise InvalidCryptoPriceError.new("Invalid exchange rate data for #{symbol}")
    end

    Price.new(
      symbol: symbol.upcase,
      price: price_str.to_f,
      currency: currency.upcase,
      timestamp: timestamp
    )
  end

  def parse_stock_daily_close(body)
    data = JSON.parse(body)

    if data.key?("Error Message")
      raise InvalidCryptoPriceError.new("Alpha Vantage error: #{data['Error Message']}")
    end
    if data.key?("Note")
      raise RateLimitError.new("Alpha Vantage rate limit exceeded: #{data['Note']}")
    end
    if data.key?("Information")
      raise InvalidCryptoPriceError.new("Alpha Vantage info: #{data['Information']}")
    end

    series = data.dig("Time Series (Daily)")
    raise InvalidCryptoPriceError.new("No daily series data found") unless series.is_a?(Hash)

    latest_date = series.keys.max
    latest_data = series[latest_date]
    close_str = latest_data&.dig("4. close")
    raise InvalidCryptoPriceError.new("Invalid close data") unless close_str.present?

    [ close_str.to_f, latest_date ]
  end

  def parse_fx_rate(body)
    data = JSON.parse(body)
    if data.key?("Error Message")
      raise InvalidCryptoPriceError.new("Alpha Vantage error: #{data['Error Message']}")
    end
    if data.key?("Note")
      raise RateLimitError.new("Alpha Vantage rate limit exceeded: #{data['Note']}")
    end
    if data.key?("Information")
      raise InvalidCryptoPriceError.new("Alpha Vantage info: #{data['Information']}")
    end

    rate_block = data.dig("Realtime Currency Exchange Rate")
    raise InvalidCryptoPriceError.new("No exchange rate data") unless rate_block.is_a?(Hash)
    rate_str = rate_block["5. Exchange Rate"]
    raise InvalidCryptoPriceError.new("Invalid exchange rate") unless rate_str.present?
    rate_str.to_f
  end
end