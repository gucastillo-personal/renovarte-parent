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
   - [`glossary.md`](./glossary.md) — términos del dominio y del proceso.
4. [`../specs/constitution.md`](../specs/constitution.md) — **reglas no
   negociables** cross-repo.
5. [`../specs/README.md`](../specs/README.md) — **qué estamos cambiando**:
   índice de features cross-repo (`specs/NNNN-slug/`).

## Notas de conocimiento

Notas cortas que dan contexto y linkean a los documentos fuente, sin
repetir el manifest. Las relaciones (repo → dominios, contrato → dominios)
van en el frontmatter, y la vista inversa sale de los backlinks de
Obsidian o de `grep -rl "<nota>" docs specs`.

| Carpeta | Una nota por… | Responde |
|---|---|---|
| [`repos/`](./repos/) | repo del manifest | por qué existe, qué no hace, dónde están sus docs |
| [`domains/`](./domains/) | área de negocio (catálogo, precios, Colibrí, órdenes, notificaciones) | reglas que la definen y flujo donde se ve |
| [`contracts/`](./contracts/) | contrato del manifest | link al schema único y qué saber antes de tocarlo |
| [`providers/`](./providers/) | proveedor externo | para qué se usa, riesgos, límites y secretos |

Las reglas de flujo de trabajo (ramas, PRs, aprobaciones humanas) están en
[`../CLAUDE.md`](../CLAUDE.md).

## Qué es fuente de verdad de qué

| Información | Fuente de verdad |
|---|---|
| Repos, rol, stack, contratos, proveedores | `manifest.yaml` |
| Por qué existe un repo, riesgos de un proveedor | `docs/repos/`, `docs/providers/` |
| Significado de un término | `docs/glossary.md` |
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
