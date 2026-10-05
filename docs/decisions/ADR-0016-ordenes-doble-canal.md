---
id: ADR-0016
title: "Órdenes entregadas por doble canal (mail + Discord), aceptadas con al menos uno, idempotencia por canal"
status: Accepted
date: 2026-09-30
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-ordenes]]"]
domains: ["[[domain-ordenes]]"]
providers: ["[[provider-aws]]", "[[provider-discord]]"]
origin: "[[specs/0017-carrito-orden-compra/spec|0017]]"
supersedes: []
extends: ["[[ADR-0006-servicio-ordenes]]"]
superseded_by:
constitution: ["§I.2 ningún secreto commiteado (URL del webhook en SSM)", "§II.5 $0 (Discord sin costo)"]
cost_impact: "$0 adicional (Discord gratis; 1 UpdateItem más por orden)"
personal_data: true
reversibility: media
retroactive: true
detail: "specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md §5, §10.1-10.2"
---

# ADR-0016 — Órdenes entregadas por doble canal (mail + Discord), aceptadas con al menos uno, idempotencia por canal

## Contexto

`renovarte-ordenes` ([ADR-0006](./ADR-0006-servicio-ordenes.md)) entrega
cada orden a RenovArte por mail (SES). En la revisión 2 del RFC de la
0017 (2026-09-30), el CTO/CEO pidió un segundo canal, un **canal privado
de Discord**, para no perder órdenes si el mail cae en spam. Con dos
canales había que definir cuándo una orden cuenta como aceptada y cómo
se reintenta sin duplicar. Ni SES ni los webhooks de Discord ofrecen
idempotencia.

## Problema

¿Cuándo le confirmamos al visitante que su orden llegó, y cómo
reintentamos sin duplicar el mail ni el mensaje?

## Restricciones

- AC-20 de la 0017: nunca confirmar una orden que no llegó.
- At-most-once por canal: un reintento no puede duplicar un mail ni un
  mensaje.
- La URL del webhook es un secreto (constitution §I.2).
- Los dos canales llevan datos personales
  ([ADR-0017](./ADR-0017-datos-personales-ordenes.md)).

## Decisión

- Cada orden se entrega **siempre por los dos canales en paralelo**, con
  el mismo número de orden: mail (SES v2) y mensaje + adjunto `.txt` por
  **webhook** a un canal privado de Discord (`?wait=true`, para
  confirmar con el `id`).
- La orden es **`aceptada` si al menos un canal quedó `entregado`**. El
  canal que falló genera una alerta operativa y no se repara
  automáticamente.
- **Idempotencia propia por canal**, en `IDEM#<key>`, con los estados
  `enviando`, `entregado`, `fallido` e `incierto`. Un reintento con la
  misma key solo reenvía los canales `fallido` (rechazo definitivo),
  mediante un claim condicional. **Nunca** reenvía los `incierto`
  (timeout, 5xx). SES usa `maxAttempts: 1`.
- La alerta de canal degradado va a un **topic SNS de alertas distinto**
  del kill-switch ([ADR-0005](./ADR-0005-tope-costo-usd20.md)): un canal
  caído no apaga el servicio.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Solo mail | Simple | Una orden perdida si cae en spam | El CTO/CEO pidió redundancia |
| Aceptar solo si entregaron los dos | Garantía más fuerte | La disponibilidad pasa a ser A_mail × A_discord; un webhook roto bloquea todas las órdenes; falsos negativos que terminan en órdenes duplicadas por otras vías | Convierte la redundancia en fragilidad |
| Reintentador asíncrono de fondo para el canal caído | Repara solo | Necesita un scan o un índice y un schedule | Costo y complejidad para un caso que no pierde la orden |
| Bot de Discord en lugar de webhook | Tiene `nonce` (idempotencia) | Token de bot con más permisos; otra integración | El webhook alcanza y tiene menos permisos |
| **Doble canal, ≥1 entregado, idempotencia por canal** | Disponibilidad 1 − (1 − A_mail)(1 − A_discord); sin duplicados | Estado por canal más complejo | Elegida (decisiones 8 y 9 del CTO/CEO, RFC §11) |

## Por qué

La promesa al visitante es que RenovArte recibió la orden, y eso se
cumple con un solo canal. El segundo canal es redundancia, no una
condición de validez. Separar `fallido` (seguro no llegó) de `incierto`
(quizás llegó) permite reintentar lo que es seguro reintentar sin
arriesgar duplicados.

## Consecuencias

- El contrato HTTP con el catálogo no cambia: el visitante no sabe
  cuántos canales hay
  ([`contract-orders-http`](../contracts/contract-orders-http.md)).
- El ítem `IDEM#` ya no se borra nunca: `orders-http` no necesita
  `dynamodb:DeleteItem`.
- Los mensajes de Discord tienen datos personales y se borran a los 60
  días (ADR-0017).
- Las notificaciones técnicas de events
  ([ADR-0010](./ADR-0010-notificaciones-event-driven.md)) van a otro
  canal y otro webhook.

## Trade-offs y riesgos

- **Los dos canales `incierto`:** el visitante no recibe confirmación,
  pero la orden no se duplica. Con dos canales independientes es poco
  probable.
- **Webhook rotado:** Discord queda `fallido` (404) con alerta hasta el
  próximo cold start. El runbook indica forzarlo.
- Los límites de Discord (2.000 caracteres, rate limit) no están
  verificados todavía (B1). El adjunto `.txt` cubre órdenes de hasta 100
  líneas.

## Salida / reversión

Media: volver a un solo canal es quitar un adaptador y simplificar el
estado de `IDEM#`. El contrato con el catálogo no cambia.

## Detalle técnico

`specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md` §5 (estados,
semántica de `aceptada`, algoritmo y alertas), §10.1 (SES) y §10.2
(webhook de Discord). Por ahora solo en la rama
`feature/carrito-orden-compra`.

## Notas posteriores
