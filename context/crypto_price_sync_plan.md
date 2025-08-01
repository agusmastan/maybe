### Plan de implementación — Sincronización automática de precios de criptomonedas con SynthFinance

> Basado en la especificación en `context/crypto_price_sync.md` y las convenciones del proyecto Maybe.

---

#### 1. Alcance y disparador
- **Objetivo**: Al crear un nuevo `Account` con `accountable` de tipo `Crypto`, consultar automáticamente el precio spot de la cripto (`symbol`) mediante la API de SynthFinance y almacenar el valor en USD (u otra divisa familiar).
- **Momento de ejecución**: `after_commit` en creación del `Crypto` *o* durante el flujo `sync_data` cuando se detecte un `Crypto` sin precio reciente.

#### 2. Diseño backend
1. **Concepto `crypto_prices` y proveedor Synth**
   - Crear interfaz `app/models/provider/concepts/crypto_price.rb`
     ```rb
     module Provider::Concepts::CryptoPrice
       # Required: precio puntual de un símbolo en una fecha (por defecto hoy)
       def fetch_price(symbol:, currency: "USD", date: Date.current);
       end
     end
     ```
   - Implementar `app/models/provider/synth.rb` que incluya `Provider::Concepts::CryptoPrice`.
     - Endpoint: `GET https://api.synthfinance.com/v1/prices/{symbol}`.
     - Manejar errores: 404 (símbolo no soportado), timeouts, 5xx ➡️ lanzar `ProviderError`.
   - Registrar en `Provider::Registry`:
     ```rb
     registry.register(:crypto_prices, :synth, Provider::Synth)
     ```

2. **Concern `CryptoPrice::Provided`**
   - Crear `app/models/crypto_price/provided.rb` (similar a `ExchangeRate::Provided`).
   - Exponer métodos de conveniencia:
     - `.provider` – devuelve proveedor registrado
     - `.current_price(symbol:, currency:)` – llama a `provider.fetch_price` y cachea en Rails.cache por 5 min.

3. **Persistencia temporal**
   - Añadir columna `spot_price_cents` y `spot_price_currency` a `accountables.crypto` (o tabla dedicada) *o* utilizar `Account` → `metadata` (jsonb) para almacenar `current_price`.
   - Alternativa mínima: no persistir en DB y solo retornar al frontend vía controlador.

4. **Hook en modelo `Crypto`**
   ```rb
   class Crypto < ApplicationRecord
     after_commit :refresh_spot_price, on: :create

     private

     def refresh_spot_price
       price = CryptoPrice.current_price(symbol: self.symbol, currency: family.currency)
       update_column(:spot_price_cents, price.cents)
     rescue Provider::ProviderError => e
       Rails.logger.error("Synth price error: #{e.message}")
     end
   end
   ```

5. **Job asíncrono (opcional)**
   - `Crypto::RefreshSpotPriceJob` para evitar bloquear solicitud de creación.

#### 3. Diseño frontend
1. **Controlador/endpoint**
   - Extender flujo existente de creación de cuentas para esperar price en respuesta JSON/Turbo Stream.
2. **UI**
   - Mostrar precio spot junto a nuevo `Account` tipo Crypto.
   - En caso de error → flash notice: "Precio no disponible por ahora".

#### 4. Tests
- **Modelos**: pruebas para `Provider::Synth` (happy path + fallbacks).
- **Concern**: `CryptoPrice::Provided.current_price` cachea resultados.
- **Integration**: creación de `Crypto` dispara job y persiste `spot_price`.

#### 5. Configuración y variables
- `.env` / credenciales de Synth (si requiere API key).
- Timeout configurable vía `Rails.configuration.x.synth.timeout`.

#### 6. Despliegue
1. Ejecutar migración para nuevas columnas si se persiste precio.
2. Añadir job a Sidekiq schedule (si periodic update requerido).
3. Actualizar `docker-compose.example.yml` para nuevas variables de entorno.

#### 7. Pasos futuros (no bloqueantes)
- Sincronización periódica (cron) de precios para mantener spot actualizado.
- Historial de precios diarios para gráficos.
- Soporte multi-divisa basado en `ExchangeRate`.
