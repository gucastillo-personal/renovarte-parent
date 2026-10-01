# RenovArte — punto de entrada

Mapa de la base de conocimiento de `renovarte-parent`. El vault de Obsidian
es la raíz de este repo; todo lo que se ve acá es Markdown/YAML versionado
en git, legible igual por personas (Obsidian, GitHub) y por agentes.

## Por dónde empezar

1. [`manifest.yaml`](../manifest.yaml) — **qué hay**: repos, responsabilidad,
   stack, contratos entre repos y proveedores externos.
2. [`arquitectura-general.md`](./arquitectura-general.md) — **cómo
   funciona**: flujos principales con diagramas.
   - [`flujo-precio-pdf.md`](./flujo-precio-pdf.md)
   - [`flujo-event-driven-precios.md`](./flujo-event-driven-precios.md)
3. [`decisions/`](./decisions/README.md) — **por qué**: ADRs, criterios para
   decidir cuándo escribir uno y su ciclo de vida.
4. [`../specs/constitution.md`](../specs/constitution.md) — **reglas no
   negociables** cross-repo.
5. [`../specs/README.md`](../specs/README.md) — **qué estamos cambiando**:
   índice de features cross-repo (`specs/NNNN-slug/`).

Las reglas de flujo de trabajo (ramas, PRs, aprobaciones humanas) están en
[`../CLAUDE.md`](../CLAUDE.md).

## Qué es fuente de verdad de qué

| Información | Fuente de verdad |
|---|---|
| Repos, rol, stack, contratos, proveedores | `manifest.yaml` |
| Cómo funciona el sistema | `docs/` (arquitectura y flujos) |
| Por qué es así | `docs/decisions/ADR-*` |
| Reglas no negociables | `specs/constitution.md` (+ la de cada repo) |
| Qué cambia una feature (AC) | `specs/NNNN-slug/spec.md` |
| Cómo se construye esa feature | `plan.md` y RFC de la spec |
| Schema exacto de un contrato | El documento que indica `contracts.<x>.schema` en el manifest |
| Requisitos de un repo | `<repo>/docs/PRD/` |
| Cómo está implementado | El código y `<repo>/docs/` |
| Setup y operación | `<repo>/README.md`, `<repo>/docs/runbook.md` |

Si dos documentos dicen lo mismo, uno de los dos sobra: el que no es fuente
de verdad tiene que linkear, no repetir.
