---
id: ADR-0013
title: "Claude Haiku 4.5: una sola llamada por turno, solo extracción; el resto es texto plantillado"
status: Accepted
date: 2026-09-22
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-colibri-rag]]"]
domains: ["[[domain-colibri]]"]
providers: ["[[provider-anthropic]]"]
origin: "[[specs/0016-chat-recomendador-cremas/spec|0016]]"
supersedes: []
extends: []
superseded_by:
constitution: ["§I.1 sin costo/margen/precio LACA en el contexto del modelo", "§I.2 ningún secreto commiteado", "§II.5 excepción acotada vía ADR-0005"]
cost_impact: "≈ USD 0,002–0,003 por turno; dentro del tope de USD 20/mes (ADR-0005)"
personal_data: false
reversibility: alta
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md §5"
---

# ADR-0013 — Claude Haiku 4.5: una sola llamada por turno, solo extracción; el resto es texto plantillado

## Contexto

Colibrí ([0016](../../specs/0016-chat-recomendador-cremas/spec.md)) usa
un LLM sobre la cuenta de Anthropic que el CTO/CEO ya tenía, con un tope
de USD 20/mes ([ADR-0005](./ADR-0005-tope-costo-usd20.md)). El chat es
público, así que cualquier texto que genere el modelo es superficie de
prompt injection. Las garantías de producto (solo productos reales, el
presupuesto como límite duro) no pueden depender de que el modelo "se
porte bien".

## Problema

¿Qué modelo usamos, para qué tareas, y cuánto del texto que ve el
visitante lo genera el modelo?

## Restricciones

- Tope de USD 20/mes, medido por el ledger propio (ADR-0005).
- `ANTHROPIC_API_KEY` solo del lado del servidor (constitution §I.2). El
  navegador nunca habla con el conector
  ([ADR-0012](./ADR-0012-websocket-invocacion-async.md)).
- Costo, margen y precio de lista nunca entran al contexto (§I.1).
- Los combos y los precios los calcula código, no el modelo
  ([ADR-0015](./ADR-0015-combos-calculados-en-codigo.md)).

## Decisión

- **Modelo: Claude Haiku 4.5** (`claude-haiku-4-5`), vía AI SDK con el
  provider **`@ai-sdk/anthropic` directo**, sin AI Gateway, para que el
  gasto caiga exactamente sobre la cuenta aprobada.
- **Una sola llamada por turno**, de **extracción estructurada**: tema
  válido o no (`onTopic`), tipo de piel en texto, presupuesto y, si falta
  algo, una pregunta de clarificación. El modelo no ve productos en esa
  llamada.
- **Todo lo demás es texto plantillado** (`render.ts`, 0 llamadas): tres
  variantes de introducción de recomendación, elegidas de forma
  determinista por hash de `turn_id`; "sin recomendación"; y "fuera de
  tema".
- El único texto libre del modelo que llega al visitante es
  `clarificationQuestion`, y pasa por un guardrail antes de mostrarse.
- El mensaje del visitante va siempre como turno `user`, nunca
  concatenado al `system`, y el prompt incluye instrucciones explícitas
  contra injection.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Sonnet | Más capacidad | ~5–6× menos turnos por el mismo tope, sin ganancia en una extracción acotada | Desperdicia presupuesto |
| El modelo redacta la recomendación completa | Texto más natural | Superficie de injection en la ruta más sensible; riesgo de inventar productos o precios | Rompe las garantías de AC-4/8/9 |
| Varias llamadas por turno (extraer, después redactar) | Más flexible | Duplica el costo y la latencia | Innecesario: el texto fijo alcanza |
| Vía Vercel AI Gateway | Fallbacks, observabilidad | Capa de facturación intermedia que complica medir el tope | El ledger necesita el `usage` directo de Anthropic |
| **Haiku, 1 llamada de extracción, resto plantillado** | Barato (~6.000–9.000 turnos/mes dentro del tope); superficie de injection mínima | Texto menos variado | Elegida |

## Por qué

La tarea real del modelo es clasificar y extraer uno o dos campos:
exactamente donde Haiku alcanza. Sacar al modelo de la redacción elimina
la superficie de injection donde más importa y hace que las respuestas
sean testeables con snapshots.

## Consecuencias

- El ledger de ADR-0005 calcula el costo con el `usage` de cada llamada
  y el precio público de Haiku 4.5. Si cambia el modelo, hay que cambiar
  el precio configurado.
- `render.ts` tiene 5 plantillas con snapshot tests.
- Un cambio de modelo es una constante (`MODEL_ID`) más la verificación
  del eval fijo de prompts (`plan.md` § AI, "Eval").

## Trade-offs y riesgos

- El texto puede sentirse repetitivo. Mitigación: tres variantes de
  introducción, rotadas de forma determinista.
- `clarificationQuestion` es texto libre del modelo. Mitigación: el
  guardrail de §5.3 del RFC.
- Si Anthropic retira o cambia el precio del modelo, se ajustan el
  `MODEL_ID` y el precio del ledger.

## Salida / reversión

Alta: el modelo es una constante y la extracción tiene un contrato de
tipos (`TurnExtraction`). Cambiar de proveedor es cambiar el provider
del AI SDK y el cálculo de costo.

## Detalle técnico

[`rfc-conector-llm-rag.md`](../../specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md)
§5.1 (modelo y extracción), §5.2 (plantillas) y §5.3 (guardrails);
`renovarte-colibri-rag` `src/slots.ts` (`MODEL_ID`).

## Notas posteriores
