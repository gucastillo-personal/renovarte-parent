# RenovArte — Parent

Superproyecto que agrupa los repos de RenovArte como git submodules. No
tiene build propio: es la base desde la que se trabajan las features que
tocan más de un repo y donde vive el contexto global del sistema.

## Por dónde empezar

- [`manifest.yaml`](./manifest.yaml) — qué repos hay, qué hace cada uno,
  qué contratos los conectan y qué proveedores usan.
- [`docs/HOME.md`](./docs/HOME.md) — mapa de la documentación (arquitectura,
  decisiones, specs) y qué documento es fuente de verdad de qué.
- [`CLAUDE.md`](./CLAUDE.md) — reglas de trabajo (ramas, PRs, aprobaciones
  humanas) para personas y agentes.

La carpeta es también un vault de Obsidian: abrila como vault para navegar
el grafo de repos, decisiones y features. Solo se versiona la configuración
compartida (`.obsidian/app.json`).

## Setup

```bash
git clone --recurse-submodules https://github.com/gucastillo-personal/renovarte-parent.git
```

Si ya clonaste sin `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

Cada submódulo tiene su propio README con instrucciones de setup y su
propio historial/remoto — se commitea y pushea independientemente. Este
repo solo versiona *a qué commit* apunta cada uno.

Para levantar el chat Colibrí completo en local (catálogo + gateway + RAG,
sin AWS): `make help`.

## Flujo de trabajo con agentes

El CTO/CEO da una necesidad y corre `/feature "<necesidad>"`. El skill en
[`.claude/skills/feature/`](./.claude/skills/feature/SKILL.md) orquesta los
subagentes de [`.claude/agents/`](./.claude/agents/) por fases —
product → UX (si toca UI) → diseño → implementación → testing —
**deteniéndose a pedir aprobación del CTO/CEO entre cada fase**. El detalle
de cada fase está en el propio skill; el diagrama, en
[`docs/arquitectura-general.md`](./docs/arquitectura-general.md).

El deploy es siempre manual: ningún agente pushea a `main`, mergea ni
deploya por su cuenta.
