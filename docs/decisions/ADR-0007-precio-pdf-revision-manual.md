---
id: ADR-0007
title: Precio del PDF de LACA como override opcional, con decisión manual por producto
status: Superseded
date: 2026-09-12
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-catalogo]]", "[[repo-renovarte-pipeline]]"]
domains: ["[[domain-precios]]"]
providers: ["[[provider-serlaca-laca]]"]
origin: "renovarte-catalogo specs/0008-pdf-price-override/spec.md"
supersedes: []
extends: ["[[ADR-0003-ingesta-en-pipeline]]"]
superseded_by: "[[ADR-0008-precio-pdf-automatico-piso-margen]]"
constitution: ["§I.1 sin costo/margen/precio LACA fuera del pipeline"]
cost_impact: "$0"
personal_data: false
reversibility: alta
retroactive: true
detail: "renovarte-catalogo specs/0008-pdf-price-override/spec.md § Scope"
---

# ADR-0007 — Precio del PDF de LACA como override opcional, con decisión manual por producto

> **Superseded por [ADR-0008](./ADR-0008-precio-pdf-automatico-piso-margen.md)
> (2026-09-14).** Se registra porque se construyó y se descartó después de
> probarlo con datos reales; explica por qué hoy no existe una página de
> revisión de precios.

## Contexto

Hasta acá, `precio_venta` salía siempre de `costo × (1 + margen)`. El PDF
de LACA trae tres precios por producto: Profesional (el costo de
RenovArte), ABC (precio sugerido de venta) y Catálogo (precio al
consumidor final). El admin quería poder usar ABC o Catálogo como precio
publicado en productos puntuales.

## Problema

¿Cómo incorporamos el precio del PDF de LACA al `precio_venta` sin
publicar el costo y sin pisar el catálogo entero de forma automática?

## Restricciones

- Precio Profesional es costo: nunca se commitea ni es una opción de
  precio de venta (constitution §I.1).
- El schema público de `products.json` no cambia
  ([ADR-0003](./ADR-0003-ingesta-en-pipeline.md)).

## Decisión

El PDF es una **fuente opcional** de precio. El admin revisa, en una
página local (nunca desplegada), cada producto con match: el precio
actual, ABC, Catálogo y el margen implícito de cada uno. Después elige,
**producto por producto**, entre ABC (preseleccionado), Catálogo o
mantener costo+margen. Las decisiones se persisten en
`data/reference/precio_pdf_decisiones.json` y `transform` las aplica como
overlay antes del descuento de oferta. "Nunca se sobreescribe el catálogo
completo de forma automática."

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Aplicar el PDF automático a todo el catálogo | Sin trabajo manual | Pisa precios sin control humano | En su momento se consideró riesgoso |
| **Override manual por producto** | Control total del admin | Trabajo manual en cada PDF nuevo; estado extra que persistir | Elegida en la spec 0008 original |

## Por qué

Daba control explícito sobre cada cambio de precio en un momento en que
el PDF era una fuente nueva, todavía no validada con datos reales.

## Consecuencias

- Python (`pdfplumber`) entra al proyecto para la extracción, como
  excepción en el catálogo (§III.11 de su constitution). Esa excepción se
  cayó con la migración a `renovarte-pipeline`.
- Requería una página de revisión, persistencia de decisiones y
  subcomandos `pdf review` / `pdf apply-decisions`.

## Trade-offs y riesgos

- Revisar cientos de productos en cada PDF nuevo no escala. Esto es lo
  que llevó al reemplazo.

## Salida / reversión

Reemplazada por [ADR-0008](./ADR-0008-precio-pdf-automatico-piso-margen.md).
La página de revisión, `pdf_decisions.py`, `pdf_review.py` y el archivo de
decisiones (que nunca llegó a commitearse) se eliminaron en
`renovarte-pipeline` `a781946`.

## Detalle técnico

`renovarte-catalogo` [`specs/0008-pdf-price-override/spec.md`](../../renovarte-catalogo/specs/0008-pdf-price-override/spec.md)
§ Scope (puntos 3 a 5); RFC-0001 del catálogo, enmienda 2026-09-12.

## Notas posteriores
