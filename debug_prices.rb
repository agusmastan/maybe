#!/usr/bin/env ruby

puts '=== DEBUGGING PRECIO ACTUALIZACIÓN ==='
puts

# 1. Verificar estado actual
security = Security.first
puts "Security: #{security.ticker}"

existing_price = Security::Price.where(security: security, date: Date.current).first
if existing_price
  puts "Precio existente: #{existing_price.price} (creado: #{existing_price.created_at})"
else
  puts "No hay precio existente para hoy"
end

puts

# 2. Probar el método find_or_fetch_price
puts "Ejecutando find_or_fetch_price..."
begin
  result = security.find_or_fetch_price(date: Date.current, cache: true)
  puts "Resultado: #{result.class.name}"
  puts "Precio: #{result.price} #{result.currency}"
rescue => e
  puts "Error: #{e.message}"
end

puts

# 3. Verificar estado después
after_price = Security::Price.where(security: security, date: Date.current).first
if after_price
  puts "Precio después: #{after_price.price} (creado: #{after_price.created_at}, actualizado: #{after_price.updated_at})"
else
  puts "Aún no hay precio para hoy"
end

puts

# 4. Probar find_or_create_by manualmente
puts "Probando find_or_create_by manualmente..."
manual_price = Security::Price.find_or_create_by!(
  security_id: security.id,
  date: Date.current
) do |p|
  p.price = 555.55
  p.currency = 'USD'
end

puts "Precio manual: #{manual_price.price} (¿era nuevo?: #{manual_price.previously_new_record?})"

puts

# 5. Estado final
final_count = Security::Price.where(date: Date.current).count
puts "Total precios para hoy: #{final_count}"









