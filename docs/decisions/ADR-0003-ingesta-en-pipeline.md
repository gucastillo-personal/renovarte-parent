---
id: ADR-0003
title: Ingesta en renovarte-pipeline (Python); products.json como único contrato con el catálogo
status: Accepted
date: 2026-09-13
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-pipeline]]", "[[repo-renovarte-catalogo]]"]
domains: ["[[domain-precios]]", "[[domain-catalogo]]"]
providers: ["[[provider-serlaca-laca]]", "[[provider-github]]"]
origin: "PLAN.md"
supersedes: []
extends: ["[[ADR-0001-superproyecto-submodulos]]"]
superseded_by:
constitution: ["§I.1 sin costo/margen/precio LACA fuera del pipeline", "§II.4 un repo, una responsabilidad", "renovarte-catalogo §II.8 schema público = RFC §2.4"]
cost_impact: "$0"
personal_data: false
reversibility: media
retroactive: true
detail: "PLAN.md § Arquitectura objetivo y § Qué se migra"
---

# ADR-0003 — Ingesta en `renovarte-pipeline` (Python); `products.json` como único contrato con el catálogo

## Contexto

La ingesta (API Serlaca, CSV, y la extracción del PDF de LACA que pedía la
spec 0008) vivía en `renovarte-catalogo` en TypeScript, con una excepción
en Python solo para el PDF (`pdfplumber`). Eso mezclaba presentación con
procesamiento de datos y hacía que el repo que se publica tocara costo y
margen. [`PLAN.md`](../../PLAN.md) movió todo ese trabajo a un repo
nuevo.

## Problema

¿Dónde vive la ingesta y el pricing, y cuál es el único punto de
acoplamiento con el catálogo?

## Restricciones

- [ADR-0001](./ADR-0001-superproyecto-submodulos.md): un repo, una
  responsabilidad.
- [ADR-0002](./ADR-0002-catalogo-ssg-sin-backend.md): el catálogo es
  estático y no tiene backend.
- Costo, margen y precio de lista de LACA nunca salen del pipeline
  (constitution §I.1).

## Decisión

Toda la ingesta y el pricing viven en **`renovarte-pipeline`, en
Python** (uv, pydantic, pdfplumber). Es el **único repo que ve costo y
margen**. Su salida es `products.json`, con el schema público de RFC-0001
§2.4 del catálogo, y ese archivo es el **único contrato** entre los dos
repos. El schema no cambió con la migración. Agregar un campo requiere
enmendar el RFC en los dos repos.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Dejar la ingesta en el catálogo (TS + excepción Python) | Sin migración | El repo publicado ve el costo; dos lenguajes en un repo de presentación | Rompe la responsabilidad única y aumenta el riesgo de fuga |
| Repo nuevo en TypeScript | Mismo lenguaje que el catálogo | El PDF ya requería Python; peor ecosistema para datos tabulares | Python ya era necesario para `pdfplumber` |
| **Repo nuevo en Python, contrato = `products.json`** | Separación limpia; el costo nunca llega al catálogo; buen stack de datos | Dos lenguajes en el proyecto; migración 1:1 con gate de diff | Elegida |

## Por qué

El catálogo queda 100 % TypeScript y solo recibe datos ya procesados. El
costo y el margen existen en un solo repo, y el contrato es un archivo
cuyo contenido se puede auditar con `check:leak` en origen y en destino.
Python era necesario igual para el PDF.

## Consecuencias

- El nombre `renovarte-pipeline` (no `-ingesta`) deja lugar para fuentes
  futuras más allá de LACA/Serlaca.
- `check:leak` corre dos veces: en el pipeline antes de publicar y en el
  `pnpm gate` del catálogo.
- `products.json` publicado pasa a ser la fuente de catálogo de **todos**
  los consumidores posteriores (Colibrí, órdenes). Esa decisión tendrá su
  propio ADR.
- La forma del handoff (PR automático con ingesta manual) y el precio del
  PDF son decisiones aparte, todavía sin ADR (ver el backfill pendiente en
  el [README](./README.md)).

## Trade-offs y riesgos

- Migrar código que lee un archivo no migra el archivo. Pasó con
  `data/offers.json` (PLAN.md, hallazgo 2 del 2026-09-14). Mitigación:
  verificar los datos de entrada aparte del código.
- Un cambio de schema toca dos repos. Mitigación: la regla de enmienda en
  los dos RFC y la nota del contrato en
  [`contract-products-json`](../contracts/contract-products-json.md).

## Salida / reversión

Volver a juntar la ingesta con el catálogo es técnicamente posible, pero
reintroduce el costo en el repo publicado. Costo medio.

## Detalle técnico

[`PLAN.md`](../../PLAN.md) § Arquitectura objetivo, § Qué se migra y
§ Fases de ejecución 1 a 5.

## Notas posteriores
