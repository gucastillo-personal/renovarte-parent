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
