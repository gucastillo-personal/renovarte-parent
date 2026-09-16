# Plan — POC event-driven: notificación de cambios de precio

**Estado:** 🚧 en progreso.
**Fecha inicio:** 2026-09-16.

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
- [ ] Crear IAM user del **producer** (permiso único `sns:Publish`, distinto del usuario `renovarte-events-terraform` de arriba) + access key (manual, fuera de Terraform) — pendiente para Fase 5/6.

**Fase 4 — Cambio en `renovarte-pipeline`** (rama `feature/price-change-events`)
- [x] `src/pipeline/publish/price_diff.py` (diff producto por producto, sin dependencias nuevas).
- [x] Invocación best-effort en `run_publish` (`src/pipeline/publish/run.py`), antes de `prepare_branch`.
- [x] Tests nuevos (`tests/test_price_diff.py` + 2 tests nuevos en `tests/test_publish_run.py` — uno prueba que el archivo se escribe bien, otro que una falla ahí no bloquea el publish real).
- [x] `data/price-changes.json` a `.gitignore`.
- [x] `make check` (ruff + mypy + pytest) en verde — 122 tests, sin dependencias nuevas en `pyproject.toml`.
- [x] Commit + push de la rama + PR abierto (sin mergear) — https://github.com/gucastillo-personal/renovarte-pipeline/pull/3, CI en verde.

**Fase 5 — Integración CI (`publish.yml`)** (mismo PR #3, mismo repo)
- [x] Pasos nuevos best-effort (`continue-on-error: true` + `if: always()`) en `.github/workflows/publish.yml`: checkout de `renovarte-events`, instalar `uv`, correr el producer. CI en verde.
- [ ] Cargar secrets/vars nuevos en `renovarte-pipeline` (`RENOVARTE_EVENTS_AWS_ACCESS_KEY_ID/SECRET`, `RENOVARTE_EVENTS_SNS_TOPIC_ARN`) — bloqueado hasta que exista la infra real (Fase 3).

**Fase 6 — Verificación end-to-end**
- [ ] Producer local contra fixture de prueba → evento visible en CloudWatch Logs de la Lambda.
- [ ] Notificación real recibida en canal de Discord de prueba.
- [ ] Camino de la DLQ probado (webhook inválido temporal → mensaje cae en la DLQ tras 5 intentos) y revertido.
- [ ] `workflow_dispatch` manual de `publish.yml` con un cambio de precio chico real: confirmar que el PR de siempre a `renovarte-catalogo` sigue abriéndose igual, y que además llega la notificación a Discord.

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
