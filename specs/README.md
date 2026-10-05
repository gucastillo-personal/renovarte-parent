# Specs cross-repo — renovarte-parent

Este folder es el centralizador de documentación de **features que tocan
más de un repo/submódulo** de `renovarte-parent`. Sigue la misma
convención de spec-driven-development que ya usan `renovarte-catalogo` y
`renovarte-pipeline` en su propio `specs/`, con una diferencia de alcance:

- Una feature que vive enteramente **dentro de un solo repo** tiene su
  `specs/NNNN-slug/` en ese repo (como siempre).
- Una feature que **toca 2 o más repos** — o que crea un repo nuevo — tiene
  su `specs/NNNN-slug/` acá, en el root. Cada repo tocado conserva en su
  propia PRD (`docs/PRD/`) solo el registro de los requisitos que le tocan
  a él (con su historial de decisión), apuntando acá para el spec/plan
  técnico completo — no duplica el plan de los otros repos.

## Layout

```
specs/
├── constitution.md          # invariantes no negociables cross-repo
├── README.md                # este archivo
└── NNNN-slug/
    ├── spec.md               # WHAT & WHY — acceptance criteria (cita RF/RNF de cada PRD tocada)
    ├── ux.md                 # cuando aplica — diseño de interacción (solo si hay UI)
    ├── plan.md                # HOW — una sección por repo/agente dueño, bajo su propio heading
    ├── tasks.md               # ídem, tareas ordenadas por repo/agente
    └── rfc-*.md                # un RFC por repo nuevo o superficie técnica nueva
```

Cada repo tocado declara, en su propia PRD, qué le toca exactamente a **él**
— nunca al resto. Ejemplo del principio (spec 0016): `renovarte-catalogo`
solo se encarga de **mostrar** el chat; el transporte en vivo vive en un
repo nuevo dedicado; la conexión al LLM/RAG vive en otro repo nuevo
dedicado — cada proyecto, una responsabilidad.

Invariantes no negociables (una responsabilidad por repo, $0 infra por
defecto, repos nuevos siempre como submódulo con su propio `CLAUDE.md`,
etc.) en [`constitution.md`](./constitution.md).

## Frontmatter de la spec

El `spec.md` de cada feature (en la 0001, que predata la convención,
`PLAN-EVENTS.md`) abre con un frontmatter YAML que la conecta al grafo de
conocimiento. Lo leen los agentes en el descubrimiento de contexto
(`CLAUDE.md`, paso 2) y Obsidian lo dibuja como aristas. Solo lo lleva
`spec.md`; `plan.md`, `tasks.md`, `ux.md` y los RFC no.

```yaml
---
id: "NNNN"                     # entre comillas, para conservar los ceros
title: <feature en una línea>
type: spec
status: draft                  # draft | design | approved | implementing | done | done-with-debt | abandoned
created: YYYY-MM-DD
closed:                        # fecha de cierre, si aplica
repos: ["[[repo-renovarte-xxx]]"]          # repos que toca o crea
domains: ["[[domain-xxx]]"]
contracts: ["[[contract-xxx]]"]            # contratos que crea, cambia o consume
providers: ["[[provider-xxx]]"]            # proveedores que suma o usa
decisions: ["[[ADR-NNNN-slug]]"]           # ADRs existentes que reutiliza o la condicionan
---
```

`decisions` sigue la regla de [`docs/decisions/README.md`](../docs/decisions/README.md)
(cada relación se escribe una sola vez): lista solo los ADRs **previos**
que la feature reutiliza o que la restringen. Los ADRs que **nacen** en
la spec ya la nombran en su propio `origin`, así que no se repiten acá.
Se encuentran por backlinks en Obsidian o con
`grep -l 'origin:.*NNNN' docs/decisions/ADR-*.md`. El cuerpo de la spec
repite la lista de `decisions` como links Markdown en
`## Decisiones relacionadas`.

## Feature index

