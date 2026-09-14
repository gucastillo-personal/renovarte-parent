# RenovArte — Parent

Superproyecto que agrupa los repos de RenovArte como git submodules. No tiene
build propio — es solo la base de trabajo para abrir todo junto en el
editor y ver ingesta + catálogo lado a lado.

- [`renovarte-catalogo`](https://github.com/gucastillo-personal/renovarte-catalogo) —
  web del catálogo (Next.js, SSG). Solo presentación: lee `public/data/products.json`
  ya procesado.
- [`renovarte-pipeline`](https://github.com/gucastillo-personal/renovarte-pipeline) —
  ingesta y transformación de datos (Python): API Serlaca, CSV, PDF de LACA.
  Produce el `products.json` que consume el catálogo.

Ver [`PLAN.md`](./PLAN.md) para la arquitectura completa, el mapeo de
migración y las fases de trabajo.

## Setup

```bash
git clone --recurse-submodules https://github.com/gucastillo-personal/renovarte-parent.git
```

Si ya clonaste sin `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

Cada submodule tiene su propio README con instrucciones de setup y su
propio historial/remoto — se commitea y pushea independientemente. Este
repo solo versiona *a qué commit* apunta cada uno.

## Flujo de trabajo con agentes

Este repo abre siempre el workspace padre para trabajar con agentes. El
CTO/CEO da una necesidad y corre `/feature "<necesidad>"`; el skill en
`.claude/skills/feature/` orquesta tres subagentes (`.claude/agents/`) en
secuencia, **deteniéndose a pedir aprobación del CTO/CEO entre cada fase**:

1. **`product-agent`** — necesidad → PRD (`docs/PRD/`) + `spec.md`
   (acceptance criteria) en el repo (`renovarte-catalogo` y/o
   `renovarte-pipeline`) que corresponda, siguiendo el spec-kit ya en uso en
   `renovarte-catalogo/specs/` (y ahora también en `renovarte-pipeline/specs/`).
2. **`developer-agent`**, modo diseño → RFC (`docs/rfc/`) + `plan.md` +
   `tasks.md` con estimación.
3. **`developer-agent`**, modo implementación → código, tareas tildadas,
   gate del repo (`pnpm gate` / `make check`) verde.
4. **`tester-agent`** → verifica cada acceptance criterion de forma
   independiente, re-corre el gate, reporta go/no-go.

El deploy es siempre manual: el CTO/CEO revisa el resultado final y lo
publica (Vercel para el catálogo, `make publish-live`/merge de PR para el
pipeline) — ningún agente pushea, mergea ni deploya por su cuenta.
