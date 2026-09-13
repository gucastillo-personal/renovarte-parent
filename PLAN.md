# Plan de reorganización — RenovArte (parent + submodules)

**Estado:** aprobado, en ejecución.
**Fecha:** 2026-09-13.

## Objetivo

Separar la ingesta/procesamiento de datos (lectura de PDFs, API de Serlaca,
CSV) de la web de catálogo, para que:

- `renovarte-catalogo` se dedique solo a **mostrar** información ya procesada
  (catálogo, marca, futuro carrito/turnero).
- Un repo nuevo en Python (`renovarte-pipeline`) sea el único responsable de
  **ingerir y transformar** datos desde distintas fuentes (PDF, API, CSV).

## Arquitectura objetivo

```
renovarte-parent/                    (superproyecto, sin build propio)
├── renovarte-catalogo/  (submodule)  Next.js SSG — SOLO presentación
│     public/data/products.json  ←── único contrato de entrada
│     src/, specs/, docs/         → sin cambios de lógica de negocio
│
└── renovarte-pipeline/  (submodule, NUEVO)  Python — SOLO ingesta/transformación
      fuentes: API Serlaca, CSV fallback, PDF LACA (pdfplumber)
      salida:  products.json (mismo schema RFC-0001 §2.4)
      corre en GH Actions (cron) → abre PR a renovarte-catalogo
```

El contrato entre los dos repos es el que ya existe hoy: `public/data/products.json`
con el schema de `RFC-0001 §2.4` de `renovarte-catalogo`
(`proveedor, categoria, nombre, presentacion, descripcion, precio_venta, imagen,
en_oferta, tags`). **No cambia el schema** — la web (`src/lib/products.ts`,
`src/lib/types.ts`, componentes) queda intacta.

## Qué se migra (1:1, TypeScript → Python) — ya construido y probado hoy

| Hoy en `renovarte-catalogo` | Pasa a `renovarte-pipeline` |
|---|---|
| `scripts/ingest.ts` (etapa 1: descarga cruda) | `pipeline/ingest/serlaca_download.py` |
| `scripts/transform.ts` (etapa 2: orquestación) | `pipeline/transform/build_catalog.py` |
| `scripts/lib/pricing.ts` (margen, `buildPublicProduct`) | `pipeline/transform/pricing.py` |
| `scripts/lib/cost-row.ts` (modelo intermedio) | `pipeline/models.py` (pydantic) |
| `scripts/lib/categories.ts` (limpieza de categorías) | `pipeline/transform/categories.py` |
| `scripts/lib/images.ts` (resolución de imagen) | `pipeline/transform/images.py` |
| `scripts/lib/html.ts` (limpieza de HTML/entidades) | `pipeline/sources/html.py` |
| `scripts/lib/offers.ts` + `data/offers.json` | `pipeline/transform/offers.py` (el `.json` se muda: es input de negocio, no de presentación) |
| `scripts/lib/sources/csv.ts` | `pipeline/sources/csv_source.py` |
| `scripts/lib/sources/serlaca-api.ts` | `pipeline/sources/serlaca_api.py` |
| `data/raw/`, `data/input/` (gitignored) | se mudan tal cual (gitignored también ahí) |
| `.env.example` (`SERLACA_*`, `MARGIN_PERCENT_*`) | pasa entero a `renovarte-pipeline` |
| `scripts/check-leak.mjs` | se duplica (defensa en origen + defensa en destino) |

Cada módulo tiene tests Vitest ya escritos (0009 sola tiene 98 tests): se migra
módulo por módulo, portando el mismo caso de test a pytest — no se reinventa
cobertura.

## Qué se construye nuevo directo en Python (no hay nada que migrar)

La spec `0008` de `renovarte-catalogo` (precio desde PDF de LACA, hoy
"Backlog") ya definió formalmente en `constitution.md §III.11` y
`RFC-0001 §4` que esa pieza se hace en Python + `pdfplumber`, corriendo
local/CI, nunca en Vercel. Se construye directo en `renovarte-pipeline` en
vez de escribirla en TS y migrarla después:

- `pipeline/sources/pdf_laca.py`: extrae `codigo, nombre_pdf,
  precio_profesional, precio_abc, precio_catalogo` a un crudo gitignored;
  deriva `data/reference/laca_pdf_precios.csv` (público, sin
  `precio_profesional`).
- Match contra `products.json`, decisión manual por producto (ABC / Catálogo
  / actual) — la "página de revisión" (spec 0008 pt.3) deja de ser una
  página Next.js interna; se resuelve como reporte CLI/HTML local generado
  por el propio pipeline.
