# Flujo: del cambio de precio a la notificación en Discord

Diagrama en distintos niveles de detalle del POC event-driven descrito en
[`PLAN-EVENTS.md`](../PLAN-EVENTS.md): desde que `renovarte-pipeline`
detecta un cambio de precio hasta que llega la notificación a Discord,
pasando por AWS (SNS → SQS → Lambda). El contrato de datos completo está en
[`renovarte-events/docs/evento-price-changes.md`](../renovarte-events/docs/evento-price-changes.md).

**Principio de diseño que atraviesa todo el flujo:** `renovarte-pipeline`
no sabe nada de AWS, y todo lo de AWS es **best-effort** — si cualquier
paso de acá falla, la publicación real del catálogo (el PR a
`renovarte-catalogo`) ya se hizo antes y nunca se ve afectada.

## Nivel 1 — Vista general

Los cuatro sistemas involucrados, sin detalle interno.

```mermaid
flowchart LR
    PIPE["🛠️ renovarte-pipeline<br/>detecta el cambio de precio"]
    CATALOGO["🖥️ renovarte-catalogo<br/>sitio público (Next.js)"]
    EVENTS["📡 renovarte-events<br/>producer + infra AWS"]
    AWS["☁️ AWS<br/>SNS → SQS → Lambda"]
    DISCORD["💬 Discord"]

    PIPE -->|"PR (siempre,<br/>revisión humana)"| CATALOGO
    PIPE -.->|"evento (best-effort,<br/>nunca bloquea lo de arriba)"| EVENTS
    EVENTS --> AWS
    AWS -->|"notificación"| DISCORD
```

## Nivel 2 — Componentes

Qué vive en cada repo y qué recursos de AWS entran en juego (todos dentro
del "Always Free tier" al volumen de este proyecto).

```mermaid
flowchart TD
    subgraph PIPE["renovarte-pipeline (Python) — corre en publish.yml"]
        OLDJSON[("products.json<br/>ya publicado en catalogo")]
        NEWJSON[("products.json<br/>nuevo, recién generado")]
        DIFF["price_diff.py<br/>compara por id + precio_venta"]
        CHANGES[("data/price-changes.json<br/>contrato neutro, sin AWS")]
        PUBLISH["run_publish()<br/>leak-check + PR a catalogo"]
    end

    subgraph EVT["renovarte-events — único dueño de AWS/boto3"]
        subgraph PROD["producer (Python + uv)"]
            CLI["cli.py publish"]
            MSG["sns_client.build_message()<br/>resumen + hasta 200 cambios"]
        end
        subgraph AWSBOX["AWS us-east-1"]
            ROLE["IAM role github-actions-producer<br/>(vía OIDC, solo sns:Publish)"]
            TOPIC(["SNS topic<br/>price-changes"])
            QUEUE[["SQS queue<br/>price-changes"]]
            DLQ[["SQS DLQ<br/>tras 5 intentos fallidos"]]
            LAMBDA["Lambda consumer (Node.js)<br/>handler.mjs + discord.mjs"]
        end
    end

    DISCORDBOX{{"Discord<br/>webhook"}}

    OLDJSON --> DIFF
    NEWJSON --> DIFF
    DIFF --> CHANGES
    DIFF -.->|"best-effort"| PUBLISH
    CHANGES --> CLI
    ROLE --> CLI
    CLI --> MSG --> TOPIC
    TOPIC -->|"raw_message_delivery=true"| QUEUE
    QUEUE -->|"event source mapping<br/>batch de hasta 10"| LAMBDA
    QUEUE -.->|"5 reintentos fallidos"| DLQ
    LAMBDA -->|"POST"| DISCORDBOX
```

## Nivel 3 — Secuencia real (una corrida de `publish.yml`)

Orden exacto de lo que pasa en CI, tal como se verificó en un run real
(ver `PLAN-EVENTS.md`, Fase 6).

