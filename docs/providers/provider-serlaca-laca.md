---
type: provider
provider: serlaca-laca
---

# Proveedor: Serlaca / LACA

Servicios y repos que lo usan: entrada `providers.serlaca-laca` de
[`manifest.yaml`](../../manifest.yaml).

## Para qué lo usamos

Es el proveedor comercial de los productos que vende RenovArte. Hay dos
fuentes de datos, y las dos las consume solo `renovarte-pipeline`:

- **API de Serlaca**: catálogo y costo
  ([`serlaca-api.md`](../../renovarte-pipeline/docs/serlaca-api.md)). Hay
  un CSV de respaldo.
- **PDF de precios de LACA**: precio profesional, ABC y de catálogo. El
  precio ABC es la fuente primaria del precio de venta
  ([`flujo-precio-pdf.md`](../flujo-precio-pdf.md)).

## Riesgos y límites

- **Las dos fuentes traen datos sensibles** (costo y precio profesional).
  Los archivos crudos quedan en el `.gitignore` y nunca salen del pipeline.
- El PDF no tiene un formato estable: se parsea por posición fija de
  columnas y algunas páginas pueden no reconstruirse bien. `pdf-extract`
  avisa cuáles.
- `SERLACA_API_KEY` solo existe en el `.env.local` del admin, no en CI.
