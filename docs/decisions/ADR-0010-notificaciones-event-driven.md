---
id: ADR-0010
title: "Notificaciones event-driven: SNS → SQS → Lambda → Discord, best-effort, en renovarte-events"
status: Accepted
date: 2026-09-16
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-events]]", "[[repo-renovarte-pipeline]]"]
domains: ["[[domain-notificaciones]]", "[[domain-precios]]"]
providers: ["[[provider-aws]]", "[[provider-discord]]", "[[provider-github]]"]
origin: "[[specs/0001-poc-event-driven-discord/PLAN-EVENTS|0001]]"
supersedes: []
extends: ["[[ADR-0009-handoff-pipeline-catalogo-por-pr]]"]
superseded_by:
constitution: ["§I.1 sin costo/margen en los mensajes", "§I.2 ningún secreto commiteado", "§II.4 un repo, una responsabilidad", "§II.5 $0 infraestructura", "§II.6 submódulo"]
cost_impact: "$0 (Always Free de SNS, SQS y Lambda; CloudWatch Logs con free tier de 12 meses, después fracciones de centavo)"
personal_data: false
reversibility: alta
retroactive: true
detail: "specs/0001-poc-event-driven-discord/PLAN-EVENTS.md; renovarte-events infra/ y docs/evento-price-changes.md"
---

# ADR-0010 — Notificaciones event-driven: SNS → SQS → Lambda → Discord, best-effort, en `renovarte-events`

## Contexto

El CTO/CEO quería practicar arquitectura event-driven, AWS y Node.js con
un caso real y costo $0. El caso elegido: cuando el pipeline publica un
`products.json` con cambios de precio, avisar por Discord con un resumen
(altas, bajas, subas y bajas de precio). Era un ejercicio de aprendizaje,
no una necesidad urgente del negocio. El POC
([0001](../../specs/0001-poc-event-driven-discord/PLAN-EVENTS.md)) se
verificó de punta a punta en producción el 2026-09-16 y quedó
funcionando.

## Problema

¿Cómo notificamos eventos del sistema sin que la notificación pueda
romper la publicación del catálogo, sin costo y sin meter AWS en repos
que no lo necesitan?

## Restricciones

- Constitution §II.4: un repo, una responsabilidad. El pipeline procesa
  datos; no debería saber de AWS.
- $0 de infraestructura (constitution §II.5).
- Los mensajes nunca llevan costo ni margen (§I.1); ningún secreto en
  repos (§I.2).
- El publish del catálogo
  ([ADR-0009](./ADR-0009-handoff-pipeline-catalogo-por-pr.md)) es lo único
  crítico de esa Action.

## Decisión

- Un repo nuevo, **`renovarte-events`** (público, submódulo), dueño de
  todo lo de AWS para este flujo: un **producer** en Python que publica
  en **SNS**; una cola **SQS** con **DLQ** (`maxReceiveCount = 5`); y un
  **consumer Lambda en Node.js**, sin dependencias npm, que llama al
  **webhook de Discord**. La infra está en **Terraform**, aplicada a mano.
- `renovarte-pipeline` **no depende de AWS**: solo calcula el diff y
  escribe `data/price-changes.json`, un contrato neutro de archivo.
- El producer corre como **pasos best-effort** de `publish.yml`
  (`continue-on-error: true`): si fallan, el job sigue en verde y el PR al
  catálogo ya está abierto.
- La autenticación de CI en AWS es por **OIDC**, con un rol limitado a
  `sns:Publish` sobre el topic y asumible solo desde el repo del pipeline.
  No hay access keys guardadas: solo dos variables con ARNs.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Webhook de Discord directo desde el pipeline | Mínimo código | No es event-driven (sin desacople ni reintentos); el pipeline suma una integración externa | No cumple el objetivo de aprendizaje ni la responsabilidad única |
| Producer AWS (`boto3`) dentro del pipeline | Un repo menos | El pipeline pasa a depender de AWS | Rompe §II.4; el pipeline queda limpio con un archivo neutro |
| SNS → Lambda directo, sin SQS | Menos piezas | Sin cola durable ni DLQ: un fallo del webhook se pierde | La cola da reintentos y un lugar donde inspeccionar fallos |
| IAM user con access key en secrets de GitHub (plan original) | Simple | Credencial de larga duración | Reemplazado por OIDC durante la implementación, por recomendación de AWS |
| **SNS → SQS (+DLQ) → Lambda en repo propio, best-effort, OIDC** | Desacople, reintentos, $0, sin credenciales de larga duración | Más piezas para un aviso | Elegida |

## Por qué

Cumple el objetivo de aprendizaje con un patrón real: pub/sub, cola
durable, DLQ y consumidor serverless. Todo cabe en el Always Free
permanente de AWS. Separar el contrato de archivo del transporte deja al
pipeline sin dependencias nuevas, y el carácter best-effort asegura que
un aviso fallido nunca frene una publicación de precios.

## Consecuencias

- Primer repo del proyecto en AWS: estableció las convenciones que
  después reusaron la 0016 y la 0017 (cuenta compartida, OIDC desde
  GitHub Actions, Terraform aplicado a mano, IAM con permisos mínimos por
  recurso). La elección de AWS + Terraform como plataforma tendrá su
  propio ADR.
- Nuevo contrato: [`contract-price-change-event`](../contracts/contract-price-change-event.md).
- Agregar otro tipo de evento es sumar un mensaje o topic en este repo,
  no tocar el que lo origina.
- El canal de Discord de notificaciones técnicas es distinto del canal
  privado de órdenes (0017).

## Trade-offs y riesgos

- Un evento perdido no se reintenta desde el origen: si falla el paso de
  publicación en SNS, no hay aviso. Se acepta porque el catálogo no
  depende de esto.
- El camino de la DLQ no se ejercitó a mano todavía (ítem opcional de la
  Fase 6 de la 0001). El consumer ya devuelve `batchItemFailures`.
- CloudWatch Logs sale del free tier después de los 12 meses de la
  cuenta: fracciones de centavo por mes, documentado en el runbook.

## Salida / reversión

Alta: `terraform destroy` en `renovarte-events` y quitar los pasos
best-effort de `publish.yml`. El pipeline sigue escribiendo
`price-changes.json` sin efecto.

## Detalle técnico

[`PLAN-EVENTS.md`](../../specs/0001-poc-event-driven-discord/PLAN-EVENTS.md)
(decisiones, fases y notas de IAM/OIDC);
`renovarte-events` [`docs/evento-price-changes.md`](../../renovarte-events/docs/evento-price-changes.md),
[`docs/runbook.md`](../../renovarte-events/docs/runbook.md) e `infra/`;
[`docs/flujo-event-driven-precios.md`](../flujo-event-driven-precios.md).

## Notas posteriores
