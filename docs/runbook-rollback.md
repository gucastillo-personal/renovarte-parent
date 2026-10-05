---
type: runbook
---

# Runbook: rollback después de un merge que rompe

Qué hacer cuando algo mergeado a `main` rompe producción. El orden es
siempre el mismo:

1. **Mitigar**: volver rápido al estado anterior, sin tocar git si se
   puede.
2. **Revertir el código** por PR, como cualquier otro cambio (nunca push
   directo a `main`, nunca merge por un agente: [`CLAUDE.md`](../CLAUDE.md)).
3. **Arreglar hacia adelante** con calma, en una rama nueva.

Cómo despliega cada repo: campo `deploy` de cada entrada en
[`manifest.yaml`](../manifest.yaml).

## Revertir un PR (cualquier repo)

- **Desde GitHub**: en el PR mergeado, botón **Revert**. Crea una rama y un
  PR que deshace el merge. Revisarlo y mergearlo a mano.
- **Desde la terminal** (equivalente):

  ```sh
  git switch -c revert/<slug> origin/main
  git revert -m 1 <sha del merge commit>
  git push -u origin revert/<slug>
  gh pr create --fill
  ```

- El PR de revert pasa por los mismos checks que cualquier otro: `gate` en
  `renovarte-catalogo` (requerido por el ruleset) y el CI de cada repo.
- Revertir el código **no despliega** en los repos con Lambdas: ver la
  sección de AWS más abajo.

## `renovarte-catalogo` (sitio en Vercel)

Cada merge a `main` despliega solo a producción. Para mitigar:

1. **Instant Rollback**: en el dashboard de Vercel, proyecto `renovarte` →
   tile de Production Deployment → **Instant Rollback** → confirmar. Es
   instantáneo y no toca git. Por CLI: `vercel rollback`.
   - En el plan **Hobby** solo se puede volver al deploy **inmediatamente
     anterior**. Si el que rompió no fue el último, hay que revertir el
     código por PR.
   - Las variables de entorno **no se revierten**: si lo que rompió fue un
     cambio de env var, hay que volver a su valor anterior en Vercel.
2. **Revertir el PR** (sección anterior).
3. **Deshacer el rollback**. Después de un rollback, Vercel **apaga la
   promoción automática**: los merges nuevos a `main` construyen pero **no
   salen a producción** hasta que se promueva uno. Cuando el revert o el
   arreglo estén desplegados y verificados en su URL de preview/deploy:
   **Undo Rollback** en el tile de Production Deployment, o
   `vercel promote <url-o-id del deploy>`. Si se olvida este paso, el sitio
   queda congelado en el deploy viejo sin avisar.

Fuente: [Instant Rollback](https://vercel.com/docs/instant-rollback) en la
documentación de Vercel.

## Precios mal publicados (`renovarte-pipeline` → catálogo)

El pipeline nunca escribe en producción: abre un PR en
`renovarte-catalogo` desde la rama `pipeline/auto-update-products`
([ADR-0009](./decisions/ADR-0009-handoff-pipeline-catalogo-por-pr.md)).
Si ese PR se mergeó con precios equivocados:

1. Mitigar con el Instant Rollback del catálogo, o revertir ese PR en
   `renovarte-catalogo` (su merge vuelve a desplegar el `products.json`
   anterior).
2. Corregir en `renovarte-pipeline` (`ingest`/`transform` a mano, revisar
   el diff) y volver a publicar. El próximo PR del bot trae los precios
   correctos.
3. Si el problema vino de un cambio de código del pipeline, revertir ese
   PR también, en `renovarte-pipeline`.

El aviso de Discord de `renovarte-events` sobre ese cambio de precio ya
salió y no se borra; no hace falta hacer nada con él.

## Repos con Lambdas en AWS

`renovarte-chat-gateway`, `renovarte-colibri-rag` y `renovarte-events` (y
`renovarte-ordenes` cuando exista). Acá **mergear no despliega**: el código
se compila y lo sube un `terraform apply` que corre una persona, con el
estado local de Terraform de esa máquina
([ADR-0011](./decisions/ADR-0011-aws-terraform-plataforma-runtime.md)).

### Mitigar: apagar el servicio sin desplegar

- **Chat (Colibrí)**: corte manual con `chat-control` en
  `reason: "maintenance"`. El comando para apagar y para reactivar está en
  el README de `renovarte-chat-gateway`, sección "Corte manual del chat"
  ([README](../renovarte-chat-gateway/README.md)). El widget muestra el chat
  como no disponible y el resto del catálogo sigue funcionando
  ([ADR-0005](./decisions/ADR-0005-tope-costo-usd20.md)).
- **Notificaciones de precio**: son best-effort y nunca bloquean el publish
  ([ADR-0010](./decisions/ADR-0010-notificaciones-event-driven.md)). Si
  fallan, el catálogo no se ve afectado; se puede esperar al arreglo.
- **Órdenes** (cuando existan): el kill-switch de `budget-guard` y el flag
  `CONTROL` de [ADR-0005](./decisions/ADR-0005-tope-costo-usd20.md); el
  runbook de ese repo va a tener el comando.

### Volver a la versión anterior

En la máquina que tiene el estado de Terraform del repo, con aprobación
humana para el `apply`:

```sh
cd <repo>
git switch --detach <último commit que funcionaba>
pnpm install && pnpm build          # o el build del repo (ver su README)
cd terraform                        # infra/ en renovarte-events
terraform plan -var-file=terraform.tfvars   # revisar que solo cambie el código
terraform apply -var-file=terraform.tfvars
git switch main
```

- Revisar el `plan` antes del `apply`: si el commit viejo también cambia
  recursos (no solo el código de las Lambdas), puede borrar o recrear
  cosas. Ante la duda, frenar y revisar.
- Después revertir el PR (para que `main` coincida con lo desplegado) y
  arreglar hacia adelante.
- Si el chat quedó apagado con `maintenance`, reactivarlo cuando el
  servicio esté sano.

## `renovarte-parent`

Son docs y configuración de agentes: alcanza con el botón **Revert** del
PR. Después correr `make docs-check`.
