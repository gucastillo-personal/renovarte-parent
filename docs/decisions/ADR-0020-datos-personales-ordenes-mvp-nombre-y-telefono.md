---
id: ADR-0020
title: "Datos personales de órdenes (MVP): nombre y apellido más teléfono, sin borrado automático de Discord ni Gmail"
status: Accepted
date: 2026-10-05
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-ordenes]]", "[[repo-renovarte-catalogo]]"]
domains: ["[[domain-ordenes]]"]
providers: ["[[provider-aws]]", "[[provider-discord]]"]
origin: "[[specs/0017-carrito-orden-compra/spec|0017]]"
supersedes: ["[[ADR-0017-datos-personales-ordenes]]"]
extends: ["[[ADR-0006-servicio-ordenes]]", "[[ADR-0016-ordenes-doble-canal]]"]
superseded_by:
constitution: ["§I.2 ningún secreto commiteado"]
cost_impact: "$0 (se elimina el Lambda diario `discord-retention` y su cola por fecha)"
personal_data: true
reversibility: media
retroactive: false
detail: "specs/0017-carrito-orden-compra/spec.md, precisión 2026-10-05; rfc-servicio-ordenes.md revisión 3"
---

# ADR-0020 — Datos personales de órdenes (MVP): nombre y apellido más teléfono, sin borrado automático de Discord ni Gmail

## Contexto

El [ADR-0017](./ADR-0017-datos-personales-ordenes.md) fijó que una orden
lleva nombre, email, teléfono, dirección y localidad, y que los mensajes
de Discord y los mails de Gmail se borran a los 60 días. El 2026-10-05 el
CTO/CEO habló con la CEO de RenovArte, que pidió reducir lo que se le
pide al visitante: por ahora **solo el teléfono**, y RenovArte comparte el
suyo para coordinar el pago y el envío. En este MVP no se prioriza la
protección de datos personales, así que se acordó **pedir menos datos**.
Al revisar este ADR, el CTO/CEO precisó que además del teléfono hay que
pedir **nombre y apellido**, para saber a quién se dirige RenovArte. La spec 0017 recoge el recorte a solo teléfono (precisión 2026-10-05) y
hay que ajustarla al agregado de nombre y apellido; falta registrar la
decisión, porque contradice al ADR-0017 `Accepted`.

## Problema

¿Qué datos personales pide y retiene el servicio de órdenes en el MVP, y
con qué política de borrado?

## Restricciones

- Ley 25.326 (art. 6 información, art. 12 transferencia internacional,
  art. 21 registro de bases). El nombre y el teléfono **siguen siendo datos
  personales**: el recorte reduce el alcance, no lo elimina.
- Ningún secreto en repos (§I.2): el secreto HMAC y la URL del webhook van
  a SSM ([ADR-0019](./ADR-0019-secretos-en-ssm.md)).
- `renovarte-ordenes` es un repo público
  ([ADR-0006](./ADR-0006-servicio-ordenes.md)).
- Doble canal con idempotencia por canal
  ([ADR-0016](./ADR-0016-ordenes-doble-canal.md)): no cambia.

## Decisión

- El formulario pide **dos campos obligatorios: nombre y apellido, y
  teléfono**. El nombre y apellido sirve para saber a quién se dirige
  RenovArte al contactar. Ya no se piden email, dirección ni localidad.
- Se **retiran** el borrado automático de los mensajes de Discord a los 60
  días (Lambda `discord-retention`, cola `BORRAR#`), la política de borrado
  de Gmail a los 60 días y el aviso de privacidad del formulario.
- Los mensajes de Discord y los mails de órdenes quedan **sin plazo de
  borrado**. Cualquier supresión es manual, a pedido.
- La confirmación, los avisos de falla y los `noscript` muestran el
  **teléfono de RenovArte** (1130579528, a confirmar si sirve para llamada
  y WhatsApp) como medio principal de coordinación, además del email y el
  MD de Instagram.
