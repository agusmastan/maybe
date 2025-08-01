# Plan de Implementación: Migración de Synth a Alpha Vantage para Criptomonedas

## 📋 Resumen Ejecutivo
Reemplazar la integración actual con SynthFinance por Alpha Vantage para obtener cotizaciones de criptomonedas, manteniendo la arquitectura de proveedores existente y siguiendo las convenciones del proyecto Maybe.

---

## 🎯 Objetivos
1. **Migrar de Synth a Alpha Vantage** para cotizaciones de criptomonedas
2. **Mantener compatibilidad** con la funcionalidad existente
3. **Seguir el patrón de proveedores** establecido en el proyecto
4. **Manejar errores** de manera robusta

---

## 📊 Análisis de la Estructura Actual

### Componentes Existentes:
- **`app/models/crypto.rb`**: Modelo principal que incluye `CryptoPrice::Provided`
- **`app/models/crypto_price/provided.rb`**: Concern que maneja la abstracción del proveedor
- **`app/models/provider/synth.rb`**: Implementación actual con Synth
- **`app/models/provider/concepts/crypto_price.rb`**: Interfaz del concepto

### Flujo Actual:
1. Al crear un `Crypto`, se ejecuta `after_commit :refresh_spot_price`
2. Se llama a `CryptoPrice.current_price(symbol:, currency:)`
3. Internamente usa `provider.fetch_crypto_price`
4. Cachea el resultado por 5 minutos

---

## 🔄 Diferencias de API

### Synth (Actual)
```ruby
# Endpoint: GET https://api.synthfinance.com/v1/prices/{symbol}
# Respuesta:
{
  "symbol": "BTC",
  "price": 67340.21,
  "currency": "USD",
  "timestamp": "2025-07-22T14:00:00Z"
}
```

### Alpha Vantage (Nuevo)
```ruby
# Endpoint: GET https://www.alphavantage.co/query?function=DIGITAL_CURRENCY_DAILY&symbol=BTC&market=USD&apikey=KEY
# Respuesta: (ver digital_currency_daily_response.json)
{
  "Meta Data": { ... },
  "Time Series (Digital Currency Daily)": {
    "2025-08-01": {
      "4. close": "100773.46000000"  # Precio más reciente
    }
  }
}
```

---

## 🚀 Plan de Implementación

### **Fase 1: Crear Proveedor Alpha Vantage**

#### 1.1 Crear clase base del proveedor
**Archivo:** `app/models/provider/alpha_vantage.rb`

```ruby
class Provider::AlphaVantage < Provider
  include Provider::Concepts::CryptoPrice
  
  Error = Class.new(Provider::Error)
  InvalidCryptoPriceError = Class.new(Error)
  
  def initialize(api_key)
    @api_key = api_key
  end
  
  def healthy?
    with_provider_response do
      # Hacer una llamada de prueba para verificar conectividad
      fetch_crypto_price(symbol: "BTC", currency: "USD")
      true
    end
  end
  
  # Implementar método requerido por CryptoPrice concept
  def fetch_crypto_price(symbol:, currency: "USD")
    with_provider_response do
      response = client.get(base_url) do |req|
        req.params["function"] = "DIGITAL_CURRENCY_DAILY"
        req.params["symbol"] = symbol
        req.params["market"] = currency
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
    
    # Verificar errores de API
    if data.key?("Error Message")
      raise InvalidCryptoPriceError.new("Alpha Vantage error: #{data['Error Message']}")
    end
    
    if data.key?("Note")
      raise InvalidCryptoPriceError.new("Alpha Vantage rate limit: #{data['Note']}")
    end
    
    time_series = data.dig("Time Series (Digital Currency Daily)")
    raise InvalidCryptoPriceError.new("No price data found for #{symbol}") unless time_series
    
    # Obtener el precio más reciente (primer elemento del hash ordenado)
    latest_date = time_series.keys.first
    latest_data = time_series[latest_date]
    
    price = latest_data&.dig("4. close")
    raise InvalidCryptoPriceError.new("Invalid price data for #{symbol}") unless price
    
    # Retornar en el formato esperado por el sistema
    CryptoPrice.new(
      symbol: symbol,
      price: price.to_f,
      currency: currency,
      timestamp: latest_date
    )
  end
end
```

