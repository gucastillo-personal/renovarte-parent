---
id: ADR-0012
title: "Chat por API Gateway WebSocket, invocación async del conector y respuesta directa con postToConnection"
status: Accepted
date: 2026-09-22
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-chat-gateway]]", "[[repo-renovarte-colibri-rag]]", "[[repo-renovarte-catalogo]]"]
domains: ["[[domain-colibri]]"]
providers: ["[[provider-aws]]"]
origin: "[[specs/0016-chat-recomendador-cremas/spec|0016]]"
supersedes: []
extends: ["[[ADR-0004-runtime-chat-fuera-del-catalogo]]", "[[ADR-0011-aws-terraform-plataforma-runtime]]"]
superseded_by:
constitution: ["§II.4 un repo, una responsabilidad", "renovarte-catalogo §II.4 no runtime backend"]
cost_impact: "$0 en free tier (API Gateway WS con free tier de 12 meses, ver ADR-0011)"
personal_data: false
reversibility: media
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md §2-4; plan.md § AI, corrección post gate de Fase 2"
---

# ADR-0012 — Chat por API Gateway WebSocket, invocación async del conector y respuesta directa con `postToConnection`

## Contexto

[ADR-0004](./ADR-0004-runtime-chat-fuera-del-catalogo.md) separó el chat
en dos repos: transporte (`renovarte-chat-gateway`) y conector LLM/RAG
(`renovarte-colibri-rag`). Faltaba decidir cómo viaja un turno: del
navegador al transporte, del transporte al conector, y de vuelta al
navegador con streaming. El primer borrador del RFC del conector asumía
una invocación **síncrona** entre Lambdas. Se corrigió después del gate de
la Fase 2 de la 0016.

## Problema

¿Cómo llega un turno al LLM y su respuesta, en streaming, de vuelta al
navegador, sin chocar con los límites de tiempo de API Gateway?

## Restricciones

- [ADR-0004](./ADR-0004-runtime-chat-fuera-del-catalogo.md): el catálogo
  solo tiene un cliente en el navegador; el runtime vive en los dos repos.
- [ADR-0011](./ADR-0011-aws-terraform-plataforma-runtime.md): AWS
  serverless, Terraform por repo, sin estado remoto compartido.
- Una integración de API Gateway WebSocket corta a los **29 s**, y una
  llamada al LLM con RAG puede superarlo.

## Decisión

- **API Gateway WebSocket API** con tres Lambdas Node.js en el
  transporte: `on-connect`, `on-disconnect` y `on-message`. El estado de
  la conexión vive en DynamoDB (`chat-connections`, TTL de 24 h, sin
  historial persistido).
- `on-message` valida el mensaje, chequea el flag de control de gasto
  ([ADR-0005](./ADR-0005-tope-costo-usd20.md)) e **invoca al conector de
  forma asíncrona** (`InvocationType: Event`). Responde `200` de
  inmediato.
- El conector **responde directo al navegador** con `postToConnection`
  (permiso `execute-api:ManageConnections` sobre la API del transporte),
  emitiendo uno o más `ChatEnvelope`. No vuelve a pasar por el
  transporte.
- Si el conector falla, **avisa él mismo** al cliente: un `try/catch` de
  nivel superior emite `unavailable` / `internal_error`.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Invocación síncrona Lambda → Lambda (primer borrador del RFC del conector) | Los errores se propagan solos al invocador | El límite de 29 s se propaga a toda la cadena | Una llamada al LLM puede superarlo |
| SQS entre transporte y conector (como en [ADR-0010](./ADR-0010-notificaciones-event-driven.md)) | Cola durable, reintentos | Suma latencia y una pieza más, sin ganancia a este volumen | Acá la latencia importa (UX con streaming); queda como mejora si la invocación directa falla seguido |
| HTTP con polling o SSE | Más simple que WebSocket | Sin canal bidireccional; streaming más torpe | El chat necesita ida y vuelta por turno |
| **WebSocket + invocación async + `postToConnection`** | Sin límite de 29 s; streaming directo; transporte liviano | El conector carga con el manejo de errores; sin DLQ | Elegida |

## Por qué

La invocación async desacopla la duración del LLM del límite de
integración de API Gateway. Que el conector responda directo evita un
segundo salto por el transporte y deja a cada repo con su
responsabilidad: el transporte maneja conexiones y corte de gasto, y el
conector se ocupa del contenido.

## Consecuencias

- Se crean dos contratos:
  [`contract-chat-envelope`](../contracts/contract-chat-envelope.md) (lo
  que ve el navegador) y
  [`contract-connector-invocation`](../contracts/contract-connector-invocation.md)
  (el payload de la invocación async).
- El conector necesita el ARN de la API del transporte, copiado a mano
  en su Terraform (ADR-0011, convención 5).
- El conector puede actualizar `tipo_piel` y `presupuesto` en
  `chat-connections` para tener memoria dentro de la conexión activa.

## Trade-offs y riesgos

- **Invocación async sin DLQ:** si el conector muere antes del `catch`
  (timeout duro, OOM), nadie avisa al cliente y el error se pierde.
  Mitigación: timeout acotado, alarma de CloudWatch y el estado de
  "escribiendo" en el cliente.
- **Cold start en `$connect`:** `ux.md` tolera ~400 ms antes de mostrar
  el indicador. Se eligió Node.js liviano, sin dependencias, en parte por
  esto.
- El free tier de API Gateway vence a los 12 meses de la cuenta
  (ADR-0011).

## Salida / reversión

Media: pasar a SQS o a invocación síncrona cambia el contrato de
invocación y el manejo de errores de los dos repos. El envelope hacia el
navegador no tiene por qué cambiar.

## Detalle técnico

[`rfc-transporte-websocket.md`](../../specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md)
§2 (stack), §3 (envelope) y §4 (ciclo de vida e invocación);
[`plan.md`](../../specs/0016-chat-recomendador-cremas/plan.md) § AI,
"Corrección post gate de Fase 2";
[`rfc-conector-llm-rag.md`](../../specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md)
§6 y riesgo 4 de §7.

## Notas posteriores
