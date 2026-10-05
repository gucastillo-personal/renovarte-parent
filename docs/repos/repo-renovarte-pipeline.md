---
type: repo
repo: renovarte-pipeline
domains: ["[[domain-precios]]", "[[domain-catalogo]]"]
---

# renovarte-pipeline

Rol, stack, gate, deploy, contratos y proveedores: entrada
`repositories.renovarte-pipeline` de [`manifest.yaml`](../../manifest.yaml).

## Por qué existe

Es el **único lugar del proyecto que ve costo, margen y precios de lista
del proveedor**. Junta los datos de Serlaca/LACA (API, CSV de respaldo y PDF
de precios), resuelve el precio de venta y genera un `products.json` sin
datos sensibles. Separar la ingesta del sitio permite que el catálogo no
tenga secretos ni lógica de precios.

## Qué no hace

- No publica directo en el sitio. Abre un PR en `renovarte-catalogo` y una
  persona lo revisa y lo mergea.
- No conoce AWS. Escribe `data/price-changes.json` y
  [renovarte-events](./repo-renovarte-events.md) se encarga del resto
  ([price-change-event](../contracts/contract-price-change-event.md)).
- `ingest`, `transform` y `pdf-extract` no corren en CI: los ejecuta el
  admin en su máquina. En CI solo corre `publish`.

## Documentos

- README (comandos y setup): [`README.md`](../../renovarte-pipeline/README.md)
- Constitution: [`specs/constitution.md`](../../renovarte-pipeline/specs/constitution.md)
- PRD: [`docs/PRD/PRD-pipeline-renovarte.md`](../../renovarte-pipeline/docs/PRD/PRD-pipeline-renovarte.md)
- RFC de arquitectura: [`docs/rfc/0001-arquitectura-pipeline.md`](../../renovarte-pipeline/docs/rfc/0001-arquitectura-pipeline.md)
- API de Serlaca: [`docs/serlaca-api.md`](../../renovarte-pipeline/docs/serlaca-api.md)
- Flujo de precio: [`flujo-precio-pdf.md`](../flujo-precio-pdf.md)
