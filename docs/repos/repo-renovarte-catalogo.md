---
type: repo
repo: renovarte-catalogo
domains: ["[[domain-catalogo]]", "[[domain-colibri]]", "[[domain-ordenes]]"]
---

# renovarte-catalogo

Rol, stack, gate, deploy, contratos y proveedores: entrada
`repositories.renovarte-catalogo` de [`manifest.yaml`](../../manifest.yaml).

## Por qué existe

Es la cara pública de RenovArte: el sitio donde el visitante ve los
productos, arma el carrito y conversa con Colibrí. Se separó de la ingesta
para que el sitio sea **solo presentación**. Es un build estático (SSG), sin
backend ni base de datos, con costo de infraestructura $0.

## Qué no hace

- No calcula precios ni ve costo o margen; solo lee el `products.json` que
  le llega por PR ([products-json](../contracts/contract-products-json.md)).
- No tiene runtime propio. El chat y las órdenes existen en el sitio, pero
  su lógica corre en otros repos:
  [chat-gateway](./repo-renovarte-chat-gateway.md),
  [colibri-rag](./repo-renovarte-colibri-rag.md) y
  [ordenes](./repo-renovarte-ordenes.md).

## Documentos

- Constitution: [`specs/constitution.md`](../../renovarte-catalogo/specs/constitution.md)
- PRD: [`docs/PRD/PRD-catalogo-renovarte.md`](../../renovarte-catalogo/docs/PRD/PRD-catalogo-renovarte.md)
- RFC de arquitectura: [`docs/rfc/0001-arquitectura-catalogo.md`](../../renovarte-catalogo/docs/rfc/0001-arquitectura-catalogo.md)
- Marca: [`docs/brand.md`](../../renovarte-catalogo/docs/brand.md)
- Specs propias del repo: [`specs/README.md`](../../renovarte-catalogo/specs/README.md)
