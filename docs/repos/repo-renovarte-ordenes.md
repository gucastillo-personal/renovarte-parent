---
type: repo
repo: renovarte-ordenes
status: planned
domains: ["[[domain-ordenes]]"]
---

# renovarte-ordenes

Rol, stack, contratos y proveedores: entrada
`repositories.renovarte-ordenes` de [`manifest.yaml`](../../manifest.yaml).
**Todavía no existe.** Se crea en la Fase 4 de la spec 0017.

## Por qué existe

El carrito necesita un servidor que reciba la orden, la valide contra el
catálogo publicado y la entregue a RenovArte. Ese servidor no puede vivir
en `renovarte-catalogo`, que no tiene runtime, y tampoco encaja en el chat.
Por eso es un repo aparte. Entrega cada orden por **dos canales** (mail y
un canal privado de Discord) y la da por aceptada si **al menos uno** la
recibió.

## Qué no hace

- No cobra ni coordina el envío: eso se resuelve después, fuera del sitio.
- No acepta precios que mande el cliente. Valida cada línea contra el
  [products.json](../contracts/contract-products-json.md) publicado.

## Documentos

La spec y el diseño están en la rama `feature/carrito-orden-compra`, en
`specs/0017-carrito-orden-compra/`. Todavía no están en `main`:

- `spec.md`: alcance, AC y decisiones de producto (Ley 25.326, retención).
- `rfc-servicio-ordenes.md`: contrato HTTP, validación, doble canal,
  anti-abuso, datos personales y tope de costo.
