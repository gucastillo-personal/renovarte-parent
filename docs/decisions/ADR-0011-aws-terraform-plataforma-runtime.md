---
id: ADR-0011
title: AWS + Terraform como plataforma del runtime fuera del catálogo
status: Accepted
date: 2026-09-16
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-events]]", "[[repo-renovarte-chat-gateway]]", "[[repo-renovarte-colibri-rag]]", "[[repo-renovarte-ordenes]]"]
domains: []
providers: ["[[provider-aws]]", "[[provider-github]]"]
origin: "[[specs/0001-poc-event-driven-discord/PLAN-EVENTS|0001]]"
supersedes: []
extends: []
superseded_by:
constitution: ["§I.2 ningún secreto commiteado", "§II.5 $0 infraestructura", "§III.11 nada se aprovisiona en modo diseño"]
cost_impact: "$0 dentro del free tier; excepciones acotadas en ADR-0005"
personal_data: false
reversibility: baja
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/plan.md § Backend / transporte; specs/0017-carrito-orden-compra/plan.md § Infra I-D10; Terraform de cada repo"
---

# ADR-0011 — AWS + Terraform como plataforma del runtime fuera del catálogo

## Contexto

El catálogo es estático y sin backend
([ADR-0002](./ADR-0002-catalogo-ssg-sin-backend.md)), así que todo lo
que necesita runtime vive en repos aparte
([ADR-0004](./ADR-0004-runtime-chat-fuera-del-catalogo.md),
[ADR-0006](./ADR-0006-servicio-ordenes.md)). El primero fue
`renovarte-events` ([ADR-0010](./ADR-0010-notificaciones-event-driven.md)),
que eligió AWS y Terraform. Las specs 0016 y 0017 lo tomaron como
precedente explícito ("misma cuenta AWS que `renovarte-events`, mismo
patrón OIDC + Terraform") en lugar de volver a elegir. La elección nunca
se registró como decisión propia: este ADR la hace explícita, junto con
las convenciones que comparten esos repos.

## Problema

¿Sobre qué plataforma y con qué convenciones corre todo runtime que no
puede vivir en el catálogo?

## Restricciones

- $0 de infraestructura por defecto (constitution §II.5). Las
  excepciones van con ADR propio
  ([ADR-0005](./ADR-0005-tope-costo-usd20.md)).
- Ningún secreto en repos (§I.2). Varios de estos repos son públicos.
- Nada se aprovisiona en modo diseño (§III.11). Cada `terraform apply`
  requiere aprobación humana (`CLAUDE.md`).

## Decisión

Todo runtime fuera del catálogo corre en **AWS, en una sola cuenta**,
con servicios serverless que entran en el free tier (Lambda, SNS, SQS,
DynamoDB, API Gateway WebSocket, Lambda Function URL, SES,
EventBridge Scheduler, Budgets). La infraestructura se define con
**Terraform**, con estas convenciones:

1. **Terraform por repo:** cada repo tiene su propia carpeta de
   Terraform y su **estado local** (`*.tfstate*` y `*.tfvars`
   gitignoreados). No hay backend remoto ni estado compartido.
2. **`apply` manual, en vivo con una persona**, con un **usuario IAM de
   Terraform por repo** cuya policy está **acotada por prefijo de
   recursos** (`renovarte-<repo>-*`).
3. **CI → AWS solo por OIDC**, con roles limitados a la acción
   necesaria (publicar en un topic, actualizar el código de una Lambda).
   No hay access keys de larga duración.
4. **`default_tags` por proyecto** a nivel de provider, para filtrar
   Budgets y costos por repo.
5. **Las dependencias entre repos** (ARNs, nombres de tabla) se copian a
   mano como variables, documentadas en el plan de la spec. No se usa
   `terraform_remote_state`.
6. Los repos públicos **no publican** el ID de cuenta, ARNs reales ni
   URLs de webhook en README o docs. Los valores reales quedan en
   `terraform output` local o en SSM.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Funciones de Vercel | Mismo proveedor que el catálogo | Implica runtime en el catálogo o un segundo proyecto Vercel; sin colas, WebSocket nativo ni DynamoDB | Choca con ADR-0002/0004 y no cubre las necesidades (colas, WebSocket) |
| Otra nube (GCP, Cloudflare Workers) | Free tiers comparables | Sin precedente en el proyecto | AWS era el objetivo de aprendizaje del CTO/CEO desde la 0001 |
| AWS por consola, sin IaC | Arranque rápido | Sin revisión, sin reproducibilidad, deriva | Inaceptable con aprobación humana por cambio |
| Terraform con backend remoto (S3 + lock) | Estado compartido; deja usar remote-state | Más infraestructura, y el bootstrap es otro recurso que mantener | Un solo operador aplica a mano; el estado local alcanza hoy |
| **AWS serverless + Terraform por repo, estado local, OIDC** | $0, reproducible, aislado por repo | Estado solo en una máquina; ARNs copiados a mano | Elegida |

## Por qué

AWS fue un objetivo explícito de aprendizaje y su free tier permanente
cubre el volumen del proyecto. Terraform por repo mantiene "un repo, una
responsabilidad" también en la infraestructura: cada repo puede
destruirse sin tocar a los otros. El apply manual con IAM acotado por
prefijo y OIDC limita lo que un error o una credencial filtrada pueden
romper.

## Consecuencias

- Todo repo nuevo con runtime arranca con el mismo esqueleto: carpeta de
  Terraform, usuario IAM por prefijo, rol OIDC, tags y `.gitignore`
  para estado y tfvars. El `devops-agent` es dueño de esa parte.
- AWS Budgets queda como guardrail del gasto AWS. No ve proveedores
  externos (ADR-0005).
- Coordinar dependencias entre repos es trabajo manual explícito en el
  `plan.md` de cada spec.

## Trade-offs y riesgos

- **Estado local:** si se pierde la máquina, se pierde el estado. Hay
  que importar los recursos para recuperarlo. Mitigación: hay backups
  locales (`.tfstate.backup`). Pasar a un backend remoto requeriría un
  ADR que extienda este.
- **ARNs copiados a mano:** pueden desincronizarse si un repo recrea un
  recurso. Mitigación: el plan de cada spec lista las dependencias.
- **Free tiers con vencimiento** (API Gateway, CloudWatch Logs, SES a los
  12 meses de la cuenta): el costo después es de centavos por mes. Está
  documentado en cada runbook y en el riesgo 1 del RFC de transporte de
  la 0016.
- Proveedor de Terraform AWS con versiones distintas por repo (`~> 5.0`
  en 0016; `~> 6.28` en 0017). Cada repo tiene su propio lock y no se
  afectan entre sí.

## Salida / reversión

Baja: cambiar de nube implica reescribir la infraestructura y los
adaptadores (SDK de AWS) de cuatro repos. Pasar a un backend remoto de
Terraform, en cambio, es barato (`terraform init -migrate-state`).

## Detalle técnico

Terraform de cada repo (`renovarte-events/infra/`,
`renovarte-chat-gateway/terraform/`, `renovarte-colibri-rag/terraform/`);
[`plan.md` de la 0016](../../specs/0016-chat-recomendador-cremas/plan.md)
§ Backend / transporte; `specs/0017-carrito-orden-compra/plan.md`
§ Infra I-D10 (por ahora solo en la rama `feature/carrito-orden-compra`);
[`PLAN-EVENTS.md`](../../specs/0001-poc-event-driven-discord/PLAN-EVENTS.md)
§ Notas de avance (IAM y OIDC).

## Notas posteriores
