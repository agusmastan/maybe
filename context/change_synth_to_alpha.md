Especificación Técnica: Integración con Alpha Vantage para cotización de criptomonedas
🎯 Objetivo
Reemplazar el uso de la API de SynthFinance por la API de Alpha Vantage para consultar cotizaciones de criptomonedas en tiempo real al agregar un nuevo activo en la aplicación.

🔗 API de Alpha Vantage
Alpha Vantage ofrece cotizaciones de criptomonedas mediante el endpoint de ejemplo:

GET https://www.alphavantage.co/query?function=DIGITAL_CURRENCY_DAILY&symbol=BTC&market=EUR&apikey=demo
Endpoint: DIGITAL_CURRENCY_DAILY
Parámetros:

API Parameters
❚ Required: function

The time series of your choice. In this case, function=DIGITAL_CURRENCY_DAILY

❚ Required: symbol

The digital/crypto currency of your choice. It can be any of the currencies in the digital currency list. For example: symbol=BTC.

❚ Required: market

The exchange market of your choice. It can be any of the market in the market list. For example: market=EUR.

❚ Required: apikey

Your API key. Claim your free API key here.

Ejemplo de request:
GET https://www.alphavantage.co/query?function=DIGITAL_CURRENCY_DAILY&symbol=BTC&market=EUR&apikey=demo
Respuesta esperada:
    {
  "Meta Data": {
    "1. Information": "Daily Prices and Volumes for Digital Currency",
    "2. Digital Currency Code": "BTC",
    "3. Digital Currency Name": "Bitcoin",
    "4. Market Code": "EUR",
    "5. Market Name": "Euro",
    "6. Last Refreshed": "2025-08-01 00:00:00",
    "7. Time Zone": "UTC"
  },
  "Time Series (Digital Currency Daily)": {
    "2025-08-01": {
      "1. open": "101377.69000000",
      "2. high": "101530.74000000",
      "3. low": "100056.96000000",
      "4. close": "100773.46000000",
      "5. volume": "23.47070509"
    },
    "2025-07-31": {
      "1. open": "103073.76000000",
      "2. high": "104033.59000000",
      "3. low": "101187.92000000",
      "4. close": "101383.62000000",
      "5. volume": "263.09174814"
    },
    "2025-07-30": {
      "1. open": "102087.49000000",
      "2. high": "103437.16000000",
      "3. low": "101300.01000000",
      "4. close": "103071.35000000",
      "5. volume": "236.00351853"
    }
  }
    }

🧱 Requisitos Funcionales
Al crear un nuevo activo tipo "crypto", en el formulario preguntar por nombre de la moneda y cantidad de la misma, luego consultar a Alpha Vantage el valor actual de dicha criptomoneda y mostrar su valor actualizado segun la cantidad que posea el usuario.

Manejar errores de red o respuesta incompleta de la API.

La clave API debe almacenarse en una variable de entorno segura.

