---
type: contract
contract: price-change-event
domains: ["[[domain-precios]]", "[[domain-notificaciones]]"]
---

# Contrato: evento de cambio de precio

Productor y consumidor: entrada `contracts.price-change-event` de
[`manifest.yaml`](../../manifest.yaml).

**Schema (única fuente):** [`renovarte-events/docs/evento-price-changes.md`](../../renovarte-events/docs/evento-price-changes.md).
Tiene dos partes: el archivo `data/price-changes.json` (pipeline →
producer) y el mensaje SNS/SQS (producer → consumer).

## Qué hay que saber antes de tocarlo

- El archivo es neutro y no depende de AWS: el pipeline solo lo escribe,
  y la publicación en SNS la hace `renovarte-events`.
- Es best-effort: un evento perdido no afecta el catálogo publicado.
- Nunca lleva costo ni margen, solo precios públicos.
