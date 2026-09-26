# 0016 — Chat recomendador de combos ("Colibrí") · Tasks

> Igual que `plan.md`: cada agente agrega tareas bajo su propio heading, sin
> reescribir las de otro. `backend-agent` agrega `## Backend / transporte`,
> `frontend-agent` agrega `## Frontend` cuando le toque su fase.

## Backend / transporte

### Estimate

**Tamaño: M — 8 a 12 horas de trabajo de ingeniería** (repo nuevo desde
cero, Terraform + 4 Lambdas livianas, sin lógica de negocio de RAG/LLM),
repartidas así:

- **Bootstrap + infra base (T1-T4): ~2-3h.** Repo nuevo, Terraform de API
  Gateway WS + DynamoDB, tipos del envelope.
- **Transporte core (T5-T9): ~3-4h.** Los 3 handlers WS + libs de soporte,
  la parte con más superficie de tests (casos de `chat-control` en
  distintos momentos del ciclo de vida).
- **Corte de gasto (T10-T13): ~2-3h.** `budget-guard` + Terraform de AWS
  Budgets + el audit de no-leak.
- **Cierre y coordinación cross-repo (T14-T19): ~1-2h.** T17 (coordinación
  de ARNs con `ai-agent`) ya no tiene incertidumbre de mecanismo — el
  invocation model (async) está reconciliado entre ambas secciones; T17
  queda acotado a intercambiar ARNs reales una vez existan los 2 repos.

**Top riesgos que podrían mover el estimate:**

1. ~~Mecanismo de invocación entre los 2 Lambdas no coincide entre este
   plan y la sección `## AI`~~ — **resuelto**: `ai-agent` revisó su sección,
   aceptó la justificación async (límite de 29s de la integración WS) y
   corrigió su plan/tasks/RFC en consecuencia. Sin divergencia pendiente.
