---
type: contract
contract: connector-invocation
domains: ["[[domain-colibri]]"]
---

# Contrato: `ConnectorInvocationPayload`

Productor y consumidor: entrada `contracts.connector-invocation` de
[`manifest.yaml`](../../manifest.yaml).

**Schema (única fuente):** [`rfc-transporte-websocket.md` §4](../../specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md#4-ciclo-de-vida-de-la-conexión-y-límite-con-el-conector-llmrag).

## Qué hay que saber antes de tocarlo

- Es una invocación Lambda **asíncrona** (`InvocationType: Event`). El
  gateway no espera respuesta, y el conector le contesta al cliente con
  `postToConnection`.
- Si el conector falla, no puede propagarle el error al gateway: tiene que
  avisarle al cliente por su cuenta. No hay DLQ (ver
  [chat-gateway](../repos/repo-renovarte-chat-gateway.md)).
