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

## Feature index

| ID | Feature | Repos que toca | Status |
|----|---------|-----------------|--------|
| [0016](./0016-chat-recomendador-cremas/spec.md) | Chat conversacional embebido ("Colibrí"): tipo de piel + presupuesto → 3 combos de cremas reales (más barato/medio/premium, 2+ productos c/u); "más barato"/"medio" ≤ presupuesto, "premium" ≤ presupuesto × 1.20 | `renovarte-catalogo` (muestra el chat, RF-14/RNF-06..09 en su PRD) · `renovarte-chat-gateway` (nuevo, transporte WebSocket) · `renovarte-colibri-rag` (nuevo, conexión LLM/RAG) | Diseño completo (plan + 55 tareas entre los 3), sin divergencias abiertas — listo para Fase 4 (Implementación) |
