---
type: repo
repo: renovarte-events
domains: ["[[domain-notificaciones]]"]
---

# renovarte-events

Rol, stack, gate, deploy, contratos y proveedores: entrada
`repositories.renovarte-events` de [`manifest.yaml`](../../manifest.yaml).

## Por qué existe

Nació como POC de arquitectura event-driven en AWS (spec
[0001](../../specs/0001-poc-event-driven-discord/PLAN-EVENTS.md)) y quedó en
producción: avisa por Discord cuando cambian los precios del catálogo
publicado. Es el **único repo que tiene credenciales de AWS y `boto3`** para
este flujo, así el pipeline sigue sin saber nada de AWS.

## Qué no hace

- No detecta cambios: recibe el `price-changes.json` que calcula el
  pipeline.
- No bloquea la publicación. El evento es best-effort: si falla, el PR al
  catálogo se abre igual.

## Documentos

- README (flujo y desarrollo local): [`README.md`](../../renovarte-events/README.md)
- Runbook: [`docs/runbook.md`](../../renovarte-events/docs/runbook.md)
- Contrato del evento: [`docs/evento-price-changes.md`](../../renovarte-events/docs/evento-price-changes.md)
- Flujo: [`flujo-event-driven-precios.md`](../flujo-event-driven-precios.md)
