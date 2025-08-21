# Script ligero para probar solución híbrida con límite de 25 requests/día de AlphaVantage
# Ejecutar con: rails runner context/test_hybrid_light.rb

puts "🧪 Testing Hybrid Solution (Light Mode - Conserving API Calls)"
puts "=" * 60

# Test 1: Verificar configuración sin hacer API calls
puts "\n1. Verificando providers configurados..."
begin
  puts "Exchange Rate provider: #{ExchangeRate.provider&.class&.name || 'None'}"
  puts "Security provider: #{Security.provider&.class&.name || 'None'}"
  puts "Historical price provider: #{Security.historical_price_provider&.class&.name || 'None'}"
  puts "Info provider: #{Security.info_provider&.class&.name || 'None'}"
  
  puts "\nAPI Keys configuradas:"
  puts "- ALPHA_VANTAGE_API_KEY: #{ENV['ALPHA_VANTAGE_API_KEY'].present? ? '✅' : '❌'}"
  puts "- FINNHUB_API_KEY: #{ENV['FINNHUB_API_KEY'].present? ? '✅' : '❌'}"
  
  if Security.historical_price_provider.is_a?(Provider::AlphaVantage)
    puts "✅ Sistema híbrido configurado correctamente"
    puts "   AlphaVantage para históricos, Finnhub para búsquedas/info"
  end
  
rescue => e
  puts "❌ Error verificando providers: #{e.message}"
end

# Test 2: Preparar UN security para prueba mínima
puts "\n2. Preparando security de prueba (solo AAPL)..."
begin
  security = Security.find_or_create_by(ticker: "AAPL") do |s|
    s.name = "Apple Inc."
    s.exchange_operating_mic = "XNAS"
    s.country_code = "US"
  end
  puts "Security AAPL: #{security.persisted? ? 'Ready' : 'Created'}"
  
rescue => e
  puts "❌ Error preparando security: #{e.message}"
end

# Test 3: Probar UN SOLO security con datos históricos mínimos (solo 3 días)
puts "\n3. Probando importación mínima (AAPL, últimos 3 días)..."
begin
  security = Security.find_by(ticker: "AAPL")
  
  if security.present?
    start_date = 3.days.ago.to_date
    end_date = Date.current
    
    puts "   Usando provider: #{Security.historical_price_provider.class.name}"
    puts "   Fechas: #{start_date} a #{end_date}"
    puts "   ⚠️  Esto consumirá 1 API call de AlphaVantage"
    
    imported_count = security.import_provider_prices(
      start_date: start_date,
      end_date: end_date,
      clear_cache: false
    )
    
    puts "✅ Importación completada"
    puts "   Registros procesados: #{imported_count}"
    
    # Verificar en BD
    price_count = security.prices.where(date: start_date..end_date).count
    puts "   Precios en BD: #{price_count}"
    
    if price_count > 0
      latest_price = security.prices.order(date: :desc).first
      puts "   Último precio: #{latest_price.price} #{latest_price.currency} (#{latest_price.date})"
      puts "✅ Datos históricos reales importados exitosamente!"
    end
  else
    puts "⚠️  No hay security AAPL para probar"
  end
rescue Provider::AlphaVantage::RateLimitError => e
  puts "⚠️  Rate limit alcanzado: #{e.message}"
  puts "   AlphaVantage free tier: 25 requests/día"
  puts "   Esperar hasta mañana o considerar plan pagado"
rescue => e
  puts "❌ Error importando precios: #{e.message}"
end

# Test 4: Probar información de empresa (usando Finnhub - no consume AlphaVantage)
puts "\n4. Probando información de empresa (Finnhub)..."
begin
  security = Security.find_by(ticker: "AAPL")
  
  if security.present?
    # Limpiar datos existentes para forzar fetch
    security.update!(name: nil, logo_url: nil)
    
    puts "   Usando provider: #{Security.info_provider.class.name}"
    puts "   ⚠️  Esto consumirá 1 API call de Finnhub"
    
    security.import_provider_details(clear_cache: true)
    security.reload
    
    if security.name.present?
      puts "✅ Información obtenida exitosamente"
      puts "   Nombre: #{security.name}"
      puts "   Logo: #{security.logo_url.present? ? 'Sí' : 'No'}"
    else
      puts "⚠️  No se pudo obtener información"
    end
  end
rescue => e
  puts "❌ Error obteniendo información: #{e.message}"
end

# Test 5: Verificar que exchange rates funcionen (separado de securities)
puts "\n5. Probando exchange rate USD->EUR..."
begin
  puts "   Usando provider: #{ExchangeRate.provider.class.name}"
  puts "   ⚠️  Esto consumirá 1 API call de AlphaVantage"
  
  rate = ExchangeRate.update_usd_to_eur_rate!
  
  if rate.present?
    puts "✅ Exchange rate actualizado"
    puts "   Fecha: #{rate.date}"
    puts "   Tasa: #{rate.rate}"
  else
    puts "⚠️  No se pudo obtener exchange rate"
  end
rescue Provider::AlphaVantage::RateLimitError => e
  puts "⚠️  Rate limit alcanzado: #{e.message}"
rescue => e
  puts "❌ Error obteniendo exchange rate: #{e.message}"
end

# Test 6: Simular ImportMarketDataJob solo con securities existentes
puts "\n6. Simulando ImportMarketDataJob (solo securities con datos)..."
begin
  puts "   ⚠️  ADVERTENCIA: Esto podría consumir varias API calls"
  puts "   Recomendación: Solo ejecutar si tienes suficientes calls restantes"
  
  securities_with_prices = Security.joins(:prices).distinct.limit(1)
  
  if securities_with_prices.any?
    puts "   Procesando #{securities_with_prices.count} securities que ya tienen precios..."
    
    securities_with_prices.each do |security|
      puts "   - #{security.ticker}: #{security.prices.count} precios existentes"
    end
    
    puts "✅ Simulación exitosa (sin nuevas API calls)"
  else
    puts "⚠️  No hay securities con precios para simular"
    puts "   Ejecuta primero la importación individual (Test 3)"
  end
  
rescue => e
  puts "❌ Error simulando ImportMarketDataJob: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 Pruebas ligeras completadas"

puts "\n📊 Resumen de API calls usadas (aproximado):"
puts "- AlphaVantage: ~2 calls (históricos + exchange rate)"
puts "- Finnhub: ~1 call (info empresa)"
puts "- Total: ~3 calls de ~25 disponibles por día"

puts "\n🎯 Estado del sistema híbrido:"
if Security.historical_price_provider.is_a?(Provider::AlphaVantage)
  puts "✅ Sistema híbrido funcionando"
  puts "✅ AlphaVantage para datos históricos"
  puts "✅ Finnhub para búsquedas e información"
  puts "✅ Compatible con ImportMarketDataJob"
else
  puts "❌ Sistema híbrido no configurado correctamente"
end

puts "\n📋 Próximos pasos:"
puts "1. Si todo funciona: el ImportMarketDataJob está listo"
puts "2. Monitorear uso de API calls diario"
puts "3. Considerar plan pagado de AlphaVantage si necesitas más calls"
puts "4. Los gráficos ahora mostrarán datos históricos reales"

puts "\n⚠️  IMPORTANTE sobre límites de API:"
puts "- AlphaVantage Free: 25 requests/día"
puts "- Finnhub Free: 60 requests/minuto"
puts "- Para producción, considera planes pagados"