- **Se mantiene del ADR-0017**, sin cambios:
  - los datos personales se procesan en memoria y nunca van a DynamoDB,
    logs ni respuestas;
  - el registro `IDEM#` queda seudonimizado y se borra a los 90 días por
    TTL;
  - la IP se guarda solo como `HMAC(secreto, ip)`, con TTL de 24 h;
  - los logs usan una allowlist de campos;
  - el asunto y la primera línea de Discord no llevan datos personales;
  - el canal de Discord es privado, visible solo para los propietarios;
  - el navegador guarda solo esos dos campos, solo en la sesión de la pestaña;
  - los datos de contacto no se publican ni se commitean.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Mantener ADR-0017 (5 campos, borrado a 60 días) | Mejor postura frente a la Ley 25.326 | Más fricción para el visitante; la CEO pidió pedir menos datos; más código y un Lambda diario | La CEO de RenovArte pidió el recorte |
| Nombre y teléfono, **manteniendo** el borrado a 60 días | Menos datos y plazo acotado | Sigue el costo del Lambda y de la cola; dos campos son poco para justificar el job | Decisión del CTO/CEO: retirar el borrado en el MVP |
| **Nombre y teléfono, sin borrado automático** | Mínimo código y fricción; $0 | Los nombres y teléfonos quedan indefinidamente en Discord y Gmail (EE.UU.) | Elegida (pedido de la CEO de RenovArte, 2026-10-05) |

## Por qué

RenovArte necesita un medio para coordinar el pedido, y nombre y
teléfono alcanzan. Pedir menos datos reduce la fricción y el alcance del dato
personal. La retención sin plazo es una concesión consciente del MVP: se
prefiere simplicidad y menos código a la protección máxima, y el costo de
revertirla es bajo.

## Consecuencias

- La spec 0017 pierde AC-29 y AC-31 (borrado), y B23 e I19 quedan
  retiradas; ver `tasks.md`.
- RenovArte contacta por teléfono a la persona por su nombre y apellido; el
  número de orden identifica el pedido.
- El ADR-0017 pasó a `Superseded` con
  `superseded_by: ADR-0020`, en el mismo PR que este ADR.
- `docs/domains/domain-ordenes.md` deja de decir que los mensajes se borran
  a los 60 días. La línea equivalente del ADR-0016 (Consecuencias) no se
  edita: queda superada por este ADR y se anota en sus Notas posteriores.
- **Deuda explícita de MVP** (no bloquea el diseño): aviso de privacidad
  (art. 6) con mención de la transferencia internacional (SES, Gmail,
  Discord), registro de las bases ante la AAIP si corresponde, y consulta
  profesional opcional.

## Trade-offs y riesgos

- **Datos sin plazo de borrado en terceros** (Discord, Gmail) → el
  volumen es un nombre y un teléfono por orden; la supresión manual queda disponible.
  Reponer el borrado exige un ADR nuevo.
- **Incumplimiento de la Ley 25.326 por falta de aviso** → se acepta como
  riesgo del MVP, decidido por el CTO/CEO a pedido de RenovArte. Debe
  resolverse antes de cualquier uso con volumen o publicidad.
- **El teléfono de RenovArte no sirve para WhatsApp** → confirmar con
  RenovArte; el email y el MD de Instagram quedan como alternativa.

## Salida / reversión

Media: pedir más datos o volver a borrar a los 60 días es agregar campos y
reponer el Lambda y la cola `BORRAR#`, ya diseñados en el ADR-0017 y el
RFC. Requiere un ADR nuevo que supersede a este.

## Detalle técnico

`specs/0017-carrito-orden-compra/spec.md` (precisión 2026-10-05) y
`rfc-servicio-ordenes.md` (revisión 3). Por ahora solo en la rama
`feature/carrito-orden-compra`.

## Notas posteriores

<!-- Append-only. -->
