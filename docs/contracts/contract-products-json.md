---
type: contract
contract: products-json
domains: ["[[domain-catalogo]]", "[[domain-precios]]"]
---

# Contrato: `products.json`

Productor, consumidores y cómo le llega a cada uno: entrada
`contracts.products-json` de [`manifest.yaml`](../../manifest.yaml).

**Schema (única fuente):** [RFC-0001 del pipeline §2.4](../../renovarte-pipeline/docs/rfc/0001-arquitectura-pipeline.md#24-modelo-de-datos-público-productsjson).
Si otro documento copia el schema, la versión que vale es esta y el otro
debería linkear a ella.

## Qué hay que saber antes de tocarlo

- Es **el** catálogo del sistema. Todo consumidor lee la versión publicada
  y ninguno arma una propia.
- **Nunca** incluye costo, margen ni precio profesional. Hay un
  `check:leak` en el productor y otro en el catálogo.
- Cambiar un campo cambia el contrato y necesita un ADR. Los consumidores
  se adaptan en el mismo cambio o antes de que se publique.
