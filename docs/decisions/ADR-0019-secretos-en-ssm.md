---
id: ADR-0019
title: Los secretos de runtime viven en SSM Parameter Store (SecureString) con value_wo, no en .tfvars
status: Accepted
date: 2026-10-02
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-events]]", "[[repo-renovarte-chat-gateway]]", "[[repo-renovarte-colibri-rag]]", "[[repo-renovarte-ordenes]]"]
domains: []
providers: ["[[provider-aws]]", "[[provider-anthropic]]", "[[provider-voyage-ai]]", "[[provider-discord]]"]
origin: ""
supersedes: []
extends: ["[[ADR-0011-aws-terraform-plataforma-runtime]]"]
superseded_by:
constitution: ["§I.2 ningún secreto commiteado", "§II.5 $0 infraestructura"]
cost_impact: "$0 (parámetros SSM Standard y clave administrada aws/ssm dentro del free tier de KMS)"
personal_data: false
reversibility: alta
retroactive: false
detail: "specs/0017-carrito-orden-compra/plan.md § Infra I-D9 (primera aplicación)"
---

# ADR-0019 — Los secretos de runtime viven en SSM Parameter Store (SecureString) con `value_wo`, no en `.tfvars`

## Contexto

[ADR-0011](./ADR-0011-aws-terraform-plataforma-runtime.md) fijó AWS +
Terraform como plataforma, pero no fijó cómo llegan los secretos (API keys,
URLs de webhooks, secretos HMAC) a las Lambdas. En la práctica conviven dos
mecanismos:

- **`.tfvars` → variable de entorno del Lambda**: `renovarte-events` (URL
  del webhook de Discord) y `renovarte-colibri-rag` (API keys de Anthropic y
  Voyage). El comentario en el Terraform de colibri-rag lo justifica porque
  SSM "agrega costo", y el prompt viejo de `devops-agent` lo tenía como
  regla: "nunca SSM salvo que la spec diga otra cosa".
- **SSM SecureString con `value_wo`**: `renovarte-ordenes`
  ([ADR-0017](./ADR-0017-datos-personales-ordenes.md), plan de la 0017,
  I-D9), que verificó que SSM Standard cuesta USD 0.

La contradicción salió a la luz al separar el núcleo del plugin
`agentic-sdd` de la capa de RenovArte (2026-10-02): la regla vivía solo en
el prompt de un agente y ningún ADR la fijaba.

## Problema

¿Dónde viven los secretos de runtime y cómo llegan a las Lambdas?

## Restricciones

- Ningún secreto en el repo (constitution §I.2), y varios repos son
  públicos.
- $0 de infraestructura por defecto (constitution §II.5).
- [ADR-0011](./ADR-0011-aws-terraform-plataforma-runtime.md): Terraform
  por repo con estado **local**, `apply` manual.

## Decisión

1. Todo secreto de runtime vive en **SSM Parameter Store**, tipo
   **SecureString**, tier **Standard**, con la clave administrada `aws/ssm`.
   Nombre: `/<repo>/<secreto>`.
2. Terraform crea el parámetro con **`value_wo`** (write-only) y un
   placeholder, así el valor real **nunca queda en el estado** ni en un
   `.tfvars`. Requiere Terraform ≥ 1.11.
3. Una persona carga el valor real con
   `aws ssm put-parameter --overwrite`, leyéndolo sin eco (`read -rs`),
   nunca por chat ni git.
4. La Lambda lo lee en el cold start (`GetParameter` con descifrado), con
   IAM limitado a los ARN de sus parámetros. Para rotar sin redeploy y sin
   drift, se sube una variable `config_revision` que fuerza contenedores
   nuevos (patrón de I-D9).
5. **Repos existentes**: `renovarte-events` y `renovarte-colibri-rag`
   migran **cuando se toque su infraestructura** por otra razón, o antes si
   se rota una clave. No hay migración forzada: queda registrada como deuda
   técnica.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| `.tfvars` → variable de entorno (lo que hacen events y colibri-rag) | Lo más simple; cero código extra en la Lambda | El secreto queda en texto plano en `terraform.tfstate` (`sensitive` solo lo oculta en pantalla) y en el `.tfvars` del disco; visible en la consola del Lambda; rotar requiere `apply` | Expone el secreto en tres lugares sin ganar nada en costo |
| AWS Secrets Manager | Rotación administrada, auditoría | ~USD 0,40 por secreto por mes | Rompe el $0 sin necesidad a esta escala |
| SSM SecureString con `value` normal | Simple en Terraform | El provider refresca el valor descifrado y lo guarda en el estado | Mismo problema que `.tfvars` en el estado (verificado en la 0017) |
| **SSM SecureString con `value_wo`** | $0; fuera del estado, del disco y de la consola del Lambda; rotación sin `apply` | Un paso manual para cargar el valor; código para leerlo; Terraform ≥ 1.11 | Elegida |

## Por qué

Cuesta lo mismo que la opción simple (USD 0) y saca el secreto de los tres
lugares donde hoy queda expuesto. Con el estado de Terraform local
(ADR-0011), una copia o backup de esa máquina hoy se lleva las API keys en
texto plano. El patrón ya está diseñado y aprobado para órdenes; este ADR
lo vuelve la regla.

## Consecuencias

- `devops-agent` (plugin `agentic-sdd`) toma este ADR como la regla de
  secretos del proyecto.
- Todo repo nuevo con runtime nace con este patrón.
- Deuda técnica: migrar `renovarte-events` y `renovarte-colibri-rag`
  (punto 5). Hasta entonces, su `terraform.tfstate` local contiene
  secretos y se trata como un secreto más.
- El comentario de `renovarte-colibri-rag/terraform/variables.tf` queda
  desactualizado hasta la migración.

## Trade-offs y riesgos

- Si `GetParameter` falla en el cold start, la Lambda no arranca bien.
  Mitigación: error explícito y alarma, igual que cualquier dependencia.
- `value_wo` depende de la versión del provider de Terraform. Mitigación:
  fijar la versión mínima en cada repo (como en la 0017).

## Salida / reversión

Alta: volver a variables de entorno es cambiar cómo la Lambda lee el valor
y dónde lo carga una persona. No hay datos que migrar.

## Detalle técnico

Patrón completo, IAM y rotación: `specs/0017-carrito-orden-compra/plan.md`
§ Infra I-D9 (por ahora solo en la rama `feature/carrito-orden-compra`).

## Notas posteriores
