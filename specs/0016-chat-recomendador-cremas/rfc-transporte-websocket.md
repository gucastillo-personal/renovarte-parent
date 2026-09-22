# RFC — Transporte WebSocket de Colibrí (spec 0016)

**Autor:** `backend-agent`. **Estado:** propuesta, pendiente de aprobación
CTO/CEO en el gate de Fase 2 (junto con el RFC del conector LLM/RAG de
`ai-agent`, que se escribe por separado y en paralelo).

**Alcance de este documento:** arquitectura del **repo nuevo #1** de los 2
que confirma `spec.md` (`## Contexto de arquitectura y dependencias`) —
el transporte WebSocket, ciclo de vida de conexión, envelope de mensajes,
y el mecanismo de corte a los USD 20/mes (RNF-09/AC-13). **No** decide qué
va dentro del payload de una recomendación (RAG/LLM) — eso es del RFC de
`ai-agent` para el repo #2. Los dos documentos comparten el contrato de
envelope definido acá (`## 3. Envelope de mensajes`), que es la superficie
de acoplamiento entre ambos repos.

No enmienda `renovarte-catalogo/specs/constitution.md` — RNF-08 ya cerró
esa pregunta (el runtime nunca vive en `renovarte-catalogo`; ver
`spec.md`). Si esta arquitectura se aprueba, sí es información nueva que
`renovarte-catalogo/specs/constitution.md` debería **referenciar** (no
enmendar) desde una nota, igual que ya referencia a `renovarte-pipeline` —
tarea de implementación, marcada en `tasks.md`.

---

## 1. Repo nuevo propuesto

**Nombre:** `renovarte-chat-gateway`.

Sigue el precedente de `renovarte-events` (repo nuevo por capability, sin
PRD/`constitution.md` formal por ser un proyecto de práctica — solo
`README.md` + `CLAUDE.md` con las mismas reglas de aprobación humana que
ya rigen el resto del proyecto). No existe todavía — se crea recién en la
fase de implementación (Fase 4), nunca en esta fase de diseño.

Sugiero coordinar con `ai-agent` para que el repo del conector LLM/RAG use
un prefijo hermano (p.ej. `renovarte-chat-brain` o `renovarte-chat-rag`)
para que ambos se identifiquen como parte de la misma feature en el
listado de repos — no es una decisión mía, es una sugerencia de
naming para la ronda de coordinación de Fase 3.

## 2. Stack

**API Gateway WebSocket API + AWS Lambda (Node.js 22.x) + DynamoDB**, en la
misma cuenta AWS que `renovarte-events` (mismo patrón OIDC de GitHub
Actions, Terraform como IaC).

**Node.js, no Python, para este repo** (a diferencia de `renovarte-pipeline`
y del `producer` de `renovarte-events`), por tres razones concretas:

1. **Precedente directo dentro del propio `renovarte-events`:** su
   `consumer/` (Lambda disparada por evento, sin trabajo pesado de datos)
   ya es Node.js — este repo es el mismo tipo de componente (Lambda
   liviana, orientada a I/O: DynamoDB + API Gateway Management API), no un
   pipeline de transformación de datos como `renovarte-pipeline`/el
   `producer` de `renovarte-events`, que sí son Python por manipular
   datos tabulares con Pydantic.
2. **Cold start.** Un runtime Node.js sin dependencias pesadas (el SDK de
   AWS ya viene incluido en el runtime Lambda, cero `npm install` en el
   paquete de despliegue si nos limitamos a `@aws-sdk/*`) tiene cold starts
   más chicos y predecibles que un Lambda Python con dependencias — relevante
   porque `ux.md` fija un umbral de 400ms antes de mostrar el indicador de
   "escribiendo" en la conexión inicial del panel (ver `## 6. Riesgos`).
3. **Vocabulario compartido con `renovarte-catalogo`.** El envelope de
   mensajes (`## 3`) es JSON con una forma fija; documentarlo como tipos
   TypeScript en este repo permite que el `frontend-agent` copie/adapte
   esos tipos literalmente a su cliente WS en `renovarte-catalogo` (no un
   paquete npm compartido — over-engineering para 2 repos de práctica — pero
   sí el mismo lenguaje de tipos, copiado a mano y versionado por comentario,
   igual criterio que el archivo de precios reference sincronizado a mano
   entre `renovarte-pipeline` y `renovarte-catalogo`).

No se elige `Node` para el repo de `ai-agent` — esa decisión es de su RFC.
Nada en este diseño asume que el conector LLM/RAG está en el mismo
runtime; el límite entre los dos repos es una invocación de Lambda a
Lambda (`## 4`), agnóstica de lenguaje.

