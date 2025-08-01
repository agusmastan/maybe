Especificación Técnica: Integración con SynthFinance para cotización de criptomonedas
🎯 Objetivo
Permitir que al añadir una nueva criptomoneda a la aplicación, se consulte automáticamente su cotización actual utilizando la API de SynthFinance.

🧱 Requisitos Funcionales
Consulta automática de cotización:

Al añadir una criptomoneda (ej. BTC, ETH, SOL), se debe hacer una solicitud a SynthFinance para obtener su valor actual en USD (u otra moneda base configurable).

Almacenamiento del valor:

El valor actual debe almacenarse temporalmente en el frontend y/o base de datos para su visualización inmediata.

Fallback o manejo de errores:

Si SynthFinance no responde o la moneda no es compatible, se debe mostrar un mensaje adecuado.

🔗 API de SynthFinance
Supuestos:
SynthFinance tiene una API pública con endpoint tipo:

bash
Copiar
Editar
GET https://api.synthfinance.com/v1/prices/{symbol}
Respuesta esperada (ejemplo):

json
Copiar
Editar
{
  "symbol": "BTC",
  "price": 67340.21,
  "currency": "USD",
  "timestamp": "2025-07-22T14:00:00Z"
}
Nota: Si la API real difiere, esta parte deberá ajustarse según la documentación oficial.