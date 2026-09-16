# Plan — POC event-driven: notificación de cambios de precio

**Estado:** ✅ completo — flujo end-to-end verificado en producción (CI real).
**Fecha inicio:** 2026-09-16. **Verificado end-to-end:** 2026-09-16.

## Objetivo

Sumar al proyecto una prueba de concepto de arquitectura event-driven, con
costo real $0, para aprender arquitectura backend, AWS y Node.js — no es una
necesidad de negocio urgente, es un ejercicio de aprendizaje que además deja
algo útil funcionando: cuando `renovarte-pipeline` detecta cambios de precio
en el catálogo, se publica un evento por AWS (SNS → SQS → Lambda) y llega
una notificación a Discord resumiendo los cambios.

Plan completo (contexto, diseño, contratos de datos, infra Terraform) en
`/Users/gucastillo/.claude/plans/necesitamos-sumar-al-proyecto-wild-bonbon.md`.
Este archivo es el checklist de avance — se va tildando a medida que se
completa cada paso, y cada `git commit`/`git push`/instalación/`terraform
apply` requiere aprobación humana explícita en el momento (ver `CLAUDE.md`).

## Decisiones tomadas

- **Broker:** AWS — SNS (pub/sub) + SQS (cola durable + DLQ) + Lambda
  (consumidor), dentro del "Always Free tier" permanente de AWS.
- **Lenguajes:** pipeline sigue en Python (ya existente); consumidor nuevo
  en **Node.js** (aprendizaje).
- **Caso de uso:** detectar altas/bajas/subas/bajas de precio entre
  corridas de `products.json`, publicar un evento resumen, notificar a
  Discord vía webhook.
- **IaC:** Terraform.
- **Ubicación:** repo/submódulo nuevo y separado `renovarte-events` (no se
  mete AWS/Node dentro de `renovarte-pipeline`).
- **Diseño clave:** `renovarte-pipeline` se mantiene 100% libre de AWS/boto3
  — solo calcula el diff y escribe `data/price-changes.json` (contrato de
  datos neutro, sin dependencias nuevas). Todo lo de AWS vive en
  `renovarte-events/producer`, invocado como paso best-effort (no
  bloqueante) desde `publish.yml`.

## Fases de ejecución

**Fase 0 — Setup de repo e infra base**
- [x] Armar esqueleto del repo (`CLAUDE.md`, `README.md`, `docs/`, carpetas `producer/`, `consumer/`, `infra/`, `.github/workflows/ci.yml`).
- [x] Crear repo `gucastillo-personal/renovarte-events` en GitHub (público) — https://github.com/gucastillo-personal/renovarte-events
- [x] `git submodule add` de `renovarte-events` en `renovarte-parent` + commit de `.gitmodules` (commit `6b5e3d3`, pusheado a `main`).
- [x] CI del repo nuevo en verde (producer, consumer, terraform fmt/validate).
- [x] Confirmar cuenta AWS (usuario ya tenía cuenta admin) + usuario IAM dedicado `renovarte-events-terraform` (least-privilege, scoped a recursos `renovarte-events-*`) para correr Terraform.