## 3. Envelope de mensajes

Contrato JSON, versión `v: 1`, compartido por ambas direcciones del
WebSocket y por la invocación interna hacia el conector LLM/RAG. Es la
pieza que resuelve el "Contrato de interacción" que `ux.md` exige (los 4
puntos de su sección homónima) y la pregunta abierta #2 de `ux.md`
("¿el transporte puede distinguir techo de gasto de otra falla?" —
respuesta: **sí**, ver `## 5`).

```ts
// Forma general — ambas direcciones
interface ChatEnvelope<T = unknown> {
  v: 1;
  type: MessageType;
  turn_id: string;      // uuid v4, uno por turno de asistente; el cliente lo genera para user_message y lo reusa como correlación
  ts: string;            // ISO-8601
  payload: T;
}
```

### 3.1 Cliente → servidor (ruta `$default` de API Gateway WS)

```ts
type MessageType = "user_message";

interface UserMessagePayload {
  text: string; // texto libre del visitante, tal cual lo escribió
}
```

No hay un "modo formulario" separado (`ux.md`, "Captura de tipo de
piel..."): siempre es `user_message`, sea la primera línea o una
respuesta a una pregunta de seguimiento.

### 3.2 Servidor → cliente

Seis tipos, cerrados (el cliente puede tratar cualquier `type`
desconocido como no-op, para tolerancia a futuro sin romper):

| `type` | Cuándo | `payload` |
|---|---|---|
| `text_delta` | Token a token, mientras el modelo genera texto libre (streaming visual) | `{ token: string }` |
| `text_done` | Fin de un turno de texto libre — **contenido completo**, no solo señal de corte | `{ text: string }` |
| `profile_confirmed` | El conector LLM/RAG confirmó de forma estructurada tipo de piel y/o presupuesto | `{ tipo_piel?: string; presupuesto?: number }` — solo trae las claves que cambiaron; el cliente mergea sobre el estado que ya tenía (barra de resumen, `ux.md`) |
| `combo_recommendation` | Los 3 combos están completos y listos — **nunca parcial** (`ux.md`, "Cards de combo... nunca se renderizan parciales") | ver `## 3.3` |
| `no_recommendation` | AC-6: no hay combo razonable para los datos dados | `{ mensaje: string }` — texto libre del modelo, se renderiza como burbuja normal (`ux.md`), pero el `type` evita que el cliente tenga que parsear prosa para distinguirlo de un `text_done` cualquiera |
| `unavailable` | AC-13 / RNF-07: el chat no puede responder, con motivo distinguible | ver `## 5` |

Nota de streaming (`ux.md`, "Streaming / carga"): `text_delta` es
puramente visual — el `role="log" aria-live="polite"` del cliente **no**
debe engancharse a `text_delta`, solo a `text_done` (contenido final
completo) y a los demás tipos estructurados. Esta regla vive documentada
acá porque es el emisor (este repo + el conector) quien decide cuántos
`text_delta` manda, no una decisión del cliente.

### 3.3 `combo_recommendation` — payload

```ts
interface ComboRecommendationPayload {
  combos: [ComboEntry, ComboEntry, ComboEntry]; // siempre exactamente 3, en orden ascendente (AC-5)
}

interface ComboEntry {
  nivel: "mas_barato" | "medio" | "premium"; // AC-3
  items: ComboItem[]; // 2+ (AC-7)
  total: number; // suma de precio_venta de items — AC-4/AC-8/AC-9 se verifican contra esto
}

interface ComboItem {
  producto_id: string;
  nombre: string;
  presentacion: string;
  precio_venta: number; // verbatim de products.json — nunca inventado (AC-4)
}
```

Este shape es **verbatim** el que pide `ux.md` §"Contrato de interacción"
punto 2. La responsabilidad de que `producto_id`/`nombre`/`precio_venta`
coincidan con `products.json` vigente, que `total` sea la suma correcta, y
que el orden sea ascendente, es de `ai-agent`/el conector — este repo no
valida contenido de negocio, solo transporta el shape tal cual (ver
`## 4`, límite de responsabilidad).

## 4. Ciclo de vida de la conexión y límite con el conector LLM/RAG

```
Navegador (renovarte-catalogo)
   │ wss://<api-id>.execute-api.<region>.amazonaws.com/prod
   ▼
API Gateway WebSocket API
   │
   ├─ $connect  → Lambda `on-connect`  (este repo)
   ├─ $disconnect → Lambda `on-disconnect` (este repo)
   └─ $default  → Lambda `on-message` (este repo)
                     │
                     │ invoke async (InvocationType: Event),
                     │ payload = { connection_id, api_endpoint,
                     │             turn_id, user_text,
                     │             tipo_piel?, presupuesto? }
                     ▼
          Lambda del conector LLM/RAG (repo #2, de ai-agent)
                     │ RAG + llamada a la API de Claude (streaming)
                     │ postToConnection(...) directo, uno o más ChatEnvelope
                     │ (text_delta*, text_done, profile_confirmed?,
                     │  combo_recommendation | no_recommendation)
                     ▼
          API Gateway Management API → de vuelta al navegador
```

**Reparto de responsabilidad (para que `ai-agent` y `frontend-agent` no lo
reinterpreten cada uno a su manera):**

- **`on-connect` (este repo):** registra `connection_id` en la tabla
  `chat-connections` (TTL 24h — nunca "historial persistido", `spec.md`
  "Out"). Antes de devolver `200`, chequea `chat-control` (`## 5`); si
  `enabled=false`, hace `postToConnection` con un `unavailable` (motivo
  incluido) **antes** de que el cliente mande nada — resuelve el caso de
  `ux.md` "si el handshake inicial falla o el transporte responde
  'deshabilitado'". Si `enabled=true`, no manda nada — el saludo inicial
  lo pinta el cliente sin red (`ux.md`, "Arranque de la conversación").
- **`on-message` (este repo):** valida que el mensaje entrante matchee
  `UserMessagePayload` (si no, responde `unavailable`/`reason:
  internal_error`, nunca cuelga la conexión en silencio), vuelve a chequear
  `chat-control` (cubre el caso "el techo se alcanza a mitad de una
  conversación ya iniciada", `ux.md`), y si está habilitado invoca **async**
  (no espera respuesta) al Lambda del conector con el mensaje + el estado de
  perfil que ya tenga en `chat-connections`. Responde `200` a API Gateway de
  inmediato — el límite de integración WS (29s) nunca se expone a la
  duración real de una llamada a un LLM, que puede superarlo.
- **El conector LLM/RAG (repo #2, `ai-agent`) llama directo a
  `postToConnection`** con los `ChatEnvelope` que arma — no vuelve a pasar
  por este repo. Esto requiere que su Lambda tenga permiso IAM
  `execute-api:ManageConnections` sobre el ARN de esta API Gateway (`this
  repo` exporta ese ARN como output de Terraform; `ai-agent` lo referencia
  a mano en su propio Terraform — sin Terraform remote-state compartido
  entre repos, incluido a propósito para no sumar acoplamiento de estado
  entre 2 proyectos de práctica). Documentado como tarea de coordinación
  explícita en `tasks.md`.
- **Cuando el conector confirma perfil o entrega combos**, este repo no
  se entera en tiempo real (no hay vuelta por `on-message`) — pero si el
  conector también actualiza `chat-connections.tipo_piel`/`presupuesto`
  (mismo `connection_id`, permiso `dynamodb:UpdateItem` acotado a esa
  tabla), la sesión sigue teniendo memoria de conversación *dentro de la
  conexión activa* sin persistirla más allá de eso — importante para que
  "Cambiar" (`ux.md`) tenga contexto de qué ya se sabía.

**Por qué invocación async y no SQS de por medio (a diferencia de
`renovarte-events`, que sí usa SNS→SQS):** ahí la latencia no importa
(notificación a Discord, corre en background sobre un diff ya calculado);
acá sí importa (UX espera respuesta en segundos, con streaming). Un buffer
SQS entre `on-message` y el conector solo suma latencia y un componente
más a operar, sin ganancia real a este volumen — se deja documentado como
mejora futura si la invocación directa demuestra ser poco confiable, no
como parte de este diseño.

## 5. Corte a los USD 20/mes (RNF-09/AC-13)

**Primero, un hallazgo que hay que resolver con el CTO/CEO antes de
implementar** (ver también reporte): **AWS Budgets no puede medir el gasto
de la API de Anthropic/Claude**, porque esa facturación es externa a AWS —
Cost Explorer (la fuente de datos de cualquier AWS Budget) solo ve gasto
de recursos AWS de esta cuenta, nunca la factura de un proveedor externo.
"AWS Budgets + Budget Actions" tal como se planteó en la conversación con
el CTO/CEO **no puede ser, literalmente, el mecanismo que mide los USD
20/mes de Claude** — es una limitación estructural del servicio, no una
elección de diseño mía. Lo que sigue es el diseño real que sí cumple
AC-13, y usa AWS Budgets donde sí aplica de verdad (gasto AWS del propio
proyecto, no el de Claude).

### 5.1 Medición real del gasto de Claude — ledger propio (fuente de verdad de AC-13)

- Tabla `chat-budget-ledger` (este repo la crea; el conector de `ai-agent`
  escribe en ella con permiso `dynamodb:UpdateItem` acotado). PK `period`
  (`"YYYY-MM"`, UTC). Atributo `spent_usd_estimate` (Number).
- Después de cada llamada a la API de Claude, el conector calcula el costo
  real de esa llamada a partir de `usage.input_tokens`/`usage.output_tokens`
  que la propia API devuelve (dato exacto, no estimado a ojo) × el pricing
  público vigente del modelo elegido, y hace
  `UpdateItem ... ADD spent_usd_estimate :costo` (atómico, sin condición de
  carrera entre conexiones concurrentes).
- Este cálculo (qué modelo, qué pricing) es responsabilidad del RFC de
  `ai-agent` — acá solo se fija el **contrato de la tabla** (nombre,
  key, atributo) que ese repo escribe y que este repo lee.

### 5.2 Lambda `budget-guard` (este repo) — la "acción que dispara"

- Disparada por **DynamoDB Streams** sobre `chat-budget-ledger`
  (`NEW_IMAGE`) — se ejecuta solo cuando el ledger cambia, no en polling.
- Si `spent_usd_estimate >= 20` (env var `BUDGET_CAP_USD`, no hardcodeado)
  y `chat-control.enabled` todavía es `true`, escribe
  `chat-control = { enabled: false, reason: "budget_cap", updated_at }`
  (idempotente — si ya está en `false`, no vuelve a escribir).
- **Reactivación mensual:** un `EventBridge Scheduler` (`cron(0 0 1 * ? *)`,
  primer día de cada mes, UTC) invoca la misma Lambda en modo "reset":
  `chat-control = { enabled: true, reason: null }`. Esto es una
  **inferencia mía de "techo mensual"**, no algo que AC-13 pida
  literalmente (AC-13 solo exige el apagado, no el reencendido) — lo dejo
  marcado como supuesto a confirmar con el CTO/CEO en el gate de Fase 2,
  no como algo ya cerrado.

### 5.3 `chat-control` — el flag que `on-connect`/`on-message` chequean

```ts
// Item único, pk fijo "status"
interface ChatControlItem {
  pk: "status";
  enabled: boolean;
  reason: "budget_cap" | "maintenance" | null;
  updated_at: string;
}
```

`on-connect`/`on-message` (este repo) leen este item (GetItem simple, sin
lógica de negocio) y, si `enabled=false`, responden:

```json
{ "v": 1, "type": "unavailable", "turn_id": "...", "ts": "...",
  "payload": { "reason": "budget_cap" } }
```

El cliente ya sabe (por `ux.md`) mapear `reason: "budget_cap"` al copy
específico y cualquier otro `reason` (`"maintenance"`, `"connection_error"`,
`"internal_error"`) al copy genérico — resuelve la pregunta abierta #2 de
`ux.md` con un **sí, es viable distinguir el motivo**, siempre que el
cliente trate `budget_cap` como el único caso con copy dedicado y todo lo
demás caiga al genérico (tal como `ux.md` ya lo dejaba previsto).

`"maintenance"` es un extra que agrego para poder deshabilitar el chat a
mano (ej. si el CTO/CEO quiere cortarlo sin esperar al techo de gasto) —
un `UpdateItem` manual sobre `chat-control`, sin Lambda ni Budget
Action de por medio. No es un requisito de la spec, es una superficie
operativa barata de sumar ya que la tabla existe; se puede omitir del
scope de implementación si no se considera necesaria.

### 5.4 AWS Budgets + Budget Actions — donde sí aplica de verdad (gasto AWS, no de Claude)

Guardrail secundario, no el mecanismo de AC-13: protege la invariante "$0
infraestructura" (`constitution.md §II.5`) del propio `renovarte-chat-gateway`
(y, transitivamente, del repo del conector si comparte tags) contra un bug
real (ej. un loop de reconexión infinita, una `$connect` sin límite de
throttling) que dispare costo de AWS de verdad — no de Claude.

- Todos los recursos Terraform de este repo llevan
  `default_tags = { Project = "renovarte-chat" }` a nivel de provider
  (`ai-agent` debería taguear igual en su repo si quiere que este mismo
  Budget cubra también sus recursos AWS).
- **AWS Budget** tipo "Cost budget", filtrado por ese tag, límite mensual
  **USD 5** (holgado sobre el gasto esperado real, ~USD 0, dado el volumen
  de un proyecto de práctica — evita falsos positivos por el ruido normal
  de Free Tier).
- Umbral 80% (actual o forecast): notificación SNS/email, informativa, sin
  acción.
- Umbral 100% (actual): **Budget Action** tipo "IAM policy" — adjunta una
  policy `Deny` de `lambda:InvokeFunction` a los roles de ejecución de este
  proyecto (`on-connect`, `on-message`, `budget-guard`), con aprobación
  automática (dado que ya es un límite de emergencia, no una decisión de
  negocio) o manual, a definir en implementación — recomiendo automática
  para que el circuit breaker funcione sin depender de que alguien esté
  mirando.
- **No sustituye ni se confunde con el ledger de `## 5.1`** — este Budget
  nunca ve un centavo de lo que cobra Anthropic; solo protege contra un
  costo de AWS inesperado en *este* proyecto.

## 6. Riesgos

1. **Free tier de 12 meses de API Gateway — no puedo confirmarlo desde
   este repo.** SNS/SQS/Lambda que ya usa `renovarte-events` están en el
   *Always Free* permanente, pero **API Gateway (REST y WebSocket) no** —
   su free tier (1M mensajes + 750.000 minutos de conexión/mes) es válido
   solo durante los primeros 12 meses **de la cuenta AWS**, no del repo.
   `renovarte-events` (el proyecto AWS más antiguo del portfolio) tiene su
   primer commit el 2026-09-16 — 5 días antes de hoy — pero eso acota
   cuándo se creó *el repo*, no necesariamente cuándo se creó *la cuenta*
   (pudo haberse creado antes y usarse recién ahí). **No puedo confirmar
   con la información disponible en este checkout si la cuenta sigue
   dentro de ese período de 12 meses** — queda como riesgo explícito, a
   verificar en la consola de AWS Billing → "Free Tier" antes de
   aprovisionar nada. Si ya venció, el costo real a este volumen es de
   fracciones de centavo/mes (igual orden que la salvedad de CloudWatch
   Logs que ya documenta `renovarte-events/docs/runbook.md`) — bajo, pero
   técnicamente rompe "$0 infraestructura" literal y necesitaría el mismo
   tipo de excepción explícita que ya tiene el techo de USD 20/mes.
2. **Cold start de Lambda en la ruta `$connect`.** `ux.md` no muestra
   indicador de carga antes de ~400ms. Un Lambda Node.js liviano
   (`on-connect`, sin dependencias npm externas) debería estar bien debajo
   de eso en caliente y probablemente cerca en frío, pero no hay forma de
   garantizarlo sin medir contra la infraestructura real — riesgo a
   validar en implementación, no bloqueante de diseño. El cold start del
   **conector LLM/RAG** (repo de `ai-agent`, con dependencias de
   RAG/embeddings, probablemente más pesado) es un riesgo mayor y ajeno a
   este repo — lo señalo para que `ai-agent` lo considere en su propio
   RFC, dado que `ux.md` ya diseñó el fallback (los 3 puntos de "escribiendo")
   precisamente para absorber esto, así que no es bloqueante tampoco, solo
   documentado.
3. **Coordinación de IAM cross-repo (`## 4`).** El permiso
   `execute-api:ManageConnections` que necesita el Lambda del conector
   sobre el ARN de esta API Gateway, y el `dynamodb:UpdateItem` sobre
   `chat-connections`/`chat-budget-ledger`, se resuelven copiando ARNs de
   un output de Terraform de este repo a un `.tfvars` del otro — manual,
   sin automatización entre repos (a propósito, ver `## 4`). Si el ARN de
   la API Gateway cambia (recreación del recurso), hay que repetir la
   copia a mano — riesgo operativo bajo pero real, documentado en el
   `README.md` de implementación de ambos repos.
4. **Supuesto de reencendido mensual automático (`## 5.2`) no exigido
   literalmente por AC-13.** Lo diseñé porque "techo *mensual*" lo implica,
   pero si el CTO/CEO prefiere que el reencendido sea manual (para revisar
   antes de reabrir el grifo), es un cambio de una línea (sacar el
   `EventBridge Scheduler`) — a confirmar en el gate de Fase 2, no a
   asumir en Fase 4.
5. **Pricing de Claude usado por el ledger (`## 5.1`) vive en el repo de
   `ai-agent`, no en este.** Si ese pricing queda desactualizado (Anthropic
   cambia precios), el ledger de este repo sigue siendo aritméticamente
   correcto pero el corte podría dispararse antes o después del gasto real
   — riesgo de datos que pertenece al RFC de `ai-agent`, señalado acá solo
   porque el corte (`## 5.2`) confía ciegamente en ese número.
