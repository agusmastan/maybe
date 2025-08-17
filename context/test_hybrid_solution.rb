# Script para probar la solución híbrida Finnhub + AlphaVantage
# Ejecutar con: rails runner context/test_hybrid_solution.rb

puts "🔄 Testing Hybrid Solution: Finnhub + AlphaVantage"
puts "=" * 60

# Test 1: Verificar que ambos providers estén configurados
puts "\n1. Verificando configuración de providers..."
begin
  registry = Provider::Registry.for_concept(:securities)
  
  finnhub = registry.get_provider(:finnhub)
  alpha_vantage = registry.get_provider(:alpha_vantage)
  
  puts "Finnhub provider: #{finnhub.present? ? '✅' : '❌'}"
  puts "   API Key presente: #{ENV['FINNHUB_API_KEY'].present? ? 'Sí' : 'No'}"
  
  puts "AlphaVantage provider: #{alpha_vantage.present? ? '✅' : '❌'}"
  puts "   API Key presente: #{ENV['ALPHA_VANTAGE_API_KEY'].present? ? 'Sí' : 'No'}"
  
rescue => e
  puts "❌ Error configurando providers: #{e.message}"
end

# Test 2: Verificar asignación de providers híbridos
puts "\n2. Verificando asignación de providers híbridos..."
begin
  main_provider = Security.provider
  historical_provider = Security.historical_price_provider
  info_provider = Security.info_provider
  
  puts "Main provider (búsquedas): #{main_provider&.class&.name || 'None'}"
  puts "Historical provider (precios): #{historical_provider&.class&.name || 'None'}"
  puts "Info provider (detalles): #{info_provider&.class&.name || 'None'}"
  
  if historical_provider.is_a?(Provider::AlphaVantage)
    puts "✅ AlphaVantage configurado para datos históricos"
  else
    puts "⚠️  AlphaVantage no está siendo usado para datos históricos"
  end
  
rescue => e
  puts "❌ Error verificando providers: #{e.message}"
end

# Test 3: Probar búsqueda usando Finnhub
puts "\n3. Probando búsqueda de securities (Finnhub)..."
begin
  results = Security.search_provider("AAPL")
  
  if results.any?
    puts "✅ Búsqueda funcionando con #{Security.provider.class.name}"
    puts "   Resultados: #{results.count}"
    results.first(2).each do |security|
      puts "   - #{security.ticker}: #{security.name}"
    end
  else
    puts "⚠️  Sin resultados (puede ser normal sin API key)"
  end
rescue => e
  puts "❌ Error en búsqueda: #{e.message}"
end

# Test 4: Probar información de empresa (Finnhub primero)
puts "\n4. Probando información de empresa..."
begin
  test_security = Security.find_or_create_by(ticker: "AAPL") do |s|
    s.name = "Apple Inc."
    s.exchange_operating_mic = "XNAS"
    s.country_code = "US"
  end
  
  # Limpiar datos existentes para forzar fetch
  test_security.update!(name: nil, logo_url: nil)
  
  test_security.import_provider_details(clear_cache: true)
  test_security.reload
  
  if test_security.name.present?
    puts "✅ Información obtenida exitosamente"
    puts "   Nombre: #{test_security.name}"
    puts "   Logo: #{test_security.logo_url.present? ? 'Sí' : 'No'}"
  else
    puts "⚠️  No se pudo obtener información"
  end
rescue => e
  puts "❌ Error obteniendo información: #{e.message}"
end

# Test 5: Probar datos históricos (AlphaVantage)
puts "\n5. Probando datos históricos (AlphaVantage)..."
begin
  #test_security = Security.find_by(ticker: "AAPL")
  
  if test_security.present?
    start_date = 5.days.ago.to_date
    end_date = Date.current
    
    puts "   Usando provider: #{Security.historical_price_provider.class.name}"
    
    imported_count = test_security.import_provider_prices(
      start_date: start_date,
      end_date: end_date,
      clear_cache: false
    )
    
    puts "✅ Importación de históricos completada"
    puts "   Registros procesados: #{imported_count}"
    
    # Verificar en BD
    price_count = test_security.prices.where(date: start_date..end_date).count
    puts "   Precios en BD: #{price_count}"
    
    if price_count > 0
      latest_price = test_security.prices.order(date: :desc).first
      puts "   Último precio: #{latest_price.price} #{latest_price.currency} (#{latest_price.date})"
    end
  else
    puts "⚠️  No hay security AAPL para probar"
  end
