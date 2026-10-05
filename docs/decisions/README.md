# Decisiones (ADRs) — RenovArte

Registro de las decisiones que explican **por qué** el sistema está
construido como está. Un ADR vive independiente de la feature que lo
originó: la feature describe *qué cambia*, el ADR describe *por qué
elegimos así* y sigue vigente después de que la feature se cerró.

Todos los ADRs del proyecto viven acá, en `renovarte-parent`, con una sola
numeración global (`ADR-0001`, `ADR-0002`, …), incluso cuando una decisión
toca un solo repo. El formato está en [`_template.md`](./_template.md).

## Qué va a ADR y qué no

| Nivel | Es este nivel si… | Dónde se registra |
|---|---|---|
| **L0 — local** | Queda dentro de un módulo, se revierte en el mismo PR, no cambia contratos ni dependencias. Ej.: un `Map` en vez de un array | Nada, o una línea en `plan.md` |
| **L1 — técnica relevante** | Librería o patrón durable dentro de **un solo repo**, sin cruzar fronteras. Ej.: hexagonal liviano en `renovarte-colibri-rag` | Tabla `## Decisiones` del `plan.md` de la spec, con ID `D-<spec>-<n>` (ej. `D-0017-03`). **Se promueve a ADR** cuando otra feature o repo pasa a depender de ella |
| **L2 — arquitectónica** | Crea o elimina un repo, cambia un contrato entre repos (ver `manifest.yaml`), agrega una dependencia entre repos, cambia el modo de comunicación o de persistencia, o toca una invariante de `constitution.md` | **ADR obligatorio** |
| **L3 — estratégica (proveedor/infra)** | Proveedor o cuenta externa nueva, excepción al $0 (constitution §II.5), datos personales que salen a un tercero (Ley 25.326), recursos cloud nuevos | **ADR obligatorio**, con costo, plan de salida y tratamiento de datos |

Desempate: si alguien que llega en 6 meses se preguntaría "¿por qué
hicieron esto?" y el nivel es L1 o más, va ADR.

## Checklist de detección

Se responde en la Fase 1 de `/agentic-sdd:feature` (decisiones candidatas) y en la
Fase 3 (definitivas):

1. ¿La feature requiere una decisión arquitectónica?
2. ¿Ya hay un ADR que la resuelve? (buscar en el índice de abajo)
3. ¿Hay una decisión L1 relacionada en el `plan.md` de otra spec?
4. ¿Introduce una tecnología nueva?
5. ¿Elige un proveedor?
6. ¿Cambia un ADR `Accepted`?
7. ¿Descarta una alternativa que en su momento se eligió?
8. ¿Crea una dependencia nueva entre repos o cambia un contrato?

## Ciclo de vida

`Proposed` (se redacta en la Fase 3) → `Accepted` (aprobación explícita
del CTO/CEO en el gate de la Fase 3, ADR por ADR) → `Superseded` /
`Deprecated`.

| Situación | Acción |
|---|---|
| La feature trabaja dentro de una decisión existente | **Reutilizar**: la spec lo lista en `## Decisiones relacionadas` |
| Amplía el alcance sin contradecir la decisión | **ADR nuevo** con `extends: ADR-x`. El viejo no se edita |
| La elección se revierte, o se adopta una alternativa que antes se había descartado | **Supersede**: ADR nuevo con `supersedes: ADR-x`; el viejo pasa a `Superseded` y gana `superseded_by`. Las dos cosas en el mismo PR |
| El componente desaparece y no hay reemplazo | `Deprecated` |
| Hallazgo real que no cambia la decisión | Nota fechada en `## Notas posteriores` (solo se agrega, nunca se edita) |
| ADR en `Proposed` | Se edita libremente |
| ADR en `Accepted` | Solo se puede editar: `status`, `superseded_by`, `## Notas posteriores` y typos. **Nunca se reescribe la decisión** |

Si en la Fase 4 la implementación se aparta de un ADR `Accepted`, el
agente se detiene y lo reporta — igual que un conflicto con
`constitution.md`. No se "corrige" el ADR para que coincida con el código.

## Cómo se linkea

- **Frontmatter** (relaciones del grafo): wikilinks entre comillas,
  `"[[ADR-0006-servicio-ordenes]]"`. Obsidian los toma como aristas y un
  agente los parsea como YAML.
- **Cuerpo**: links Markdown relativos,
  `[ADR-0006](./ADR-0006-servicio-ordenes.md)`. Funcionan en GitHub, en
  Obsidian y para agentes.
- **Cada relación se escribe una sola vez**, del lado del documento más
  nuevo o más específico. Un ADR lista su spec de origen, no las features
  que lo usan después; esas lo referencian desde su propia spec, y la
  relación inversa se obtiene por backlinks (Obsidian) o con
  `grep -rl "ADR-0006" specs docs` (agente). Así un ADR `Accepted` nunca
  tiene que editarse porque una feature nueva lo usa.

