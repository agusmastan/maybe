# Maybe Finance - Project Roadmap

## 🎯 Próximas Tareas Prioritarias

### 1. Sistema de Tipos de Cambio Automático ✅
**Estado:** 🟢 Completado  
**Prioridad:** Alta  
**Descripción:** ✅ Implementado cálculo automático cada 12 horas de USD a EUR usando AlphaVantage y almacenamiento en BD

**Tareas específicas:**
- [x] Crear job/scheduler para actualización cada 12 horas de tipos de cambio
- [x] Integrar con API de tipos de cambio (AlphaVantage)
- [x] Almacenar histórico de tipos de cambio en `exchange_rates` table
- [x] Configurar cron job en Sidekiq scheduler
- [x] Optimizar uso de tabla local vs llamadas API
- [x] Crear método de actualización manual forzada

**Archivos implementados:**
- ✅ `app/models/provider/concepts/exchange_rate.rb` (nuevo)
- ✅ `app/models/provider/alpha_vantage.rb` (actualizado)
- ✅ `app/models/exchange_rate/provided.rb` (optimizado)
- ✅ `app/jobs/update_usd_to_eur_job.rb` (implementado)
- ✅ `config/schedule.yml` (job cada 12 horas)
- ✅ `context/test_exchange_rate_implementation.rb` (testing)
- ✅ `context/usd_eur_exchange_rate_setup.md` (documentación)

---

### 2. Corrección Botón Edit para Cryptos/Stocks
**Estado:** 🔴 Pendiente  
**Prioridad:** Media  
**Descripción:** Arreglar funcionalidad de edición para cuentas de crypto y stocks

**Tareas específicas:**
- [ ] Identificar el problema específico en los botones de edición
- [ ] Revisar rutas para `edit` en cryptos y stocks controllers
- [ ] Verificar permisos y validaciones
- [ ] Testear funcionalidad de actualización

**Archivos a revisar:**
- `app/controllers/cryptos_controller.rb`
- `app/controllers/stocks_controller.rb`
- `app/views/cryptos/edit.html.erb`
- `app/views/stocks/edit.html.erb`
- `config/routes.rb`

---

### 3. Sistema de Ingresos Periódicos
**Estado:** 🔴 Pendiente  
**Prioridad:** Alta  
**Descripción:** Implementar transacciones recurrentes (ej: sueldo mensual)

**Tareas específicas:**
- [ ] Crear modelo `RecurringTransaction`
- [ ] Implementar scheduler para ejecutar transacciones periódicas
- [ ] Crear interfaz para configurar ingresos recurrentes
- [ ] Integrar con sistema de notificaciones

**Archivos a crear/modificar:**
- `app/models/recurring_transaction.rb`
- `app/controllers/recurring_transactions_controller.rb`
- `app/jobs/process_recurring_transactions_job.rb`
- `db/migrate/` (nueva migración)

---

### 4. Migración de Stocks a Investment Brokerage
**Estado:** 🟡 En análisis  
**Prioridad:** Alta  
**Descripción:** Cambiar sistema actual de stocks individuales a cuentas de inversión con holdings

**Tareas específicas:**
- [ ] **Investigación:** Analizar estructura actual de holdings vs stocks
- [ ] **Migración:** Crear script para migrar stocks existentes a investment accounts
- [ ] **Cálculo automático:** Implementar actualización automática de precios
- [ ] **Vista:** Cambiar interfaz para mostrar cantidad de acciones en lugar de balance
- [ ] **Holdings:** Verificar dónde se almacena la cantidad de acciones en activity/holdings

**Archivos principales:**
- `app/models/investment.rb`
- `app/models/holding.rb` 
- `app/models/stock.rb` (posible deprecación)
- `app/controllers/investments_controller.rb`
- `app/views/investments/`
- `db/migrate/` (migración de datos)

**Sub-tareas detalladas:**
- [ ] Revisar `app/models/holding.rb` para entender estructura actual
- [ ] Analizar `app/views/holdings/` para ver cómo se muestran las cantidades
- [ ] Crear migración de datos de `stocks` a `investment` + `holdings`
- [ ] Implementar cálculo automático de precios en investments
- [ ] Actualizar vistas para mostrar holdings en lugar de balance directo

---

### 5. Sistema de Actualización Automática de Precios
**Estado:** 🔴 Pendiente  
**Prioridad:** Media  
**Descripción:** Botón manual y actualización automática periódica de precios

