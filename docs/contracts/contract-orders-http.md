---
type: contract
contract: orders-http
status: planned
domains: ["[[domain-ordenes]]"]
---

# Contrato: HTTP de órdenes

Productor y consumidor: entrada `contracts.orders-http` de
[`manifest.yaml`](../../manifest.yaml). **Planeado**: todavía no existe un
productor (spec 0017, Fase 4).

**Schema (única fuente):** `specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md`
§3, en la rama `feature/carrito-orden-compra` (todavía no está en `main`).

## Qué hay que saber antes de tocarlo

- Tiene dos endpoints: `GET /v1/estado` (disponibilidad y token de
  formulario) y `POST /v1/ordenes` (crear la orden).
- El servidor recalcula todo contra el catálogo publicado. El cliente no
  manda precios que se usen.
- Los reintentos del cliente son idempotentes: la misma orden nunca se
  entrega dos veces.
