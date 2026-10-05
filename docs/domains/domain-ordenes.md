---
type: domain
domain: ordenes
status: planned
---

# Dominio: órdenes

El pedido que arma el visitante, ya sea con el carrito del catálogo o con
un combo de Colibrí. Al confirmarlo, el pedido llega a RenovArte para
coordinarlo por fuera del sitio. Diseñado en la spec 0017, **todavía no
implementado**.

## Reglas que lo definen

- No hay pagos ni envío en el sitio: la orden es un pedido, no una compra
  cerrada.
- Cada línea se valida contra el catálogo publicado. Los precios que manda
  el cliente nunca se usan.
- La orden se entrega por **dos canales**, mail y canal privado de Discord,
  con el mismo número de orden. Se acepta si llegó **al menos por uno**, y
  reintentar nunca la duplica.
- **Datos personales (Ley 25.326)**: el formulario pide solo nombre y
  apellido más teléfono; el registro de la orden queda seudonimizado 90
  días y los mensajes de Discord y Gmail no se borran automáticamente en
  el MVP ([ADR-0020](../decisions/ADR-0020-datos-personales-ordenes-mvp-nombre-y-telefono.md)).
- Mismo tope de USD 20/mes, con ledger y kill-switch, que el chat.

## Dónde se ve funcionando

- [Flujo 4 — orden de compra](../arquitectura-general.md#flujo-4--orden-de-compra-spec-0017-diseñado-no-implementado)
- Spec y RFC: `specs/0017-carrito-orden-compra/`, en la rama
  `feature/carrito-orden-compra`.
