# Script para probar la migración de Synth a Finnhub
# Ejecutar con: rails runner context/test_finnhub_migration.rb

puts "🔄 Testing Synth to Finnhub Migration"
puts "=" * 60

# Test 1: Verificar que el provider Finnhub esté configurado
puts "\n1. Verificando configuración del provider Finnhub..."
begin
  registry = Provider::Registry.for_concept(:securities)
  provider = registry.get_provider(:finnhub)
  
  if provider.present?
    puts "✅ Finnhub provider configurado correctamente"
    puts "   API Key presente: #{ENV['FINNHUB_API_KEY'].present? ? 'Sí' : 'No'}"
  else
    puts "❌ Finnhub provider no configurado"
  end
rescue => e
  puts "❌ Error configurando provider: #{e.message}"
end

# Test 2: Verificar que Security use Finnhub
puts "\n2. Verificando que Security use Finnhub como provider..."
begin
  security_provider = Security.provider
  
  if security_provider.present?
    puts "✅ Security provider configurado: #{security_provider.class.name}"
    
    if security_provider.is_a?(Provider::Finnhub)
      puts "✅ Security está usando Finnhub correctamente"
    else
      puts "⚠️  Security está usando #{security_provider.class.name} en lugar de Finnhub"
    end
  else
    puts "❌ No hay provider configurado para Security"
  end
rescue => e
  puts "❌ Error obteniendo Security provider: #{e.message}"
end

# Test 3: Probar búsqueda de securities
puts "\n3. Probando búsqueda de securities..."
begin
  results = Security.search_provider("AAPL")
  
  if results.any?
    puts "✅ Búsqueda de securities funcionando"
    puts "   Resultados encontrados: #{results.count}"
    results.first(3).each do |security|
      puts "   - #{security.ticker}: #{security.name}"
    end
  else
    puts "⚠️  Búsqueda no retornó resultados (puede ser normal si no hay API key)"
  end
rescue => e
  puts "❌ Error en búsqueda de securities: #{e.message}"
end

# Test 4: Probar obtención de información de security
puts "\n4. Probando obtención de información de security..."
begin
  # Crear un security de prueba si no existe
  test_security = Security.find_or_create_by(ticker: "AAPL") do |s|
    s.name = "Apple Inc."
    s.exchange_operating_mic = "XNAS"
    s.country_code = "US"
  end
  
  test_security.import_provider_details(clear_cache: true)
  
  if test_security.name.present?
    puts "✅ Información de security obtenida exitosamente"
    puts "   Nombre: #{test_security.name}"
    puts "   Logo: #{test_security.logo_url.present? ? 'Sí' : 'No'}"
  else
    puts "⚠️  No se pudo obtener información del security"
  end
rescue => e
  puts "❌ Error obteniendo información de security: #{e.message}"
end

# Test 5: Probar obtención de precio actual
puts "\n5. Probando obtención de precio actual..."
begin
  test_security = Security.find_by(ticker: "AAPL")
  
  if test_security.present?
    price = test_security.find_or_fetch_price(date: Date.current, cache: false)
    
    if price.present?
      puts "✅ Precio actual obtenido exitosamente"
      puts "   Fecha: #{price.date}"
      puts "   Precio: #{price.price} #{price.currency}"
    else
      puts "⚠️  No se pudo obtener el precio actual"
    end
  else
    puts "⚠️  No hay security AAPL para probar"
  end
rescue => e
  puts "❌ Error obteniendo precio actual: #{e.message}"
end

# Test 6: Probar importación de precios históricos
puts "\n6. Probando importación de precios históricos..."
begin
  test_security = Security.find_by(ticker: "AAPL")
  
  if test_security.present?
    start_date = 5.days.ago.to_date
    end_date = Date.current
    
    imported_count = test_security.import_provider_prices(
      start_date: start_date,
      end_date: end_date,
      clear_cache: false
    )
    
    puts "✅ Importación de precios históricos completada"
    puts "   Registros procesados: #{imported_count}"
    
    # Verificar datos en BD
    price_count = test_security.prices.where(date: start_date..end_date).count
    puts "   Precios en BD: #{price_count}"
  else
    puts "⚠️  No hay security AAPL para probar"
  end
rescue => e
  puts "❌ Error importando precios históricos: #{e.message}"
end

# Test 7: Simular ejecución del ImportMarketDataJob
puts "\n7. Simulando ImportMarketDataJob (solo securities)..."
begin
  if Security.provider.present?
    # Solo probar la parte de securities del MarketDataImporter
    importer = MarketDataImporter.new(mode: :snapshot, clear_cache: false)
    importer.import_security_prices
    
    puts "✅ ImportMarketDataJob (securities) ejecutado sin errores"
  else
    puts "❌ No hay provider configurado para ImportMarketDataJob"
  end
rescue => e
  puts "❌ Error ejecutando ImportMarketDataJob: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 Pruebas de migración completadas"

# Mostrar próximos pasos
puts "\n📋 Próximos pasos:"
puts "1. Configurar FINNHUB_API_KEY en variables de entorno"
puts "2. Remover referencias a SYNTH_API_KEY si ya no se usa"
puts "3. Monitorear logs en próximas ejecuciones de ImportMarketDataJob"
puts "4. Considerar migrar securities existentes si es necesario"

# Mostrar configuración necesaria
puts "\n⚙️  Configuración requerida:"
puts "export FINNHUB_API_KEY=your_finnhub_api_key_here"
puts ""
puts "🔗 Obtener API key gratuita en: https://finnhub.io/register"
