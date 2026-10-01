---
type: repo
repo: renovarte-colibri-rag
domains: ["[[domain-colibri]]"]
---

# renovarte-colibri-rag

Rol, stack, gate, deploy, contratos y proveedores: entrada
`repositories.renovarte-colibri-rag` de [`manifest.yaml`](../../manifest.yaml).

## Por qué existe

Concentra toda la lógica de IA de Colibrí. En cada turno hace una sola
llamada al LLM para clasificar el mensaje y extraer tipo de piel y
presupuesto. Después busca productos en el catálogo sincronizado, arma
los combos **en código** y verifica cada producto contra el catálogo real.
Estar separado del transporte permite cambiar modelo, embeddings o reglas
de combos sin tocar el WebSocket.

## Qué no hace

- No maneja la conexión: eso es de [chat-gateway](./repo-renovarte-chat-gateway.md).
  Este repo solo responde por `postToConnection`.
- No deja que el LLM haga cuentas: los precios y totales de los combos
  salen siempre de `combos.ts`.
- No dibuja nada: la UI es de [catalogo](./repo-renovarte-catalogo.md).

## Documentos

- README (setup, sync y debug local): [`README.md`](../../renovarte-colibri-rag/README.md)
- Arquitectura interna: [`docs/ARQUITECTURA.md`](../../renovarte-colibri-rag/docs/ARQUITECTURA.md)
- Diseño: [`rfc-conector-llm-rag.md`](../../specs/0016-chat-recomendador-cremas/rfc-conector-llm-rag.md)
- Spec de origen: [0016](../../specs/0016-chat-recomendador-cremas/spec.md)