#### 1.2 Crear estructura de datos
**Archivo:** `app/models/crypto_price.rb`

```ruby
class CryptoPrice
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :symbol, :string
  attribute :price, :float
  attribute :currency, :string
  attribute :timestamp, :string
  
  def initialize(attributes = {})
    super(attributes)
  end
end
```

### **Fase 2: Actualizar Configuración**

#### 2.1 Registrar proveedor en Registry
**Archivo:** `app/models/provider/registry.rb`

```ruby
# Actualizar el registro para usar Alpha Vantage
def self.build_registry
  registry = new
  
  # ... otros proveedores ...
  
  # Cambiar de :synth a :alpha_vantage
  registry.register(:crypto_prices, :alpha_vantage, Provider::AlphaVantage)
  
  registry
end
```

#### 2.2 Actualizar CryptoPrice::Provided
**Archivo:** `app/models/crypto_price/provided.rb`

```ruby
module CryptoPrice::Provided
  extend ActiveSupport::Concern

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:crypto_prices)
      # Cambiar de :synth a :alpha_vantage
      registry.get_provider(:alpha_vantage)
    end

    def current_price(symbol:, currency: "USD")
      return nil unless provider.present?

      # Mantener el mismo cache key para compatibilidad
      Rails.cache.fetch("crypto_price_#{symbol}_#{currency}", expires_in: 5.minutes) do
        response = provider.fetch_crypto_price(symbol: symbol, currency: currency)

        if response.success?
          response.data
        else
          Rails.logger.warn("Failed to fetch crypto price for #{symbol}: #{response.error.message}")
          nil
        end
      end
    end
  end
end
```

### **Fase 3: Configuración de Variables de Entorno**

#### 3.1 Actualizar configuración
**Archivo:** `config/application.rb` o donde corresponda

```ruby
# Agregar configuración para Alpha Vantage
config.alpha_vantage_api_key = ENV['ALPHA_VANTAGE_API_KEY']
```

#### 3.2 Documentación de variables de entorno
**Archivo:** `.env.example`

```bash
# Alpha Vantage API Key para cotizaciones de criptomonedas
ALPHA_VANTAGE_API_KEY=your_alpha_vantage_api_key_here
```

### **Fase 4: Testing**

#### 4.1 Tests unitarios para el proveedor
**Archivo:** `test/models/provider/alpha_vantage_test.rb`

```ruby
require "test_helper"

class Provider::AlphaVantageTest < ActiveSupport::TestCase
  setup do
    @provider = Provider::AlphaVantage.new("test_api_key")
  end

  test "fetch_crypto_price returns valid data" do
    VCR.use_cassette("alpha_vantage_btc_usd") do
      response = @provider.fetch_crypto_price(symbol: "BTC", currency: "USD")
      
      assert response.success?
      assert_instance_of CryptoPrice, response.data
      assert_equal "BTC", response.data.symbol
      assert response.data.price > 0
      assert_equal "USD", response.data.currency
    end
  end

  test "handles API errors gracefully" do
    VCR.use_cassette("alpha_vantage_error") do
      response = @provider.fetch_crypto_price(symbol: "INVALID", currency: "USD")
      
      assert_not response.success?
      assert_instance_of Provider::AlphaVantage::InvalidCryptoPriceError, response.error
    end
  end
end
```

#### 4.2 Tests de integración
**Archivo:** `test/models/crypto_test.rb` (actualizar existente)

```ruby
# Agregar test para verificar que funciona con Alpha Vantage
test "refreshes spot price with Alpha Vantage" do
  VCR.use_cassette("alpha_vantage_eth_usd") do
    crypto = create(:crypto, symbol: "ETH")
    
    assert_not_nil crypto.spot_price_cents
    assert_equal "USD", crypto.spot_price_currency
  end
end
```

### **Fase 5: Migración y Limpieza**

