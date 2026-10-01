---
id: ADR-0009
title: "Handoff pipeline → catálogo por PR automático; ingesta y transform manuales"
status: Accepted
date: 2026-09-14
deciders: CTO/CEO
level: L2
repos: ["[[repo-renovarte-pipeline]]", "[[repo-renovarte-catalogo]]"]
domains: ["[[domain-catalogo]]", "[[domain-precios]]"]
providers: ["[[provider-github]]"]
origin: "PLAN.md"
supersedes: []
extends: ["[[ADR-0003-ingesta-en-pipeline]]"]
superseded_by:
constitution: ["§I.1 sin costo/margen/precio LACA fuera del pipeline", "§I.2 ningún secreto commiteado", "§II.5 $0 infraestructura"]
cost_impact: "$0 (GitHub Actions free tier)"
personal_data: false
reversibility: alta
retroactive: true
detail: "renovarte-pipeline .github/workflows/publish.yml y src/pipeline/publish/; docs/flujo-precio-pdf.md"
---

# ADR-0009 — Handoff pipeline → catálogo por PR automático; ingesta y transform manuales

## Contexto

Con la ingesta separada del catálogo
([ADR-0003](./ADR-0003-ingesta-en-pipeline.md)), el `products.json`
generado en `renovarte-pipeline` tiene que llegar a
`renovarte-catalogo`. [`PLAN.md`](../../PLAN.md) (Fase 3) diseñó una
GitHub Action con cron que corría `ingest` + `transform` + `publish`. La
forma final se ajustó dos veces después de implementarla:

- **2026-09-14** (`98f5cb7`): la Action deja de generar datos. `ingest`,
  `transform` y `pdf-extract` pasan a ser siempre manuales, en la máquina
  del admin.
- **2026-09-17** (`14bcf42`): el cron semanal se reemplaza por un
  disparo en push a `main` del pipeline, filtrado por
  `public/data/products.json`. `workflow_dispatch` queda como fallback.

## Problema

¿Cómo llega un `products.json` nuevo al catálogo, con control humano y
sin exponer credenciales ni datos de costo?

## Restricciones

- [ADR-0002](./ADR-0002-catalogo-ssg-sin-backend.md): el catálogo es
  estático; sin storage compartido ni backend.
- $0 de infraestructura (constitution §II.5).
- Costo y margen nunca cruzan al catálogo (constitution §I.1); ningún
  secreto en el repo (§I.2).
- Nunca push directo a `main` y nunca merge automático (`CLAUDE.md`).

## Decisión

1. El admin corre `ingest` / `transform` (y `pdf-extract` cuando cambia el
   PDF) **a mano**, revisa el diff de `products.json` y lo sube por PR a
   `renovarte-pipeline`, que pasa por su CI (`make check`).
2. Al mergear a `main` un cambio en `public/data/products.json`, la Action
   `publish.yml` corre **solo `publish`**: `leak_check()` en origen,
   después la rama fija `pipeline/auto-update-products` en
   `renovarte-catalogo` (reseteada a `main` en cada corrida, con force-push)
   y un PR abierto o reutilizado. Sin cambios, no hace nada.
3. Ese PR **lo mergea siempre una persona**. Ahí corre `pnpm gate` del
   catálogo, con su propio `check:leak` como defensa en destino.
4. La única credencial en CI es `CATALOGO_PAT`: un PAT fine-grained con
   acceso **solo** a `renovarte-catalogo` (Contents + Pull requests).

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Artifact/release descargado en el build del catálogo | Sin PRs | El build depende de otro repo; no queda diff revisable | Saca el control humano del cambio de precios |
| Storage compartido (bucket) leído en runtime | Desacople total | Infra con costo; el catálogo pasa a tener runtime de datos | Rompe ADR-0002 y $0 |
| Action con cron que hace ingest + transform + publish (diseño de `PLAN.md`) | Totalmente automático | Secrets de Serlaca y márgenes en GitHub; nadie ve el diff antes del PR | Reemplazado el 2026-09-14 |
| Disparo por cron semanal (solo publish) | Simple | Retraso arbitrario; corre aunque no haya nada | Reemplazado el 2026-09-17 por el disparo por push |
| **Ingesta manual + PR automático disparado por push** | Dos puntos de control humano; mínima superficie de credenciales en CI | El admin tiene que correr la ingesta | Elegida |

## Por qué

El cambio de precios es la decisión de negocio más sensible del sistema,
y el control humano sobre el diff ya demostró su valor: así se encontró
el problema del piso de margen
([ADR-0008](./ADR-0008-precio-pdf-automatico-piso-margen.md)). Dejar el
procesamiento fuera de CI saca de GitHub la API key de Serlaca y la
configuración de márgenes. El disparo por push publica justo cuando hay
un dato nuevo, no según un horario.

## Consecuencias

- Hay dos puntos de control humano: el merge del `products.json` en el
  pipeline y el merge del PR en el catálogo.
- `leak_check` corre dos veces: en origen, en `publish`, y en destino, en
  `pnpm gate`.
- La misma Action es el punto donde se emiten eventos de cambio de precio
  hacia `renovarte-events`, en pasos best-effort que nunca rompen el
  publish. Esa decisión tendrá su propio ADR.

## Trade-offs y riesgos

- Depende de que el admin corra la ingesta: si no lo hace, el catálogo
  queda con precios viejos. Se acepta porque los precios de LACA cambian
  con poca frecuencia.
- El PAT vence y hay que rotarlo. Si vence, el publish falla de forma
  visible en Actions; no publica nada roto.
- La rama del bot se fuerza en cada corrida: un cambio manual sobre ella
  se pierde. Por diseño, esa rama es solo del bot.

## Salida / reversión

Alta: cambiar el disparador o volver a correr la ingesta en CI es editar
`publish.yml` y mover secrets. El contrato (`products.json`) no cambia.

## Detalle técnico

`renovarte-pipeline` [`.github/workflows/publish.yml`](../../renovarte-pipeline/.github/workflows/publish.yml)
y `src/pipeline/publish/` (`git_ops.py`, `github_api.py`, `leak_check.py`);
diagrama en [`docs/flujo-precio-pdf.md`](../flujo-precio-pdf.md).

## Notas posteriores
