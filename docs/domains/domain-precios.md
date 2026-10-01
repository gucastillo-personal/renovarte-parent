---
type: domain
domain: precios
---

# Dominio: precios

Cómo se calcula el `precio_venta` de cada producto. El cálculo se hace
entero en `renovarte-pipeline`.

## Reglas que lo definen

- **Fuente primaria: el precio ABC del PDF de LACA**, aplicado
  automáticamente a todo código que matchea, con **piso de margen**:
  `precio_venta = max(precio_abc, costo × (1 + margen))`. Sin el piso, en
  cerca de 1 de cada 3 productos el ABC es igual al costo y se vendía a
  margen cero ([`PLAN.md`](../../PLAN.md), hallazgos del 2026-09-14). Si
  no hay match, el precio es costo + margen. No hay revisión manual por
  producto: la spec 0008 la pedía y quedó reemplazada.
- El descuento de oferta (`data/offers.json`) se aplica **después**, sobre
  el precio ya resuelto.
- El **precio profesional** (lo que paga el revendedor) es información
  sensible, del mismo tipo que el costo. Nunca se commitea ni se publica.
- Un cambio de precio dispara un evento best-effort hacia
  [notificaciones](./domain-notificaciones.md).

## Dónde se ve funcionando

- [`flujo-precio-pdf.md`](../flujo-precio-pdf.md): de punta a punta, del
  PDF a la página.
- [`flujo-event-driven-precios.md`](../flujo-event-driven-precios.md):
  aviso de cambio de precio.
