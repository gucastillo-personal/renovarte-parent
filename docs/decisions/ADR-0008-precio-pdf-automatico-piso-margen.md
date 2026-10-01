---
id: ADR-0008
title: Precio ABC del PDF de LACA como fuente primaria automática, con piso de margen
status: Accepted
date: 2026-09-14
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-pipeline]]"]
domains: ["[[domain-precios]]"]
providers: ["[[provider-serlaca-laca]]"]
origin: "PLAN.md"
supersedes: ["[[ADR-0007-precio-pdf-revision-manual]]"]
extends: []
superseded_by:
constitution: ["§I.1 sin costo/margen/precio LACA fuera del pipeline"]
cost_impact: "$0"
personal_data: false
reversibility: alta
retroactive: true
detail: "docs/flujo-precio-pdf.md; renovarte-pipeline src/pipeline/transform/pricing.py build_public_product()"
---

# ADR-0008 — Precio ABC del PDF de LACA como fuente primaria automática, con piso de margen

## Contexto

[ADR-0007](./ADR-0007-precio-pdf-revision-manual.md) (spec 0008) hacía
del PDF un override opcional con decisión manual por producto. Se
construyó en `renovarte-pipeline` y, al validarlo con datos reales el
2026-09-14, se reemplazó por un precio automático (`a781946`). La
primera corrida real con credenciales de Serlaca mostró después que, en
~1 de cada 3 productos, LACA publica Precio ABC = Precio Profesional (el
costo de RenovArte). Usar ABC directo vendía a margen cero. El admin lo
detectó revisando a mano el producto `017060004` antes de publicar.
Ese mismo día se agregó el piso (`4d568a3`).

## Problema

¿Cómo usamos el precio sugerido de LACA sin trabajo manual por producto y
sin vender nunca por debajo del margen configurado?

## Restricciones

- Precio Profesional es costo y nunca sale del pipeline (constitution
  §I.1). La referencia pública `data/reference/laca_pdf_precios.csv` no lo
  incluye.
- Ningún producto puede desaparecer del catálogo por no estar en el PDF
  de un mes dado.
- El schema público de `products.json` no cambia
  ([ADR-0003](./ADR-0003-ingesta-en-pipeline.md)).

## Decisión

En `transform`, para todo producto cuyo código matchea en el PDF y tiene
Precio ABC:

```
precio_venta = max(precio_abc, costo × (1 + margen))
```

Sin match, o sin ABC, sigue con `costo × (1 + margen)`. El descuento de
oferta (`data/offers.json`) se aplica **después**, sobre el precio ya
resuelto. No hay revisión por producto ni archivo de decisiones. Precio
Catálogo ya no se usa. El control humano está en el diff del
`products.json` que el admin commitea y en el PR al catálogo, que se
mergea a mano.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Revisión manual por producto ([ADR-0007](./ADR-0007-precio-pdf-revision-manual.md)) | Control total | No escala; estado extra que persistir | Reemplazada |
| ABC automático, sin piso | Simple; sigue la lista de LACA | Margen cero en ~1/3 del catálogo real | Encontrado en la corrida real |
| **ABC automático con piso de costo+margen** | Sin trabajo manual; el margen configurado se garantiza | El precio puede quedar por encima del sugerido por LACA | Elegida |

## Por qué

El precio de LACA gana solo cuando ya es mejor que el margen de
RenovArte, y nunca vende por debajo de él. Sobre el catálogo real, de
159 productos con match, 49 subieron y ninguno bajó. Sin el piso, habrían
sido 111 bajas, varias a costo, y 48 subas. La revisión del diff de
precios antes de publicar sigue siendo el control humano que importa: fue
justamente lo que encontró el problema.

## Consecuencias

- `pdf-extract`, `ingest` y `transform` son manuales en la máquina del
  admin. El PDF entra por el CSV público derivado.
- Una oferta sobre un producto con precio del PDF descuenta sobre el
  precio ya resuelto (con piso), no sobre costo+margen.
- Hay tests de regresión del piso, con y sin oferta, en
  `renovarte-pipeline`.

## Trade-offs y riesgos

- El precio publicado puede quedar por encima del ABC sugerido por LACA.
  El PRD §2.1 pide estar por debajo del precio público de LACA, y queda a
  criterio del admin al revisar el diff, como ya preveía la spec 0008.
- Si LACA cambia el formato del PDF, el match se rompe. El efecto es que
  los productos caen al fallback de costo+margen, nunca desaparecen.

## Salida / reversión

Alta: el overlay es una función (`build_public_product()`). Volver a solo
costo+margen es dejar de cargar el CSV de referencia.

## Detalle técnico

[`docs/flujo-precio-pdf.md`](../flujo-precio-pdf.md) (diagrama completo);
`renovarte-pipeline` `src/pipeline/transform/pricing.py`
(`build_public_product()`) y `build_catalog.py`;
[`PLAN.md`](../../PLAN.md) § Hallazgos post-implementación, punto 1.

## Notas posteriores
