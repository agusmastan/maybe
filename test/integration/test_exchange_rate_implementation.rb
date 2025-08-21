# Script para probar la implementación del sistema de tipos de cambio USD->EUR
# Ejecutar con: rails runner context/test_exchange_rate_implementation.rb

puts "🧪 Testing USD to EUR Exchange Rate Implementation"
puts "=" * 60

# Test 1: Verificar que el provider AlphaVantage esté configurado
puts "\n1. Verificando configuración del provider AlphaVantage..."
begin
  registry = Provider::Registry.for_concept(:exchange_rates)
  provider = registry.get_provider(:alpha_vantage)
  
  if provider.present?
    puts "✅ AlphaVantage provider configurado correctamente"
    puts "   API Key presente: #{ENV['ALPHA_VANTAGE_API_KEY'].present? ? 'Sí' : 'No'}"
  else
    puts "❌ AlphaVantage provider no configurado"
  end
rescue => e
  puts "❌ Error configurando provider: #{e.message}"
end

# Test 2: Probar obtención de tipo de cambio
puts "\n2. Probando obtención de tipo de cambio USD->EUR..."
begin
  rate = ExchangeRate.find_or_fetch_rate(from: "USD", to: "EUR", date: Date.current)
  
  if rate.present?
    puts "✅ Tipo de cambio obtenido exitosamente"
    puts "   Fecha: #{rate.date}"
    puts "   Tasa: #{rate.rate}"
    puts "   Desde BD: #{rate.persisted? ? 'Sí' : 'No'}"
  else
    puts "❌ No se pudo obtener el tipo de cambio"
  end
rescue => e
  puts "❌ Error obteniendo tipo de cambio: #{e.message}"
end

# Test 3: Verificar datos en la base de datos
puts "\n3. Verificando datos en la base de datos..."
begin
  usd_eur_rates = ExchangeRate.where(from_currency: "USD", to_currency: "EUR")
                             .order(date: :desc)
                             .limit(5)
  
  puts "   Registros USD->EUR en BD: #{usd_eur_rates.count}"
  usd_eur_rates.each do |rate|
    puts "   - #{rate.date}: #{rate.rate}"
  end
rescue => e
  puts "❌ Error consultando BD: #{e.message}"
end

# Test 4: Probar el método de actualización forzada
puts "\n4. Probando actualización forzada..."
begin
  rate = ExchangeRate.update_usd_to_eur_rate!
  
  if rate.present?
    puts "✅ Actualización forzada exitosa"
    puts "   Fecha: #{rate.date}"
    puts "   Tasa: #{rate.rate}"
  else
    puts "❌ Falló la actualización forzada"
  end
rescue => e
  puts "❌ Error en actualización forzada: #{e.message}"
end

# Test 5: Simular ejecución del job
puts "\n5. Simulando ejecución del job..."
begin
  job = UpdateUsdToEurJob.new
  job.perform
  puts "✅ Job ejecutado sin errores"
rescue => e
  puts "❌ Error ejecutando job: #{e.message}"
end

# Test 6: Verificar uso en conversiones de Money
puts "\n6. Probando conversión de dinero USD->EUR..."
begin
  usd_money = Money.new(100, "USD")  # $100 USD
  eur_money = usd_money.exchange_to("EUR")
  
  puts "✅ Conversión exitosa"
  puts "   $100 USD = #{eur_money.format}"
rescue => e
  puts "❌ Error en conversión: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 Pruebas completadas"

# Mostrar próximos pasos
puts "\n📋 Próximos pasos para completar la implementación:"
puts "1. Configurar ALPHA_VANTAGE_API_KEY en variables de entorno"
puts "2. Reiniciar Sidekiq para cargar el nuevo job scheduled"
puts "3. Verificar que el cron job esté funcionando en Sidekiq Web"
puts "4. Monitorear logs para confirmar ejecuciones exitosas"
