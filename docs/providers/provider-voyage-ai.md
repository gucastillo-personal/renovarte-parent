---
type: provider
provider: voyage-ai
---

# Proveedor: Voyage AI

Servicios, costo y repos que lo usan: entrada `providers.voyage-ai` de
[`manifest.yaml`](../../manifest.yaml).

## Para qué lo usamos

Embeddings para el retrieval de Colibrí: los productos elegibles del
catálogo y la consulta de cada turno. Los embeddings del catálogo se
recalculan solo para los productos nuevos o modificados, en el sync
programado de `renovarte-colibri-rag`.

## Riesgos y límites

- Funciona dentro del free tier. Un catálogo mucho más grande, o recalcular
  todo de una vez, podría salirse de ese límite.
- Si cambia el modelo de embeddings, hay que recalcular todo
  `data/candidates.json`, porque no se pueden mezclar vectores de modelos
  distintos.
- La API key (`VOYAGE_API_KEY`) se usa en el sync (GitHub Action) y en el
  runtime del conector, nunca en el repo.
- Elección y alternativas: `rfc-conector-llm-rag.md` §3.2 (spec 0016).
