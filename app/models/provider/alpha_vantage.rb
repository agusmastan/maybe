class Provider::AlphaVantage < Provider
  include Provider::Concepts::CryptoPrice
  
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
        req.params["function"] = "DIGITAL_CURRENCY_DAILY"
        req.params["symbol"] = symbol.upcase
        req.params["market"] = currency.upcase
        req.params["apikey"] = api_key
      end
      
      parse_crypto_response(response.body, symbol, currency)
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
    
    # Extraer time series data
    time_series = data.dig("Time Series (Digital Currency Daily)")
    unless time_series
      raise InvalidCryptoPriceError.new("No price data found for #{symbol} in #{currency}")
    end
    
    # Obtener el precio más reciente (primer elemento del hash ordenado por fecha)
    latest_date = time_series.keys.max # Usar max para obtener la fecha más reciente
    latest_data = time_series[latest_date]
    
    unless latest_data
      raise InvalidCryptoPriceError.new("No recent price data found for #{symbol}")
    end
    
    # Extraer precio de cierre (4. close)
    price = latest_data&.dig("4. close")
    unless price
      raise InvalidCryptoPriceError.new("Invalid price data structure for #{symbol}")
    end
    
    # Retornar usando la estructura Price definida en el concepto
    Price.new(
      symbol: symbol.upcase,
      price: price.to_f,
      currency: currency.upcase,
      timestamp: latest_date
    )
  end
end