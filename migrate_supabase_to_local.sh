#!/bin/bash
set -e

echo "🛑 1. Deteniendo los contenedores de la aplicación web y workers..."
docker compose stop web worker

echo "🐘 2. Asegurando que PostgreSQL local esté corriendo..."
docker compose up -d postgres

echo "⏳ Esperando 5 segundos a que la base de datos local esté lista..."
sleep 5

echo "📥 3. Descargando datos desde Supabase..."
# Usamos un contenedor efímero de postgres para tener pg_dump disponible sin instalar nada en el host
#docker run --rm postgres:17-alpine pg_dump 'postgresql://postgres.egfnjwxagbmzukjadbtm:!Tatucarreta1980@aws-1-eu-west-1.pooler.supabase.com:5432/postgres' --no-owner --no-acl --clean --if-exists > supabase_data.sql

echo "✅ Descarga completada. Tamaño del backup:"
ls -lh supabase_data.sql

echo "📤 4. Restaurando los datos en la base de datos local..."
docker compose exec -T postgres psql -U maybe -d maybe_production < supabase_data.sql

echo "🚀 5. Levantando todos los servicios de nuevo..."
docker compose up -d

echo "🧹 6. Ejecutando migraciones de rendimiento en la DB local..."
docker compose exec web bin/rails db:migrate

echo "🎉 ¡Migración completada con éxito! La aplicación ahora usa tu PostgreSQL local con todos los datos intactos."