| ID | Feature | Repos que toca | Status |
|----|---------|-----------------|--------|
| [0001](./0001-poc-event-driven-discord/PLAN-EVENTS.md) | POC event-driven: cambio de precio en `renovarte-pipeline` publica un evento por AWS (SNS → SQS → Lambda) y notifica a Discord — ejercicio de aprendizaje de arquitectura backend/AWS/Node.js, $0 infra (free tier permanente) | `renovarte-pipeline` (detecta el cambio, publica el evento) · `renovarte-events` (nuevo en su momento, producer + consumer + infra Terraform) | ✅ Completo — verificado end-to-end en CI real (2026-09-16). Predata la convención formal de `spec.md`/AC — es un plan/checklist, no una spec con acceptance criteria |
| [0016](./0016-chat-recomendador-cremas/spec.md) | Chat conversacional embebido ("Colibrí"): tipo de piel + presupuesto → 3 combos de cremas reales (más barato/medio/premium, 2+ productos c/u); "más barato"/"medio" ≤ presupuesto, "premium" ≤ presupuesto × 1.20 | `renovarte-catalogo` (muestra el chat, RF-14/RNF-06..09 en su PRD) · `renovarte-chat-gateway` (nuevo, transporte WebSocket) · `renovarte-colibri-rag` (nuevo, conexión LLM/RAG) | ✅ Desplegado y verificado en producción real (2026-09-29): infra AWS aplicada en los 2 repos nuevos, `renovarte-catalogo` deployado con el widget habilitado, probado end-to-end contra el WebSocket real (`text_done`→`profile_confirmed`→`combo_recommendation` con datos reales) y confirmado manualmente por el CTO/CEO. Sin verificación independiente de `tester-agent` (Fase 5 de `/feature`), la validación fue manual. AI T17 corrida el 2026-09-30 contra el catálogo real — gaps abiertos no bloqueantes: `no_recommendation` evitable con presupuestos de ~18k–25k ARS (corte del ranking sin precio + elección de "más barato" pegada al tope) |
| [0017](./0017-carrito-orden-compra/spec.md) | Carrito de compras + orden de compra: el visitante agrega productos desde el catálogo o un combo completo de Colibrí, deja sus datos de contacto y genera una orden que llega por mail a una casilla propia de RenovArte y, siempre, también a un canal privado de Discord dedicado a órdenes (respaldo ante spam, 2026-09-30d); sin pagos ni definición de envío en el sitio (se coordinan después) | `renovarte-catalogo` (carrito, formulario y confirmación, RF-15..19/RNF-10..14 en su PRD) · **repo nuevo de órdenes** (nombre tentativo a definir en Fase 3; manejo propio de la orden — creación, validación contra el catálogo, anti-abuso, registro — y envío del mail a renovartebyjuli@gmail.com, que puede delegarse a un proveedor de terceros de bajo costo, más la copia siempre al canal privado de Discord de órdenes vía webhook propio; pensado para expandir funcionalidad a futuro) · `renovarte-chat-gateway`/`renovarte-colibri-rag` a priori sin cambios (el envelope `combo_recommendation` ya trae `producto_id`, a confirmar en diseño) | Diseño aprobado (Fase 3, 2026-10-01), **enmendado 2026-10-05** (formulario con solo teléfono; RenovArte comparte su teléfono; se retiran el borrado a 60 días y el aviso de privacidad), implementación del frontend iniciada (F1) — 62 tareas vigentes (B1–B24 sin B23, I1–I20 sin I19, F1–F20), ~62–80 h. Sin preguntas bloqueantes (resueltas por el CTO/CEO 2026-09-30b/c; tope USD 20/mes, RNF-14); quedan solo preguntas no bloqueantes con default propuesto; precisiones 2026-09-30d/e/f (Discord, RF-19, AC-23..AC-31: borrado automático en Discord a 60 días, canal solo para propietarios, falla parcial resuelta con "al menos un canal", mails de Gmail borrados a 60 días como política operativa); antes de producción quedan de la pregunta #12 (Ley 25.326): texto del aviso de privacidad y consulta profesional opcional AAIP/transferencia internacional |