## Índice

| ADR | Decisión | Nivel | Estado | Origen |
|---|---|---|---|---|
| [ADR-0001](./ADR-0001-superproyecto-submodulos.md) | Superproyecto con submódulos; un repo, una responsabilidad | L2 | Accepted | `PLAN.md` (retroactivo) |
| [ADR-0002](./ADR-0002-catalogo-ssg-sin-backend.md) | Catálogo SSG sin backend ni base de datos, $0 | L2 | Accepted | RFC-0001 catálogo (retroactivo) |
| [ADR-0003](./ADR-0003-ingesta-en-pipeline.md) | Ingesta en `renovarte-pipeline`; `products.json` único contrato | L2 | Accepted | `PLAN.md` (retroactivo) |
| [ADR-0004](./ADR-0004-runtime-chat-fuera-del-catalogo.md) | Runtime del chat fuera del catálogo, en 2 repos nuevos | L2 | Accepted | spec 0016 (retroactivo) |
| [ADR-0005](./ADR-0005-tope-costo-usd20.md) | Excepción de costo: tope USD 20/mes, ledger + kill-switch | L3 | Accepted | spec 0016, 0017 (retroactivo) |
| [ADR-0006](./ADR-0006-servicio-ordenes.md) | `renovarte-ordenes`: Function URL + DynamoDB + SES | L3 | Accepted | spec 0017 (retroactivo) |
| [ADR-0007](./ADR-0007-precio-pdf-revision-manual.md) | Precio del PDF LACA como override manual por producto | L2 | Superseded por ADR-0008 | spec 0008 catálogo (retroactivo) |
| [ADR-0008](./ADR-0008-precio-pdf-automatico-piso-margen.md) | Precio ABC del PDF automático, con piso de costo+margen | L2 | Accepted | `PLAN.md` (retroactivo) |
| [ADR-0009](./ADR-0009-handoff-pipeline-catalogo-por-pr.md) | Handoff pipeline → catálogo por PR automático; ingesta manual | L2 | Accepted | `PLAN.md` (retroactivo) |
| [ADR-0010](./ADR-0010-notificaciones-event-driven.md) | Notificaciones event-driven SNS → SQS → Lambda → Discord, best-effort | L3 | Accepted | spec 0001 (retroactivo) |
| [ADR-0011](./ADR-0011-aws-terraform-plataforma-runtime.md) | AWS + Terraform como plataforma del runtime fuera del catálogo | L3 | Accepted | spec 0001, 0016, 0017 (retroactivo) |
| [ADR-0012](./ADR-0012-websocket-invocacion-async.md) | Chat por API Gateway WebSocket, invocación async + `postToConnection` | L2 | Accepted | spec 0016 (retroactivo) |
| [ADR-0013](./ADR-0013-haiku-una-llamada-texto-plantillado.md) | Claude Haiku 4.5, una llamada de extracción por turno, texto plantillado | L3 | Accepted | spec 0016 (retroactivo) |
| [ADR-0014](./ADR-0014-embeddings-voyage-ai.md) | Embeddings con Voyage AI, calculados en el sync | L3 | Accepted | spec 0016 (retroactivo) |
| [ADR-0015](./ADR-0015-combos-calculados-en-codigo.md) | Combos y aritmética de presupuesto en código, nunca por el LLM | L2 | Accepted | spec 0016 (retroactivo) |
| [ADR-0016](./ADR-0016-ordenes-doble-canal.md) | Órdenes por doble canal mail + Discord, aceptadas con ≥1, idempotencia por canal | L3 | Accepted | spec 0017 (retroactivo) |
| [ADR-0017](./ADR-0017-datos-personales-ordenes.md) | Datos personales de órdenes: en memoria, registro seudonimizado 90 días, borrado a 60 | L3 | Superseded por ADR-0020 | spec 0017 (retroactivo) |
| [ADR-0018](./ADR-0018-products-json-fuente-unica-consumidores.md) | `products.json` publicado como fuente única de todos los consumidores | L2 | Accepted | spec 0016, 0017 (retroactivo) |
| [ADR-0019](./ADR-0019-secretos-en-ssm.md) | Secretos de runtime en SSM SecureString con `value_wo`, no en `.tfvars` | L3 | Accepted | migración a agentic-sdd |
| [ADR-0020](./ADR-0020-datos-personales-ordenes-mvp-nombre-y-telefono.md) | Datos personales de órdenes (MVP): nombre y apellido más teléfono, sin borrado automático | L3 | Accepted | spec 0017 |

### Backfill

Completo: todas las decisiones ya tomadas antes de esta base de
conocimiento tienen ADR (ADR-0001 a ADR-0018, todos `retroactive: true`).
Las decisiones nuevas se registran en la Fase 3 de `/agentic-sdd:feature`.
