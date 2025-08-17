# Script para probar ImportMarketDataJob con solución híbrida
# Ejecutar con: rails runner context/test_import_market_data_job.rb

puts "🧪 Testing ImportMarketDataJob with Hybrid Solution"
puts "=" * 60

# Test 1: Verificar configuración de providers
puts "\n1. Verificando providers configurados..."
begin
  puts "Exchange Rate provider: #{ExchangeRate.provider&.class&.name || 'None'}"
  puts "Security provider: #{Security.provider&.class&.name || 'None'}"
  puts "Historical price provider: #{Security.historical_price_provider&.class&.name || 'None'}"
  puts "Info provider: #{Security.info_provider&.class&.name || 'None'}"
  
  # Verificar API keys
  puts "\nAPI Keys configuradas:"
  puts "- ALPHA_VANTAGE_API_KEY: #{ENV['ALPHA_VANTAGE_API_KEY'].present? ? '✅' : '❌'}"
  puts "- FINNHUB_API_KEY: #{ENV['FINNHUB_API_KEY'].present? ? '✅' : '❌'}"
  
rescue => e
  puts "❌ Error verificando providers: #{e.message}"
end

# Test 2: Crear algunos securities de prueba si no existen
puts "\n2. Preparando securities de prueba..."
begin
  test_securities = ["AAPL", "GOOGL", "MSFT"]
  
  test_securities.each do |ticker|
    security = Security.find_or_create_by(ticker: ticker) do |s|
      s.name = "#{ticker} Test Security"
      s.exchange_operating_mic = "XNAS"
      s.country_code = "US"
    end
    puts "Security #{ticker}: #{security.persisted? ? 'Ready' : 'Created'}"
  end
  
rescue => e
  puts "❌ Error preparando securities: #{e.message}"
end

# Test 3: Probar MarketDataImporter directamente (modo snapshot)
puts "\n3. Probando MarketDataImporter en modo snapshot..."
begin
  puts "Modo: snapshot (últimos 31 días)"
  puts "Clear cache: false"
  
  importer = MarketDataImporter.new(mode: :snapshot, clear_cache: false)
  
  puts "\n--- Importando Exchange Rates ---"
  importer.import_exchange_rates
  puts "✅ Exchange rates importados"
  
  puts "\n--- Importando Security Prices ---"
  importer.import_security_prices
  puts "✅ Security prices importados"
  
rescue => e
  puts "❌ Error en MarketDataImporter: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

# Test 4: Ejecutar ImportMarketDataJob completo
puts "\n4. Ejecutando ImportMarketDataJob completo..."
begin
  puts "Simulando ejecución programada del job..."
  
  job = ImportMarketDataJob.new
  
  # Simular con parámetros del schedule.yml
  job_params = {
    mode: "snapshot",  # Usar snapshot para pruebas (menos datos)
    clear_cache: false
  }
  
  puts "Parámetros: #{job_params}"
  
  # Ejecutar job
  job.perform(job_params)
  
  puts "✅ ImportMarketDataJob ejecutado exitosamente"
  
rescue => e
  puts "❌ Error ejecutando ImportMarketDataJob: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

# Test 5: Verificar resultados en base de datos
puts "\n5. Verificando resultados en base de datos..."
begin
  # Verificar exchange rates
  usd_eur_rates = ExchangeRate.where(from_currency: "USD", to_currency: "EUR")
                             .order(date: :desc)
                             .limit(5)
  
  puts "Exchange rates USD->EUR recientes: #{usd_eur_rates.count}"
  usd_eur_rates.each do |rate|
    puts "  #{rate.date}: #{rate.rate}"
  end
  
  # Verificar security prices
  test_securities = Security.where(ticker: ["AAPL", "GOOGL", "MSFT"])
  
  puts "\nSecurity prices importados:"
  test_securities.each do |security|
    recent_prices = security.prices.order(date: :desc).limit(3)
    puts "  #{security.ticker}: #{recent_prices.count} precios recientes"
    recent_prices.each do |price|
      puts "    #{price.date}: #{price.price} #{price.currency}"
    end
  end
  
rescue => e
  puts "❌ Error verificando resultados: #{e.message}"
end

# Test 6: Probar con modo full (más completo)
puts "\n6. Probando modo 'full' (datos históricos completos)..."
begin
  puts "⚠️  ADVERTENCIA: Modo full consume más API calls"
  puts "¿Continuar? (y/N)"
  
  # Para script automático, saltar esta parte
  puts "Saltando modo full para conservar API calls..."
  
  # Si quisieras ejecutarlo manualmente:
  # importer_full = MarketDataImporter.new(mode: :full, clear_cache: false)
  # importer_full.import_all
  
rescue => e
  puts "❌ Error en modo full: #{e.message}"
end

# Test 7: Verificar logs y errores
puts "\n7. Verificando logs de la ejecución..."
begin
  puts "Revisa los logs de Rails para ver detalles de la ejecución:"
  puts "  tail -f log/development.log | grep -i 'ImportMarketData'"
  puts "  tail -f log/development.log | grep -i 'AlphaVantage'"
  puts "  tail -f log/development.log | grep -i 'Finnhub'"
  
  # Mostrar estadísticas básicas
  total_securities = Security.count
  total_prices = Security::Price.count
  total_exchange_rates = ExchangeRate.count
  
  puts "\nEstadísticas actuales:"
  puts "  Securities: #{total_securities}"
  puts "  Precios: #{total_prices}"
  puts "  Exchange rates: #{total_exchange_rates}"
  
rescue => e
  puts "❌ Error verificando logs: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 Pruebas de ImportMarketDataJob completadas"

puts "\n📋 Próximos pasos:"
puts "1. Revisar logs para errores específicos"
puts "2. Verificar que los gráficos muestren datos históricos"
puts "3. Monitorear ejecuciones programadas del job"
puts "4. Ajustar rate limits si es necesario"

puts "\n⚙️  Comandos útiles:"
puts "# Ver logs en tiempo real:"
puts "tail -f log/development.log | grep -E '(ImportMarketData|AlphaVantage|Finnhub)'"
puts ""
puts "# Ejecutar job manualmente:"
puts "rails runner \"ImportMarketDataJob.new.perform(mode: 'snapshot')\""
puts ""
puts "# Ver datos en consola:"
puts "rails console"
puts "Security.first.prices.order(:date).last(5)"
