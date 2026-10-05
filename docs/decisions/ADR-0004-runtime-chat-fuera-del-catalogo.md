---
id: ADR-0004
title: Runtime del chat fuera del catálogo, en 2 repos nuevos, sin enmendar §II.4
status: Accepted
date: 2026-09-21
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-chat-gateway]]", "[[repo-renovarte-colibri-rag]]", "[[repo-renovarte-catalogo]]"]
domains: ["[[domain-colibri]]"]
providers: ["[[provider-aws]]", "[[provider-anthropic]]"]
origin: "[[specs/0016-chat-recomendador-cremas/spec|0016]]"
supersedes: []
extends: ["[[ADR-0002-catalogo-ssg-sin-backend]]"]
superseded_by:
constitution: ["§I.3 un repo nuevo no invalida una invariante de otro", "§II.4 un repo, una responsabilidad", "renovarte-catalogo §II.4 no runtime backend"]
cost_impact: "ver ADR-0005"
personal_data: false
reversibility: media
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/spec.md § Contexto de arquitectura y dependencias; rfc-transporte-websocket.md §1-4"
---

# ADR-0004 — Runtime del chat fuera del catálogo, en 2 repos nuevos, sin enmendar §II.4

## Contexto

La spec [0016](../../specs/0016-chat-recomendador-cremas/spec.md)
("Colibrí") agrega un chat que recomienda combos de cremas con un LLM y
RAG. El chat necesita runtime: conexiones en vivo, llamadas al LLM y
estado de conversación. El catálogo tiene como invariante "no database,
no runtime backend" (§II.4 de su constitution,
[ADR-0002](./ADR-0002-catalogo-ssg-sin-backend.md)). La primera versión de
la spec dejaba abierta la tensión entre las dos cosas.

## Problema

¿Dónde vive el runtime del chat sin romper el catálogo estático?

## Restricciones

- [ADR-0002](./ADR-0002-catalogo-ssg-sin-backend.md): catálogo sin
  backend.
- [ADR-0001](./ADR-0001-superproyecto-submodulos.md) y constitution §II.4:
  un repo, una responsabilidad.
- Constitution §I.3: un repo nuevo no invalida una invariante de otro; por
  defecto, el trabajo nuevo va a un repo separado.

## Decisión

Todo el runtime del chat vive en **2 repos nuevos**:
`renovarte-chat-gateway` (transporte WebSocket, ciclo de conexión,
envelope de mensajes y corte de gasto) y `renovarte-colibri-rag`
(conector LLM/RAG). `renovarte-catalogo` sigue **100 % estático** y solo
suma un cliente WebSocket en el navegador, con una URL pública
(`NEXT_PUBLIC_CHAT_WS_URL`). La invariante §II.4 del catálogo **no se
enmienda**; su constitution solo agrega una nota de referencia.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Enmendar §II.4 y usar API routes / funciones de Vercel en el catálogo | Un solo repo y un solo deploy | Rompe la invariante; mezcla presentación con runtime y secretos | Constitution §I.3: no se enmienda si hay alternativa |
| Un solo repo nuevo para transporte + LLM | Menos repos | Mezcla dos responsabilidades (conexiones vs. razonamiento) | Rompe "un repo, una responsabilidad" |
| **Dos repos nuevos, catálogo con solo un cliente** | Invariante intacta; cada repo con un rol | Dos repos más; contrato de envelope entre ellos | Elegida por el CTO/CEO |

## Por qué

Repite el patrón que ya funcionaba con `renovarte-pipeline`: el catálogo
consume algo producido afuera. Separar transporte de LLM deja a cada repo
con una sola responsabilidad y un contrato explícito entre ellos (el
envelope y la invocación del conector). También era un objetivo de
aprendizaje explícito del CTO/CEO (RAG, embeddings, LLM por API).

## Consecuencias

- Aparecen dos contratos nuevos:
  [`contract-chat-envelope`](../contracts/contract-chat-envelope.md) y
  [`contract-connector-invocation`](../contracts/contract-connector-invocation.md).
- El chat requiere infraestructura con costo, cubierta por la excepción
  de [ADR-0005](./ADR-0005-tope-costo-usd20.md).
- Fija el precedente para las órdenes
  ([ADR-0006](./ADR-0006-servicio-ordenes.md)): misma resolución, sin
  enmienda.
- AC-12 de la 0016 se verifica en que el catálogo no suma runtime propio.

## Trade-offs y riesgos

- Más repos y más infraestructura que operar (Terraform, AWS). Mitigación:
  mismas convenciones (OIDC, tags, `CLAUDE.md`) en todos.
- Si el chat cae, el catálogo tiene que seguir funcionando (RNF-07).
  Mitigación: el widget degrada a un estado "no disponible".

## Salida / reversión

Apagar el chat es quitar el widget del catálogo y destruir la
infraestructura de los dos repos. El catálogo no depende de ellos para
nada más.

## Detalle técnico

[`spec.md`](../../specs/0016-chat-recomendador-cremas/spec.md)
§ Contexto de arquitectura y dependencias;
[`rfc-transporte-websocket.md`](../../specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md)
§1-4; [`rfc-conector-llm-rag.md`](../../specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md).

## Notas posteriores