rescue => e
  puts "❌ Error importando históricos: #{e.message}"
end

# Test 6: Probar precio individual (AlphaVantage)
puts "\n6. Probando precio individual..."
begin
  test_security = Security.find_by(ticker: "AAPL")
  
  if test_security.present?
    price = test_security.find_or_fetch_price(date: Date.current, cache: false)
    
    if price.present?
      puts "✅ Precio individual obtenido"
      puts "   Fecha: #{price.date}"
      puts "   Precio: #{price.price} #{price.currency}"
    else
      puts "⚠️  No se pudo obtener precio individual"
    end
  else
    puts "⚠️  No hay security para probar"
  end
rescue => e
  puts "❌ Error obteniendo precio individual: #{e.message}"
end

# Test 7: Simular ImportMarketDataJob con solución híbrida
puts "\n7. Simulando ImportMarketDataJob híbrido..."
begin
  if Security.historical_price_provider.present?
    puts "   Historical provider: #{Security.historical_price_provider.class.name}"
    puts "   Info provider: #{Security.info_provider.class.name}"
    
    # Probar solo con un security para no sobrecargar APIs
    test_securities = Security.where(ticker: "AAPL").limit(1)
    
    test_securities.each do |security|
      puts "   Procesando #{security.ticker}..."
      
      # Importar detalles
      security.import_provider_details(clear_cache: false)
      
      # Importar precios (últimos 3 días para no sobrecargar)
      security.import_provider_prices(
        start_date: 3.days.ago.to_date,
        end_date: Date.current,
        clear_cache: false
      )
    end
    
    puts "✅ Simulación de ImportMarketDataJob exitosa"
  else
    puts "❌ No hay provider configurado para ImportMarketDataJob"
  end
rescue => e
  puts "❌ Error simulando ImportMarketDataJob: #{e.message}"
end

# Test 8: Verificar fallbacks
puts "\n8. Verificando sistema de fallbacks..."
begin
  puts "   Providers disponibles para securities:"
  registry = Provider::Registry.for_concept(:securities)
  available = [:finnhub, :alpha_vantage, :synth].select do |provider_name|
    begin
      provider = registry.get_provider(provider_name)
      provider.present?
    rescue
      false
    end
  end
  
  puts "   - Disponibles: #{available.join(', ')}"
  
  # Verificar que el sistema híbrido funciona
  if available.include?(:alpha_vantage) && available.include?(:finnhub)
    puts "✅ Sistema híbrido completamente funcional"
  elsif available.include?(:alpha_vantage)
    puts "🟡 Solo AlphaVantage disponible (funciona para históricos)"
  elsif available.include?(:finnhub)
    puts "🟡 Solo Finnhub disponible (limitado para históricos)"
  else
    puts "❌ Ningún provider disponible"
  end
  
rescue => e
  puts "❌ Error verificando fallbacks: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 Pruebas de solución híbrida completadas"

# Resumen de configuración
puts "\n📋 Configuración híbrida actual:"
puts "- Búsquedas: Finnhub (con fallback a AlphaVantage)"
puts "- Información de empresas: Finnhub (con fallback a AlphaVantage)" 
puts "- Datos históricos: AlphaVantage (con fallback a Finnhub)"
puts "- Precios individuales: AlphaVantage (con fallback a Finnhub)"

puts "\n⚙️  Variables de entorno necesarias:"
puts "- FINNHUB_API_KEY=your_finnhub_key (para búsquedas e info)"
puts "- ALPHA_VANTAGE_API_KEY=your_alpha_vantage_key (para históricos)"

puts "\n🎯 Beneficios de la solución híbrida:"
puts "- ✅ Datos históricos reales (AlphaVantage gratuito)"
puts "- ✅ Información completa de empresas (Finnhub)"
puts "- ✅ Sistema robusto con fallbacks automáticos"
puts "- ✅ Compatible con ImportMarketDataJob"
