---
id: ADR-0006
title: "renovarte-ordenes: Lambda Function URL + DynamoDB + SES"
status: Accepted
date: 2026-10-01
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-ordenes]]", "[[repo-renovarte-catalogo]]"]
domains: ["[[domain-ordenes]]"]
providers: ["[[provider-aws]]", "[[provider-discord]]"]
origin: "[[specs/0017-carrito-orden-compra/spec|0017]]"
supersedes: []
extends: ["[[ADR-0004-runtime-chat-fuera-del-catalogo]]"]
superseded_by:
constitution: ["§I.3 un repo nuevo no invalida una invariante de otro", "§II.5 $0 (excepción vía ADR-0005)", "§II.6 submódulo", "§II.7 CLAUDE.md propio", "renovarte-catalogo §II.4 no runtime backend"]
cost_impact: "< USD 0,10/mes esperado; tope de USD 20/mes (ADR-0005)"
personal_data: true
reversibility: media
retroactive: true
detail: "specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md §1-2; plan.md ## Infra I-D1"
---

# ADR-0006 — `renovarte-ordenes`: Lambda Function URL + DynamoDB + SES

## Contexto

La spec 0017 agrega un carrito y una orden de compra: el visitante arma
un pedido (desde el catálogo o desde un combo de Colibrí) y RenovArte lo
recibe para coordinarlo por fuera del sitio, sin pagos ni envío en el
sitio. Recibir una orden requiere un servidor, y el catálogo no tiene
runtime ([ADR-0002](./ADR-0002-catalogo-ssg-sin-backend.md)). El diseño
se aprobó en la Fase 3, el 2026-10-01. La implementación todavía no
empezó.

## Problema

¿Dónde y con qué recibimos, validamos y entregamos una orden, a costo
casi cero y con un corte de gasto efectivo?

## Restricciones

- [ADR-0004](./ADR-0004-runtime-chat-fuera-del-catalogo.md): el runtime
  vive fuera del catálogo, en un repo propio, sin enmendar su §II.4.
- [ADR-0005](./ADR-0005-tope-costo-usd20.md): tope de USD 20/mes,
  independiente del chat.
- Datos personales (email, teléfono) bajo la Ley 25.326.
- Precios validados contra el `products.json` publicado; nunca se usan
  los que manda el cliente.

## Decisión

Un repo nuevo y **público**, **`renovarte-ordenes`**, en **AWS Lambda
(Node.js 22, TypeScript, arm64) + DynamoDB + Amazon SES v2**, en la misma
cuenta AWS que la 0016. La superficie HTTP es una **Lambda Function URL**
(`AuthType NONE`) con **reserved concurrency** y CORS configurado en la
URL. Cada orden se entrega también por **webhook a un canal privado de
Discord**, sin librería de Discord. El catálogo la consume desde el
navegador vía `NEXT_PUBLIC_ORDERS_API_URL`, una URL pública.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| API Gateway HTTP API delante del Lambda | Dominio propio, throttling por stage | Cobra cada request aunque el Lambda esté apagado; su throttling no es por IP | El kill-switch no llega a gasto cero |
| Funciones de Vercel en el catálogo | Sin AWS | Rompe §II.4 del catálogo | Descartado por ADR-0004 |
| Formulario de terceros (Formspree, Google Forms) | Sin código | Sin validación contra el catálogo; los datos personales quedan en un tercero más | No cumple la validación de precios ni el control de datos |
| **Function URL + reserved concurrency** | Sin cargo propio; `PutFunctionConcurrency(0)` da gasto cero literal | Sin dominio propio ni WAF | Elegida: ninguno de los dos está en el alcance |

## Por qué

La Function URL no tiene cargo propio y las invocaciones throttleadas no
se facturan, así que el kill-switch de ADR-0005 llega a gasto cero
literal. El stack repite el de `renovarte-chat-gateway` (Node 22, pnpm,
`@aws-sdk/*`, Terraform), lo que reduce el costo de operar un repo más.

## Consecuencias

- Nuevo contrato: [`contract-orders-http`](../contracts/contract-orders-http.md)
  (`GET /v1/estado`, `POST /v1/ordenes`).
- El repo trata datos personales: registro seudonimizado 90 días y
  mensajes con datos de contacto borrados a los 60 días. Esa política
  tendrá su propio ADR.
- La entrega por doble canal (mail + Discord) también tendrá su propio
  ADR.
- Por ser público, el repo no publica IDs de cuenta, ARNs ni URLs de
  webhook, y `check:leak` lo verifica.

## Trade-offs y riesgos

- Sin dominio propio ni WAF. Si hacen falta, se pone CloudFront o API
  Gateway delante sin cambiar el contrato.
- SES en sandbox: el único destinatario es la casilla de RenovArte. El
  smoke test del remitente decide entre la opción A y la B.
- La cuota de concurrencia de la cuenta puede ser 10, y en ese caso no
  hay reserva posible (I-D4, caso b).

## Salida / reversión

Cambiar la superficie HTTP (por ejemplo, a API Gateway) no cambia el
contrato. Cambiar de proveedor implica reescribir el Terraform y los
adaptadores de SES y DynamoDB. Costo medio.

## Detalle técnico

`specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md` §1-2 y
`plan.md` § Infra I-D1 a I-D3 (por ahora solo en la rama
`feature/carrito-orden-compra`).

## Notas posteriores
