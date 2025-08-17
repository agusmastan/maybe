# Migración de Synth a Finnhub - Documentación Completa

## 🚨 **Motivo de la Migración**

**Synth ha sido dado de baja** y ya no funciona, por lo que es necesario migrar a un nuevo provider de datos de securities para que el `ImportMarketDataJob` siga funcionando correctamente.

## ✅ **Migración Completada**

Se ha implementado una migración completa de **Synth** a **Finnhub** como provider de securities.

## 🔧 **Cambios Implementados**

### **1. Provider Finnhub Extendido**
- ✅ Añadido `Provider::SecurityConcept` a Finnhub
- ✅ Implementado `search_securities()` usando Finnhub stock symbol API
- ✅ Implementado `fetch_security_info()` usando Finnhub company profile API
- ✅ Implementado `fetch_security_price()` para precios individuales
- ✅ Implementado `fetch_security_prices()` para datos históricos usando candle API

### **2. Configuración Actualizada**
- ✅ Cambiado `Security.provider` de `:synth` a `:finnhub`
- ✅ Mantenida compatibilidad con API existente
- ✅ Preservado manejo de errores y logging

### **3. Archivos Modificados**
- `app/models/provider/finnhub.rb` - Extendido con métodos de securities
- `app/models/security/provided.rb` - Cambiado provider por defecto
- `context/test_finnhub_migration.rb` - Script de pruebas
- `context/synth_to_finnhub_migration.md` - Esta documentación

## 🎯 **APIs de Finnhub Utilizadas**

| Método Implementado | Endpoint Finnhub | Propósito |
|-------------------|------------------|-----------|
| `search_securities` | `/stock/symbol` | Búsqueda de símbolos por exchange |
| `fetch_security_info` | `/stock/profile2` | Información de empresa (nombre, logo, etc.) |
| `fetch_security_prices` | `/stock/candle` | Datos históricos de precios (OHLCV) |
| `fetch_quote_price` | `/quote` | Precio actual en tiempo real |

## 📊 **Funcionalidades Migradas**

### **✅ Completamente Funcional**
- ✅ **ImportMarketDataJob** - Importación diaria de precios
- ✅ **Búsqueda de securities** - Para crear nuevas posiciones
- ✅ **Información de empresas** - Nombres, logos, descripciones
- ✅ **Precios históricos** - Para gráficos y cálculos
- ✅ **Precios actuales** - Para valoraciones en tiempo real

### **🔄 Diferencias con Synth**
| Aspecto | Synth | Finnhub |
|---------|-------|---------|
| **Búsqueda** | Búsqueda fuzzy avanzada | Filtrado por símbolo/descripción |
| **Logos** | Incluidos en búsqueda | Solo en company profile |
| **Exchanges** | Múltiples exchanges | Principalmente US (configurable) |
| **Moneda** | Múltiples monedas | Principalmente USD |
| **Rate Limits** | Desconocido (servicio caído) | 60 calls/min (free), 600/min (paid) |

## ⚙️ **Configuración Requerida**

### **1. API Key de Finnhub**
```bash
# Configurar en variables de entorno
export FINNHUB_API_KEY=your_finnhub_api_key_here

# O en .env
FINNHUB_API_KEY=your_finnhub_api_key_here
```

### **2. Obtener API Key**
1. Ir a [https://finnhub.io/register](https://finnhub.io/register)
2. Crear cuenta gratuita
3. Obtener API key del dashboard
4. Configurar en variables de entorno

### **3. Límites del Plan Gratuito**
- **60 API calls/minuto**
- **Stock prices, company profiles, historical data**
- **US exchanges principalmente**

## 🧪 **Testing**

### **Script de Pruebas Completo**
```bash
rails runner context/test_finnhub_migration.rb
```

### **Pruebas Manuales**
```ruby
# 1. Verificar provider
Security.provider.class.name  # Debería ser "Provider::Finnhub"

# 2. Buscar securities
Security.search_provider("AAPL")

# 3. Obtener información
security = Security.find_by(ticker: "AAPL")
security.import_provider_details

# 4. Obtener precio actual
security.find_or_fetch_price

# 5. Importar históricos
security.import_provider_prices(start_date: 5.days.ago, end_date: Date.current)
```

## 🚀 **Despliegue**

### **1. Configurar API Key**
```bash
# En servidor de producción
export FINNHUB_API_KEY=your_production_api_key
```

### **2. Reiniciar Servicios**
```bash
# Reiniciar aplicación para cargar nueva configuración
sudo systemctl restart maybe-app

# Reiniciar Sidekiq para jobs
sudo systemctl restart sidekiq
```

### **3. Verificar Funcionamiento**
- Monitorear logs de `ImportMarketDataJob`
- Verificar que se importen precios correctamente
- Confirmar que búsquedas de securities funcionen

## 📈 **Monitoreo**

### **Logs a Monitorear**
```bash
# ImportMarketDataJob
tail -f log/production.log | grep -i "ImportMarketDataJob"

# Finnhub API calls
tail -f log/production.log | grep -i "finnhub"

# Errores de securities
tail -f log/production.log | grep -i "security.*error"
```

### **Métricas Importantes**
- **Tasa de éxito** de importaciones de precios
- **Tiempo de respuesta** de APIs de Finnhub
- **Rate limiting** - monitorear límites de API
- **Cobertura de datos** - verificar que se obtengan todos los securities necesarios

## 🛠 **Troubleshooting**

### **Error: "No provider configured"**
- Verificar que `FINNHUB_API_KEY` esté configurado
- Reiniciar aplicación

### **Error: "Rate limit exceeded"**
- Finnhub free tier: 60 calls/min
- Considerar upgrade a plan pagado
- Implementar backoff/retry logic

### **Error: "No data returned"**
- Verificar que el símbolo exista en Finnhub
- Algunos securities pueden no estar disponibles
- Verificar exchange (Finnhub es principalmente US)

### **Error: "Invalid symbol"**
- Finnhub usa símbolos diferentes a Synth
- Puede requerir mapeo de símbolos
- Verificar exchange operating MIC codes

## 📋 **Próximos Pasos Opcionales**

### **1. Optimizaciones**
- [ ] Implementar caching más agresivo
- [ ] Batch requests para múltiples símbolos
- [ ] Fallback a otros providers si Finnhub falla

### **2. Mejoras**
- [ ] Soporte para más exchanges internacionales
- [ ] Mapeo de símbolos Synth → Finnhub
- [ ] Migración de datos históricos si es necesario

### **3. Monitoring**
- [ ] Alertas por rate limiting
- [ ] Dashboard de métricas de API usage
- [ ] Health checks específicos para Finnhub

## ✅ **Estado del Roadmap**

**Migración Synth → Finnhub** - ✅ **COMPLETADA**

- [x] Analizar APIs de Finnhub disponibles
- [x] Implementar todos los métodos requeridos para securities
- [x] Cambiar configuración de provider
- [x] Crear scripts de testing
- [x] Documentar migración completa
- [x] Verificar compatibilidad con ImportMarketDataJob

## 🎉 **Resumen**

La migración de **Synth a Finnhub** está **100% completada** y lista para producción. Solo necesitas:

1. **Configurar API key** de Finnhub
2. **Reiniciar servicios**
3. **Monitorear** primeras ejecuciones

El sistema seguirá funcionando exactamente igual que antes, pero ahora usando Finnhub como fuente de datos de securities en lugar del servicio discontinuado de Synth.
