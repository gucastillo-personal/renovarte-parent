---
type: provider
provider: aws
---

# Proveedor: AWS

Servicios, costo y repos que lo usan: entrada `providers.aws` de
[`manifest.yaml`](../../manifest.yaml). Los repos que lo usan son los que
lo listan en `providers`.

## Para qué lo usamos

Es el runtime de todo lo que no puede vivir en el sitio estático: eventos
de precio (SNS → SQS → Lambda), el WebSocket de Colibrí (API Gateway WS +
Lambda + DynamoDB) y, cuando exista, el servicio de órdenes (Lambda
Function URL + DynamoDB + SES). Toda la infra se define con Terraform en
cada repo, y una persona aplica los cambios a mano.

## Riesgos y límites

- **Costo**: el default es $0 dentro del free tier. La única excepción es
  el tope de USD 20/mes de chat y órdenes, con ledger propio, AWS Budgets y
  kill-switch. CloudWatch Logs es la salvedad conocida del free tier (ver
  el runbook de `renovarte-events`).
- **API Gateway WebSocket corta a los 29 s**: por eso el conector LLM se
  invoca de forma asíncrona.
- **Invocación async sin DLQ** entre gateway y RAG: si falla, el error se
  pierde sin aviso (README de `renovarte-chat-gateway`).
- **SES** queda en sandbox a propósito: el único destinatario es la casilla
  de RenovArte, fijada por IAM, así que no se pide acceso de producción
  (`rfc-servicio-ordenes.md` §6.1, spec 0017).
- Las credenciales van como secretos de CI o en el entorno local, nunca en
  el repo (constitution root §I.2).
- **Secretos de runtime**: en SSM SecureString con `value_wo`
  ([ADR-0019](../decisions/ADR-0019-secretos-en-ssm.md)). `renovarte-events`
  y `renovarte-colibri-rag` todavía los tienen como variables de entorno
  vía `.tfvars`: su `terraform.tfstate` local contiene secretos.
- **ARNs entre repos**: se copian a mano (ADR-0011) y se documentan en la
  sección "Coordinación de ARNs" del README de cada repo que los necesita.