2. **Free tier de 12 meses de API Gateway sin confirmar** (RFC §6, riesgo
   #1) — no bloquea el diseño ni la implementación, pero si ya venció hay
   que documentar la excepción a "$0 infraestructura" igual que ya existe
   para el techo de USD 20/mes.
3. **Reencendido mensual automático del corte de gasto (T11) es una
   inferencia mía**, no exigido literalmente por AC-13 — si el CTO/CEO
   prefiere reencendido manual, T11 se achica (sacar el
   `EventBridge Scheduler`), no crece.

### Tasks

#### Bootstrap + infra base

- [x] **T1.** Crear repo `renovarte-chat-gateway` (o el nombre final
  acordado con `ai-agent`) con estructura mínima (`src/`, `terraform/`,
  `tests/`, `.github/workflows/`, `README.md`, `CLAUDE.md` con las mismas
  reglas de aprobación humana que el resto del proyecto). *Check:* repo
  clona y `npm install` corre limpio. — **Hecho localmente** (directorio
  `renovarte-chat-gateway/` con la estructura completa); `pnpm install`
  corrió limpio local (`pnpm gate` en verde, ver reporte de implementación).
  **Pendiente de aprobación humana**: no se corrió `gh repo create` (crea
  un recurso real en GitHub) ni se agregó como submódulo de
  `renovarte-parent`, ni se hizo ningún `git commit`/`git push` — ninguno
  de los 3 está aprobado todavía por proceso (`CLAUDE.md`).
- [x] **T2.** `src/types.ts`: `ChatEnvelope`, `MessageType`, y los 7
  payloads (`UserMessagePayload` + los 6 servidor→cliente) tal como
  quedaron en `rfc-transporte-websocket.md` §3 — mismos tipos que
  `ai-agent`/`frontend-agent` copian a mano a sus repos. *Check:*
  `tsc --noEmit` en verde + test de shape que serializa un ejemplo de cada
  `type` y lo valida contra el contrato. — Verificado verbatim contra
  `renovarte-colibri-rag/src/types/wire.ts` (ya mergeado a `main` de ese
  repo) — sin drift.
- [x] **T3.** `terraform/`: API Gateway WebSocket API + rutas
  `$connect`/`$disconnect`/`$default`, roles IAM mínimos por Lambda,
  output del ARN de la API Gateway (para que `ai-agent` lo referencie,
  RFC §4). *Check:* `terraform validate` en verde; `terraform plan` sin
  errores contra la cuenta AWS de práctica (aprobación humana explícita
  antes de cualquier `apply`, fuera del alcance de esta tarea). —
  `terraform validate`/`terraform fmt -check -recursive` en verde (ver
  reporte). `terraform plan` **no se pudo correr**: no hay credenciales
  AWS configuradas en este entorno de implementación (`aws sts
  get-caller-identity` falla con `NoCredentials`) — no es un blocker de
  diseño, es un límite del sandbox actual; queda pendiente para cuando
  haya una cuenta de práctica accesible.
- [x] **T4.** `terraform/dynamodb.tf`: tablas `chat-connections` (TTL
  24h), `chat-control` (item único `pk="status"`), `chat-budget-ledger`
  (PK `period`, DynamoDB Streams `NEW_IMAGE` habilitado). *Check:*
  `terraform validate`; test de integración local (DynamoDB Local o mock)
  confirma el TTL configurado en `chat-connections`. — `terraform
  validate` en verde. El "test de integración local" se implementó como
  unit test con DynamoDB Document Client mockeado (`tests/unit/
  connections.test.ts`, confirma el `ttl` calculado), no contra DynamoDB
  Local real — mismo criterio de mocking que el resto de la suite, ninguna
  tarea de este repo asume Docker/DynamoDB Local disponible.

#### Transporte core

- [x] **T5.** `src/handlers/on-connect.ts`: registra `connection_id` en
  `chat-connections`, chequea `chat-control` antes de devolver `200`,
  `postToConnection` con `unavailable`/`reason:"budget_cap"` si
  `enabled=false` (AC-1, AC-13; RFC §4). *Check:* unit test con mocks de
  API Gateway Management API + DynamoDB — casos `enabled=true`/`false`,
  sin exigir ningún token de sesión (AC-1). — `tests/unit/on-connect.test.ts`.
- [x] **T6.** `src/handlers/on-disconnect.ts`: limpieza de
  `chat-connections`. *Check:* unit test, no lanza si el `connection_id`
  ya no existe. — `tests/unit/on-disconnect.test.ts`.
- [x] **T7.** `src/handlers/on-message.ts`: valida `UserMessagePayload`,
  re-chequea `chat-control` (cubre "el techo se alcanza a mitad de una
  conversación", `ux.md`), invoca **async** (`InvocationType: Event`,
  pendiente confirmar con `ai-agent` — ver riesgo #1) al Lambda del
  conector con `{connection_id, api_endpoint, turn_id, user_text,
  tipo_piel?, presupuesto?}`, responde `200` de inmediato sin esperar al
  conector. *Check:* unit test — mensaje malformado → `unavailable`/
  `reason:"internal_error"`; `chat-control.enabled=false` a mitad de
  conversación → corta antes de invocar; confirma `InvocationType: Event`
  en el mock de invocación. — `tests/unit/on-message.test.ts` +
  `tests/unit/lambda-invoke.test.ts` (confirma `InvocationType: "Event"`
  en el `InvokeCommand`). El riesgo #1 de este mismo `tasks.md` ya está
  marcado resuelto en `plan.md` ("Divergencia detectada... RESUELTO") —
  confirmado async en ambos lados.
- [x] **T8.** `src/lib/connections.ts`: merge parcial de
  `tipo_piel`/`presupuesto` sobre `chat-connections` (escrito por el
  conector de `ai-agent` con permiso `dynamodb:UpdateItem` acotado, leído
  por este repo). *Check:* unit test de merge sin pisar campos que no
  vinieron en el update. — `tests/unit/connections.test.ts`.
- [x] **T9.** `src/lib/chat-control.ts`: `GetItem` simple sobre
  `chat-control`, sin lógica de negocio, usado por T5/T7. *Check:* unit
  test, devuelve cada `reason` (`"budget_cap"` / `"maintenance"` / `null`)
  tal cual. — `tests/unit/chat-control.test.ts`.

#### Corte de gasto (AC-13/RNF-09)

- [x] **T10.** `src/handlers/budget-guard.ts`: disparado por DynamoDB
  Streams sobre `chat-budget-ledger`; si `spent_usd_estimate >=
  BUDGET_CAP_USD` (env var, default 20) y `enabled=true` → escribe
  `chat-control={enabled:false, reason:"budget_cap"}`, idempotente.
  *Check:* unit test con evento de stream simulado — dispara una vez, no
  reescribe si ya está en `false`. — `tests/unit/budget-guard.test.ts`.
- [x] **T11.** `terraform/budget.tf` (parte 1): `EventBridge Scheduler`
  (`cron(0 0 1 * ? *)`) que invoca `budget-guard` en modo "reset" —
  supuesto de reencendido mensual automático, a confirmar con el CTO/CEO
  en el gate de Fase 2 (RFC riesgo #4). *Check:* `terraform validate`;
  unit test del modo "reset" del handler — vuelve a `enabled:true,
  reason:null`. — `aws_scheduler_schedule.budget_reset`
  (`terraform/budget.tf`), `terraform validate` en verde; modo "reset"
  cubierto en `tests/unit/budget-guard.test.ts`. **El supuesto de
  reencendido mensual automático sigue sin confirmación explícita del
  CTO/CEO** — implementado tal como lo dejó el RFC (riesgo #4, a
  confirmar), no como algo ya cerrado; si se prefiere manual, borrar este
  recurso es el único cambio.
- [x] **T12.** `terraform/budget.tf` (parte 2): AWS Budget tipo "Cost
  budget" filtrado por tag `Project=renovarte-chat`, límite USD 5, umbral
  80% (SNS/email informativo) y 100% (Budget Action `Deny
  lambda:InvokeFunction` sobre los roles de `on-connect`/`on-message`/
  `budget-guard`) — guardrail secundario del gasto AWS propio, no del
  gasto de Claude (RFC §5.4). *Check:* `terraform validate`; revisión
  manual de que el filtro de tag no afecta a `renovarte-events`. —
  `aws_budgets_budget.aws_cost_guardrail` + `aws_budgets_budget_action.
  deny_invoke_at_100_percent`, `terraform validate` en verde. Filtro
  `TagKeyValue = "user:Project$renovarte-chat"` — `renovarte-events` no
  usa ese tag (confirmado leyendo su `infra/*.tf`, no tiene
  `default_tags` de provider), así que no puede matchear.
- [x] **T13.** `src/leak-audit.ts` (script de CI): grep de tokens
  prohibidos (API key, costo, margen, variantes de precio de lista LACA)
  sobre `src/`, nombres de env vars referenciadas, y un JSON de ejemplo
  serializado de cada `payload` (AC-10). *Check:* script corre en CI,
  falla el build si encuentra un match; test adicional confirma que
  `ChatEnvelope`/`ComboItem` no tienen ningún campo de costo/margen en su
  definición de tipos. — `pnpm check:leak` en verde (ver reporte); tipos
  de `src/types.ts` no tienen ningún campo de costo/margen/LACA por
  diseño (revisión manual del archivo, no hay ningún test de "ausencia de
  campo" automatizado más allá de que el propio guard de shape solo
  reconoce los campos documentados en el RFC).

#### Cierre y coordinación cross-repo

- [x] **T14.** `.github/workflows/ci.yml`: lint + `tsc --noEmit` + tests
  unitarios + `terraform validate` + el audit de T13, todo en verde antes
  de cualquier PR. *Check:* CI corre limpio en un PR de prueba. — Workflow
  escrito (`.github/workflows/ci.yml`, jobs `gate` + `terraform`); **no
  se pudo verificar "CI corre limpio en un PR de prueba" literalmente**
  porque el repo todavía no existe en GitHub (T1) — cada paso del
  workflow sí se corrió localmente de forma equivalente (`pnpm lint`,
  `pnpm typecheck`, `pnpm test`, `pnpm check:leak`, `pnpm build`,
  `terraform fmt -check -recursive`, `terraform init -backend=false`,
  `terraform validate`), todos en verde.
- [x] **T15.** `tests/unit/`: al menos un test que arma cada uno de los 7
  `ChatEnvelope` completos (1 cliente→servidor + 6 servidor→cliente) y lo
  valida contra el shape de RFC §3.1-3.3 — contrato con `frontend-agent`.
  *Check:* suite en verde. — `tests/unit/types.test.ts`.
- [x] **T16.** Test de resiliencia AC-11: `on-connect`/`on-message` con
  `chat-control` en cualquier estado (incluidos estados inesperados/
  malformados del item) nunca lanzan una excepción no controlada, siempre
  responden un `ChatEnvelope` válido — la verificación completa de
  "grilla/filtro/búsqueda siguen funcionando" es de `frontend-agent` en
  `renovarte-catalogo`, pero este repo no debe ser la causa de una falla
  ahí. *Check:* suite en verde, cobertura explícita de los estados
  "raros" del item `chat-control` (campo faltante, `reason` desconocido).
  — `tests/unit/resilience.test.ts` (5 estados crudos de `chat-control` ×
  `on-connect`/`on-message`, más body no-JSON/`null`), más casos T16
  puntuales dentro de `on-connect.test.ts`/`on-message.test.ts`/
  `budget-guard.test.ts`/`chat-control.test.ts`.
- [ ] **T17.** Coordinar con `ai-agent`: (a) copiar el ARN de la API
  Gateway (output de T3) al `.tfvars`/config del repo del conector y
  confirmar el permiso IAM `execute-api:ManageConnections` que ese repo
  necesita sobre este ARN, más `dynamodb:UpdateItem` acotado sobre
  `chat-connections`/`chat-budget-ledger`; (b) mecanismo de invocación ya
  reconciliado (async, `InvocationType: Event`, ver `plan.md`) — queda
  pendiente solo el intercambio real de ARNs una vez existan los 2 repos.
  *Check:* ambos repos confirman por escrito (comentario en PR o nota en
  README) el ARN copiado — sin Terraform remote-state compartido. —
  **No completada, a propósito, no por omisión.** (b) está resuelto (ver
  `plan.md`). (a) requiere un ARN *real* de una API Gateway realmente
  desplegada (`terraform apply`, fuera de alcance sin aprobación humana +
  credenciales AWS) y un repo `renovarte-chat-gateway` real en GitHub (T1,
  también pendiente de aprobación) — no hay nada concreto que copiar
  todavía. `terraform/outputs.tf` ya expone los 3 valores que
  `ai-agent`/`frontend-agent` van a necesitar
  (`api_gateway_execution_arn`, `chat_connections_table_arn`,
  `chat_budget_ledger_table_arn`, `websocket_url`) y el README documenta
  el procedimiento — la coordinación por escrito queda para cuando ambos
  repos estén realmente desplegados.
- [x] **T18.** Agregar una nota de **referencia** (no enmienda) en
  `renovarte-catalogo/specs/constitution.md`, cerca de `§II.4`/`§II.5`,
  mencionando `renovarte-chat-gateway` (y el repo del conector de
  `ai-agent`) como el runtime externo del chat — mismo criterio que ya
  usa esa sección para referenciar a `renovarte-pipeline`. `spec.md` ya
  cerró que esto no requiere enmienda ("Conflictos con `constitution.md`:
  ninguno bloqueante"). *Check:* nota agregada, sin tocar el texto de la
  invariante ni requerir aprobación de enmienda. — Nota agregada entre los
  puntos 5 y 6 de `renovarte-catalogo/specs/constitution.md` (§II). **Sin
  commitear/pushear** — es un cambio en el working tree de otro submódulo
  (`renovarte-catalogo`), pendiente de su propia rama + PR + aprobación
  humana antes de commit/push, mismo proceso que este mismo repo.
- [x] **T19.** `README.md` de `renovarte-chat-gateway`: documenta el corte
  manual de `chat-control` (`reason:"maintenance"`), el riesgo de free
  tier de 12 meses de API Gateway (RFC §6, riesgo #1 — a verificar en AWS
  Billing antes de aprovisionar), y el procedimiento de re-copiar el ARN
  si la API Gateway se recrea (RFC §6, riesgo #3). *Check:* README
  completo, formato consistente con el runbook ya existente de
  `renovarte-events`. — `README.md` + `docs/runbook.md` (mismo separador
  README/runbook que usa `renovarte-events`).

## AI

### Estimate

**Tamaño: L — 10 a 16 horas de trabajo de ingeniería** (repo nuevo desde
cero, sin nada reusable de `renovarte-catalogo` salvo el schema de
`Product`), repartidas así:

- **Bootstrap + sync de catálogo (T1-T4): ~2-3h.** Repo nuevo, CI básica,
  script de sync con su propio test de integración contra un server HTTP
  local de fixture.
- **Retrieval + combos (T5-T9): ~4-6h.** Es la parte más sensible a bugs
  sutiles (AC-5/7/8/9 son matemáticos, no de copy) — el tiempo mayor está en
  los tests exhaustivos de `combos.ts`, no en el código en sí.
- **LLM + guardrails (T10-T14, incluye T13a/T13b): ~3.5-4.5h.** Una sola
  llamada por turno acota bastante el trabajo; el tiempo va en el
  denylist/validación post-generación, sus tests de injection, y el
  `try/catch` de nivel superior de T13 + `dispatch.ts`/`apigw-client.ts`
  (T13a/T13b) que agrega la invocación async ya confirmada (ver riesgo #1
  abajo — resuelto, ya no incertidumbre, solo trabajo).
- **Eval + integración con el contrato de `backend-agent` (T15-T18): ~1-3h**,
  con incertidumbre real porque depende de que el RFC de `backend-agent` esté
  cerrado (ya lo está) y de la coordinación operativa de ARNs (T18), no del
  mecanismo de invocación en sí (ya resuelto, riesgo #1 abajo).

**Top riesgos que podrían mover el estimate:**

1. **Mecanismo de invocación entre los 2 Lambdas — resuelto (era el riesgo
   #1 original).** Confirmado como async (`InvocationType: Event`) contra
   `rfc-transporte-websocket.md §4` — ver `plan.md` "Corrección post gate de
   Fase 2". Ya no es incertidumbre de diseño; lo que queda es trabajo real
   de implementación ya reflejado en T13/T13a/T13b abajo (handler.ts con
   `try/catch` de nivel superior + `dispatch.ts` + `apigw-client.ts`, en vez
   de un simple `return`). No debería mover el estimate más de lo que ya
   está repartido en esas tareas.
2. **Voyage AI sin confirmar** (`plan.md` punto #3) — bloquea únicamente
   T7/T8 (cálculo real de embeddings); el resto del pipeline (filtro de
   categoría, combos, guardrails, eval) es independiente de qué método de
   ranking se use, así que no bloquea el resto del trabajo si se demora.
3. **Calidad real del ranking con datos reales todavía no medida** — el eval
   fijo (T17) cubre casos sintéticos con fixtures controladas; una vez que
   haya catálogo real sincronizado, vale la pena correr el eval con datos
   reales antes de dar por cerrada la feature — no es una tarea nueva, es una
   repetición de T17 con datos reales en vez de fixtures.

### Tasks

#### Bootstrap + sync de catálogo

- [ ] **T1.** Crear repo `renovarte-colibri-rag` (o el nombre final acordado
  con `backend-agent`) con estructura mínima (`src/`, `data/`, `scripts/`,
  `tests/`, `.github/workflows/`, `README.md`, `CLAUDE.md` con las mismas
  reglas de aprobación humana que el resto del proyecto). *Check:* repo
  clona y `pnpm install` (o el gestor elegido) corre limpio.
- [ ] **T2.** `src/types.ts`: `ConnectorInvocationPayload` (entrada) +
  `TurnResult` (interno) + `ChatEnvelope`/`MessageType` (copiados a mano de
  `rfc-transporte-websocket.md §3`, salida real vía `postToConnection`), tal
  como quedaron en `rfc-conector-llm-rag.md §6` (corregido), más `Product`
  (copiado/adaptado de `renovarte-catalogo/src/lib/types.ts`, sin importar
  entre repos). *Check:* `tsc --noEmit` en verde.
- [ ] **T3.** `scripts/sync-catalog.ts`: fetch del `products.json` público de
  producción, diff contra el commiteado, filtro por allowlist de categorías
  (RFC §3.1) → `data/candidates.json` (sin vectores todavía). *Check:* test
  de integración con un server HTTP local que sirve un `products.json` fixture
  — confirma que el filtro de categorías deja afuera Fragancias/Uñas/etc. y
  adentro Rostro/Hidratación/etc.
- [ ] **T4.** `.github/workflows/sync-catalog.yml` (cron 6h + manual) que
  corre T3 y abre PR si hay diff — sin auto-merge (mismo criterio que el
  resto del proyecto). *Check:* `workflow_dispatch` corrido manualmente una
  vez en un fork/rama de prueba produce un PR con el diff esperado.

#### Retrieval + combos

- [ ] **T5.** Confirmar con el CTO/CEO la decisión de Voyage AI vs. fallback
  léxico (RFC §3.2) — **bloqueante solo para T7**, no para T6/T9+. *Check:*
  respuesta explícita registrada (no silencio).
- [ ] **T6.** `src/retrieval.ts`: interfaz `rankCandidates(query,
  candidates): ScoredProduct[]` + implementación por defecto (la que se haya
  confirmado en T5). *Check:* unit tests con vectores/scores mockeados —
  determinismo dado el mismo input.
- [ ] **T7.** Si T5 confirma Voyage: extender `scripts/sync-catalog.ts` para
  calcular y cachear embeddings por producto (hash-based, solo
  nuevos/modificados) → `data/candidates.json` con vector incluido. *Check:*
  test de integración: segunda corrida sin cambios de catálogo no vuelve a
  llamar al provider de embeddings (mock que falla el test si se invoca).
- [ ] **T8.** `src/combos.ts`: búsqueda exacta acotada por banda de precio
  (RFC §4) — firma `buildComboSet(candidates, presupuesto): ComboSet |
  null`. *Check:* build pasa, sin tests todavía (van en T9).
- [ ] **T9.** `tests/unit/combos.test.ts` — **exhaustivo**, cubre como mínimo:
  presupuesto exacto en el límite de `barato`/`medio`; presupuesto que solo
  alcanza 1 producto (debe devolver `null`, nunca un combo de 1 ítem — AC-7);
  premium exactamente en `presupuesto * 1.20` (debe aceptar, `≤`) y en
  `presupuesto * 1.20 + 1` (debe rechazar); orden ascendente estricto
  garantizado por construcción, no por post-chequeo. *Check:* suite en verde,
  cobertura de cada rama de `combos.ts` visible en el reporte de coverage.

#### LLM + guardrails

- [ ] **T10.** `src/slots.ts`: 1 llamada a Claude Haiku 4.5 vía AI SDK +
  `@ai-sdk/anthropic`, salida estructurada `TurnExtraction` (RFC §5.1) — API
  exacta de `generateObject`/equivalente verificada contra
  `node_modules/ai/docs` en el momento de implementación (skill `ai-sdk`), no
  contra este RFC. *Check:* unit tests con el provider mockeado (sin gastar
  LLM real) — casos con ambos datos, uno solo, ninguno, mensaje fuera de tema.
- [ ] **T11.** `src/render.ts`: las 5 plantillas de texto (RFC §5.2 —
  corregido post gate de Fase 3: 3 variantes fijas de intro de
  recomendación en vez de 1 sola, más `no_recommendation` y `off_topic`), 0
  llamadas al LLM; `pickTemplate(turnId, variants)` selecciona la variante
  de recomendación por hash determinista de `turn_id` (no aleatorio).
  *Check:* snapshot tests de las 5 plantillas + test de `pickTemplate` que
  confirma que el mismo `turn_id` siempre produce la misma variante y que
  las 3 variantes de recomendación se alcanzan con `turn_id` fixtures
  distintos.
- [ ] **T12.** `src/guardrails.ts`: (a) re-verificación post-generación de
  cada producto de cada combo contra `data/products.json` cargado (AC-4); (b)
  denylist + validación de `clarificationQuestion` con fallback canned.
  *Check:* unit test que fuerza un producto "inventado" en un combo fixture →
  confirma degradación a `no_recommendation`; unit test con
  `clarificationQuestion` conteniendo tokens del denylist → confirma fallback.
- [ ] **T13.** `src/handler.ts` (corregido — invocación async,
  `rfc-transporte-websocket.md §4`/RFC §5.3.5-6/§6): entry point, recibe
  `ConnectorInvocationPayload` (no un `TurnRequest` con `disabled` — ese
  campo ya no existe, `backend-agent` filtra antes de invocar), orquesta
  `slots.ts` → (si ambos slots) `retrieval.ts` + `combos.ts` →
  `guardrails.ts` → `render.ts` → `dispatch.ts` (T13a), todo envuelto en un
  `try/catch` de nivel superior que, ante cualquier excepción no controlada,
  arma un `TurnResult{kind:"error"}` y lo pasa igual por `dispatch.ts` (que
  lo traduce a `unavailable`/`internal_error`) usando
  `connection_id`/`api_endpoint`/`turn_id` del payload de entrada, siempre
  disponibles. *Check:* unit test — cada dependencia externa mockeada para
  tirar una excepción (LLM, retrieval, catalog) → confirma que igual sale un
  `unavailable` por el mock de `postToConnection`, nunca una excepción sin
  capturar ni silencio.
- [ ] **T13a.** `src/dispatch.ts`: mapea `TurnResult.kind` a 1+
  `ChatEnvelope` según la tabla de RFC §6 corregida post gate de Fase 3
  (`off_topic`→`text_done`; `clarification`→`profile_confirmed?`+`text_done`;
  `recommendation`→`text_done` (intro plantillada de
  `TurnResult.message`)+`profile_confirmed?`+`combo_recommendation`, mismo
  `turn_id` en los tres, sin `text_delta` — ver "Corrección post gate de
  Fase 3" en `plan.md`; `no_recommendation`→`no_recommendation`;
  `error`→`unavailable`), arma `turn_id`/`ts`/`v:1` de cada envelope, y
  llama a `apigw-client.ts` (T13b) para cada uno en orden. *Check:* unit
  test — cada `kind` produce exactamente los envelopes esperados, en el
  orden correcto; caso específico de `recommendation` confirma que
  `text_done` sale antes que `combo_recommendation` y que los 3 envelopes
  comparten `turn_id`.
- [ ] **T13b.** `src/apigw-client.ts`: wrapper de
  `@aws-sdk/client-apigatewaymanagementapi` (`postToConnection`), construido
  con `connection_id`/`api_endpoint` del payload de invocación; atrapa
  `GoneException` como no-op (cliente ya desconectado), propaga cualquier
  otro error al `catch` de `handler.ts`. *Check:* unit test con el cliente
  de AWS mockeado — `GoneException` no lanza, otros errores sí se propagan.
- [ ] **T14.** Auditoría propia de no-leak (análoga a `pnpm run check:leak` de
  `renovarte-catalogo`): grep de tokens prohibidos (`costo`, `margen`,
  variantes de precio de lista LACA) sobre `src/`, `data/`, y el `system`
  prompt literal de `slots.ts`. *Check:* script corre en CI, falla el build si
  encuentra un match.

#### Eval + cierre

- [ ] **T15.** `tests/eval/`: implementar los 9 casos fijos de `plan.md`
  "Eval" con `retrieval.ts`/`slots.ts` mockeados a valores deterministas (no
  gasta LLM real en CI). *Check:* suite en verde, cada caso verifica
  propiedades (no texto exacto) como está descripto en `plan.md`.
- [ ] **T16.** Run manual opcional del mismo eval contra Claude Haiku 4.5
  real (no en CI) — documentado en el `README.md` del repo nuevo con el costo
  estimado de la corrida. *Check:* corrida manual registrada, sin
  automatizarse en CI (evita gasto recurrente no controlado).
- [ ] **T17.** Una vez que `data/products.json` tenga la primera
  sincronización real (post-T4 corrido contra prod), re-correr el eval de T15
  contra datos reales (no fixtures) y reportar cualquier caso que degrade a
  `no_recommendation` de forma inesperada — insumo para ajustar la allowlist
  de categorías (RFC §3.1) si hace falta. *Check:* reporte de resultados,
  ajuste de allowlist si corresponde con su propio commit/PR.
- [ ] **T18.** Coordinar con `backend-agent`: (a) confirmar por escrito
  (comentario en PR o nota en README de ambos repos, mismo criterio que su
  T17) el ARN de la API Gateway (output de su Terraform,
  `rfc-transporte-websocket.md §4`) y el permiso IAM
  `execute-api:ManageConnections` que este repo necesita sobre ese ARN para
  llamar `postToConnection` desde `apigw-client.ts` (T13b), más
  `dynamodb:UpdateItem` acotado sobre `chat-connections`/`chat-budget-ledger`
  para que este repo escriba `tipo_piel`/`presupuesto`/el ledger de costo
  (RFC transporte §4/§5.1); (b) confirmar que `ConnectorInvocationPayload`
  (T2) matchea exactamente el payload que arma `on-message.ts` de
  `backend-agent` — el mecanismo de invocación en sí (async,
  `InvocationType: Event`) ya no es objeto de esta coordinación, está
  resuelto (ver `plan.md` "Corrección post gate de Fase 2"); lo que queda es
  el detalle operativo de ARNs y el shape exacto del payload. *Check:*
  ambos repos confirman por escrito el ARN copiado y el shape del payload de
  invocación, sin cambios de forma de `ChatEnvelope`/`TurnResult` (`ux.md`
  depende de esa forma exacta).

## Frontend

### Estimate

**Tamaño: L — 14 a 20 horas de trabajo de ingeniería** (bastantes componentes
nuevos chicos + una máquina de estados con streaming/aria-live sensible a
errores sutiles, pero sin backend propio que escribir), repartidas así:

- **Contrato + lógica pura (T1-T5): ~4-5h.** La parte con más tests
  unitarios, la más barata de tener 100% cubierta porque no depende de DOM.
- **Shell del panel + FAB/home (T6-T9): ~4-6h.** Foco atrapado cross-breakpoint
  es la parte más fácil de arruinar.
- **Hilo, combos, composer (T10-T13): ~3-4h.**
- **Estado "no disponible" + cierre (T14-T18): ~2-3h**, más la investigación
  de `page.routeWebSocket()` (riesgo #2 abajo).

**Top riesgos que podrían mover el estimate:**

1. ~~Divergencia de contrato para el turno de recomendación~~ — **resuelto**:
   `ai-agent` corrigió `dispatch.ts` para emitir `text_done` (intro
   plantillada) antes de `combo_recommendation` (`plan.md`, sección
   "Divergencia detectada — RESUELTO"). T11/T12 siguen como estaban, sin
   ajuste adicional necesario.
2. **`page.routeWebSocket()` puede no alcanzar** para simular reconexión con
   backoff o cierre abrupto a mitad de turno — la alternativa (`ws` como
   fixture server) requiere aprobación humana explícita antes de instalar
   (`CLAUDE.md`), no está pre-aprobada.
3. **Ningún gateway real existe todavía** — todo se prueba contra el
   contrato de tipos + mocks de Playwright; la verificación end-to-end
   contra `renovarte-chat-gateway`/`renovarte-colibri-rag` reales queda
   pendiente de que esos repos existan.
4. **Foco atrapado + devolución de foco exacta** (FAB vs. tarjeta de home
   como origen distinto) — la superficie de accesibilidad más fácil de tener
   un bug sutil.

### Tasks

#### Contrato y lógica pura

- [ ] **T1.** `src/lib/chat/types.ts`: `ChatEnvelope`, `MessageType`, los 7
  payloads y `ComboEntry`/`ComboItem` copiados verbatim de
  `rfc-transporte-websocket.md §3`, más un runtime guard por tipo (mismo
  estilo que `isProduct`/`validateProducts` en `src/lib/types.ts`). *Check:*
  `tsc --noEmit` en verde + Vitest: cada guard acepta un ejemplo válido y
  rechaza uno malformado, para los 7 `type`.
- [ ] **T2.** `src/lib/chat/budget-copy.ts`: mapea `reason`
  (`"budget_cap"` | cualquier otro string | `undefined`) a 1 de 2 variantes
  de copy. *Check:* Vitest — los 4 `reason` del RFC (`budget_cap`,
  `maintenance`, `connection_error`, `internal_error`) más uno desconocido,
  confirma exactamente 2 variantes usadas.
- [ ] **T3.** `src/lib/chat/reducer.ts`: máquina de estados de conversación
  — fase de conexión (`connecting`/`connecting_slow`/`ready`/`unavailable`),
  lista de mensajes anunciables (solo `text_done` + combos +
  `no_recommendation`, nunca `text_delta`), buffer de streaming separado que
  no entra al log, perfil con merge parcial (no reemplazo), visibilidad de
  chips de ejemplo (solo antes del primer mensaje del visitante), placeholder
  de "Cambiar". *Check:* Vitest exhaustivo, un caso por tipo de envelope +
  AC-2/3/5/6/7/8/9/13 a nivel de forma del estado.
- [ ] **T4.** `src/lib/chat/transport.ts`: wrapper de WebSocket inyectable
  (`WebSocketLike`), conexión perezosa (recién al primer `openChat()`),
  backoff de reconexión, valida cada frame con T1 antes de pasarlo al
  reducer (frame malformado → `unavailable/internal_error` local, nunca una
  excepción sin capturar), `NEXT_PUBLIC_CHAT_WS_URL` ausente → directo a
  `unavailable/connection_error` sin intentar abrir el socket. *Check:*
  Vitest con un `WebSocketLike` falso — conexión ok/falla, frame malformado,
  backoff, env var ausente.
- [ ] **T5.** `src/lib/chat/content.ts`: copy cliente-only (saludo inicial,
  2–3 prompts de ejemplo, las 2 variantes de "no disponible" — borrador,
  pendiente de validación de CTO/CEO igual que en `ux.md`). *Check:*
  `tsc --noEmit` en verde; sin lógica que testear todavía (se consume en
  T10/T11/T14).

#### Shell del panel y puntos de entrada

- [ ] **T6.** `src/lib/use-mounted.ts`: extraer el `useMounted` existente de
  `MissionCarouselLive.tsx` sin cambiar su comportamiento; `ChatFab`/
  `ChatHomeInviteCard` (T7/T8) lo reusan. *Check:* la suite existente de
  `tests/unit/mission-section.test.tsx`/`tests/e2e/catalog.spec.ts` (casos de
  AC-7 del carrusel) sigue en verde sin modificarla — regresión cero.
- [ ] **T7.** `src/components/chat/ChatFab.tsx`: mobile ícono solo, desktop
  con label "Chat", `bottom-4 right-4` + `env(safe-area-inset-bottom)`,
  inerte (`tabIndex={-1}`, sin `onClick` funcional) hasta hidratar (T6).
  *Check:* Vitest con `renderToStaticMarkup` — el botón está en el HTML base
  sin `onClick` funcional/con `tabIndex="-1"` antes de hidratar, mismo
  criterio que el test de `MissionCarouselLive` "no JS".
- [ ] **T8.** `src/components/chat/ChatHomeInviteCard.tsx` + wire en
  `src/app/page.tsx`, exactamente entre el `<div className="my-10 border-t
  ...">` y `<h2>Catálogo</h2>`. *Check:* Vitest con `renderToStaticMarkup` de
  `Home` — la tarjeta aparece en ese orden exacto del DOM, mismo patrón que
  el test e2e existente de orden de `MissionSection`.
- [ ] **T9.** `src/components/chat/ChatProvider.tsx` (contexto + T3 + T4,
  renderiza `{children}` + `ChatFab` + `ChatPanel` como hermanos) + wire en
  `src/app/layout.tsx` (fuera de `<main>`) + `src/components/chat/
  ChatPanel.tsx` shell (`role="dialog" aria-modal="true"
  aria-labelledby`, mobile full-screen / desktop drawer 420px + scrim, foco
  atrapado, Escape/scrim/× devuelven foco al trigger exacto que abrió el
  panel). *Check:* Playwright e2e — abre vía FAB, Tab/Shift+Tab ciclan solo
  dentro del panel, Escape cierra y devuelve foco al FAB; abre vía tarjeta de
  home, cerrar devuelve foco ahí.

#### Hilo, combos y composer

- [ ] **T10.** `src/components/chat/ChatHeader.tsx` + `ChatProfileBar.tsx`:
  título + botón cerrar; chip "Piel: X · Presupuesto: $Y" + "Cambiar"
  (enfoca el composer con placeholder override, sin abrir un formulario).
  *Check:* Playwright e2e con `routeWebSocket` — scriptea un
  `profile_confirmed`, confirma el chip; un segundo `profile_confirmed`
  actualiza (no duplica) el chip; clic en "Cambiar" enfoca el composer con el
  placeholder esperado.
- [ ] **T11.** `src/components/chat/ChatThread.tsx` + `ChatMessageBubble.tsx`
  + `ChatExampleChips.tsx`: `role="log" aria-live="polite"
  aria-relevant="additions"`, prefijos `sr-only`, indicador de "escribiendo"
  como `role="status"` separado, chips de ejemplo que autocompletan sin
  enviar y desaparecen tras el primer mensaje del visitante, buffer de
  `text_delta` fuera del DOM del log hasta `text_done`. *Check:* Playwright
  e2e — scriptea N `text_delta` + 1 `text_done`, confirma que el contenido
  del `log` solo cambia una vez (en `text_done`), nunca por token.
- [ ] **T12.** `src/components/chat/ChatComboCard.tsx` +
  `ChatComboList.tsx`: `<ol>`/`<li>`/`<h3>` por nivel, `<ul>` de productos con
  deep link `target="_blank" rel="noopener"` a `/producto/[id]`, prefijo
  `sr-only` "Total del combo: ", 3 variantes de texto de relación con
  presupuesto (nunca badge/color de alerta), transición fade +
  `translate-y-1` respetando `motion-reduce:`. *Check:* Vitest con
  `renderToStaticMarkup` — 3 fixtures de `ComboEntry` cubriendo las 3
  variantes de copy + el borde "$0 de diferencia" ("Coincide con tu
  presupuesto"), sin ninguna clase de alerta/rojo; Playwright e2e — scriptea
  un `combo_recommendation` completo, confirma exactamente 3 `<li>` montados
  de una sola vez (nunca una card parcial) y que cada link abre
  `/producto/[id]` en pestaña nueva.
- [ ] **T13.** `src/components/chat/ChatComposer.tsx`: textarea
  auto-expandible (máx. ~4 líneas) + botón circular, deshabilitado mientras
  hay un turno en curso o en estado no disponible. *Check:* Playwright e2e —
  enviar deshabilita el composer hasta que llegue el `text_done`/
  `combo_recommendation`/`no_recommendation` correspondiente, luego se
  reactiva.

#### Estado "no disponible" y cierre

- [ ] **T14.** `src/components/chat/ChatUnavailableBlock.tsx`, wireado en
  `ChatThread`/`ChatPanel` para las 2 posiciones de `ux.md` (al abrir, a
  mitad de conversación): `role="status" aria-live="polite"`, `bg-sage-50`,
  las 2 variantes de copy (T2/T5), input `disabled` con el placeholder
  indicado, × siempre funcional. *Check:* Playwright e2e — (a) fixture WS
  manda `unavailable/budget_cap` al conectar → copy dedicado reemplaza el
  saludo, composer deshabilitado, × sigue cerrando; (b) `unavailable` con
  otro `reason` → copy genérico; (c) `unavailable` a mitad de conversación →
  hilo previo intacto y scrollable, solo el pie cambia.
- [ ] **T15.** Wire de `no_recommendation` (AC-6): renderiza
  `payload.mensaje` (provisto por `ai-agent`) como una `ChatMessageBubble`
  normal, sin badge/ícono de alerta ni botón de acción especial. *Check:*
  Playwright e2e — scriptea `no_recommendation`, confirma que renderiza con
  el mismo shape/testid que cualquier burbuja de `text_done`, solo cambia el
  contenido.
- [ ] **T16.** Pasada de `prefers-reduced-motion` sobre T9/T11/T12 (apertura/
  cierre del panel, montaje de cards, pulso de "escribiendo") —
  `motion-reduce:`, sin librería de animación nueva. *Check:* Playwright e2e
  con `page.emulateMedia({ reducedMotion: "reduce" })`, confirma que el
  contenido igual aparece (sin depender de un `transitionend` que no
  dispara).
- [ ] **T17.** Suite e2e de AC-1/AC-11/progresividad en
  `tests/e2e/chat.spec.ts` (archivo nuevo, no toca `catalog.spec.ts`): abre
  el chat sin ningún cookie/localStorage de sesión; grilla/filtro/búsqueda/
  ficha funcionan con el panel cerrado, con el panel en estado no disponible,
  y con `javaScriptEnabled: false` (mismo patrón que el test de
  `MissionCarouselLive`) — confirma FAB/tarjeta de home presentes pero
  inertes sin JS. *Check:* suite en verde, `tests/e2e/catalog.spec.ts`
  existente sigue en verde sin modificarse.
- [ ] **T18.** Cierre: agregar `NEXT_PUBLIC_CHAT_WS_URL` a
  `.env.local.example`/README (solo la URL pública del gateway, nunca una
  key — valor real pendiente de que `renovarte-chat-gateway` exista) y
  correr `pnpm gate` completo (lint + build + typecheck + Vitest +
  `check:leak` + Playwright) en verde. *Check:* `pnpm gate` en verde de punta
  a punta con todo el código de este agente incluido.