**Fase 1 — Producer (Python) y contrato de datos**
- [x] `producer/src/producer/models.py` + `sns_client.py` + `cli.py`.
- [x] Tests del producer — 9 tests, con un stub inyectado en `sns_client._sns_client` (en vez de mockear `boto3.client` directo, para no chocar con `mypy --strict`'s `no_implicit_reexport`). `ruff check`, `pytest` y `mypy` en verde.
- [x] `docs/evento-price-changes.md` con el contrato (`price-changes.json` y el mensaje SNS/SQS).

**Fase 2 — Consumer (Node.js Lambda)**
- [x] `consumer/src/handler.mjs` + `discord.mjs` (cero dependencias npm).
- [x] Tests del consumer — 6 tests con `node:test` (`t.mock.method` sobre `fetch`, auto-restaurado por test). `npm test` verde.

**Fase 3 — Infra Terraform**
- [x] `infra/*.tf` escrito (SNS, SQS + DLQ, IAM least-privilege, Lambda + event source mapping, outputs).
- [x] Instalar Terraform CLI (aprobación dada) — `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` (1.16.2; el formula `terraform` se sacó de homebrew-core por la licencia de HashiCorp).
- [x] `terraform fmt` / `terraform init -backend=false` / `terraform validate` — todo en verde.
- [x] `terraform apply` (aprobación dada) — **9 recursos creados en AWS** (SNS topic, 2 SQS, IAM role, Lambda, event source mapping). Outputs:
  - `sns_topic_arn` = `arn:aws:sns:us-east-1:839670623501:renovarte-events-price-changes`
  - `sqs_queue_url` = `https://sqs.us-east-1.amazonaws.com/839670623501/renovarte-events-price-changes`
  - `sqs_dlq_url` = `https://sqs.us-east-1.amazonaws.com/839670623501/renovarte-events-price-changes-dlq`
  - `lambda_function_name` = `renovarte-events-consumer`
- [x] ~~Crear IAM user del producer + access key~~ — reemplazado por **OIDC**: AWS recomendó no usar access keys de larga duración. Se agregó `infra/oidc.tf` (proveedor OIDC de GitHub + rol `renovarte-events-github-actions-producer`, scoped a `sns:Publish` sobre el topic, asumible solo desde `repo:gucastillo-personal/renovarte-pipeline:*`). Aplicado sin errores.

**Fase 4 — Cambio en `renovarte-pipeline`** (rama `feature/price-change-events`)
- [x] `src/pipeline/publish/price_diff.py` (diff producto por producto, sin dependencias nuevas).
- [x] Invocación best-effort en `run_publish` (`src/pipeline/publish/run.py`), antes de `prepare_branch`.
- [x] Tests nuevos (`tests/test_price_diff.py` + 2 tests nuevos en `tests/test_publish_run.py` — uno prueba que el archivo se escribe bien, otro que una falla ahí no bloquea el publish real).
- [x] `data/price-changes.json` a `.gitignore`.
- [x] `make check` (ruff + mypy + pytest) en verde — 122 tests, sin dependencias nuevas en `pyproject.toml`.
- [x] Commit + push de la rama + PR abierto (sin mergear) — https://github.com/gucastillo-personal/renovarte-pipeline/pull/3, CI en verde.

**Fase 5 — Integración CI (`publish.yml`)** (mismo PR #3, mismo repo)
- [x] Pasos nuevos best-effort (`continue-on-error: true` + `if: always()`) en `.github/workflows/publish.yml`: checkout de `renovarte-events`, instalar `uv`, correr el producer. CI en verde.
- [x] Autenticación vía **OIDC** (`aws-actions/configure-aws-credentials` + `role-to-assume`), sin access keys guardadas.
- [x] Variables cargadas en `renovarte-pipeline` (no secrets — son ARNs): `RENOVARTE_EVENTS_GITHUB_ACTIONS_ROLE_ARN`, `RENOVARTE_EVENTS_SNS_TOPIC_ARN`.

**Fase 6 — Verificación end-to-end**
- [x] Producer local contra fixture de prueba → evento visible en CloudWatch Logs de la Lambda (invocación de 2.6s, sin errores).
- [x] Notificación real recibida en canal de Discord de prueba. **Flujo completo confirmado: producer → SNS → SQS → Lambda → Discord.**
- [x] `workflow_dispatch` manual de `publish.yml` (rama `feature/price-change-events`) con un cambio de precio real que ya estaba pendiente (oferta del 10%, `precio_venta` $27.120 → $24.408): (i) el PR de siempre a `renovarte-catalogo` se abrió normal — https://github.com/gucastillo-personal/renovarte-catalogo/pull/6 —, y (ii) llegó la notificación a Discord vía OIDC (sin access keys), corriendo en 18s.
- [ ] *(opcional, no bloqueante)* Camino de la DLQ probado (webhook inválido temporal → mensaje cae en la DLQ tras 5 intentos) y revertido — el consumer ya está preparado para esto (`batchItemFailures`), solo falta ejercitarlo a mano si se quiere ver en acción.

## Notas de avance

1. **Políticas inline de usuario IAM: límite de 2048 caracteres.** La policy
   least-privilege inicial (una acción por línea) superó el límite al
   pegarla como inline policy de usuario. Se resolvió usando comodines de
   servicio (`sns:*`, `sqs:*`, `lambda:*`, `iam:*`) *dentro de cada statement
   ya acotado por `Resource` ARN* — no pierde seguridad porque el `Resource`
   sigue limitando a los recursos `renovarte-events-*`, solo compacta el JSON.
2. **No todas las acciones de Lambda soportan permisos a nivel de recurso.**
   `lambda:GetFunctionCodeSigningConfig`, `lambda:GetFunctionEventInvokeConfig`,
   `lambda:GetFunctionUrlConfig` y todas las de `EventSourceMapping`
   (`Create/Delete/Get/List/UpdateEventSourceMapping`) — además de
   `lambda:ListTags` cuando el recurso es un event source mapping (tiene su
   propio tipo de ARN, no el de la función) — exigen `Resource: "*"` en IAM;
   no aceptan un ARN específico aunque el recurso ya exista. Terraform los
   llama igual como parte de su refresh/plan interno.
3. **Los cambios de policy IAM pueden tardar en propagar.** Un intento de
   `terraform apply` falló con el JSON ya corregido y confirmado; el
   reintento (sin cambiar nada) funcionó unos minutos después. Vale la pena
   reintentar antes de asumir que la policy está mal.
4. **El claim `sub` de OIDC de GitHub puede incluir IDs inmutables.** La
   trust policy inicial usaba el formato clásico
   `repo:OWNER/REPO:ref:...`, pero esta cuenta de GitHub emite
   `repo:OWNER@id/REPO@id:ref:...` (immutable IDs, pensado para que el
   claim no se reutilice si un repo se renombra o transfiere). El síntoma
   fue `sts:AssumeRoleWithWebIdentity: Not authorized` con una trust
   policy aparentemente correcta — se diagnosticó agregando un paso
   temporal en el workflow que decodifica el JWT (`ACTIONS_ID_TOKEN_REQUEST_URL`
   + `ACTIONS_ID_TOKEN_REQUEST_TOKEN`) y lo imprime. Fix: la condición
   `StringLike` del `sub` cubre ambos formatos
   (`infra/oidc.tf`).
5. **Access keys de larga duración → OIDC.** El plan original preveía un
   IAM user del producer con una access key guardada como secret en
   GitHub. Al crear ese usuario, la consola de AWS sugirió OIDC/IAM Roles
   Anywhere como alternativa — se adoptó: `aws-actions/configure-aws-credentials`
   asume un rol scoped a `sns:Publish`, sin ningún secret de AWS guardado
   en `renovarte-pipeline` (solo 2 *variables* con ARNs, que no son
   sensibles).

## Cómo probar el flujo manualmente

```bash
cd renovarte-events/producer
AWS_PROFILE=renovarte-events AWS_REGION=us-east-1 \
  uv run renovarte-events-producer publish \
    --input ../fixtures/example-price-changes.json \
    --topic-arn arn:aws:sns:us-east-1:839670623501:renovarte-events-price-changes
```
Y en CI: `gh workflow run publish.yml --repo gucastillo-personal/renovarte-pipeline --ref <rama>`.

## Qué queda pendiente (decisión humana, no técnica)

- Mergear el PR #3 de `renovarte-pipeline` (diff de precios + wiring OIDC) — nunca automático, ver `CLAUDE.md`.
- Revisar y mergear el PR #6 de `renovarte-catalogo` (el cambio de precio real que destapó esta verificación).
- Opcional: probar el camino de la DLQ (Fase 6, ítem opcional).
- Opcional: destruir la infra (`terraform destroy`, con aprobación) si en algún momento se quiere desarmar el POC.
