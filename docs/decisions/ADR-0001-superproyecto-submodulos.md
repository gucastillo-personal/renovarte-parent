---
id: ADR-0001
title: Superproyecto con submódulos; un repo, una responsabilidad
status: Accepted
date: 2026-09-13
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-catalogo]]", "[[repo-renovarte-pipeline]]"]
domains: []
providers: ["[[provider-github]]"]
origin: "PLAN.md"
supersedes: []
extends: []
superseded_by:
constitution: ["§II.4 un repo, una responsabilidad", "§II.6 todo repo nuevo es submódulo", "§II.7 todo repo nuevo nace con CLAUDE.md", "§III.8 specs cross-repo en el root"]
cost_impact: "$0"
personal_data: false
reversibility: media
retroactive: true
detail: "PLAN.md § Arquitectura objetivo y § Fases de ejecución (Fase 0)"
---

# ADR-0001 — Superproyecto con submódulos; un repo, una responsabilidad

## Contexto

Hasta 2026-09-13 todo vivía en `renovarte-catalogo`: la web y también la
ingesta (API Serlaca, CSV, PDF LACA) y el pricing, en TypeScript con una
excepción en Python para el PDF. El catálogo no podía ser "solo
presentación", y cada fuente nueva agrandaba un repo que se despliega en
Vercel. [`PLAN.md`](../../PLAN.md) separó la ingesta en un repo propio y
armó `renovarte-parent` para contener a los dos.

## Problema

¿Cómo organizamos varios repos con roles distintos sin perder una vista
única del sistema ni mezclar sus responsabilidades?

## Restricciones

- $0 de infraestructura (constitution §II.5).
- Cada repo conserva su propio ciclo de CI, deploy y reglas (`CLAUDE.md`).

## Decisión

`renovarte-parent` es un superproyecto **sin build propio** que contiene
cada repo como **submódulo git**. Cada submódulo tiene **una sola
responsabilidad**. Si una capacidad nueva no encaja limpiamente en un repo
existente, va a un repo nuevo, que se agrega como submódulo desde el root
(nunca anidado dentro de otro) y nace con su propio `CLAUDE.md`. Las
specs, ADRs y documentos que cruzan repos viven en el root.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Monorepo (un solo repo con carpetas) | Un solo clone, refactors atómicos entre partes | Mezcla stacks (Next.js, Python, Terraform) y ciclos de deploy; Vercel vería todo | Rompe "un repo, una responsabilidad" y el aislamiento del costo |
| Repos sueltos, sin parent | Simple, sin submódulos | Sin un lugar para lo cross-repo (specs, ADRs, manifest); la vista del sistema queda dispersa | Las features cross-repo (0016, 0017) necesitan un hogar común |
| **Superproyecto + submódulos** | Un lugar para lo cross-repo; cada repo conserva su CI, deploy y permisos | Fricción de submódulos (punteros a commits, `--recurse-submodules`) | Elegida |

## Por qué

Permite que cada repo tenga su stack y su ciclo de deploy sin
interferencias (el catálogo en Vercel, el pipeline en GitHub Actions, la
infra en Terraform) y, al mismo tiempo, da un único lugar para el
conocimiento que los cruza.

## Consecuencias

- Cada capacidad nueva tiende a ser un repo nuevo: `renovarte-events`,
  `renovarte-chat-gateway`, `renovarte-colibri-rag` y `renovarte-ordenes`
  siguieron este patrón.
- Toda dependencia entre repos es un **contrato** declarado en
  [`manifest.yaml`](../../manifest.yaml), no un import.
- El root solo actualiza punteros de submódulo; el código cambia en cada
  repo, con su propio PR.

## Trade-offs y riesgos

- Puntero de submódulo desactualizado o commiteado por accidente → se
  revisa el `git status` del root antes de cada commit.
- Más repos que mantener → el manifest y las notas `docs/repos/` dan el
  mapa.

## Salida / reversión

Pasar a monorepo es posible (`git subtree` o import con historia), pero
habría que unificar CI y deploy. Costo medio, sin impacto para el usuario
final.

## Detalle técnico

[`PLAN.md`](../../PLAN.md) § Arquitectura objetivo y § Fases de ejecución
(Fase 0).

## Notas posteriores