**Tareas específicas:**
- [ ] Crear botón "Actualizar todos los precios" en interfaz
- [ ] Implementar job para actualización automática (diaria/horaria)
- [ ] Integrar con provider de precios (Synth, Alpha Vantage, etc.)
- [ ] Añadir logging y manejo de errores
- [ ] Configurar scheduler automático

**Archivos a modificar:**
- `app/jobs/update_all_prices_job.rb` (crear)
- `app/controllers/` (añadir endpoint para botón manual)
- `app/models/stock.rb` (mejorar refresh_spot_price)
- `app/views/` (añadir botón en interfaz)

---

### 6. Configuración de Dominio Local
**Estado:** 🔴 Pendiente  
**Prioridad:** Baja  
**Descripción:** Configurar DNS para acceder via maybe.local en lugar de IP

**Tareas específicas:**
- [ ] Configurar DNS local o modificar /etc/hosts
- [ ] Actualizar configuración de Rails para aceptar maybe.local
- [ ] Configurar SSL si es necesario
- [ ] Documentar proceso de configuración

**Archivos a modificar:**
- `config/environments/development.rb`
- `config/application.rb` (posible host configuration)
- Documentación de setup

---

## 📋 Notas de Implementación

### Orden Sugerido de Implementación:
1. **Corrección botón edit** (rápido, mejora UX inmediata)
2. **Sistema de tipos de cambio** (base para cálculos precisos)
3. **Migración stocks → investments** (cambio arquitectural importante)
4. **Actualización automática de precios** (complementa punto anterior)
5. **Ingresos periódicos** (nueva funcionalidad)
6. **Dominio local** (configuración de desarrollo)

### Consideraciones Técnicas:
- Usar Sidekiq para jobs en background
- Implementar proper error handling y logging
- Añadir tests para nueva funcionalidad
- Considerar backward compatibility en migraciones
- Documentar cambios en API/interfaces

### Dependencias:
- Gems necesarios: `sidekiq-cron` o `whenever` para scheduling
- APIs externas: Alpha Vantage, Finnhub, etc. para precios
- Configuración de Redis para Sidekiq

---

---

## 🆕 **NUEVA TAREA COMPLETADA**

### 7. Migración de Synth a Finnhub ✅
**Estado:** 🟢 Completado  
**Prioridad:** Crítica  
**Descripción:** ✅ Migración completa de Synth (discontinuado) a Finnhub para datos de securities

**Motivo:** Synth fue dado de baja y dejó de funcionar, requiriendo migración urgente.

**⚠️ PROBLEMA DETECTADO:** Finnhub plan gratuito NO incluye datos históricos (/stock/candle premium only)

**✅ SOLUCIÓN HÍBRIDA IMPLEMENTADA:**
- [x] Implementar métodos faltantes en Provider::Finnhub
- [x] Añadir SecurityConcept a Finnhub provider  
- [x] Implementar search_securities usando Finnhub stock symbol API
- [x] Implementar fetch_security_info usando company profile API
- [x] ⚠️ ~~fetch_security_prices usando candle API~~ (requiere premium)
- [x] **SOLUCIÓN:** Añadir SecurityConcept a AlphaVantage para datos históricos
- [x] **HÍBRIDO:** Configurar sistema Finnhub + AlphaVantage
- [x] Cambiar configuración de Security.provider a sistema híbrido
- [x] Crear scripts de testing y documentación completa

**Archivos implementados:**
- ✅ `app/models/provider/finnhub.rb` (extendido con SecurityConcept)
- ✅ `app/models/provider/alpha_vantage.rb` (extendido con SecurityConcept)
- ✅ `app/models/security/provided.rb` (sistema híbrido)
- ✅ `context/test_hybrid_solution.rb` (testing híbrido)
- ✅ `context/hybrid_solution_documentation.md` (documentación completa)

**Sistema Híbrido Final:**
- **Finnhub:** Búsquedas (/stock/symbol), Info (/stock/profile2), Precios actuales (/quote)
- **AlphaVantage:** Datos históricos (TIME_SERIES_DAILY), Fallback info (OVERVIEW)
- **Fallbacks:** Sistema robusto con providers alternativos automáticos

---

## 🔄 Actualizaciones
- **Creado:** Enero 2024
- **Última actualización:** Enero 2024 (Migración Synth→Finnhub completada)
- **Próxima revisión:** Semanal

---

*Este archivo debe actualizarse regularmente conforme se completen tareas y surjan nuevos requerimientos.*
