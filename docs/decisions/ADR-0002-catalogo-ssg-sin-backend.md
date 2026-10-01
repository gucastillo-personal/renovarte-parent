---
id: ADR-0002
title: Catálogo SSG sin backend ni base de datos, $0
status: Accepted
date: 2026-09-10
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-catalogo]]"]
domains: ["[[domain-catalogo]]"]
providers: ["[[provider-vercel]]"]
origin: "renovarte-catalogo docs/rfc/0001-arquitectura-catalogo.md"
supersedes: []
extends: []
superseded_by:
constitution: ["§II.5 $0 infraestructura (root)", "renovarte-catalogo §II.4 no database, no runtime backend", "renovarte-catalogo §II.5 $0", "renovarte-catalogo §II.6 static-first"]
cost_impact: "$0 (free tier de Vercel)"
personal_data: false
reversibility: baja
retroactive: true
detail: "renovarte-catalogo docs/rfc/0001-arquitectura-catalogo.md §2.1"
---

# ADR-0002 — Catálogo SSG sin backend ni base de datos, $0

## Contexto

El PRD del catálogo pide un catálogo web público para revender productos
de LACA con precio propio, que oculte el costo y el margen, con
actualización manual de datos y $0 de infraestructura. Los datos cambian
pocas veces (cuando el admin corre la ingesta), y el SEO de las fichas de
producto importa. RFC-0001 de `renovarte-catalogo` fijó la arquitectura.

## Problema

¿Cómo servimos un catálogo público, rápido y con buen SEO, sin costo y sin
exponer costo ni margen?

## Restricciones

- $0 de infraestructura (constitution §II.5; RNF-01 del PRD del catálogo).
- Costo, margen y precio de lista de LACA nunca son públicos (constitution
  §I.1).

## Decisión

`renovarte-catalogo` es un sitio **Next.js generado estáticamente (SSG)**,
alojado en **Vercel (free tier)**, **sin base de datos ni backend de
runtime propio**. Sus datos son un único archivo estático,
`public/data/products.json`, que trae solo campos públicos con el precio
de venta ya calculado. Cualquier cosa que necesite estado dinámico
(carrito, chat, órdenes) vive **fuera** de este repo, con su propio
diseño.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| SPA pura (React sin SSG) | Simple | SEO pobre en las fichas | El SEO es un requisito (RNF-02) |
| Next.js con SSR + base de datos | Datos en vivo, admin en línea | Costo, superficie de ataque, el costo podría llegar al servidor | Rompe $0 y aumenta el riesgo de fuga de costo/margen |
| **Next.js SSG + JSON estático** | $0, rápido, SEO real, nada sensible en runtime | Cada cambio de datos requiere rebuild y deploy | Elegida: los datos cambian poco |

## Por qué

Con datos que cambian pocas veces, un build estático da velocidad y SEO
sin servidor. No tener runtime ni base de datos elimina el costo y hace
imposible, por construcción, que el costo o el margen se filtren desde el
servidor: lo único publicado es lo que ya está en `products.json`.

## Consecuencias

- Toda capacidad dinámica nueva es un repo aparte que el catálogo consume
  desde el navegador ([ADR-0004](./ADR-0004-runtime-chat-fuera-del-catalogo.md),
  [ADR-0006](./ADR-0006-servicio-ordenes.md)).
- Los datos llegan por un contrato de archivo, no por API
  ([ADR-0003](./ADR-0003-ingesta-en-pipeline.md)).
- `check:leak` en `pnpm gate` es la defensa en destino contra la fuga de
  campos privados.

## Trade-offs y riesgos

- Cada actualización de precios requiere un rebuild y un deploy. Se acepta
  porque la ingesta es manual y poco frecuente.
- Presión para "agregar solo un endpoint" cuando aparece una feature
  dinámica. La respuesta por defecto es un repo nuevo (constitution §I.3).

## Salida / reversión

Agregarle un backend al catálogo implicaría enmendar su constitution
§II.4, sumar costo y revisar toda la defensa contra fugas. Es baja
reversibilidad en la práctica: todo el ecosistema se construyó asumiendo
un catálogo estático.

## Detalle técnico

`renovarte-catalogo` [`docs/rfc/0001-arquitectura-catalogo.md`](../../renovarte-catalogo/docs/rfc/0001-arquitectura-catalogo.md)
§2.1 (stack) y §2.4 (schema público).

## Notas posteriores
