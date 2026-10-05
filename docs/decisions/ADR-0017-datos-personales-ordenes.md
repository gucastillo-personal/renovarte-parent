---
id: ADR-0017
title: "Datos personales de órdenes: procesados en memoria, registro seudonimizado 90 días, mensajes con contacto borrados a los 60"
status: Superseded
date: 2026-09-30
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-ordenes]]", "[[repo-renovarte-catalogo]]"]
domains: ["[[domain-ordenes]]"]
providers: ["[[provider-aws]]", "[[provider-discord]]"]
origin: "[[specs/0017-carrito-orden-compra/spec|0017]]"
supersedes: []
extends: ["[[ADR-0006-servicio-ordenes]]"]
superseded_by: "[[ADR-0020-datos-personales-ordenes-mvp-nombre-y-telefono]]"
constitution: ["§I.2 ningún secreto commiteado"]
cost_impact: "$0 (SSM Standard, TTL de DynamoDB, 1 Lambda diario)"
personal_data: true
reversibility: media
retroactive: true
detail: "specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md §7, §10.3; spec.md precisiones 2026-09-30e/f"
---

# ADR-0017 — Datos personales de órdenes: procesados en memoria, registro seudonimizado 90 días, mensajes con contacto borrados a los 60

## Contexto

Una orden de la 0017 lleva nombre, email, teléfono, dirección y
localidad del visitante. Es el primer flujo del proyecto con datos
personales, alcanzado por la **Ley 25.326**. Con el doble canal
([ADR-0016](./ADR-0016-ordenes-doble-canal.md)), esos datos quedan en
dos lugares fuera de AWS: la casilla de Gmail de RenovArte y un canal
privado de Discord. El CTO/CEO decidió los plazos el 2026-09-30.

## Problema

¿Dónde quedan los datos personales de una orden, por cuánto tiempo y
quién puede verlos?

## Restricciones

- Ley 25.326: deber de información (art. 6), registro de bases (art.
  21), transferencia internacional (art. 12) y supresión.
- Ningún secreto en repos (§I.2): el secreto HMAC y la URL del webhook
  van a SSM.
- `renovarte-ordenes` es un repo público
  ([ADR-0006](./ADR-0006-servicio-ordenes.md)).

## Decisión

- **El servicio procesa los datos personales en memoria y no los
  guarda.** Nunca van a DynamoDB, logs ni respuestas.
- El **registro de la orden** en DynamoDB (`IDEM#`) queda
  **seudonimizado**: número, estados por canal, IDs de mensaje, líneas,
  total y `payload_hmac`. Se borra a los **90 días** por TTL.
- La **IP** solo se guarda como `HMAC(secreto, ip)` en los contadores de
  rate limit, con TTL de 24 h.
- Los **logs** usan una allowlist de campos. Nunca incluyen el body, el
  contacto, la IP en claro, la URL del webhook ni el body de respuesta
  de Discord.
- Los **mensajes de Discord** (con datos de contacto) se borran
  **automáticamente entre 60 y 61 días** después de publicados. Lo hace
  un Lambda diario (`discord-retention`) que borra con el propio webhook,
  a partir de una cola por fecha en DynamoDB (`BORRAR#YYYY-MM-DD`, solo
  IDs).
- Los **mails en Gmail** también se borran a los 60 días. Es una política
  y un paso operativo de RenovArte, fuera de los repos (AC-31, de
  verificación manual).
- Asunto y primera línea de Discord **sin datos personales** (número,
  total y cantidad de productos), para que no aparezcan en notificaciones
  de pantalla bloqueada.
- El canal de Discord es **privado, visible solo para los propietarios**.
  Es configuración manual (runbook), no código.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Guardar la orden completa en DynamoDB | Reenvío y consulta fáciles | Base de datos personales en el servicio; más alcance legal | Innecesario: la orden vive en los canales de entrega |
| Sin registro en el servicio | Mínimo dato | Sin idempotencia ni trazabilidad de entrega | La idempotencia por canal (ADR-0016) necesita el registro |
| Discord sin borrado automático | Más simple | Datos personales indefinidamente en un tercero en EE.UU. | Decisión del CTO/CEO: 60 días |
| Borrado con un bot de Discord | Puede borrar cualquier mensaje | Token de bot con más permisos | El webhook puede borrar lo que él creó |
| **Memoria + registro seudonimizado 90 días + Discord y Gmail a 60 días** | Alcance mínimo de datos; plazos acotados | Supresión anticipada manual | Elegida (decisiones 3 y 10 del CTO/CEO, RFC §11; precisión 2026-09-30f) |

## Por qué

Los datos personales solo existen donde RenovArte los necesita para
coordinar el pedido. El servicio guarda lo mínimo para garantizar
idempotencia y trazabilidad, sin poder reconstruir el contacto. Los
plazos acotan cuánto tiempo hay datos en terceros.

## Consecuencias

- `renovarte-ordenes` nace con una sección de **datos personales** en su
  `CLAUDE.md`.
- `check:leak` en CI cubre los dos canales (no publicar URLs de webhook).
- **Antes de producción** (no bloquea el diseño):
  - texto de privacidad en el catálogo (art. 6), con mención de la
    transferencia internacional (SES, Gmail, Discord);
  - registro de las bases (casilla y canal) ante la AAIP si corresponde.
- La supresión antes de los 60 días es manual: borrar el mail y el
  mensaje de Discord.

## Trade-offs y riesgos

- **No hay revisión legal profesional**: es opcional y queda a criterio
  del CTO/CEO. El RFC aclara que no es asesoramiento legal.
- **Falla del registro de borrado:** si no se programa, la orden sigue
  aceptada con una alerta `borrado_no_programado`, y el
  `discord_message_id` queda en `IDEM#` para el borrado manual.
- **Webhook rotado:** el webhook nuevo no puede borrar mensajes del
  anterior. El `webhook_id` guardado permite detectarlo y el runbook
  cubre el borrado manual.
- El borrado en Gmail depende de un proceso humano o de un script fuera
  de los repos.

## Salida / reversión

Media: cambiar los plazos es configuración (TTL, días del job). Guardar
más datos requeriría un ADR nuevo con su análisis legal.

## Detalle técnico

`specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md` §7 (tabla de
datos, secretos, Discord y Ley 25.326) y §10.3 (borrado a los 60 días);
`spec.md`, precisiones 2026-09-30e y 2026-09-30f. Por ahora solo en la
rama `feature/carrito-orden-compra`.

## Notas posteriores

- 2026-10-05 — Reemplazado por [ADR-0020](./ADR-0020-datos-personales-ordenes-mvp-nombre-y-telefono.md): el MVP pide solo nombre y apellido más teléfono y retira el borrado automático a 60 días de Discord y Gmail. Se mantienen el procesamiento en memoria, el registro seudonimizado de 90 días y el canal privado.
