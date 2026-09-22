# Arquitectura general — RenovArte

Vista de conjunto de `renovarte-parent` y sus submódulos: qué repo hace qué,
cómo se comunican entre sí, y cómo se construye cada feature nueva. Para el
detalle línea a línea de un flujo puntual, ver los documentos dedicados:
[`flujo-event-driven-precios.md`](./flujo-event-driven-precios.md) (evento
de cambio de precio → Discord) y [`flujo-precio-pdf.md`](./flujo-precio-pdf.md)
(resolución de precio desde el PDF de LACA). Invariantes no negociables en
[`../specs/constitution.md`](../specs/constitution.md).

## Arquitectura general — 5 repos, una responsabilidad cada uno

```mermaid
flowchart TB
    subgraph PARENT["renovarte-parent (superproyecto, sin build propio)"]
        direction TB
    end

    CATALOGO["🖥️ renovarte-catalogo<br/>Next.js SSG — SOLO presentación<br/>$0 infra, sin backend, sin DB"]
    PIPELINE["🛠️ renovarte-pipeline<br/>Python — SOLO ingesta/transformación<br/>(Serlaca API, CSV, PDF LACA)"]
    EVENTS["📡 renovarte-events<br/>SOLO notificación de eventos<br/>(producer + infra AWS)"]
    GATEWAY["🔌 renovarte-chat-gateway<br/>(planeado) SOLO transporte WebSocket<br/>del chat Colibrí"]
    RAG["🧠 renovarte-colibri-rag<br/>(en implementación) SOLO LLM/RAG<br/>del chat Colibrí"]

    PARENT -.-> CATALOGO
    PARENT -.-> PIPELINE
    PARENT -.-> EVENTS
    PARENT -.-> GATEWAY
    PARENT -.-> RAG

    PIPELINE -->|"products.json vía PR<br/>(handoff manual+revisado)"| CATALOGO
    PIPELINE -.->|"evento best-effort"| EVENTS
    CATALOGO -->|"embebe el widget de chat"| GATEWAY
    GATEWAY <-->|"invocación async<br/>+ postToConnection"| RAG
```

Invariante que atraviesa todo (`specs/constitution.md` del root): **un repo,
una responsabilidad**; **$0 infra por defecto** salvo excepción explícita y
acotada (ej. el techo de USD 20/mes del chat, RNF-09); **ningún repo nuevo
invalida una invariante ya cerrada de otro** — por eso el chat no vive
dentro de `renovarte-catalogo` (que tiene cerrado "no runtime backend"),
sino en 2 repos nuevos separados.

## Flujo 1 — catálogo de productos (pipeline → catalogo)

```mermaid
sequenceDiagram
    actor Admin
    participant Pipe as renovarte-pipeline
    participant Cat as renovarte-catalogo

    Admin->>Pipe: corre ingest + transform (manual)
    Pipe->>Pipe: costo + margen + precio PDF LACA (overlay automático)
    Pipe->>Pipe: check:leak (defensa en origen)
    Admin->>Pipe: revisa diff de precios, commitea products.json
    Pipe->>Cat: pipeline publish → PR con products.json nuevo
    Admin->>Cat: revisión humana + merge (nunca auto-merge)
    Cat->>Cat: pnpm gate (build, tests, check:leak) → deploy Vercel
```

## Flujo 2 — evento de cambio de precio → Discord (en producción)

```mermaid
flowchart LR
    PIPE["renovarte-pipeline<br/>detecta cambio de precio"] -.->|"best-effort,<br/>nunca bloquea el PR real"| EVT["renovarte-events<br/>producer"]
    EVT --> SNS["AWS SNS"] --> SQS["AWS SQS"] --> LAMBDA["AWS Lambda<br/>consumer"] --> DISCORD["Discord"]
```

Detalle completo con niveles de componentes y secuencia real verificada en
[`flujo-event-driven-precios.md`](./flujo-event-driven-precios.md).

## Flujo 3 — chat Colibrí (spec 0016, en implementación)

```mermaid
sequenceDiagram
    actor Visitante
    participant Widget as renovarte-catalogo<br/>(widget de chat)
    participant GW as renovarte-chat-gateway<br/>(WebSocket, no existe aún)
    participant RAG as renovarte-colibri-rag<br/>(LLM/RAG)
    participant Claude as Claude Haiku 4.5

    Visitante->>Widget: escribe mensaje (tipo de piel / presupuesto)
    Widget->>GW: mensaje vía WebSocket
    GW->>RAG: invoca async (InvocationType: Event)<br/>ConnectorInvocationPayload
    Note over GW,RAG: GW ya respondió 200 —<br/>no espera nada de RAG
    RAG->>Claude: 1 sola llamada (clasificar + extraer slots)
    RAG->>RAG: retrieval (Voyage embeddings + filtro 15 categorías)
    RAG->>RAG: combos.ts — búsqueda exacta en código<br/>(barato/medio ≤ presupuesto, premium ≤ 1.20x)
    RAG->>RAG: guardrails — re-verifica contra catálogo real
    RAG->>GW: postToConnection directo (ChatEnvelope: text_done,<br/>profile_confirmed?, combo_recommendation)
    GW->>Widget: reenvía por el mismo WebSocket
    Widget->>Visitante: muestra 3 combos
```

Puntos clave de este flujo (spec completa en
[`../specs/0016-chat-recomendador-cremas/spec.md`](../specs/0016-chat-recomendador-cremas/spec.md)):

- **Texto plantillado siempre**, salvo 1 sola llamada al modelo por turno —
  control de costo, RNF-09 (techo USD 20/mes).
- **Combos calculados en código** (`combos.ts`), nunca aritmética del LLM —
  garantía matemática de que "más barato"/"medio" ≤ presupuesto y "premium"
  ≤ presupuesto × 1.20.
- **Invocación asíncrona** porque API Gateway WebSocket tiene un límite de
  29s y una llamada a LLM (con eventual RAG) puede superarlo — si
  `renovarte-colibri-rag` falla, es responsable de avisarle al cliente
  directamente (no puede propagar la excepción a quien lo invocó).

## Flujo 4 — cómo se construye cada feature (gobierno del proyecto)

```mermaid
flowchart LR
    P1["Fase 1<br/>Product<br/>(product-agent)"] --> G1{"Aprobación<br/>humana"}
    G1 --> P2["Fase 2<br/>UX<br/>(ux-agent, si toca UI)"]
    P2 --> G2{"Aprobación<br/>humana"}
    G2 --> P3["Fase 3<br/>Design<br/>(frontend/backend/ai-agent)"]
    P3 --> G3{"Aprobación<br/>humana"}
    G3 --> P4["Fase 4<br/>Implementación<br/>(mismos specialists)"]
    P4 --> G4{"Aprobación<br/>humana"}
    G4 --> P5["Fase 5<br/>Testing<br/>(tester-agent)"]
```

Regla dura en cada flecha `G`: nada avanza sin aprobación explícita —
silencio o un "ok" ambiguo no cuentan. Y dentro de cada fase de código:
rama dedicada siempre, PR siempre, nunca merge automático, aprobación
explícita antes de cada commit y cada push individual (no alcanza con
haber aprobado la tarea en general — ver
[`../CLAUDE.md`](../CLAUDE.md)).