```mermaid
sequenceDiagram
    autonumber
    actor Admin
    participant GHA as GitHub Actions<br/>(publish.yml)
    participant Pipe as renovarte-pipeline<br/>(price_diff.py)
    participant Cat as renovarte-catalogo<br/>(checkout + PR)
    participant OIDC as GitHub OIDC<br/>provider
    participant STS as AWS STS
    participant Prod as renovarte-events<br/>producer
    participant SNS as AWS SNS
    participant SQS as AWS SQS
    participant Lambda as AWS Lambda<br/>consumer
    participant Discord

    Admin->>GHA: mergea PR con products.json nuevo<br/>push a main dispara el workflow
    GHA->>Cat: checkout dedicado (CATALOGO_PAT)
    GHA->>Pipe: run_publish()
    Pipe->>Pipe: leak-check (costo/margen nunca cruza)
    Pipe->>Cat: lee products.json actual (antes de pisarlo)
    Pipe->>Pipe: compute_price_diff() por id + precio_venta
    Pipe-->>Pipe: write data/price-changes.json (best-effort)
    Pipe->>Cat: prepare_branch + commit + push
    Pipe->>Cat: abre/actualiza PR (nunca auto-merge)
    Note over Pipe,Cat: ✅ Publicación real ya hecha —<br/>nada de lo que sigue puede romperla
    GHA->>OIDC: solicita ID token (aud=sts.amazonaws.com)
    GHA->>STS: AssumeRoleWithWebIdentity(role, id_token)
    STS-->>GHA: credenciales temporales (sin access keys)
    GHA->>Prod: uv run producer publish --input price-changes.json
    Prod->>Prod: valida contrato + arma mensaje (resumen + cambios)
    Prod->>SNS: sns:Publish(mensaje, attr event_type)
    SNS->>SQS: entrega raw (sin el sobre de SNS)
    SQS->>Lambda: invoca (batch de hasta 10 mensajes)
    Lambda->>Lambda: arma texto del mensaje por cada cambio
    Lambda->>Discord: POST webhook
    Discord-->>Lambda: 204 No Content
    Lambda-->>SQS: ack (borra el mensaje procesado)
```

## Nivel 4 — Cómo se clasifica cada cambio

Lógica de `compute_price_diff()` (`renovarte-pipeline/src/pipeline/publish/price_diff.py`).

```mermaid
flowchart TD
    START(["por cada id en el catálogo nuevo"]) --> EXISTS{"¿existía<br/>en el viejo?"}
    EXISTS -- no --> ADDED["kind = added"]
    EXISTS -- sí --> CMP{"comparar<br/>precio_venta"}
    CMP -- "nuevo > viejo" --> UP["kind = price_up"]
    CMP -- "nuevo < viejo" --> DOWN["kind = price_down"]
    CMP -- "sin cambio" --> SKIP(["no se reporta"])

    START2(["por cada id que estaba<br/>en el viejo y ya no está"]) --> REMOVED["kind = removed"]
```

## Notas de diseño

1. **Best-effort de punta a punta.** Cada paso del lado de AWS
   (`compute_price_diff`/`write_price_diff` en pipeline, y los 3 pasos
   nuevos en `publish.yml`) está envuelto en `try/except` o marcado
   `continue-on-error: true` — un fallo de AWS, Discord o red nunca tumba
   el job ni bloquea el PR real al catálogo.
2. **Sin credenciales de larga duración.** El producer se autentica en CI
   vía OIDC (`aws-actions/configure-aws-credentials` + `role-to-assume`),
   no con access keys guardadas como secret.
3. **Least-privilege en cada punto.** El rol que asume GitHub Actions solo
   puede `sns:Publish` sobre este topic puntual; el rol de la Lambda solo
   puede leer/borrar mensajes de su cola y escribir en su propio log group.
4. **Sin acoplamiento de código entre repos.** `renovarte-pipeline` y
   `renovarte-events` se comunican únicamente a través de
   `data/price-changes.json` (un contrato de datos versionado
   `schema_version`), igual que `renovarte-pipeline` y `renovarte-catalogo`
   ya se comunican vía `products.json`.
5. **Fallas parciales no reprocesan todo el batch.** Si Discord falla para
   un mensaje del batch, la Lambda reporta ese `messageId` en
   `batchItemFailures` — solo ese mensaje vuelve a la cola (y eventualmente
   a la DLQ tras 5 intentos), sin reprocesar los que ya se entregaron.