#### 5.1 Crear migración de datos (si es necesario)
**Archivo:** `db/migrate/xxx_migrate_crypto_prices_to_alpha_vantage.rb`

```ruby
class MigrateCryptoPricesToAlphaVantage < ActiveRecord::Migration[7.1]
  def up
    # Limpiar cache de precios de Synth
    Rails.cache.delete_matched("crypto_price_*")
    
    # Refrescar precios de todas las criptos existentes
    Crypto.where.not(symbol: nil).find_each do |crypto|
      crypto.send(:refresh_spot_price)
    end
  end

  def down
    # No-op, no podemos revertir a Synth automáticamente
  end
end
```

#### 5.2 Limpiar código de Synth
- Remover métodos relacionados con crypto de `app/models/provider/synth.rb`
- Actualizar documentación
- Remover VCR cassettes de Synth para crypto

---

## 🧪 Plan de Testing

### Casos de Prueba Críticos:
1. **Funcionamiento básico**: Obtener precio de BTC, ETH, etc.
2. **Manejo de errores**: Símbolo inválido, API key incorrecta, rate limiting
3. **Cache**: Verificar que el cache funciona correctamente
4. **Integración**: Crear crypto y verificar que se actualiza el precio
5. **Fallback**: Comportamiento cuando Alpha Vantage no está disponible

### Datos de Prueba:
- Usar VCR cassettes con respuestas reales de Alpha Vantage
- Crear fixtures para diferentes escenarios de error
- Probar con diferentes símbolos y monedas

---

## 🚨 Consideraciones de Riesgo

### Riesgos Identificados:
1. **Rate Limiting**: Alpha Vantage tiene límites más estrictos que Synth. Solo tiene 25 llamadas a la API por dia.
2. **Formato de respuesta**: Estructura más compleja que requiere parsing cuidadoso
3. **Disponibilidad**: Dependencia de un nuevo proveedor externo
4. **Costo**: Verificar límites del plan gratuito vs. necesidades

### Mitigaciones:
1. **Implementar retry logic** robusto
2. **Cache agresivo** para reducir llamadas a la API
3. **Logging detallado** para debugging
4. **Fallback graceful** cuando no hay datos disponibles

---

## 📅 Timeline Estimado

| Fase | Duración | Descripción |
|------|----------|-------------|
| 1 | 2-3 días | Implementar proveedor Alpha Vantage |
| 2 | 1 día | Actualizar configuración y registry |
| 3 | 0.5 días | Variables de entorno y documentación |
| 4 | 2 días | Testing completo |
| 5 | 1 día | Migración y limpieza |

**Total estimado: 6-7 días**

---

## ✅ Checklist de Implementación

### Pre-implementación:
- [ ] Obtener API key de Alpha Vantage
- [ ] Revisar documentación completa de la API
- [ ] Verificar límites de rate limiting

### Desarrollo:
- [ ] Crear `Provider::AlphaVantage`
- [ ] Implementar `CryptoPrice` data class
- [ ] Actualizar `Provider::Registry`
- [ ] Modificar `CryptoPrice::Provided`
- [ ] Configurar variables de entorno

### Testing:
- [ ] Tests unitarios del proveedor
- [ ] Tests de integración
- [ ] VCR cassettes
- [ ] Tests de manejo de errores

### Deployment:
- [ ] Migración de datos
- [ ] Limpiar código de Synth
- [ ] Actualizar documentación
- [ ] Monitorear en producción

---

## 📝 Notas Adicionales

### Diferencias Clave con Synth:
1. **Estructura de respuesta más compleja** - requiere parsing del time series
2. **Solo datos diarios** - no hay endpoint para precio en tiempo real
3. **Rate limiting más estricto** - 5 requests/minute en plan gratuito
4. **Parámetros diferentes** - `market` en lugar de `currency`

### Optimizaciones Futuras:
1. Implementar batch requests si Alpha Vantage lo soporta
2. Considerar usar websockets para updates en tiempo real
3. Evaluar otros proveedores como backup (CoinGecko, CryptoCompare)
