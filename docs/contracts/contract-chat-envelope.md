---
type: contract
contract: chat-envelope
domains: ["[[domain-colibri]]"]
---

# Contrato: `ChatEnvelope`

Productor y consumidores: entrada `contracts.chat-envelope` de
[`manifest.yaml`](../../manifest.yaml).

**Schema (única fuente):** [`rfc-transporte-websocket.md` §3](../../specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md#3-envelope-de-mensajes).

## Qué hay que saber antes de tocarlo

- Son los mensajes JSON que viajan por el WebSocket en las dos direcciones,
  por ejemplo `text_done`, `profile_confirmed` y `combo_recommendation`.
- **No hay un paquete compartido**: cada repo mantiene una copia a mano de
  los tipos (`src/types.ts` del gateway). Cualquier cambio tiene que
  replicarse en `renovarte-catalogo` y en `renovarte-colibri-rag` en el
  mismo cambio.
