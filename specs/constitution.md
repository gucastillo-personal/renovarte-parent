# Constitution — RenovArte (root / cross-repo)

Non-negotiable principles for `renovarte-parent` and every submódulo que
contiene. Every spec, plan, PR and review that toca más de un repo — o que
crea un repo nuevo — se chequea contra este archivo, además de contra la
`constitution.md` propia de cada repo tocado. Amending it requires a note
in the PR description explaining why.

Source of truth: [`PLAN.md`](../PLAN.md) (arquitectura de la separación
catálogo/pipeline) y [`PLAN-EVENTS.md`](../PLAN-EVENTS.md) (precedente del
primer repo nuevo, `renovarte-events`).

Este archivo no repite las invariantes propias de cada repo — ver
[`renovarte-catalogo/specs/constitution.md`](https://github.com/gucastillo-personal/renovarte-catalogo/blob/main/specs/constitution.md)
y [`renovarte-pipeline/specs/constitution.md`](https://github.com/gucastillo-personal/renovarte-pipeline/blob/main/specs/constitution.md).
Tampoco repite las reglas de flujo (aprobación humana, ramas, merges) — esas
viven en [`CLAUDE.md`](../CLAUDE.md) y aplican a todos los repos por igual.

---

## I. Security invariants (cross-repo)

1. **No cost, no margin, no LACA list price en ningún repo del proyecto,
   nunca.** No es una invariante exclusiva de `renovarte-catalogo`/
   `renovarte-pipeline` — cualquier repo nuevo (transporte, LLM/RAG, futuro)
   que llegue a ver esos datos (aunque sea de forma transitiva, ej. un
   payload que pasa por un tercer repo) hereda esta invariante sin
   excepción.
2. **Ningún secreto (API key, token, credencial) se commitea en ningún
   repo.** Siempre env var / secret de CI, nunca en código ni en docs de
   ejemplo con un valor real.
3. **Un repo nuevo nunca invalida una invariante ya cerrada de otro
   repo.** Si una feature cross-repo parece requerir violar una invariante
   de un repo existente (ej. "no runtime backend" de `renovarte-catalogo`
   §II.4), la resolución por defecto es diseñar el trabajo nuevo en un repo
   separado que no la viola — no enmendar la invariante existente salvo que
   sea genuinamente inevitable (precedente: spec 0016, resuelto sin
   enmienda vía RNF-08).

## II. Architecture

4. **Un repo, una responsabilidad.** Cada submódulo tiene un rol único y no
   absorbe el de otro — `renovarte-catalogo` solo muestra, `renovarte-pipeline`
   solo procesa datos para dejar el catálogo listo, `renovarte-events` solo
   notifica eventos, y así con cada proyecto nuevo. Si una feature nueva no
   encaja limpiamente en la responsabilidad de un repo existente, es señal
   de que necesita su propio repo nuevo, no una excepción al alcance de uno
   existente.
5. **$0 infraestructura por defecto, en todo el proyecto.** Cualquier
   excepción (ej. RNF-09: techo de USD 20/mes para la API de un LLM) tiene
   que ser explícita, acotada a la feature que la necesita, y aprobada por
   el CTO/CEO en su propio spec — nunca asumida ni heredada silenciosamente
   por otra feature.
6. **Todo repo nuevo es un submódulo de `renovarte-parent`, nunca anidado
   dentro de otro repo.** `git submodule add` desde acá, igual que
   `renovarte-catalogo`/`renovarte-pipeline`/`renovarte-events`.
7. **Todo repo nuevo nace con su propio `CLAUDE.md`**, con las mismas
   reglas de aprobación humana (instalar dependencias, cada commit, cada
   push, nunca mergear PRs, nunca commitear/pushear directo a `main`) que
   ya rigen en el resto del proyecto — no es opcional ni se difiere para
   después.

## III. Spec-Driven Development workflow (cross-repo)

8. **Una feature que toca 2+ repos — o que crea uno nuevo — tiene su
   `specs/NNNN-slug/` acá, en el root, no duplicado en cada repo tocado.**
   Cada repo tocado registra en su propia PRD (`docs/PRD/`) solo los
   requisitos (`RF-0x`/`RNF-0x`) que le tocan a él, con su propio historial
   de decisión, apuntando acá para el spec/plan/RFC completo. Una feature
   que vive enteramente dentro de un solo repo sigue teniendo su
   `specs/NNNN-slug/` en ese repo, como siempre — este archivo no cambia esa
   convención.
9. **La numeración de este `specs/` es propia e independiente** de la
   numeración de `renovarte-catalogo`/`renovarte-pipeline`/cualquier otro
   repo — no hay unicidad global de IDs entre repos (mismo criterio que ya
   aplica entre catalogo y pipeline hoy).
10. **`plan.md`/`tasks.md` de una feature cross-repo llevan una sección por
    repo/agente dueño** (`## Frontend`, `## Backend`, `## AI`, o lo que
    corresponda), cada una agregada bajo su propio heading — nunca
    reescribiendo la sección de otro. Toda divergencia detectada entre
    secciones se documenta explícitamente y se resuelve antes de pasar a
    implementación, nunca se decide unilateralmente por el agente que la
    encuentra.
11. **Ningún repo nuevo se crea, y ninguna infraestructura real se
    aprovisiona, en modo diseño.** La Fase de diseño (RFC + `plan.md` +
    `tasks.md`) es siempre no-código; la creación del repo y el
    aprovisionamiento (`terraform apply`, recursos de AWS, etc.) son Fase
    de Implementación, y requieren la misma aprobación humana explícita que
    cualquier instalación de herramientas.
