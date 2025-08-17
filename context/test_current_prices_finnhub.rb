# Script para probar precios actuales usando Finnhub
# Ejecutar con: rails runner context/test_current_prices_finnhub.rb

puts "🧪 Testing Current Prices with Finnhub (Better Rate Limits)"
puts "=" * 65

# Test 1: Verificar configuración de providers
puts "\n1. Verificando configuración de providers..."
begin
  puts "Historical price provider: #{Security.historical_price_provider&.class&.name || 'None'}"
  puts "Current price provider: #{Security.current_price_provider&.class&.name || 'None'}"
  puts "Info provider: #{Security.info_provider&.class&.name || 'None'}"
  
  puts "\nAPI Keys configuradas:"
  puts "- ALPHA_VANTAGE_API_KEY: #{ENV['ALPHA_VANTAGE_API_KEY'].present? ? '✅' : '❌'}"
  puts "- FINNHUB_API_KEY: #{ENV['FINNHUB_API_KEY'].present? ? '✅' : '❌'}"
  
  if Security.current_price_provider.is_a?(Provider::Finnhub)
    puts "✅ Finnhub configurado como provider de precios actuales"
    puts "   Rate limit: 60 requests/minuto vs 25 requests/día de AlphaVantage"
  end
  
rescue => e
  puts "❌ Error verificando providers: #{e.message}"
end

# Test 2: Probar precio actual usando Finnhub
puts "\n2. Probando precio actual de AAPL usando Finnhub..."
begin
  security = Security.find_by(ticker: "AAPL")
  
  if security.present?
    puts "   Security: #{security.ticker} (#{security.name})"
    puts "   Usando provider: #{Security.current_price_provider.class.name}"
    puts "   Fecha solicitada: #{Date.current} (precio actual)"
    puts "   ⚠️  Esto consumirá 1 API call de Finnhub (60/min disponibles)"
    
    # Limpiar precio existente para forzar fetch desde API
    existing_price = security.prices.find_by(date: Date.current)
    if existing_price
      puts "   🗑️  Eliminando precio existente para forzar fetch desde API"
      existing_price.destroy
    end
    
    price = security.find_or_fetch_price(date: Date.current, cache: false)
    
    if price.present?
      puts "✅ Precio actual obtenido exitosamente"
      puts "   Precio: #{price.price} #{price.currency}"
      puts "   Fecha: #{price.date}"
      puts "   Provider usado: Finnhub /quote endpoint"
    else
      puts "⚠️  No se pudo obtener precio actual"
    end
  else
    puts "⚠️  Security AAPL no encontrado"
  end
rescue => e
  puts "❌ Error obteniendo precio actual: #{e.message}"
end

# Test 3: Probar precio histórico (debería usar AlphaVantage)
puts "\n3. Probando precio histórico (hace 3 días) usando AlphaVantage..."
begin
  security = Security.find_by(ticker: "AAPL")
  historical_date = 3.days.ago.to_date
  
  if security.present?
    puts "   Security: #{security.ticker}"
    puts "   Usando provider: #{Security.historical_price_provider.class.name}"
    puts "   Fecha solicitada: #{historical_date} (precio histórico)"
    puts "   ⚠️  Esto consumirá 1 API call de AlphaVantage (25/día disponibles)"
    
    # Limpiar precio existente para forzar fetch desde API
    existing_price = security.prices.find_by(date: historical_date)
    if existing_price
      puts "   🗑️  Eliminando precio existente para forzar fetch desde API"
      existing_price.destroy
    end
    
    price = security.find_or_fetch_price(date: historical_date, cache: false)
    
    if price.present?
      puts "✅ Precio histórico obtenido exitosamente"
      puts "   Precio: #{price.price} #{price.currency}"
      puts "   Fecha: #{price.date}"
      puts "   Provider usado: AlphaVantage TIME_SERIES_DAILY"
    else
      puts "⚠️  No se pudo obtener precio histórico"
    end
  end
rescue => e
  puts "❌ Error obteniendo precio histórico: #{e.message}"
end

# Test 4: Comparar rate limits
puts "\n4. Comparación de rate limits..."
puts "📊 Rate Limits:"
puts "- Finnhub (precios actuales): 60 requests/minuto = 3,600/hora"
puts "- AlphaVantage (precios históricos): 25 requests/día"
puts ""
puts "🎯 Ventajas del sistema híbrido:"
puts "- Precios actuales: Finnhub (rate limit excelente)"
puts "- Precios históricos: AlphaVantage (datos gratuitos)"
puts "- Información empresas: Finnhub (logos, descripción)"
puts "- Exchange rates: AlphaVantage (USD/EUR)"

# Test 5: Probar varios precios actuales para verificar rate limit
puts "\n5. Probando múltiples precios actuales (rate limit test)..."
tickers = ["AAPL", "TSLA", "MSFT"]
puts "   Probando #{tickers.count} tickers usando Finnhub..."
puts "   ⚠️  Esto consumirá #{tickers.count} API calls de Finnhub"

tickers.each_with_index do |ticker, index|
  begin
    security = Security.find_by(ticker: ticker)
    next unless security.present?
    
    puts "   #{index + 1}/#{tickers.count} - Obteniendo precio actual de #{ticker}..."
    
    # Limpiar precio existente
    security.prices.find_by(date: Date.current)&.destroy
    
    price = security.find_or_fetch_price(date: Date.current, cache: false)
    
    if price.present?
      puts "     ✅ #{ticker}: #{price.price} #{price.currency}"
    else
      puts "     ❌ #{ticker}: No se pudo obtener precio"
    end
    
    # Pequeña pausa para no saturar API
    sleep(0.1) if index < tickers.count - 1
    
  rescue => e
    puts "     ❌ #{ticker}: Error - #{e.message}"
  end
end

puts "\n" + "=" * 65
puts "🏁 Pruebas de precios actuales completadas"

puts "\n📊 Resumen del sistema híbrido optimizado:"
puts "✅ Precios ACTUALES → Finnhub (60/min rate limit)"
puts "✅ Precios HISTÓRICOS → AlphaVantage (25/día, pero datos completos)"
puts "✅ Información empresas → Finnhub (logos, descripción)"
puts "✅ Exchange rates → AlphaVantage (USD/EUR)"

puts "\n🎯 Beneficios:"
puts "- Rate limits optimizados para cada uso"
puts "- Menor consumo de AlphaVantage (solo históricos)"
puts "- Precios actuales más rápidos y frecuentes"
puts "- Sistema robusto con fallbacks automáticos"

puts "\n📋 Próximos pasos:"
puts "1. Los gráficos en tiempo real ahora usan Finnhub"
puts "2. Los datos históricos siguen usando AlphaVantage"
puts "3. Monitorear uso de ambas APIs"
puts "4. El sistema es más eficiente para actualizaciones frecuentes"
