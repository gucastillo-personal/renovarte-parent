---
type: domain
domain: notificaciones
---

# Dominio: notificaciones

Avisos internos para RenovArte sobre lo que pasa en el sistema. Hoy hay
uno solo: el resumen de cambios de precio en Discord.

## Reglas que lo definen

- **Best-effort**: si una notificación falla, nunca bloquea el flujo
  principal que la originó. La publicación del catálogo sigue igual.
- Los mensajes nunca llevan costo ni margen.
- Las notificaciones técnicas van a un canal de Discord distinto del canal
  privado de órdenes (spec 0017). Son dos webhooks diferentes.

## Dónde se ve funcionando

- [`flujo-event-driven-precios.md`](../flujo-event-driven-precios.md)
- Spec de origen: [0001](../../specs/0001-poc-event-driven-discord/PLAN-EVENTS.md)
