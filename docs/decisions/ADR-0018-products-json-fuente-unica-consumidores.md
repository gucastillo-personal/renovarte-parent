---
id: ADR-0018
title: "El products.json publicado es la única fuente de catálogo de todos los consumidores; cada uno elige cómo sincronizar según su frescura"
status: Accepted
date: 2026-09-22
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-catalogo]]", "[[repo-renovarte-colibri-rag]]", "[[repo-renovarte-ordenes]]", "[[repo-renovarte-pipeline]]"]
domains: ["[[domain-catalogo]]", "[[domain-colibri]]", "[[domain-ordenes]]"]
providers: ["[[provider-vercel]]", "[[provider-github]]"]
origin: "[[specs/0016-chat-recomendador-cremas/spec|0016]]"
supersedes: []
extends: ["[[ADR-0003-ingesta-en-pipeline]]"]
superseded_by:
constitution: ["§I.1 sin costo/margen/precio LACA", "§II.4 un repo, una responsabilidad", "renovarte-catalogo §II.8 schema público = RFC §2.4"]
cost_impact: "$0"
personal_data: false
reversibility: media
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md §2; specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md §4"
---

# ADR-0018 — El `products.json` publicado es la única fuente de catálogo de todos los consumidores; cada uno elige cómo sincronizar según su frescura

## Contexto

[ADR-0003](./ADR-0003-ingesta-en-pipeline.md) hizo de `products.json`
el único contrato entre el pipeline y el catálogo. Con la 0016 aparecen
consumidores nuevos: el conector de Colibrí necesita productos y precios
para armar combos, y en la 0017 el servicio de órdenes necesita validar
precios. Cada uno podía leer el catálogo de otra forma: desde el repo
del pipeline, desde Serlaca o con una copia propia. Los dos RFC
eligieron leer el mismo archivo público, pero con mecanismos de
sincronización distintos.

## Problema

¿De dónde lee el catálogo cada consumidor nuevo, y cómo se mantiene
consistente con lo que ve el visitante?

## Restricciones

- Costo, margen y precio de lista nunca salen del pipeline (constitution
  §I.1).
- Un repo, una responsabilidad (§II.4): ningún consumidor reprocesa
  datos de origen.
- El schema público es el del RFC-0001 §2.4 del pipeline. Cambiarlo
  requiere enmienda en productor y consumidores (`renovarte-catalogo`
  §II.8).

## Decisión

- La **única fuente de catálogo** de todo consumidor es el
  `products.json` **publicado por el sitio de producción** del catálogo
  (`https://<dominio>/data/products.json`). Es una URL pública, sin
  secretos. Ningún consumidor lee el repo del pipeline, la API de
  Serlaca ni una versión propia del catálogo.
- Cada consumidor elige el **mecanismo de sincronización según cuánta
  frescura necesita**:

| Consumidor | Mecanismo | Lag | Por qué |
|---|---|---|---|
| `renovarte-catalogo` | PR automático desde el pipeline ([ADR-0009](./ADR-0009-handoff-pipeline-catalogo-por-pr.md)) | Lo que tarde el merge humano | Es el que publica |
| `renovarte-colibri-rag` | Snapshot versionado: sync programado cada 6 h → PR con `data/` (más embeddings, [ADR-0014](./ADR-0014-embeddings-voyage-ai.md)) → merge manual → redeploy | ≤ 6 h más el merge | Costo y latencia por turno; el chat sigue andando si el sitio cae |
| `renovarte-ordenes` | Fetch en runtime con caché de 5 min por contenedor (ETag), refetch forzado ante discrepancia y caché válida hasta 24 h si falla el fetch | ≤ 5 min | Tiene que coincidir con los precios que ve el navegador; nunca acepta una orden sin catálogo contra el cual validar |

- Cada consumidor lee **solo los campos que necesita** (allowlist, con
  guard propio copiado, sin un paquete compartido), así que una clave de
  costo filtrada por error nunca se usaría.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Leer desde el repo del pipeline | Dato más fresco | Ese repo ve costo; acopla a un consumidor con el productor | Saltea la publicación y su `check:leak` |
| Cada consumidor arma su catálogo desde Serlaca | Independencia | Duplica la ingesta; lleva costo a repos nuevos | Rompe §I.1 y §II.4 |
| Un mismo mecanismo para todos (todo snapshot o todo fetch) | Uniformidad | Snapshot rechaza órdenes honestas después de cada republicación; fetch por turno encarece el chat y lo acopla al sitio | Las necesidades de frescura son distintas |
| **Fuente única publicada, mecanismo por consumidor** | Un solo catálogo de verdad; cada uno con la frescura que necesita | Dos patrones de sync que mantener | Elegida |

## Por qué

Lo que ve el visitante es lo que publica el catálogo. Si todos leen eso,
nunca hay dos verdades sobre qué productos existen o cuánto cuestan. La
frescura sí difiere: al chat le alcanza con horas de atraso, pero
órdenes tiene que coincidir con el navegador, porque si no rechazaría
pedidos legítimos después de cada republicación de precios.

## Consecuencias

- El contrato [`contract-products-json`](../contracts/contract-products-json.md)
  tiene tres consumidores declarados en el manifest, cada uno con su
  mecanismo.
- Un cambio de schema se coordina en los cuatro repos: el productor, el
  catálogo y los guards copiados de colibri-rag y de órdenes.
- El sitio de producción del catálogo pasa a ser una dependencia en
  runtime de órdenes, y en el sync, de colibri-rag.

## Trade-offs y riesgos

- **Cambio de dominio o deploy protegido de Vercel:** el sync de
  colibri-rag falla de forma visible (CI en rojo) y órdenes responde
  `catalogo_no_disponible`. Ninguno sirve datos inventados.
- **Ventana de inconsistencia del chat:** hasta 6 h más el merge, Colibrí
  puede recomendar un precio viejo. Si el visitante convierte ese combo
  en orden, órdenes lo rechaza con `precio_cambiado` y el precio
  vigente.
- **Guards copiados a mano:** pueden divergir del schema. Mitigación: la
  allowlist toma pocos campos y hay tests en cada repo.

## Salida / reversión

Media: cambiar la fuente de un consumidor (por ejemplo, pasar
colibri-rag a fetch en runtime) es local a ese repo. Cambiar la fuente
única afectaría a todos.

## Detalle técnico

[`rfc-conector-llm-rag.md`](../../specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md)
§2 (sync de colibri-rag);
`specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md` §4 (fetch con
caché de órdenes; por ahora solo en la rama
`feature/carrito-orden-compra`); `contracts.products-json` en
[`manifest.yaml`](../../manifest.yaml).

## Notas posteriores
