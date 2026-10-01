---
id: ADR-0014
title: Embeddings con Voyage AI, calculados en el sync del catálogo
status: Accepted
date: 2026-09-22
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-colibri-rag]]"]
domains: ["[[domain-colibri]]"]
providers: ["[[provider-voyage-ai]]"]
origin: "[[specs/0016-chat-recomendador-cremas/spec|0016]]"
supersedes: []
extends: []
superseded_by:
constitution: ["§I.2 ningún secreto commiteado", "§II.5 $0 (free tier)"]
cost_impact: "$0 (free tier de Voyage); centavos por mes en el peor caso"
personal_data: false
reversibility: alta
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md §3"
---

# ADR-0014 — Embeddings con Voyage AI, calculados en el sync del catálogo

## Contexto

Practicar RAG y embeddings es parte explícita del "por qué" de la
[0016](../../specs/0016-chat-recomendador-cremas/spec.md). La API de
Mensajes de Anthropic no tiene un endpoint de embeddings, así que la
cuenta ya aprobada no cubría esa parte. El RFC del conector propuso
Voyage AI y dejó un fallback léxico por si el CTO/CEO prefería no sumar
un proveedor. El CTO/CEO confirmó Voyage (T5 de `tasks.md`).

## Problema

¿Con qué ordenamos los productos candidatos por relevancia al tipo de
piel, y cuándo se calculan los vectores?

## Restricciones

- $0 por defecto (constitution §II.5). El tope de USD 20/mes cubre al
  LLM, no a un proveedor nuevo
  ([ADR-0005](./ADR-0005-tope-costo-usd20.md)).
- `VOYAGE_API_KEY` solo como secret, nunca en el repo (§I.2).
- El ranking solo ordena candidatos. Qué entra al combo lo decide código
  ([ADR-0015](./ADR-0015-combos-calculados-en-codigo.md)).

## Decisión

- **Voyage AI** (`voyage-3.5-lite`) para los embeddings, el partner que
  recomienda Anthropic.
- Los vectores de productos se calculan **en el sync del catálogo**, no
  por turno. Solo se recalculan los productos nuevos o modificados (caché
  por `id` + hash de `nombre+descripcion+tags`). Se guardan en
  `data/candidates.json`, empaquetado con el Lambda.
- Por turno hay **una sola llamada de embedding** (la consulta del
  visitante) y similitud coseno en memoria sobre el subconjunto de
  categorías permitidas.
- `retrieval.ts` expone una interfaz (`rankCandidates`) que permite
  cambiar a un ranking léxico sin tocar el resto.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Ranking léxico local (TF-IDF/BM25) | $0 estructural, sin proveedor nuevo | Aproxima, pero no cumple, el objetivo de practicar embeddings | Quedó como fallback detrás de la interfaz |
| Embeddings de OpenAI u otro | Muy usados | Otra cuenta, sin relación con Anthropic | Voyage es el partner recomendado y tiene free tier suficiente |
| Embeddings por turno sobre todo el catálogo | Siempre frescos | Costo y latencia dominantes | Innecesario: el catálogo cambia poco |
| Base vectorial (pgvector, servicio gestionado) | Escala | Infraestructura con costo para ~150–190 vectores | Sobredimensionado; caben en el paquete del Lambda |
| **Voyage, vectores en el sync, coseno en memoria** | $0, latencia baja, cumple el objetivo de aprendizaje | Proveedor nuevo; una llamada externa por turno | Elegida |

## Por qué

Cumple el objetivo de aprendizaje con embeddings reales a costo cero. A
esta escala (~150–190 productos elegibles), los vectores entran en
memoria y la búsqueda exacta es trivial. Calcularlos en el sync deja una
sola llamada externa por turno.

## Consecuencias

- Hay un proveedor nuevo en el manifest
  ([`provider-voyage-ai`](../providers/provider-voyage-ai.md)) y un
  secret más en el repo del conector y en su CI de sync.
- El sync del catálogo (fetch del `products.json` publicado y PR con
  `data/`) también paga los embeddings. Esa forma de sincronizar tendrá
  su propio ADR (la fuente de catálogo de los consumidores).

## Trade-offs y riesgos

- Si Voyage no responde, el turno no puede rankear. Mitigación: el error
  sale como `unavailable` ([ADR-0012](./ADR-0012-websocket-invocacion-async.md)).
  La interfaz permite caer a ranking léxico si hiciera falta.
- La allowlist de categorías (§3.1 del RFC) es una heurística de una
  pasada y puede necesitar ajustes. No es parte de esta decisión.

## Salida / reversión

Alta: cambiar de proveedor es reimplementar `embeddings-voyage.ts` y
recalcular `data/candidates.json` en el próximo sync. Pasar a ranking
léxico es cambiar la implementación de `rankCandidates`.

## Detalle técnico

[`rfc-conector-llm-rag.md`](../../specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md)
§3.1–3.3 (allowlist, embeddings y uso del ranking) y §2 (sync);
`renovarte-colibri-rag` `src/embeddings-voyage.ts` y `src/retrieval.ts`.

## Notas posteriores
