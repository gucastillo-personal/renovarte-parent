---
type: provider
provider: anthropic
---

# Proveedor: Anthropic

Modelo, costo y repos que lo usan: entrada `providers.anthropic` de
[`manifest.yaml`](../../manifest.yaml).

## Para qué lo usamos

Claude Haiku 4.5, una sola llamada por turno de Colibrí, para clasificar
el mensaje y extraer tipo de piel y presupuesto. No escribe las respuestas
completas ni calcula combos.

## Riesgos y límites

- **Es la única fuente de gasto variable del chat.** El gasto se mide con
  un ledger propio a partir de los tokens de cada respuesta, y al llegar a
  USD 20/mes el chat se corta (RFC de transporte §5).
- **Datos que salen a un tercero**: el mensaje del visitante se manda al
  modelo. Nunca se mandan costo, margen ni datos de órdenes.
- La API key (`ANTHROPIC_API_KEY`) vive solo en el entorno o en los
  secretos de `renovarte-colibri-rag`.
- **Salida**: el modelo se usa a través de un puerto inyectado, así que se
  puede cambiar de proveedor sin tocar el pipeline del turno (ver
  `renovarte-colibri-rag/docs/ARQUITECTURA.md`).
