---
type: domain
domain: catalogo
---

# Dominio: catálogo

Los productos que RenovArte muestra y vende: nombre, categoría, imagen y
precio de venta publicado. El catálogo publicado es el
[`products.json`](../contracts/contract-products-json.md), que todos los
consumidores leen: el sitio, Colibrí y órdenes.

## Reglas que lo definen

- **Nunca costo, margen ni precio de lista del proveedor** fuera de
  `renovarte-pipeline` (constitution root §I.1).
- Lo que no está en el `products.json` publicado no existe para el resto
  del sistema. Ningún consumidor arma un catálogo propio con otra fuente.
- Cada cambio de catálogo llega al sitio por un PR que revisa una persona;
  nunca hay auto-merge.

## Dónde se ve funcionando

- [Flujo 1 — catálogo de productos](../arquitectura-general.md#flujo-1--catálogo-de-productos-pipeline--catalogo)
- Categorías y agrupación: specs de `renovarte-catalogo` (0003, 0012, 0015)
  y de `renovarte-pipeline` (0001).
