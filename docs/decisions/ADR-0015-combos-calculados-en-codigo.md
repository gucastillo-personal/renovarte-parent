---
id: ADR-0015
title: Los combos y su aritmética de presupuesto se calculan en código, nunca por el LLM
status: Accepted
date: 2026-09-22
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-colibri-rag]]"]
domains: ["[[domain-colibri]]"]
providers: []
origin: "[[specs/0016-chat-recomendador-cremas/spec|0016]]"
supersedes: []
extends: []
superseded_by:
constitution: ["§I.1 solo campos públicos de products.json"]
cost_impact: "$0"
personal_data: false
reversibility: media
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md §4"
---

# ADR-0015 — Los combos y su aritmética de presupuesto se calculan en código, nunca por el LLM

## Contexto

Colibrí ([0016](../../specs/0016-chat-recomendador-cremas/spec.md))
recomienda tres combos (barato, medio y premium) de 2 o más productos
reales. La spec fija garantías duras: solo productos del catálogo
(AC-4), los dos primeros dentro del presupuesto (AC-8), el premium hasta
un 20 % por encima (AC-9), y orden ascendente (AC-5). Un LLM no puede
garantizar aritmética ni existencia de productos.

Aunque vive en un solo repo, se registra como ADR porque es la
**garantía central** del chat. Si alguien quisiera "dejar que el modelo
arme los combos", la decisión tendría que revisarse acá.

## Problema

¿Quién decide qué productos van en cada combo y verifica que cumpla el
presupuesto?

## Restricciones

- AC-4/5/6/8/9 de la 0016 son límites duros, no sugerencias de texto.
- Solo se usan campos públicos de `products.json` (constitution §I.1).
- El modelo solo extrae datos
  ([ADR-0013](./ADR-0013-haiku-una-llamada-texto-plantillado.md)).

## Decisión

`combos.ts` arma los combos **de forma determinista**:

- Las bandas son restricciones de búsqueda: `barato` con
  `total ≤ presupuesto`; `medio` con
  `barato.total < total ≤ presupuesto`; `premium` con
  `medio.total < total ≤ presupuesto × 1,20`. Cada combo tiene de 2 a 4
  productos.
- En cada banda hace una **búsqueda exacta acotada** sobre los
  candidatos rankeados ([ADR-0014](./ADR-0014-embeddings-voyage-ai.md),
  `TOP_K` de 20, después 40, después todo) y elige la combinación de
  mayor relevancia agregada, no la primera que cumple.
- Si **cualquiera** de las tres bandas no tiene combo válido, la
  respuesta es `no_recommendation`. Nunca se devuelven uno o dos combos
  sueltos.
- Los campos de cada producto (`productoId`, `nombre`, `presentacion`,
  `precioVenta`) se copian **textuales** del `products.json` cargado y
  nunca pasan por el LLM.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| El LLM arma los combos con los candidatos en el contexto | Menos código; selección "creativa" | Puede inventar productos o equivocarse en sumas; más tokens por turno | No puede garantizar AC-4/8/9 |
| El LLM propone y el código valida | Combina las dos cosas | Reintentos costosos cuando la propuesta no cumple; más llamadas | Complejidad y costo sin beneficio |
| Heurística greedy | Rápida | Puede no encontrar un combo válido que sí existe (falsos negativos de AC-6) | La búsqueda exacta es trivial a esta escala |
| **Búsqueda exacta acotada en código** | Garantías por construcción; testeable; sin costo de tokens | Selección menos "creativa" | Elegida |

## Por qué

Con ≤ 40 candidatos y combos de 2 a 4 productos, el espacio es como
máximo C(40,4) ≈ 91.390 subconjuntos: se recorre en milisegundos. El
código garantiza por construcción lo que un modelo solo podría intentar
cumplir.

## Consecuencias

- Las garantías de AC-4/5/8/9 se verifican con tests unitarios de
  `combos.ts`, no con evals del modelo.
- La relevancia viene del ranking (ADR-0014); el precio y la existencia
  vienen siempre del catálogo publicado.
- Cambiar la definición de banda (el 20 % del premium, el tamaño de
  combo) es un cambio de código con tests, no de prompt.

## Trade-offs y riesgos

- Si el catálogo tiene pocos productos en un rango de precio, aparecen
  más `no_recommendation`. Mitigación: ampliar `TOP_K` antes de
  declararlo.
- Si el catálogo crece mucho, la búsqueda exacta deja de ser trivial.
  Habría que pasar a una DP o a una poda, sin cambiar la decisión de que
  lo haga el código.

## Salida / reversión

Media: delegar la selección al modelo implicaría rehacer las garantías
de la spec y su verificación.

## Detalle técnico

[`rfc-conector-llm-rag.md`](../../specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md)
§4 (armado) y §3.3 (ampliación de `TOP_K`); `renovarte-colibri-rag`
`src/combos.ts`.

## Notas posteriores
