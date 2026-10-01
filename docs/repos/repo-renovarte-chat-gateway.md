---
type: repo
repo: renovarte-chat-gateway
domains: ["[[domain-colibri]]"]
---

# renovarte-chat-gateway

Rol, stack, gate, deploy, contratos y proveedores: entrada
`repositories.renovarte-chat-gateway` de [`manifest.yaml`](../../manifest.yaml).

## Por qué existe

El chat Colibrí necesita una conexión en tiempo real, y
`renovarte-catalogo` no puede tener runtime (constitution del catálogo
§II.4). Por eso el transporte vive en un repo aparte: abre y cierra la
conexión WebSocket, transporta el `ChatEnvelope` y **corta el chat cuando
el gasto llega a USD 20/mes**.

## Qué no hace

- No decide contenido: la clasificación, la búsqueda, los combos y el LLM
  son de [colibri-rag](./repo-renovarte-colibri-rag.md).
- No espera la respuesta del conector. Lo invoca de forma asíncrona y
  `colibri-rag` le contesta directo al cliente.

## Límites conocidos

La invocación async al conector no tiene retry ni DLQ configurados. Si los
3 intentos fallan, el usuario se queda esperando sin aviso. Está detallado
en el README del repo, en "Fuera de alcance".

## Documentos

- README (flujo y estructura): [`README.md`](../../renovarte-chat-gateway/README.md)
- Runbook: [`docs/runbook.md`](../../renovarte-chat-gateway/docs/runbook.md)
- Diseño: [`rfc-transporte-websocket.md`](../../specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md)
- Spec de origen: [0016](../../specs/0016-chat-recomendador-cremas/spec.md)