- `data/reference/precio_pdf_decisiones.json` se aplica como overlay en
  `transform`, antes del descuento de ofertas (mismo orden que el AC-5 de la
  0008).

Como esto vive enteramente en el repo nuevo, se cae la excepción de
`constitution.md §III.11` en `renovarte-catalogo` — ese repo vuelve a ser
100% TypeScript.

## Handoff automatizado (ingesta → catálogo)

1. `pipeline publish`: genera `products.json`, hace checkout de
   `renovarte-catalogo`, commitea en una rama y abre PR.
2. GitHub Action en `renovarte-pipeline` con `schedule` (cron) +
   `workflow_dispatch` manual — es lo que la spec `0010` (placeholder, ya
   prevista en `renovarte-catalogo`) pedía, corriendo en el repo correcto.
3. Credencial: PAT de vida corta o GitHub App **scoped solo a
   `renovarte-catalogo`**, guardado como secret en `renovarte-pipeline` —
   nunca push directo a `main`, siempre PR (coherente con el principio de la
   0008 de "nunca se sobreescribe el catálogo completo de forma
   automática"). Merge del PR queda en revisión humana, al menos en la
   primera etapa (no auto-merge).
4. `check:leak` corre dos veces: dentro de `renovarte-pipeline` antes de
   abrir el PR (defensa en origen), y la que ya existe en
   `renovarte-catalogo` como gate de `pnpm gate` antes de deploy (defensa en
   destino).

## Fases de ejecución

**Fase 0 — Esqueleto**
1. Armar `renovarte-pipeline`: `pyproject.toml` (uv), `ruff`+`mypy`+`pytest`,
   layout `src/pipeline/`, `.gitignore` (`data/raw/`, `.env.local`), README.
2. En `renovarte-parent`: agregar `renovarte-catalogo` y `renovarte-pipeline`
   como submodules; README raíz explicando `git clone --recurse-submodules`
   y el rol de cada uno.

**Fase 1 — Migración 1:1 sin cambio de comportamiento**
3. Portar modelos + pricing + categories + images + html + offers, con sus
   tests.
4. Portar los dos adaptadores de fuente (CSV, Serlaca API).
5. Portar orquestación (`pipeline ingest`, `pipeline transform`).
6. **Gate de la migración**: correr el pipeline viejo (TS) y el nuevo
   (Python) sobre el mismo dump real y diffear el `products.json`
   resultante — tiene que salir idéntico. Sin esto no se da por migrado.

**Fase 2 — PDF (spec 0008), nuevo**
7. `pdf_laca.py` + matching + reporte de revisión + persistencia de
   decisiones + overlay en transform.

**Fase 3 — Automatización**
8. `pipeline publish` + GitHub Action (cron/manual) + leak-check en origen.

**Fase 4 — Baja de código viejo en `renovarte-catalogo`**
9. Borrar `scripts/ingest.ts`, `scripts/transform.ts`, `scripts/lib/**`,
   `data/raw/`, `data/input/`, `data/offers.json`, deps (`csv-parse`,
   `dotenv`, `tsx` si quedan sin uso), sus specs de Vitest.
10. Actualizar `constitution.md` (sacar la excepción §III.11 y las
    invariantes de ingesta que ya no aplican ahí), `RFC-0001`, PRD,
    `specs/README.md` (marcar 0002/0008/0009/0010 como "migradas a
    renovarte-pipeline").

**Fase 5 — Validación end-to-end**
11. `pnpm gate` completo en `renovarte-catalogo` con un `products.json`
    generado por el PR real.
12. Corrida real: ingest → PR → review → merge → deploy en Vercel, confirmar
    que el catálogo se ve igual.

## Decisiones tomadas

- Nombre del repo nuevo: **`renovarte-pipeline`** (en vez de
  `renovarte-ingesta`/`renovarte-ingest`), pensando en que a futuro pueda
  sumar otras fuentes además de LACA/Serlaca.
- Handoff: **GitHub Action + PR/commit automático**, no artifact/release
  descargado en build ni storage compartido — mantiene el principio de "$0
  infraestructura, sin backend" ya vigente en `renovarte-catalogo`.

## Riesgos / decisiones abiertas (no bloquean el arranque)

- `data/reference/*` (CSV público + decisiones de precio PDF): viven
  enteramente en `renovarte-pipeline` porque nada en `src/` de la web los
  lee hoy. Lo único que cruza a `renovarte-catalogo` es `products.json`.
- El futuro carrito/turnero de `renovarte-catalogo` va a requerir su propio
  backend, lo cual choca con el principio actual "no database, no runtime
  backend" — no es parte de esta migración, pero va a necesitar su propia
  RFC cuando llegue.
