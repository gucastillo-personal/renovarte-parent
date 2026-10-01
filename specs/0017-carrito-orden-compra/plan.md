# 0017 — Carrito y orden de compra · Plan

> Plan cross-repo (`specs/constitution.md` §III.10). Cada agente agrega su
> sección bajo su propio heading y nunca reescribe la de otro:
> `backend-agent` → `## Backend` (repo nuevo de órdenes);
> `devops-agent` → `## Infra` (Terraform/IAM/CI/deploy del repo nuevo, a
> partir de `## Backend` y del RFC); `frontend-agent` → `## Frontend`
> (carrito, formulario y confirmación en `renovarte-catalogo`, a partir de
> `ux.md` y del contrato de `## Backend`). Toda divergencia entre
> secciones se documenta y se resuelve antes de implementar.

## Aprobación de la Fase 3 (2026-10-01)

El CTO/CEO aprobó el diseño completo (`## Backend` rev. 2, `## Infra`
rev. 2, `## Frontend` rev. 2 y `rfc-servicio-ordenes.md` rev. 2) con
estas propuestas de la gate, que pasan a ser decisiones:

1. **Recarga durante "Enviando…":** la `idempotency_key` del envío en
   curso se guarda en `sessionStorage` de la pestaña (no solo en memoria),
   así una recarga a mitad del envío no puede duplicar la orden (AC-24).
   Cambio para `## Frontend` (F11/F13) a incorporar al implementar.
2. **Umbrales anti-abuso:** los propuestos en el RFC (20 POST/h, 3 órdenes
   aceptadas/h y 10/día por IP hasheada; cupo global 50 órdenes/día y
   1000/mes).
3. **Kill-switch al 100 % real del Budget:** aceptado; en ese caso extremo
   el visitante ve la falla genérica en lugar del aviso de tope.
4. **`Reply-To` del mail:** el email del visitante, para responderle
   directo desde la casilla.
5. **Divergencias N1–N4 entre `## Infra` y `## Backend`:** se resuelven a
   favor de `## Infra` (secretos con `value_wo`, rotación con
   `config_revision`, latido de `discord-retention` en toda corrida más
   mecanismo para resolver los `requieren_manual`, logs con
   `process.stdout.write(JSON.stringify(...))`).

Pendiente antes de producción (no bloquea implementación): texto del aviso
de privacidad mencionando mail y Discord, y la consulta profesional
opcional sobre Ley 25.326 (AAIP / transferencia internacional). Pendiente
al implementar: los 4 textos que `ux.md` no fija (Q-F2), a cargo de
`ux-agent`.

**La implementación (Fase 4) no está iniciada:** el CTO/CEO decidió
mergear la spec aprobada y arrancar la implementación más adelante.

## Backend

**Autor:** `backend-agent`. **Revisión 2 (2026-09-30).** **Repo:**
`renovarte-ordenes`, **público** (decisión del CTO/CEO; no existe todavía,
se crea en Fase 4 con aprobación humana). **Diseño completo y
justificación:** [`rfc-servicio-ordenes.md`](./rfc-servicio-ordenes.md)
(revisión 2).

**Constitución:** sin conflictos. `renovarte-catalogo` sigue estático
(AC-14). El runtime vive en el repo nuevo, igual que en la 0016: se agrega
una nota de referencia en la constitución del catálogo, no una enmienda.
La excepción a §II.5 ya está aprobada en la spec (RNF-14), y Discord no
suma costo. No hace falta enmendar §II.4.

### Qué cambió en esta revisión

1. **Doble canal de entrega (RF-19, AC-23..AC-25):** cada orden se
   entrega **siempre** por mail (SES) y por un mensaje a un canal privado
   de Discord vía webhook, con el mismo número de orden (RFC §5, §10.2).
2. **Idempotencia por canal (AC-24):** cada canal es at-most-once por
   separado; un reintento solo reenvía el canal que falló de forma
   definitiva (RFC §5.2–§5.4). `IDEM#` ya no se borra nunca.
3. **Semántica de falla parcial (AC-20, AC-25):** `aceptada` si al menos
   un canal entregó; el canal fallido se registra y alerta (RFC §5.3,
   §5.5).
4. **Borrado automático de los mensajes de Discord a los 60 días
   (AC-29):** cola por fecha en DynamoDB + Lambda diario
   `discord-retention` que borra con el propio webhook (RFC §10.3). El
   canal lo ven solo los propietarios (paso manual, B24).
5. **Decisiones incorporadas:** remitente opción A con smoke test; repo
   público; registro seudonimizado de 90 días (AC-27); alarma de flood →
   `budget-guard` con motivo `flood`; **máximo 100 líneas** (Q-F1);
   `token_vencido` también para el token de < 3 s (Q-F4).
6. **Divergencias de `## Infra` aceptadas** (RFC §13): deploy (Terraform
   manual + código por OIDC con `workflow_dispatch`), CORS en la Function
   URL, reset con `DeleteFunctionConcurrency` sin reserva y `expira_en`
   Number en epoch-segundos.

### Resumen de decisiones (detalle en el RFC)

- **Stack:** Lambda Node.js 22 + TypeScript, DynamoDB (tabla única
  on-demand), Amazon SES v2 y webhook de Discord, en la misma cuenta AWS
  que la 0016. Dependencias de runtime: solo `@aws-sdk/*`. Discord se
  llama con `fetch`/`FormData`/`Blob` nativos, sin librería.
- **Tres Lambdas:** `orders-http` (Function URL + reserved concurrency),
  `budget-guard` (kill-switch por Budget o flood, y reset mensual) y
  `discord-retention` (borrado diario).
- **Contrato:** `GET /v1/estado` y `POST /v1/ordenes`, discriminados por
  `resultado`. **No cambia por Discord** (RFC §3).
- **Precios:** rechazar y volver a mostrar, nunca corregir. Catálogo
  leído en runtime desde el `products.json` público de producción, con
  caché de 5 min + ETag y refresco forzado ante discrepancia (RFC §4).
- **Entrega:** envío en paralelo por los dos canales, con timeout de 4 s
  cada uno. Estado por canal (`enviando` / `entregado` / `fallido` /
  `incierto`) con claim condicional para reintentos. SES con
  `maxAttempts: 1`, para que el SDK no duplique el mail (RFC §5).
- **Mensaje de Discord:** una sola request `multipart` con
  `?wait=true` (el `id` del mensaje es la confirmación). Texto plano en
  un bloque de código (sin markdown, links ni menciones del visitante),
  `allowed_mentions: { parse: [] }`, `SUPPRESS_EMBEDS`, ≤ 1.900
  caracteres con corte por presupuesto, y **siempre** un adjunto
  `orden-RA-xxxxx.txt` con la orden completa, idéntico a la parte de
  texto del mail. Así una orden de 100 líneas entra en un mensaje (RFC
  §10.2).
- **Destinos fijos:** mail por código + IAM `ses:Recipients` + sandbox;
  Discord por la URL del webhook, que vive solo en SSM y se valida contra
  el host `discord.com` al cargar (RFC §6.1).
- **Anti-abuso:** `Origin`, `form_token` HMAC (3 s–2 h), honeypot,
  esquema estricto, rate limit por IP hasheada y **cupo global de
  órdenes** (una vez por key; cubre los dos canales) (RFC §6).
- **Datos personales:** no se persisten en AWS. Dos copias completas
  fuera de AWS: el mail (política de la casilla) y el mensaje de Discord
  (borrado automático a los 60–61 días). Logs con allowlist; nunca la
  URL del webhook ni el body de respuesta de Discord (RFC §7).
- **Tope de USD 20/mes:** ledger al 90 %, reserved concurrency, alarma de
  flood y Budget al 100 % → `budget-guard` → concurrency 0. Reset el día
  1 (RFC §8). Discord y el borrado cuestan USD 0.
- **Número de orden:** `RA-` + 5 dígitos aleatorios, uno por key, igual
  en los dos canales (RFC §9).

### Semántica de fallas parciales (RFC §5.3)

La orden es `aceptada` si **al menos un** canal confirmó (`MessageId` de
SES o `id` de mensaje de Discord). Por qué:

- la promesa al visitante es "RenovArte recibió tu orden", y eso se
  cumple con un canal;
- exigir los dos multiplica las disponibilidades: un webhook borrado o una
  caída de Discord bloquearía órdenes que el mail sí entregó;
- decir "no se envió" cuando sí llegó genera órdenes duplicadas por otras
  vías (AC-20 prohíbe confirmar lo que no llegó, no lo contrario).

| Mail | Discord | Respuesta | Reintento con la misma key |
|---|---|---|---|
| `entregado` | cualquiera | `201`/`200 aceptada` | `200 aceptada`, mismo número, sin reenviar |
| cualquiera | `entregado` | `201`/`200 aceptada` | Ídem |
| `fallido` | `fallido` | `502 falla`/`envio_fallido` | Reenvía los dos |
| `fallido` | `incierto` (o al revés) | `502 falla`/`envio_fallido` | Reenvía solo el `fallido` |
| `incierto` | `incierto` | `502 falla`/`estado_incierto` | No reenvía nada |

El canal que no entregó en una orden aceptada **no se repara solo**:
genera la línea de log `canal_fallido` (sin contenido) → alarma → topic de
alertas operativas → email. La orden está completa en el otro canal.

### Contrato para `frontend-agent` (fuente: RFC §3 y §5)

**No cambia ningún tipo.** Los tipos TS del RFC §3 se copian
**literalmente** a `renovarte-catalogo` (`src/lib/orders/wire.ts`, con un
comentario de versión `v: 1`). Solo cambian dos cosas documentadas:

- **Q-F1:** `lineas` pasa de 1..30 a **1..100** (`MAX_LINEAS = 100`).
- **Q-F4:** un token de menos de 3 s responde `invalida` con
  `campo: "form_token"`, `codigo: "token_vencido"`, el mismo caso que el
  token vencido. El manejo actual del cliente sirve tal cual: token
  nuevo, espera mínima y un reintento con la misma key. **Recomendación:**
  que la espera mínima del cliente sea de **3,5 s**, no 3 s justos.
- **Q-F6, confirmado:** `total_vigente` = Σ precio vigente × cantidad de
  las líneas disponibles, que es exactamente lo que recalcula el
  cliente. Si alguna vez difiere, gana el total local y el servidor
  revalida.
- `aceptada` ahora significa "al menos un canal confirmó". Para el
  cliente no cambia nada: sigue siendo la única respuesta que lleva a la
  confirmación. El visitante no ve cuántos canales hubo.

Lo que el cliente tiene que cumplir (sin cambios salvo los límites):

1. `NEXT_PUBLIC_ORDERS_API_URL` es pública (termina en `/`) y se
   configura **solo en Production**.
2. Al montar `/carrito` con líneas: `GET /v1/estado` →
   `tope_alcanzado` (variante #F), `disponible` (guarda el token) o
   `no_disponible`/error (no bloquea).
3. `POST /v1/ordenes` con `precio_visto` y `total_visto` de pantalla; sin
   nombre ni presentación; honeypot `sitio_web` oculto e inerte.
4. `idempotency_key`: nueva en el primer envío de un payload; se reusa en
   "Reintentar" y en el reintento por `token_vencido`; se regenera ante
   cualquier cambio; solo en memoria.
5. Timeout de 15 s. Timeout, error de red, 5xx sin body o `resultado`
   desconocido → falla genérica, nunca éxito (AC-20). Una Function URL
   throttleada responde sin body del contrato y sin CORS: el cliente lo
   ve como error de red.
6. Mapeo `resultado` → estado UX: RFC §3.2.
7. `rechazada_por_catalogo` → aplicar `precio_vigente`/`no_disponible`,
   mostrar el total y exigir un nuevo envío con key nueva.
8. Límites que valida también el servidor: cantidad 1..20, **1..100
   líneas**, reglas de contacto de `ux.md`. Además, el servidor rechaza
   en los campos de texto los caracteres de control y de control
   bidireccional (U+202A–U+202E, U+2066–U+2069). No afecta a ningún
   usuario real; si el cliente quiere, puede filtrarlos al validar.

### Qué le paso a `devops-agent` (decisiones de infra que **no** tomo)

Adopto las decisiones de `## Infra` (I-D1..I-D12). Lo que esta revisión
**agrega o cambia** respecto de lo que ya está en `## Infra` (detalle en
RFC §10.4 y §13):

- **SSM:** un parámetro `SecureString` nuevo con la **URL del webhook de
  Discord** (por ejemplo `/renovarte-ordenes/discord-webhook-url`), con
  valor placeholder e `ignore_changes = [value]`, como el HMAC. El valor
  real lo carga el CTO/CEO con `put-parameter --overwrite` (B24), nunca
  por chat ni por git.
- **`orders-http`:**
  - env var `DISCORD_WEBHOOK_PARAM` (nombre del parámetro);
  - `ssm:GetParameter` también sobre ese ARN;
  - **quitar `dynamodb:DeleteItem`** (y su condición `LeadingKeys
    IDEM#*`): `IDEM#` ya no se libera;
  - su `UpdateItem` sobre la tabla ya cubre los ítems `BORRAR#<fecha>`.
  - Timeout de 10 s y 256 MB alcanzan (envíos en paralelo, 4 s cada uno).
- **`budget-guard`:** env vars `FLOOD_ALARM_NAME` y `BUDGET_NAME`. Acepta
  el mensaje del Budget (motivo `presupuesto`) y el de la alarma de flood
  en estado `ALARM` (motivo `flood`); ignora `OK`/`INSUFFICIENT_DATA`; un
  formato desconocido apaga igual (fail-safe). Reset:
  `ORDERS_HTTP_RESERVED_CONCURRENCY` vacía → `DeleteFunctionConcurrency`.
- **Lambda nuevo `discord-retention`:** Node 22 arm64, mismo zip, timeout
  60 s, 128 MB, sin reserved concurrency, log group de 14 días. Env vars:
  `ORDERS_TABLE`, `DISCORD_WEBHOOK_PARAM`, `BORRADO_MAX_POR_CORRIDA=200`.
  **Fuera del kill-switch:** corre aunque el servicio esté apagado.
  - IAM: logs de su propio group; DynamoDB `GetItem`/`UpdateItem`/
    `DeleteItem` **solo** con `LeadingKeys` `BORRAR#*`; `ssm:GetParameter`
    sobre el parámetro del webhook.
  - Schedule diario `cron(0 6 * * ? *)` UTC (03:00 de Argentina).
  - El rol de deploy por OIDC (I11) suma su ARN.
- **Topic SNS de alertas operativas, nuevo y separado del kill-switch**,
  con suscripción por email al CTO/CEO. **No puede ser el topic de
  `budget-guard`**: un canal caído no tiene que apagar el servicio.
  Alarmas hacia ese topic:
  - metric filter `{ $.evento = "canal_fallido" }` en `orders-http`, ≥ 1
    en 5 min;
  - metric filter `{ $.evento = "borrado_no_programado" }` en
    `orders-http`;
  - metric filter sobre `retencion_discord` con `requieren_manual > 0` o
    `pendientes_viejos > 0` en `discord-retention`;
  - `Errors` > 0 de `discord-retention` en 1 día.
  Con la de flood, son 5 alarmas: confirmar en I1 que entran en las 10
  gratis (si no, se pueden unir las metric filters de `orders-http` en
  una sola).
- **Egress:** nada nuevo. Los Lambdas no están en VPC y ya salen a
  internet; Discord es HTTPS saliente, igual que el fetch al catálogo.
- **README público:** sin URL del webhook, ni ID del canal o del
  servidor, ni ID de cuenta ni ARNs reales.
- **Runbook de infra:** cargar y rotar el webhook (y forzar un cold start
  con una env var dummy). Al rotar, los mensajes del webhook viejo de
  menos de 60 días hay que borrarlos a mano: el job lo avisa.

Lo que sigue igual: Function URL `AuthType NONE` con CORS (el handler no
emite `Access-Control-*`), reserved concurrency 5 (o sin reserva, I-D4),
tabla única con TTL `expira_en` (Number, epoch-segundos), SES en sandbox
con condición IAM de destinatario, Budget sin acciones, alarma de flood y
deploy de código por OIDC con `workflow_dispatch`.

### Módulos del repo nuevo (`renovarte-ordenes`, no existe aún)

| Archivo | Responsabilidad |
|---|---|
| `src/wire.ts` | Tipos del contrato (RFC §3); se copia a `renovarte-catalogo` |
| `src/handlers/http.ts` | Entry point de la Function URL: routing por `rawPath` de `GET /v1/estado` y `POST /v1/ordenes`, orden de operaciones (RFC §6.5); sin headers CORS |
| `src/handlers/budget-guard.ts` | SNS (Budget o alarma de flood) → `CONTROL` + concurrency 0; modo `reset` con `Put`/`Delete` según la configuración |
| `src/handlers/discord-retention.ts` | Job diario: recorre `BORRAR#` desde el cursor, borra por webhook y registra el resultado (RFC §10.3) |
| `src/lib/validate-order.ts` | Pura: esquema estricto, contacto, honeypot, límites (1..100 líneas), caracteres de control y bidi |
| `src/lib/catalog.ts` | Fetch + caché + ETag + guard `isProduct` + allowlist de campos |
| `src/lib/price-check.ts` | Pura: líneas vs. catálogo → ok / `rechazada_por_catalogo` |
| `src/lib/form-token.ts` | Pura: emitir/verificar HMAC, ventana de 3 s–2 h, fuera de ventana → `token_vencido` |
| `src/lib/order-model.ts` | Pura: builder de `OrdenParaEntrega` por allowlist (el modelo único que usan los dos canales) |
| `src/lib/idempotency.ts` | Reserva `IDEM#` con estado por canal, claim condicional de canales `fallido`, persistencia por canal, agregado |
| `src/lib/delivery.ts` | Orquesta la entrega en paralelo, aplica la tabla de §5.3, programa el borrado y emite `canal_fallido` |
| `src/lib/order-number.ts` | `RA-ddddd` + reserva `NUM#` con reintentos |
| `src/lib/rate-limit.ts` | Contadores por IP hasheada y cupo global de órdenes (una vez por key) |
| `src/lib/ledger.ts` / `src/lib/control.ts` | Ledger mensual con corte al 90 %; `CONTROL` con caché de 30 s y mapeo de motivo a respuesta |
| `src/lib/render/text.ts` | Pura: `renderTextoPlano(orden)`, compartido por la parte `text/plain` del mail y el adjunto de Discord |
| `src/lib/mail/render.ts` | Pura: asunto + HTML escapado + texto (de `render/text.ts`) |
| `src/lib/mail/ses-sender.ts` | `SendEmail` con `Destination` fijo, `maxAttempts: 1`, timeout de 4 s, clasificación `entregado`/`fallido`/`incierto` |
| `src/lib/discord/render.ts` | Pura: `content` ≤ 1.900 caracteres con presupuesto, bloque de código con backticks neutralizados, `allowed_mentions`, flags y adjunto |
| `src/lib/discord/webhook.ts` | Carga y valida la URL desde SSM; `POST ?wait=true` multipart; `DELETE` de mensajes; manejo de 429 y rate-limit headers; clasificación; nunca loguea URL ni body |
| `src/lib/discord/retention-queue.ts` | Buckets `BORRAR#YYYY-MM-DD` (String Set), cursor, cálculo de fecha (+61 días UTC) |
| `src/lib/log.ts` | Logger JSON con allowlist de campos (sin datos personales, sin URL de webhook) |
| `src/leak-audit.ts` | `check:leak`: tokens prohibidos en `src/` y en los renders de ejemplo de **los dos canales**, emails ajenos al destinatario, URLs de webhook de Discord reales y patrones de credenciales |
| `dev/local-server.ts` | Harness local HTTP con mailer fake y Discord fake (imprimen lo que enviarían), catálogo fixture y la opción de forzar la falla de un canal |

**Patrones de acceso DynamoDB (tabla única; todo `expira_en` es Number en
epoch-segundos):**

| `pk` | Atributos | TTL |
|---|---|---|
| `IDEM#<uuid>` | `numero_orden`, `payload_hmac`, `creado_en`, `mail_estado`, `mail_intento_en`, `mail_message_id`, `mail_codigo`, `discord_estado`, `discord_intento_en`, `discord_message_id`, `discord_codigo`, `lineas`, `total` | 90 días (AC-27) |
| `NUM#RA-ddddd` | `idempotency_key`, `creado_en` | sin TTL |
| `BORRAR#YYYY-MM-DD` | `ids` (String Set de `webhook_id:message_id`) | fecha + 30 días |
| `BORRAR#CURSOR` | `desde` (fecha del bucket pendiente más viejo) | sin TTL |
| `RL#<hmac_ip>#<ventana>` | `n` | 24 h |
| `CUPO#dia#YYYY-MM-DD` / `CUPO#mes#YYYY-MM` | `n` (órdenes) | 40 días |
| `LEDGER#YYYY-MM` | `gasto_estimado_usd` | 400 días |
| `CONTROL` | `habilitado`, `motivo` (`tope_alcanzado`/`presupuesto`/`flood`/`manual`/`desconocido`), `actualizado_en` | sin TTL |

### Cómo se verifica cada AC que toca este repo

| AC | Verificación (vitest, sin AWS ni Discord reales salvo donde se indica) |
|---|---|
| AC-9 (server-side) | `validate-order.test.ts`: tabla de casos por campo (vacíos, largo, formato, ninguno de los dos medios, trim, CR/LF, control, bidi); cada error mapea a `campo`/`codigo` |
| AC-10 / AC-13 | `http.test.ts`: el `numero_orden` de la respuesta es igual al del asunto y cuerpo que recibe el mailer fake. `render.test.ts`: fecha y hora, contacto, una fila por línea y total = Σ. **Exactamente un mail:** reintento con la misma key → mismo número, mailer llamado 1 vez. **Real:** smoke en SES sandbox (B19) |
| AC-11 | `ses-sender.test.ts`: `ToAddresses` siempre `[ORDER_RECIPIENT]`, sin `Cc`/`Bcc`; el email del visitante nunca en `Destination` |
| AC-15 | `price-check.test.ts` + `http.test.ts`: 409 con `precio_vigente`/`no_disponible` y `total_vigente`, **sin llamar a ningún canal**; `total_visto` inconsistente → 422; refetch forzado; sin catálogo → `catalogo_no_disponible` |
| AC-16 | `check:leak` en CI sobre los renders de ejemplo de mail **y Discord**; `order-model.test.ts` con una clave de costo inyectada en el catálogo → no aparece en ninguna salida |
| AC-17 | `http.test.ts`: bodies con `to`/`cc`/`bcc`/`reply_to`/`webhook`/`canal`/`thread_id` → 422, **ningún canal llamado**; asserción sobre `Destination` y sobre la URL que usa el cliente Discord (siempre la de SSM). `webhook.test.ts`: URL de SSM con otro host → `fallido`/`config`, sin request. Infra: IAM + sandbox (I16) |
| AC-18 / AC-27 | `log.test.ts` (allowlist); `http.test.ts` captura todos los logs y todas las escrituras DynamoDB de una orden aceptada y verifica que no contienen nombre, email, teléfono, dirección, localidad, IP en claro, URL del webhook ni el body de respuesta de Discord; `IDEM#` con `expira_en` = +90 días en epoch-segundos |
| AC-19 | `http.test.ts`: `Origin` ajeno → 403; token ausente, < 3 s, > 2 h o ajeno → 422 `token_vencido`; honeypot → 422 `errores: []`; 21.ª request/hora → 429; 4.ª aceptada/hora → 429; cupo global agotado → 503. En todos, **ningún canal llamado**. Reintentos de la misma key no consumen cupo |
| AC-20 | `delivery.test.ts`: los dos canales `fallido` → 502 `envio_fallido` y el reintento reenvía los dos; los dos `incierto` → `estado_incierto` y el reintento no reenvía; **nunca un 201 sin `MessageId` ni `id` de Discord**. `ses-sender.test.ts`: cliente con `maxAttempts: 1`; 4xx → `fallido`, 5xx/timeout → `incierto` |
| AC-22 | `ledger.test.ts`: 90 % → `CONTROL` apagado; `http.test.ts`: flag apagado → `tope_alcanzado` (o `mantenimiento` según motivo), **cero** escrituras y ningún canal llamado; `budget-guard.test.ts`: mensaje de Budget → `presupuesto` + concurrency 0; alarma `ALARM` → `flood` + concurrency 0; alarma `OK` → sin cambios; formato desconocido → apaga; `reset` con n → `Put(n)`, sin n → `Delete` |
| AC-23 | `discord-render.test.ts`: primera línea con el mismo `numero_orden`, total y cantidad de productos; contacto completo; adjunto = `renderTextoPlano(orden)` = parte `text/plain` del mail (igualdad de strings); orden de 100 líneas → `content` ≤ 2.000 con "… y N productos más" y adjunto completo. `http.test.ts`: en una orden aceptada, el Discord fake recibe exactamente un mensaje con el mismo número que la respuesta y el mail. **Real:** smoke (B19) |
| AC-24 | `idempotency.test.ts` + `delivery.test.ts`: reintento tras `aceptada` → 200 mismo número, 0 mails y 0 mensajes nuevos; 2 requests concurrentes con la misma key → 1 mail + 1 mensaje + `en_proceso`; 2 reintentos concurrentes con Discord `fallido` → un solo claim gana, 1 mensaje; payload distinto con la misma key → 422 sin envíos |
| AC-25 | `delivery.test.ts`: mail `entregado` + Discord `fallido` (y al revés, y con `incierto`) → `201 aceptada`, estado del canal fallido persistido y **una** línea `canal_fallido` con `orden_aceptada: true`, sin datos personales |
| AC-26 | `check:leak` (patrón de URL de webhook en todo archivo trackeado); `webhook.test.ts`: la URL nunca aparece en logs ni en errores lanzados; `wire.ts` no tiene ningún campo de Discord. Frontend verifica el bundle |
| AC-29 | `retention-queue.test.ts`: fecha de bucket = `creado_en` + 61 días UTC (nunca borra antes de 60). `discord-retention.test.ts` con Discord fake: 204 → borrado y sacado del set; 404/10008 → ya borrado; 404/10015 o `webhook_id` distinto → `requieren_manual`; 429 → espera y sigue; 5xx → pendiente para mañana; recuperación desde el cursor tras días sin correr; tope por corrida; bucket vacío → `DeleteItem` y el cursor avanza; el log de resumen no contiene ids ni URL. **Real:** en el smoke (B19), ejecutar el job con un bucket de prueba de fecha pasada y verificar que el mensaje desaparece del canal |
| AC-14 / AC-21 / AC-28 | No son de este repo. Los verifica `frontend-agent`. Este repo solo garantiza que su caída (incluida la de Discord) no afecta nada fuera del flujo de orden |

### Riesgos (detalle en el RFC §12)

1. **Entregabilidad del mail con la opción A:** puede caer en spam. Ahora
   la orden llega igual por Discord; se mantienen filtro, smoke test y
   fallback a la opción B.
2. **Discord sin SLA:** una caída o un cambio de límites deja el canal
   `fallido`/`incierto`, con alerta y sin pérdida de órdenes.
3. **Filtración de la URL del webhook:** permite publicar en el canal y
   borrar mensajes del webhook, no leerlos. Mitigado con SSM, logs sin
   URL, `check:leak` y runbook de rotación.
4. **Webhook rotado antes de los 60 días:** sus mensajes ya no se pueden
   borrar por API; el job alerta para borrarlos a mano.
5. **Pricing y límites sin verificar hoy** (SES, Discord): B1.
6. **Ambos canales `incierto`:** el visitante ve "no se envió" aunque
   pudo llegar. Nunca duplica, y es mucho menos probable que con un solo
   canal.
7. **CGNAT:** falsos positivos del rate limit; umbrales configurables.
8. **Ley 25.326:** texto de privacidad (art. 6), registro AAIP (art. 21)
   y transferencia internacional (SES, Gmail, Discord). No bloquea el
   diseño; sí la salida a producción.

### Divergencias respecto de `ux.md` / `spec.md`

- **Ninguna bloqueante.** El RFC implementa los 5 puntos del "Contrato de
  interacción" de `ux.md` y AC-23..AC-29 de la spec enmendada.
- AC-23 pide "el mismo contenido que el mail": el mensaje de Discord
  muestra encabezado, contacto y todas las líneas que entren en 2.000
  caracteres, y **siempre** adjunta el texto completo, idéntico a la
  parte de texto del mail. Una orden larga ocupa **un solo** mensaje, lo
  que simplifica AC-29 ("si ocupó más de un mensaje, se borran todos").
- `falla`/`limite_frecuencia` cae en la falla genérica. Un copy propio
  sería una mejora opcional de UX, no un cambio de contrato.

### Estimate

**Tamaño L: ~24 a 31 horas** de ingeniería backend (antes: 16 a 22), sin
contar el Terraform/CI de `devops-agent` ni el frontend. El aumento sale
de Discord (render + webhook), la idempotencia por canal, el job de
borrado y el `budget-guard` ampliado. Son **24 tareas (B1–B24)** en
`tasks.md`: las 20 anteriores, algunas ampliadas, más B21–B24.

## Frontend

**Autor:** `frontend-agent`. **Revisión 2 (2026-09-30).** **Repo:**
`renovarte-catalogo` (rama `feature/carrito-orden-compra`). **Diseño:**
construido sobre
[`ux.md`](./ux.md), aprobado en la Fase 2, con los defaults del mockup para
las preguntas que quedaron sin respuesta: #C no se agrega desde la grilla,
#D máximo 20 unidades por línea, #E aviso de privacidad de una línea, #G
header sticky y #H número `RA-48271`. Consume el contrato de `## Backend` y
del RFC §3/§5. Este plan no decide layout, copy ni interacción: donde
`ux.md` no alcanza, lo dejo como pregunta al final de la sección.

**Constitución:** sin conflictos.

- §II.4: no se agregan route handlers, middleware, server actions ni
  `"use server"`. `/carrito` es una página SSG más. El carrito es estado
  del navegador y la orden se crea en `renovarte-ordenes` con un `fetch`
  del cliente a una URL pública (`NEXT_PUBLIC_ORDERS_API_URL`), con el
  mismo patrón que `NEXT_PUBLIC_CHAT_WS_URL`. Un test estructural lo
  verifica (AC-14).
- §I.1: al cliente solo llegan campos que `products.json` ya publica
  (`id`, `nombre`, `presentacion`, `precio_venta`, `imagen`), proyectados
  por allowlist explícita y nunca con spread de `Product`. `check:leak`
  sigue escaneando `.next`.
- §III.10: mobile-first a 390px y los requisitos de accesibilidad de
  `ux.md` se testean.
- Nota de referencia en `specs/constitution.md` del catálogo, igual que la
  de la 0016 y como pide B20. No es una enmienda.

### Qué cambió en esta revisión

1. **Spec enmendada (31 AC).** Mail + Discord, borrado a 60 días y
   registro seudonimizado son server-side o manuales: no agregan UI ni
   cambian el contrato (RFC §3 rev. 2, verificado: los tipos son los
   mismos). La tabla AC → test marca cuáles no aplican al frontend.
2. **AC-28** pasa a regir el `sessionStorage` de la confirmación
   (decisión 9 reescrita, módulo nuevo `confirmation-store.ts`). **Q-F5
   cerrada:** aprobado por el CTO/CEO.
3. **AC-24** (reintento / doble clic): se hace explícito el guard
   síncrono contra doble envío y los tests que lo prueban (decisión 6).
4. **Q-F1 cerrada:** `MAX_LINEAS = 100` en el servidor; el cliente no
   pone tope de líneas y no hay UX nueva (decisión 4).
5. **Q-F4 cerrada:** token de < 3 s → `token_vencido`; la espera mínima
   del cliente pasa a **3,5 s** (decisión 7).
6. **Q-F6 cerrada:** `total_vigente` = total local.
7. **Q-F3 cerrada:** `limite_frecuencia`, y también `no_disponible` por
   `flood` (`falla`/`mantenimiento` en el POST), van a la falla genérica.
8. **Q-F2 sigue abierta** y se le pasa a `ux-agent` durante la
   implementación: F7, F9, F12 y F14 quedan marcadas como dependientes.
9. **AC-26:** `check:leak` suma el patrón de URL de webhook de Discord
   (defensa en profundidad del bundle; el catálogo nunca la conoce).

### Resumen de decisiones de implementación (ninguna es de UX)

1. **Estado del carrito:** un store externo propio
   (`src/lib/cart/store.ts`) sobre `localStorage`, consumido con
   `useSyncExternalStore`. El snapshot de servidor es "vacío", el mismo
   patrón sin mismatch de hidratación que `useMounted`, y respeta la regla
   de lint `react-hooks/set-state-in-effect`. Se sincroniza entre
   pestañas con el evento `storage` (ux.md "Persistencia"). No agrega
   dependencias.
2. **Qué se persiste** (clave `renovarte:carrito:v1`): por línea
   `{producto_id, cantidad, precio_visto, nombre, presentacion, imagen}`.
   - `precio_visto` es el contrato de ux.md #5.
   - `nombre`, `presentacion` e `imagen` son un snapshot, porque una
     línea "Ya no está en el catálogo" tiene que seguir mostrando su
     nombre y el catálogo vigente ya no lo tiene.
   - **Nunca** se persisten datos de contacto (AC-18, ux.md "Formulario").
   - Si el JSON guardado está corrupto o tiene otra versión, el carrito
     se trata como vacío sin romper nada (guard de parseo, como
     `isProduct`).
3. **Revalidación contra el catálogo vigente (ux.md "Revalidación", AC-15
   y #10):**
   - `src/app/carrito/page.tsx` (server, SSG) arma en build un **mapa
     reducido** del catálogo (allowlist de 5 campos) y se lo pasa a la
     vista cliente. Es "el `products.json` del build vigente" sin un
     fetch de 512 KB y sin un estado de "falló la carga".
   - Al montar `/carrito` se ejecuta `revalidateCart(lines, catalogo)`,
     que es pura.
     - Si el precio cambió, actualiza `precio_visto` al vigente y guarda
       la nota "antes/ahora" en memoria.
     - Si el id no existe, marca la línea como no disponible.
     - El resultado se escribe en el store.
   - El contador del header excluye las líneas no disponibles **en todas
     las páginas**. Para eso, el root layout le pasa al `CartProvider` la
     lista de ids del catálogo (~4,6 KB sin comprimir). La alternativa de
     marcar la línea solo al abrir `/carrito` dejaba al contador contando
     de más hasta esa visita, y ux.md dice "sin contar líneas de
     productos que ya no están".
4. **Límites:** `MAX_POR_LINEA = 20` (#D, igual que el contrato
   `cantidad` 1..20). Líneas: el contrato acepta **1..100** (Q-F1,
   cerrada). El carrito **no** impone un tope de líneas en el cliente:
   100 productos distintos no se alcanzan en uso real, y un tope
   silencioso sería una decisión de UX. `MAX_LINEAS = 100` vive solo en
   `wire.ts` como constante documental y lo usa un test (un payload de
   100 líneas se arma bien). Si alguna vez se superara, el servidor
   responde `invalida` con `campo: "lineas"`, que cae en el error general
   (Q-F2a); no se necesita UX propia.
5. **Cliente de órdenes (`src/lib/orders/client.ts`)**, puro y con puertos
   inyectados:
   - Recibe `fetch`, `now()`, `schedule` y `cancel`. Los defaults son
     **wrappers flecha**, `(fn, ms) => globalThis.setTimeout(fn, ms)`,
     nunca la referencia suelta a `setTimeout` guardada como campo o
     método. Así no se repite el bug "Illegal invocation" de
     `src/lib/chat/transport.ts`, que no se toca en esta spec. Un test
     llama a los defaults sin `this` como regresión.
   - Timeout de 15 s con `AbortController`.
   - Normaliza cualquier respuesta a un `OrderOutcome` discriminado. Un
     body que no parsea, un `resultado` desconocido, un 5xx sin body, un
     error de red, un timeout o una URL no configurada dan `falla`. Nunca
     dan éxito (AC-20).
6. **Máquina de envío (`src/lib/orders/checkout.ts`)**, un reducer puro:
   - Estados: `editando` → `enviando` → `confirmada` | `fallida` | `tope`
     | `rechazada_por_catalogo` | `invalida`.
   - **`idempotency_key`:** se guarda junto con la huella canónica del
     payload (líneas, cantidades, `precio_visto`, total y contacto
     normalizado). "Enviar" o "Reintentar" con la misma huella **reusa**
     la key. Con cualquier cambio, incluida la aplicación de precios
     después de un `rechazada_por_catalogo`, se genera una **nueva** con
     `crypto.randomUUID()` (inyectado). Vive solo en memoria (RFC §5.1).
   - **AC-24 (doble clic / reintento):**
     - Guard síncrono: el envío en curso se marca en un `ref` antes del
       primer `await`, además del estado `enviando`. Dos clicks en el
       mismo tick producen **un** solo POST (el `aria-disabled` de ux.md
       no alcanza por sí solo, porque no bloquea eventos).
     - "Reintentar envío" y el reintento por `token_vencido` mandan la
       misma key, y el servidor responde `200 aceptada` con el mismo
       `numero_orden` si la primera sí había entrado.
     - `falla`/`en_proceso` (misma key en vuelo en el servidor) cae en la
       falla genérica; el "Reintentar" posterior reusa la key.
     - Límite conocido, sin decisión pendiente: si el visitante recarga
       **durante** "Enviando…", la key en memoria se pierde (RFC §5.1). Al
       volver tiene que retipear nombre y dirección (AC-28 no los guarda),
       así que el reenvío es un envío nuevo con key nueva. La ventana es
       de pocos segundos y ux.md ya pide "No cierres esta página". Queda
       documentado como riesgo, no se agrega persistencia.
7. **`form_token` (RFC §3.1, §6.2):**
   - Al montar `/carrito` con líneas disponibles, se hace `GET
     /v1/estado`:
     - `tope_alcanzado` → variante "tope avisado al entrar" (#F, sin
       formulario);
     - `disponible` → se guarda `{token, emitidoEn}`;
     - `no_disponible` (corte manual o por `flood`) o error de red → no
       cambia nada visible (no bloquea, RFC §3.1).
   - Al enviar:
     - si no hay token o tiene más de 1 h 50 min, se pide uno nuevo. Si
       ese GET devuelve `tope_alcanzado`, va al banner de tope. Si
       devuelve `no_disponible` o falla, va a la falla genérica;
     - si el token tiene **menos de 3,5 s** (`TOKEN_ESPERA_MIN_MS =
       3500`, recomendación de `## Backend` para Q-F4), el cliente espera
       lo que falta (el visitante sigue viendo "Enviando orden…");
     - `invalida` + `form_token`/`token_vencido` (vencido **o**
       prematuro, RFC §6.2) → token nuevo, espera mínima de 3,5 s y **un**
       reintento silencioso con la misma key. Si vuelve a fallar, es
       falla genérica reintentable.
8. **Honeypot `sitio_web`:** un input fuera de pantalla dentro de un
   wrapper `aria-hidden`, con `tabIndex={-1}` y `autocomplete="off"`. Su
   valor se manda tal cual; si un bot lo completa, el servidor rechaza.
9. **Confirmación que sobrevive a la recarga (AC-28, ux.md
   "Confirmación"; Q-F5 aprobada):**
   - Módulo puro `src/lib/orders/confirmation-store.ts` sobre un
     `Storage` inyectable (en producción, `sessionStorage`), clave
     `renovarte:orden-confirmada:v1`.
   - Se escribe **solo** después de `aceptada`, nunca mientras se edita
     el formulario. Proyección por allowlist, nunca spread:
     `{ numero_orden, lineas: [{nombre, presentacion, cantidad,
     precio}], total, email?, telefono? }`. **Nunca** nombre, dirección
     ni localidad.
   - Se borra cuando la ruta deja de ser `/carrito`:
     - navegación dentro del sitio: el `CartProvider` lo hace al cambiar
       `usePathname()`;
     - carga completa de otra página del sitio (link externo que vuelve,
       URL tipeada, "atrás" desde otro origen a una página que no sea
       `/carrito`): el `CartProvider` la borra al montar en cualquier
       ruta que no sea `/carrito`;
     - cerrar la pestaña: lo hace el navegador (`sessionStorage`).
   - Así la recarga sobre `/carrito` sigue mostrando el número, "navegar
     a otra página y volver" muestra el carrito vacío, y el doble montaje
     de StrictMode no la borra.
   - Límite conocido: si desde la confirmación el visitante va a otro
     origen (p.ej. `ig.me` en la misma pestaña) y cierra el navegador sin
     volver, el dato vive hasta que se cierre la pestaña, en storage
     aislado por origen. `ContactChannels` abre Instagram con
     `target="_blank"` (ux.md), lo que minimiza el caso.
   - El carrito persistido (`localStorage`) nunca tiene contacto (AC-5,
     AC-18): lo garantiza `serialize` de F4, que escribe solo claves de
     `CartLine`.
10. **Chat, "agregado" por card:** `ChatPanel` devuelve `null` cuando está
    cerrado, así que el estado local de la card se perdería. Por eso
    "agregado" se guarda en el **reducer del chat** (acción nueva
    `COMBO_ADDED`, keyed por `message.id` + índice del combo). Así
    sobrevive a cerrar el panel, reabrirlo y navegar a `/carrito`, como
    pide ux.md, Contrato #3.
11. **"Ver carrito" desde el chat:**
    - `closeChat` recibe una opción `{ restoreFocus: false }`, compatible
      hacia atrás.
    - El `CartProvider` recibe un flag en memoria,
      `requestHeadingFocus()`, que `/carrito` consume al montar para
      enfocar su `h1` (`tabIndex={-1}`).
12. **Anuncios:**
    - Una sola live region `role="status"` `sr-only` del sitio, que
      renderiza el `CartProvider` fuera de `<main>`.
    - Una segunda live region **dentro del diálogo** del chat, hermana del
      hilo y fuera del `role="log"` (ux.md "Accesibilidad").
13. **Testing sin dependencias nuevas:** el repo no tiene Testing Library
    y no se instala nada.
    - Toda la lógica vive en módulos puros testeados con Vitest.
    - Los componentes se testean con `renderToStaticMarkup` (atributos,
      copy, a11y estática), con el mismo patrón que
      `chat-combo-card.test.tsx`.
    - Las interacciones (foco, clicks, persistencia, red) se prueban con
      Playwright.
    - El servicio de órdenes se mockea con `page.route()` contra una URL
      placeholder (`https://ordenes.test`) que `playwright.config.ts`
      inyecta en `webServer.env`, igual que `NEXT_PUBLIC_CHAT_WS_URL`.
      Las respuestas llevan headers CORS. Hay que verificar
      empíricamente, contra el `@playwright/test` instalado, el manejo
      del preflight de un `POST application/json`, como se hizo con
      `routeWebSocket` en la 0016.
    - Para el timeout de 15 s se usa `page.clock`.

### Archivos nuevos

| Archivo | Responsabilidad |
|---|---|
| `src/lib/contact.ts` | Constantes `RENOVARTE_EMAIL`, `INSTAGRAM_USER`, `INSTAGRAM_DM_URL` (`https://ig.me/m/renovarte_by_juli`) y un helper `mailtoConsulta(numero)`. Única fuente para confirmación, banners y `noscript` |
| `src/lib/orders/wire.ts` | Copia literal de `src/wire.ts` de `renovarte-ordenes` (B3, RFC §3 rev. 2: `lineas` 1..100), con comentario `v: 1` y la fuente, más guards de runtime `isEstadoResponse` / `isCrearOrdenResponse` (mismo estilo que `src/lib/chat/types.ts`) |
| `src/lib/orders/client.ts` | `fetchEstado()` y `crearOrden()` con puertos inyectados; timeout de 15 s; normalización a `OrderOutcome` (decisión 5) |
| `src/lib/orders/checkout.ts` | Reducer puro del envío, huella del payload, guard de doble envío y reglas de `idempotency_key` y `form_token` con espera mínima de 3,5 s (decisiones 6 y 7) |
| `src/lib/orders/confirmation-store.ts` | Guardar / leer / borrar la confirmación en un `Storage` inyectable, con proyección por allowlist (AC-28, decisión 9) |
| `src/lib/orders/validate-contact.ts` | Validación pura de AC-9 con las reglas y el copy **textual** de ux.md "Validación". Normaliza con trim. Devuelve errores por campo en el orden del formulario |
| `src/lib/orders/order-text.ts` | Texto plano de "Copiar detalle del pedido" (formato de ux.md) |
| `src/lib/cart/model.ts` | Tipos `CartLine`/`CartState` y operaciones puras: `addProduct`, `addCombo`, `setCantidad`, `removeLine`/`restoreLine` (deshacer en la misma posición), `clear`, `unidadesDisponibles`, `total`, `parseStored` y `serialize`. Constante `MAX_POR_LINEA` (sin tope de líneas en el cliente, decisión 4) |
| `src/lib/cart/revalidate.ts` | `revalidateCart(lines, catalogo)` y `applyRechazoCatalogo(lines, respuesta)`, puras (AC-15) |
| `src/lib/cart/store.ts` | Store externo: `subscribe`/`getSnapshot`/`getServerSnapshot` sobre un `Storage` inyectable, evento `storage` y claves versionadas |
| `src/lib/cart/catalog-slim.ts` | `toCartCatalogEntry(product)`: proyección por allowlist de 5 campos; la usa `/carrito/page.tsx` |
| `src/components/cart/CartProvider.tsx` | Client. Contexto `useCart()` (líneas, acciones, `announce`, `requestHeadingFocus`), live region del sitio, borrado de la confirmación al montar o navegar fuera de `/carrito` (AC-28) e ids del catálogo para el contador |
| `src/components/cart/CartHeaderLink.tsx` | Client. `<a href="/carrito">` (Link) con ícono de bolsa; label "Carrito" desde `sm`; contador en posición absoluta y `aria-hidden` (99+, oculto en 0, escala de 320 ms salvo con `prefers-reduced-motion`); `aria-label` dinámico; `aria-current` en `/carrito` |
| `src/components/cart/AddToCartButton.tsx` | Client. Botón de la ficha, inerte antes de hidratar (`useMounted`), línea de estado "✓ En tu carrito: N · Ver carrito", anuncio, foco que queda en el botón y `<noscript>` |
| `src/components/cart/CartView.tsx` | Client. Orquesta `/carrito`: revalidación al montar, estados (vacío, solo no disponibles, con productos, tope al entrar, confirmada) y layout de 1 y 2 columnas de ux.md |
| `src/components/cart/CartLineItem.tsx` | Línea con miniatura, link a la ficha, presentación opcional, precio c/u, `QuantityStepper`, "Quitar" y subtotal; nota "El precio cambió…"; variante atenuada "Ya no está en el catálogo" |
| `src/components/cart/QuantityStepper.tsx` | `role="group"`, botones de 44×40, `<output>` y traspaso de foco al otro botón cuando uno se deshabilita |
| `src/components/cart/CartUndoRow.tsx` / `CartClearControl.tsx` | Fila "Quitaste… Deshacer" y confirmación de vaciar en el lugar (foco en "Cancelar") |
| `src/components/cart/CartEmpty.tsx` | Bloque punteado, "Ver catálogo" y "Pedile un combo a Colibrí" (`openChat`) |
| `src/components/cart/CartNotice.tsx` | Aviso neutro `sage-50` `role="status"`: revalidación, precios actualizados al enviar y tope al entrar |
| `src/components/cart/CartSummary.tsx` | Total y "No se cobra nada en este paso…" |
| `src/components/orders/OrderForm.tsx` | "Tus datos": campos, `fieldset` de contacto, hints y errores con `aria-describedby`, `novalidate`, honeypot, aviso de privacidad, "Enviar orden" y estado "Enviando…" con `readonly` |
| `src/components/orders/FormErrorSummary.tsx` | Resumen de errores enfocable; cada ítem es un botón que enfoca su campo |
| `src/components/orders/OrderSendBanner.tsx` | `role="alert"`, variantes falla (con "Reintentar envío") y tope (sin "Reintentar"), canales y "Copiar detalle del pedido" |
| `src/components/orders/ContactChannels.tsx` | Email con `mailto:` más "Copiar", e Instagram MD con `target="_blank" rel="noopener"` |
| `src/components/orders/CopyButton.tsx` | Portapapeles con label temporal ("Copiado" por 1,6 s, timer inyectable). Si falla: selecciona el texto o usa un `textarea` readonly |
| `src/components/orders/OrderConfirmation.tsx` | Número, "Qué sigue", canales, "Lo que pediste" y "Volver al catálogo"; foco en el `h1` |
| `src/components/chat/ChatComboAddToCart.tsx` | Client. Botón "Agregar combo al carrito" / "Agregar otra vez" (mismo nodo), confirmación "✓ Agregaste…" y link "Ver carrito" |
| `src/components/chat/ChatAnnouncer.tsx` | Live region `role="status"` dentro del diálogo, fuera del `role="log"` |
| `src/app/carrito/page.tsx` | Server/SSG. `metadata` con title "Tu carrito" (el template agrega "— RenovArte") y `robots: { index: false }` (verificado en `node_modules/next/dist/docs/.../generate-metadata.md`). Mapa reducido del catálogo, `<noscript>` de ux.md y padding inferior ≥ 104px |

### Archivos existentes que se tocan

| Archivo | Cambio |
|---|---|
| `src/app/layout.tsx` | `CartProvider` envuelve a `ChatProvider` (la card de combo, que vive dentro del panel del chat, necesita `useCart`) y recibe los ids del catálogo. Header `sticky top-0 z-30`, `justify-between` y `CartHeaderLink` a la derecha. No se agrega nada dentro de `<main>` |
| `src/app/producto/[id]/page.tsx` | `AddToCartButton` entre `ProductPrice` y la descripción, con un producto proyectado por allowlist. **Sin `ul > li`** |
| `src/components/chat/ChatComboCard.tsx` | Bloque nuevo al pie con `ChatComboAddToCart`. `aria-describedby` al `h3`, que pasa a tener `id`, y sufijo `sr-only` "(N productos)". Lo existente no cambia |
| `src/components/chat/ChatComboList.tsx` / `ChatThread.tsx` | Pasan `messageId` e índice a la card, para la clave de "agregado" |
| `src/lib/chat/reducer.ts` | Estado `combosAgregados: Record<string, { veces: number; mensaje: … }>` y acción `COMBO_ADDED`. El resto del estado no cambia |
| `src/components/chat/ChatProvider.tsx` | `closeChat(options?: { restoreFocus?: boolean })` (default `true`, sin cambio de comportamiento). Expone `markComboAdded` |
| `src/components/chat/ChatPanel.tsx` | Monta `ChatAnnouncer` como hermano del hilo |
| `playwright.config.ts` | `webServer.env.NEXT_PUBLIC_ORDERS_API_URL = "https://ordenes.test"` (placeholder público) |
| `.env.local.example`, `README.md` | `NEXT_PUBLIC_ORDERS_API_URL`: solo en producción. Sin ella, enviar da la falla genérica y nunca una confirmación. Desarrollo local contra el harness `dev/local-server.ts` de B18 |
| `specs/constitution.md` (catálogo) | Nota de referencia de la 0017 bajo §II.4, igual que la de la 0016 (no es una enmienda) |
| `scripts/check-leak.mjs` | Suma a `FORBIDDEN` el patrón `/discord(?:app)?\.com\/api\/webhooks/i` (AC-26). El catálogo nunca conoce la URL; es defensa en profundidad del bundle, igual que el resto del script. Mensaje de error ajustado para nombrar los dos invariantes |

### Consumo del contrato: `resultado` → estado de UX

| Respuesta (RFC §3) | Estado en `/carrito` (ux.md) | Foco / anuncio | Carrito y formulario |
|---|---|---|---|
| `GET estado` → `disponible` | Normal; se guarda `form_token` | — | — |
| `GET estado` → `tope_alcanzado` (al montar) | Variante "Por ahora no podemos recibir órdenes desde el sitio", `role="status"`, **sin formulario** | — | Carrito intacto y editable |
| `GET estado` → `no_disponible` (manual o `flood`) o error (al montar) | Sin cambio visible | — | — |
| `GET estado` → `no_disponible` o error (al renovar el token antes de enviar) | Banner "Tu orden no se envió" (falla genérica) | Banner | Intactos |
| `POST` → `aceptada` (201 primera vez / 200 reintento idempotente; "al menos un canal confirmó", invisible para el visitante) | Confirmación con `numero_orden` | `h1` | Carrito vaciado; confirmación en `sessionStorage` (allowlist de AC-28) |
| `POST` → `rechazada_por_catalogo` | Precios actualizados y líneas no disponibles; aviso "Los precios se actualizaron mientras completabas tus datos…" | Aviso | Líneas actualizadas (el total se recalcula localmente; `total_vigente` coincide por contrato, Q-F6 cerrada; si difiere, gana el local y el servidor revalida); formulario intacto; la próxima key es nueva |
| `POST` → `invalida` con `campo` de `contacto.*` / `contacto` | Errores por campo + resumen, con el copy de ux.md por campo | Resumen | Intactos |
| `POST` → `invalida` `form_token` / `token_vencido` (vencido o < 3 s) | **No visible**: token nuevo, espera de 3,5 s y 1 reintento con la misma key | — | — |
| `POST` → `invalida` sin campo mapeable (`lineas`, `total_visto`, `null`, `errores: []`, u otro problema de token) | Error general arriba del formulario (copy: Q-F2) | Error general | Intactos |
| `POST` → `tope_alcanzado` | Banner de tope, sin "Reintentar", con canales y "Copiar detalle" | Banner | Intactos |
| `POST` → `falla` (cualquier `codigo`: `limite_frecuencia`, `mantenimiento` por `flood`/corte manual, `en_proceso`, etc.), 5xx sin body, JSON inválido, `resultado` desconocido, red, timeout de 15 s, URL no configurada | Banner "Tu orden no se envió" con "Reintentar envío" (misma key si no hubo cambios), canales y "Copiar detalle" | Banner | Intactos |

Invariante que verifican los tests: solo `resultado === "aceptada"`, con un
`numero_orden` string no vacío, lleva a la confirmación. **El payload
nunca** lleva `nombre`/`presentacion` de producto ni ninguna clave fuera de
`CrearOrdenRequest`. Se arma con un builder tipado, no con spread.

### Cómo se verifica cada AC de frontend

| AC | Vitest (unit / markup) | Playwright (`tests/e2e/cart.spec.ts`, más casos en `chat.spec.ts`) |
|---|---|---|
| AC-1 | `add-to-cart-button.test.tsx`: botón y `noscript` en el HTML; inerte antes de hidratar | Ficha → Agregar → `/carrito` muestra nombre, presentación y el mismo precio que la ficha |
| AC-2 | `cart-header-link.test.tsx`: `aria-label` vacío / N; contador `aria-hidden`; "99+"; `cart-model.test.ts`: unidades excluyendo no disponibles | Header con el link en home, categoría, grupo, ofertas, ficha y carrito; contador visible después de scrollear (sticky) |
| AC-3 | `cart-model.test.ts`: `setCantidad`, límites 1..20, subtotal y total, quitar/restaurar posición, vaciar | Stepper +/−, Quitar → Deshacer, Vaciar → Cancelar / Sí; totales en pantalla; foco en cada caso |
| AC-4 | `cart-model.test.ts`: agregar dos veces suma cantidad, sin duplicar la línea | Dos toques en Agregar → una línea × 2 |
| AC-5 | `cart-store.test.ts`: persistencia con `Storage` fake, evento `storage`, JSON corrupto → vacío | Recargar, navegar ficha → grilla → carrito y abrir/cerrar el chat conservan el carrito; segunda pestaña actualiza el contador |
| AC-6 | `cart-model.test.ts` (`addCombo` suma 1 de cada uno); `chat-combo-card.test.tsx` (botón, `aria-describedby`, sufijo sr-only); `chat-reducer.test.ts` (`COMBO_ADDED`) | Combo por `routeWebSocket` → "Agregar combo" → líneas con el mismo nombre y precio que la card; "Agregar otra vez" suma |
| AC-7 | `chat-reducer.test.ts`: `COMBO_ADDED` no toca `isOpen` ni `messages` | Después de agregar, el panel sigue abierto con el hilo; "Ver carrito" → `/carrito` con foco en el `h1`; reabrir el FAB muestra el hilo y "Agregar otra vez" |
| AC-8 | `cart-view` markup: vacío sin `<form>` ni "Enviar orden"; solo no disponibles, sin formulario | `/carrito` vacío no ofrece envío |
| AC-9 | `validate-contact.test.ts`: tabla por regla y copy textual; `order-form.test.tsx`: labels, `autocomplete`, `aria-describedby`, `novalidate`, `fieldset`/`legend` | Enviar vacío → resumen enfocado y **ningún** POST; corregir un campo al perder el foco borra su error |
| AC-10 | `order-confirmation.test.tsx`: número, "Qué sigue" con solo los medios dados, `mailto` con asunto, link a `ig.me` y resumen | POST mock 201 → confirmación con `RA-48271`, carrito vacío y contador oculto; ir a `/` y volver → vacío |
| AC-11 | El cliente no pide copia: no hay UI ni campo para eso. La entrega es server-side | Cubierto por el body capturado de AC-17 |
| AC-12 | `order-form.test.tsx`: no hay campos de pago, envío, cupón ni comentario | Recorrido completo sin medios de pago ni envío |
| AC-13 | Parte cliente: `orders-client.test.ts`, `precio_visto`/`total_visto` = lo que muestra la pantalla; `numero_orden` se muestra tal cual llega. El contenido del mail es server-side (`## Backend`) | En F20: una orden real, el número de pantalla coincide con el del mail |
| AC-14 | `no-runtime-backend.test.ts` (nuevo): ningún `route.ts`/`route.js`, `middleware.*`, `proxy.*` ni `"use server"` bajo `src/` | `pnpm build`: `/carrito` listada como estática |
| AC-15 | `cart-revalidate.test.ts`: precio cambiado, id inexistente y `applyRechazoCatalogo`; `checkout.test.ts`: key nueva después del rechazo | `localStorage` sembrado con un precio viejo o un id inexistente → aviso y notas; POST mock 409 → aviso enfocado y reenvío con una key distinta |
| AC-16 | `catalog-slim.test.ts`: solo 5 claves; `check:leak` existente sobre `.next` | — |
| AC-17 | `orders-client.test.ts`: el builder emite exactamente las claves de `CrearOrdenRequest` (sin `to`/`cc`/`bcc`/`reply_to`/`webhook`/`canal`); no hay UI para elegir destino. El rechazo de claves extra es server-side | Body capturado: solo claves del contrato |
| AC-18 | `cart-store.test.ts`: lo guardado nunca contiene claves de contacto; `checkout.test.ts`: contacto solo en memoria | Después de un envío, `localStorage` sin datos de contacto (ver AC-28 para `sessionStorage`) |
| AC-19 | Parte cliente: `order-form.test.tsx`, honeypot `sitio_web` fuera de pantalla, `aria-hidden`, `tabIndex={-1}`; `checkout.test.ts`, el POST siempre lleva el `form_token` del GET. Rate limit, cupo y verificación del token son server-side | — |
| AC-20 | `orders-client.test.ts`: 500, 502 sin body, JSON inválido, `resultado` desconocido, `falla`/`mantenimiento`, `falla`/`en_proceso`, red, timeout de 15 s (timer fake) → `falla`, nunca `aceptada`; `checkout.test.ts`: "Reintentar" reusa la key | POST abortado / 500 → banner, carrito y datos intactos; "Reintentar" manda la **misma** `idempotency_key` (bodies capturados); `page.clock` para el timeout |
| AC-21 | — | Con el servicio de órdenes abortado, la grilla, el filtro, la búsqueda, la ficha y el chat funcionan (se reusan pasos de `catalog.spec.ts`/`chat.spec.ts`); `catalog.spec.ts` sigue verde con el header sticky |
| AC-22 | `orders-client.test.ts` (`tope_alcanzado` en GET y POST); `order-send-banner.test.tsx` (sin "Reintentar", con canales) | Tope al entrar (sin formulario) y tope al enviar (banner); GET `no_disponible` al entrar → formulario visible (no es tope) |
| AC-23 | **No aplica al frontend** (entrega a Discord server-side; el visitante no ve canales). El cliente no cambia | — |
| AC-24 | `checkout.test.ts`: dos `SUBMIT` seguidos → un solo efecto de envío; "Reintentar" y el reintento por `token_vencido` → misma key; cambio de contacto/cantidad → key nueva | Doble clic en "Enviar orden" (`dblclick` y dos `click` sin esperar) → **un** POST capturado; POST abortado → "Reintentar" → el mock responde `200 aceptada` con el mismo `RA-48271` y la key capturada es idéntica en los dos bodies. No-duplicación en mail/Discord: server-side |
| AC-25 | **No aplica al frontend** más allá de AC-10/AC-20: `aceptada` con un solo canal se ve igual que con dos | — |
| AC-26 | `check:leak` con el patrón de webhook de Discord sobre `.next` y `public/data` (F18); `src/` no referencia Discord | — |
| AC-27, AC-29, AC-30, AC-31 | **No aplican al frontend** (registro seudonimizado y borrados server-side; acceso al canal y retención de Gmail, manuales) | — |
| AC-28 | `confirmation-store.test.ts`: lo guardado tiene solo `numero_orden`, líneas, total, `email?`, `telefono?` (nunca nombre/dirección/localidad, aunque se le pase el contacto completo); borrar/leer con `Storage` fake; JSON corrupto → nada | Después de 201: `sessionStorage` sin nombre/dirección/localidad; recarga en `/carrito` → mismo número; navegar a `/` → la clave ya no está en `sessionStorage`; `page.goto('/')` (carga completa) → tampoco; página nueva del mismo contexto → sin confirmación; `localStorage` nunca con contacto |
| Sin JS / reduced-motion | Markup de `noscript` en la ficha y en `/carrito` | Contexto con `javaScriptEnabled: false`: el link del header navega y se ven los avisos `noscript`; `reducedMotion: "reduce"` |

`form_token`: `checkout.test.ts` cubre que un token de < 3,5 s espera lo
que falta, que uno de > 1 h 50 min se renueva y que `token_vencido`
produce exactamente un reintento con la misma key (y un segundo
`token_vencido` termina en falla genérica).

### Dependencias con otras secciones

- **B3 (`wire.ts`)** → F2. Mientras no exista, F2 copia los tipos del RFC
  §3 (revisión 2) textualmente y se re-sincroniza cuando B3 cierre (un
  diff vacío es el check).
- **`ux-agent` (Q-F2)** → F7, F9, F12 y F14. El orquestador le pasa las
  cuatro preguntas durante la implementación; cada una de esas tareas no
  arranca su parte visible hasta tener la respuesta aprobada por un
  humano.
- **B18 (harness local)** → F20 (smoke manual contra el contrato real).
- **B20 + `## Infra`** → F20. La URL de producción de
  `NEXT_PUBLIC_ORDERS_API_URL` se carga en Vercel **solo en Production**,
  y `ALLOWED_ORIGINS` tiene que ser el dominio de producción del
  catálogo. Configurar la env var en Vercel es un paso de `devops-agent`
  o del humano, no mío.
- Ninguna otra dependencia: F1–F19 corren con mocks y dejan `pnpm gate`
  verde sin el servicio desplegado. Discord, retención y registro no
  tocan el catálogo.

### Divergencias y preguntas abiertas

Sin divergencias con `## Backend` / RFC rev. 2 ni con la spec enmendada.

**Cerradas en esta revisión:**

- **Q-F1** → `MAX_LINEAS = 100` en el servidor; sin tope ni UX en el
  cliente (decisión 4).
- **Q-F3** → `limite_frecuencia` y `no_disponible`/`mantenimiento` por
  `flood` van a la falla genérica.
- **Q-F4** → token de < 3 s = `token_vencido`; espera mínima del cliente
  de 3,5 s (decisión 7).
- **Q-F5** → aprobado: email/teléfono en `sessionStorage` de la pestaña
  mientras esté en `/carrito` (AC-28, decisión 9).
- **Q-F6** → `total_vigente` se calcula igual que el total local.

**Abierta (va a `ux-agent` durante la implementación, no bloquea el
diseño):**

- **Q-F2 — Copy/comportamiento que `ux.md` no fija:**
  - (a) texto del "error general arriba del formulario" para `invalida`
    sin campo mapeable (cubre también honeypot y `lineas` > 100) →
    bloquea la parte visible de **F12**;
  - (b) bajada de la variante "tope avisado al entrar": ¿reusa el
    cuerpo, los canales y "Copiar detalle" del banner de tope? →
    **F14**;
  - (c) "Agregar al carrito" en la ficha y "Agregar combo" cuando una
    línea ya está en 20: ¿se topea en silencio y se muestra la nota de
    #D?, ¿dónde? → **F7** (y el caso de combo en **F17**, que usa la
    misma regla del modelo);
  - (d) ubicación y copy de la nota de #D (¿debajo del stepper cuando
    `+` está deshabilitado?) → **F9**.

  Mientras tanto, la lógica pura (F3: `addProduct`/`addCombo` topean en
  20 y devuelven un flag `topeado`) se construye sin decidir cómo se
  muestra.

**Riesgos conocidos (sin decisión pendiente):**

- Recarga durante "Enviando…" pierde la key en memoria (decisión 6).
- Confirmación en `sessionStorage` si el visitante sale a otro origen en
  la misma pestaña y no vuelve (decisión 9).
- El header sticky puede interceptar clicks en los e2e existentes.
  Playwright reintenta scrolleando; si algún test se vuelve flaky, se
  ajusta el test, nunca el diseño.

### Estimate

**Tamaño L: ~28 a 36 h** de frontend (antes ~26–34 h). Son **20 tareas
(F1–F20)**, con F20 dependiente del deploy real. El aumento viene de
AC-24 (guard de doble envío y sus e2e), AC-28 (`confirmation-store` y sus
e2e) y AC-26 (`check:leak`); Q-F1 cerrada ahorra un poco.

| Bloque | Tareas | Horas |
|---|---|---|
| Base pura (contacto, wire, modelo, store, revalidación) | F1–F5 | ~6–8 h |
| Header, ficha y shell de `/carrito` | F6–F9 | ~6–8 h |
| Cliente de órdenes, formulario, envío y confirmación | F10–F15 | ~10,5–12,5 h |
| Chat | F16–F17 | ~3–4 h |
| Cierre (AC-14/18/21/26, docs, gate, smoke real) | F18–F20 | ~2,5–3,5 h |

Lo que puede mover el estimate:

- el manejo del preflight CORS de `page.route` en la versión instalada
  de Playwright;
- que el header sticky obligue a ajustar e2e existentes;
- las respuestas de `ux-agent` a Q-F2.

## Infra

**Autor:** `devops-agent`. **Revisión 2 (2026-09-30).** **Repo:**
`renovarte-ordenes`, **público** (decisión del CTO/CEO). Todos los nombres
físicos salen de `var.project_name`. Parte de `## Backend` (revisión 2,
"Qué le paso a `devops-agent`") y del RFC revisión 2 (§5.5, §6.1, §7, §8,
§10.3, §10.4 y §13). **Misma cuenta AWS y misma región** que la 0016
(`us-east-1`).

**Constitución:** sin conflictos. Todos los recursos son pay-per-request o
de free tier y ninguno cobra en reposo (§II.5, dentro de la excepción
RNF-14). Discord no suma costo. No hay estado remoto de Terraform (estado
local y por repo, como en la 0016). Nada de esto se aprovisiona en modo
diseño (§III.11).

### Qué cambió en esta revisión

1. **Tercer Lambda `discord-retention`** (AC-29) con su log group, rol,
   schedule diario y alarma (I-D3, I-D13; tarea nueva I19).
2. **Parámetro SSM nuevo con la URL del webhook de Discord** (I-D9).
   Además corrijo un error mío de la revisión 1: con `ignore_changes`,
   Terraform **sí** guarda el valor real en el estado local al refrescar.
   Paso a `value_wo` (atributo write-only, Terraform ≥ 1.11) para los dos
   secretos.
3. **IAM de `orders-http`:** se quita `dynamodb:DeleteItem`; se suma
   `ssm:GetParameter` sobre el parámetro del webhook (I-D5, I-D9).
4. **`budget-guard`:** env vars `FLOOD_ALARM_NAME` y `BUDGET_NAME`
   (I-D3). La alarma de flood queda aprobada por el CTO/CEO (I-D8).
5. **Topic SNS de alertas operativas**, separado del kill-switch, y **4
   alarmas en total** (flood + 3 operativas), dentro de las 10 gratis
   (I-D13; tarea nueva I18). Una alarma de "latido" reemplaza las 2 de
   retención que proponía el backend y cubre además el caso "el job no
   corrió".
6. **Repo público:** se cierra I-D12 y se simplifica I-D11 (minutos
   ilimitados, secret scanning con push protection gratis). Tarea manual
   nueva I20 (configuración del repo en GitHub).
7. **Rotación del webhook y del HMAC sin drift:** variable
   `config_revision` en Terraform en lugar de una env var dummy puesta a
   mano (I-D9, divergencia N2).
8. Pasos manuales del CTO/CEO actualizados con Discord (B24), la
   confirmación del email de alertas y la retención de Gmail (AC-31).

> **Verificado en la web el 2026-09-30** (el resto sigue sujeto a B1):
> - Una Function URL con `AuthType NONE` necesita en la resource policy
>   **tanto** `lambda:InvokeFunctionUrl` **como** `lambda:InvokeFunction`
>   con la condición `lambda:InvokedViaFunctionUrl`. Rige para URLs nuevas
>   desde octubre de 2025 y para todas desde el 01/11/2026. Si falta, la URL
>   responde 403. En Terraform, el argumento `invoked_via_function_url` de
>   `aws_lambda_permission` existe **desde el provider AWS v6.28.0**.
> - Las cuentas nuevas pueden tener una cuota de concurrencia de Lambda
>   de **10**. Con esa cuota, AWS exige que las 10 queden sin reservar, y
>   **no se puede reservar concurrencia en ninguna función**.
> - AWS Budgets: los budgets **sin acciones** notifican gratis. Los
>   *action-enabled* son gratis hasta 2 y después cuestan USD 0,10/día.
> - La atribución del costo de envío de SES a un tag de recurso **no quedó
>   confirmada**. Ver I-D6.
> - **CloudWatch free tier** (página de pricing): **10 alarm metrics**
>   (alarmas standard que listan métricas directamente), **10 custom
>   metrics** y 5 GB de logs. Fuera del free tier: USD 0,10 por alarm
>   metric/mes y USD 0,30 por custom metric/mes.
> - **`aws_ssm_parameter`** (docs del provider): "The unencrypted value of
>   a SecureString will be stored in the raw state as plain-text". El
>   argumento `value_wo` ("write-only values are never stored to state")
>   necesita **Terraform ≥ 1.11** y `value_wo_version`.

### Decisiones de infra

**I-D1 · Superficie HTTP: Lambda Function URL (`AuthType NONE`) + reserved
concurrency.** Sin cambios. El motivo es el tope de costo:

- La URL no tiene cargo propio. Las invocaciones throttleadas (concurrency
  agotada o en 0) **no se facturan**, así que `PutFunctionConcurrency(0)`
  es un kill-switch con gasto cero literal (RFC §8.4).
- Con API Gateway HTTP API, en cambio, cada request cobra aunque el Lambda
  esté apagado. Su throttling por stage no es por IP y no aporta nada que
  no dé la reserved concurrency.
- Lo que perdemos: dominio propio y WAF (≥ USD 5/mes). Ninguno está en el
  alcance; si hacen falta, se pone CloudFront o API Gateway delante sin
  cambiar el contrato.
- Recursos:
  - `aws_lambda_function_url` con `authorization_type = "NONE"`, invoke
    mode `BUFFERED`.
  - **Dos** `aws_lambda_permission`: uno con `lambda:InvokeFunctionUrl`
    (`function_url_auth_type = "NONE"`) y otro con `lambda:InvokeFunction`
    más `invoked_via_function_url = true`, `principal = "*"`. Sin esa
    condición, el segundo permiso habilitaría la API `Invoke` directa para
    cualquier cuenta AWS: no se omite.
- **Provider `hashicorp/aws ~> 6.28`** (mínimo para el permiso de arriba)
  y **Terraform `>= 1.11`** (por `value_wo`, I-D9). No afecta a los otros
  repos: cada uno tiene su estado y su lock file.

**I-D2 · CORS en la Function URL, no en el handler.** Sin cambios
(aceptado por backend, RFC §13 #2).
- `allow_origins = var.allowed_origins` (solo el dominio de producción del
  catálogo, sin previews ni `*`), `allow_methods = ["GET","POST"]`,
  `allow_headers = ["content-type"]`, `allow_credentials = false`,
  `max_age = 3600`.
- El preflight `OPTIONS` lo responde el servicio de Function URL **sin
  invocar el Lambda**: no cuesta ni consume concurrencia.
- El chequeo de `Origin` del handler (RFC §6.2) sigue haciendo falta.

**I-D3 · Lambdas.** Runtime `nodejs22.x` y `arm64` (~20 % más barato por
GB-s; JS puro con solo `@aws-sdk/*`). **Build sin bundler:** `tsc` a
`dist/`, como `renovarte-chat-gateway`. Discord se llama con `fetch`/
`FormData`/`Blob` nativos de Node 22, así que sigue sin haber
dependencias de runtime fuera de `@aws-sdk/*`. **Un solo zip compartido
por los tres Lambdas.**

| Lambda | Timeout | Memoria | Reserved concurrency | Env vars |
|---|---|---|---|---|
| `renovarte-ordenes-orders-http` | 10 s (el cliente corta a los 15 s; los dos canales van en paralelo, 4 s cada uno) | 256 MB | **5** (`var.orders_http_reserved_concurrency`), ver I-D4 | `ORDER_RECIPIENT_EMAIL`, `ORDER_SENDER_EMAIL`, `CATALOG_PRODUCTS_URL`, `ALLOWED_ORIGINS` (CSV), `ORDERS_TABLE`, `HMAC_SECRET_PARAM`, **`DISCORD_WEBHOOK_PARAM`** (nombres de parámetros, no valores), `BUDGET_CAP_USD=20`, `BUDGET_STOP_RATIO=0.9`, umbrales de rate limit y cupos (RFC §6.3), costos unitarios del ledger (RFC §8.2), **`CONFIG_REVISION`** (I-D9) |
| `renovarte-ordenes-budget-guard` | 10 s | 128 MB | sin reservar | `ORDERS_TABLE`, `ORDERS_HTTP_FUNCTION_NAME`, `ORDERS_HTTP_RESERVED_CONCURRENCY` (vacía si no hay reserva), **`FLOOD_ALARM_NAME`**, **`BUDGET_NAME`** |
| **`renovarte-ordenes-discord-retention`** (nuevo) | 60 s | 128 MB | sin reservar | `ORDERS_TABLE`, `DISCORD_WEBHOOK_PARAM`, `BORRADO_MAX_POR_CORRIDA=200`, `CONFIG_REVISION` |

- `FLOOD_ALARM_NAME` y `BUDGET_NAME` salen de `locals` (los mismos que
  usan `aws_cloudwatch_metric_alarm` y `aws_budgets_budget`), no de
  referencias al recurso: así no se arma un ciclo función → alarma →
  topic → suscripción → función, y los nombres no pueden divergir.
- **`discord-retention` queda fuera del kill-switch:** `budget-guard` solo
  tiene permiso sobre el ARN de `orders-http`, y ni el Budget ni la alarma
  de flood lo apagan. Su única superficie es el schedule diario (no tiene
  URL ni trigger público), así que su costo está acotado por diseño a ~30
  invocaciones/mes.
- Con 60 s y los `DELETE` en serie respetando el rate limit de Discord,
  una corrida no llega a los 200 borrados si Discord limita fuerte; el
  handler corta limpio con < 10 s y sigue al día siguiente (RFC §10.3).
  El volumen real esperado es de 1 a 10 por día: sobra.
- **Log groups creados por Terraform** (`retention_in_days = 14`) antes
  que las funciones. Los roles **no** tienen `logs:CreateLogGroup`, solo
  `CreateLogStream`/`PutLogEvents` sobre su propio log group.
- **Formato de log `Text` (default)**, no `JSON` de Lambda. Los metric
  filters de I-D13 usan patrones JSON (`$.evento`), que solo matchean si
  **toda la línea** es JSON. `console.log` en el runtime Node con formato
  Text antepone `timestamp  requestId  INFO`, y con formato JSON el
  objeto queda anidado en `message`. Por eso el logger del backend tiene
  que escribir **una línea JSON cruda** con `process.stdout.write`
  (divergencia N4).

**I-D4 · Reserved concurrency y el drift con Terraform.** Sin cambios de
fondo; la divergencia 3 quedó aceptada (reset con
`DeleteFunctionConcurrency` si no hay reserva).
- `aws_lambda_function.orders_http` lleva
  `lifecycle { ignore_changes = [reserved_concurrent_executions] }`: un
  `apply` con el kill-switch activo no la vuelve a 5 en silencio.
- Para cambiar el valor: variable (que alimenta
  `ORDERS_HTTP_RESERVED_CONCURRENCY`) + `aws lambda
  put-function-concurrency` a mano, según el runbook.
- **Chequeo antes de aplicar (I1):** si la cuota de concurrencia de la
  cuenta es 10, (a) pedir el aumento en Service Quotas (gratis, puede
  tardar días) o (b) aplicar con `orders_http_reserved_concurrency =
  null`: el techo pasa a ser la cuota de 10 compartida con la 0016 más la
  alarma de flood. `discord-retention` y `budget-guard` usan el pool no
  reservado en los dos casos.

**I-D5 · DynamoDB.**
- Una tabla, `renovarte-ordenes-datos`: `PAY_PER_REQUEST`,
  `hash_key = "pk"` (S), `ttl { attribute_name = "expira_en" }` (Number,
  epoch-segundos; aceptado por backend). Sin streams, sin PITR y con la
  cifra por default. `deletion_protection_enabled = true` (protege `NUM#`
  y `BORRAR#CURSOR`, que no tienen TTL).
- **IAM acotado por prefijo de clave** (`dynamodb:LeadingKeys`, con
  `ForAllValues:StringLike`):
  - `orders-http`: `GetItem`, `PutItem` y `UpdateItem` sobre la tabla
    (cubre `IDEM#`, `NUM#`, `RL#`, `CUPO#`, `LEDGER#`, `CONTROL` de solo
    lectura y los `UpdateItem ADD` a `BORRAR#<fecha>`). **Sin
    `DeleteItem`** (revisión 2: `IDEM#` ya no se libera).
  - `budget-guard`: `GetItem`, `PutItem` y `UpdateItem` **solo** sobre
    `LeadingKeys = ["CONTROL"]`.
  - **`discord-retention`:** `GetItem`, `UpdateItem` y `DeleteItem`
    **solo** sobre `LeadingKeys` `BORRAR#*` (incluye `BORRAR#CURSOR`). No
    puede leer `IDEM#` ni ningún otro ítem. El cursor se crea con
    `UpdateItem` (upsert), así que no necesita `PutItem`.

**I-D6 · AWS Budget + SNS kill-switch + reset.**
- `aws_budgets_budget` `renovarte-ordenes-aws-cost-cap`: COST mensual de
  USD 20, `cost_filter TagKeyValue = user:Project$renovarte-ordenes`.
  Notificaciones:
  - 80 % ACTUAL: email a `var.budget_notification_email`.
  - 100 % ACTUAL: SNS `renovarte-ordenes-budget-alerts` **y además email**
    al mismo destinatario (cambio: antes solo iba al SNS, y el CTO/CEO no
    se enteraba de que el servicio se apagó). Budgets admite los dos
    tipos de suscriptor en la misma notificación.
  - **Sin Budget Action:** USD 0, no consume los 2 action-enabled gratis.
- Topic del kill-switch: sin KMS (el mensaje no tiene datos personales y
  con `aws/sns` Budgets no puede publicar); policy que permite
  `SNS:Publish` a `budgets.amazonaws.com` y `cloudwatch.amazonaws.com`
  con `aws:SourceAccount`; suscripción `lambda` a `budget-guard` + su
  `aws_lambda_permission`. **Solo** lo usan el Budget al 100 % y la
  alarma de flood; ninguna alerta operativa va acá (I-D13).
- IAM de `budget-guard`: `lambda:Put/Delete/GetFunctionConcurrency`
  **solo** sobre el ARN de `orders-http`; DynamoDB según I-D5.
- **Schedules** (EventBridge Scheduler, un solo rol de Scheduler con
  `lambda:InvokeFunction` sobre los dos ARN):
  - `renovarte-ordenes-budget-reset`: `cron(0 0 1 * ? *)` UTC, input
    `{"mode":"reset"}` → `budget-guard`.
  - **`renovarte-ordenes-discord-retention`** (nuevo): `cron(0 6 * * ? *)`
    UTC (03:00 de Argentina), input `{}`, flexible window `OFF` →
    `discord-retention`. La invocación es asíncrona: si el handler falla,
    Lambda lo reintenta hasta 2 veces, lo que es seguro porque borrar es
    idempotente (RFC §10.3).
- **Atribución de SES al tag (no confirmada):** filtro **solo por tag**
  (Budgets combina filtros con AND). Hueco acotado a ≤ USD 0,10/mes por el
  cupo de 1.000 mails; el ledger lo cuenta. Se verifica en Cost Explorer
  al primer mes (I16). Lo mismo aplica a las custom metrics de los metric
  filters (no se pueden taggear): USD 0 dentro del free tier, ≤ USD 0,90
  si no (I-D13).
- **Prerrequisito manual:** tag `Project` activo como cost allocation tag
  (I1).

**I-D7 · SES v2, en sandbox, con destinatario fijo en IAM.** Sin cambios.
Opción A decidida por el CTO/CEO, con smoke test (B19) y paso a la opción
B (I17) si cae en spam.
- `aws_sesv2_email_identity` para `var.order_recipient_email`
  (renovartebyjuli@gmail.com): el CTO/CEO hace clic en el mail de
  verificación (vence a las 24 h). Esa identidad es remitente y
  destinatario, que es lo que exige el sandbox.
- Opción B detrás de `var.sender_domain != ""`: identidad de dominio con
  Easy DKIM, MAIL FROM `mail.<dominio>` y DMARC `p=none`, con los DNS en
  el registrador (no Route 53, que cuesta USD 0,50/mes).
- **No se pide acceso de producción.**
- IAM de `orders-http`: `ses:SendEmail` sobre los ARN de las identidades,
  con `ForAllValues:StringEquals ses:Recipients = [destinatario]`,
  `StringEquals ses:FromAddress` y `Null ses:Recipients = false` (evita
  el "vacuous truth"). El valor sale de la misma variable que
  `ORDER_RECIPIENT_EMAIL`.

**I-D8 · Alarma de flood → kill-switch.** **Aprobada por el CTO/CEO** y
aceptada por backend (motivo `flood`, reactivación manual o el día 1).
- `aws_cloudwatch_metric_alarm` `renovarte-ordenes-orders-http-flood`:
  `AWS/Lambda Invocations` de `orders-http`, `Sum`, período 60 s, 1 de 1,
  umbral `var.flood_invocations_per_minute` = 300 (tráfico legítimo:
  ~5.000 requests por **mes**).
- `alarm_actions` = **[topic del kill-switch, topic de alertas
  operativas]** (cambio: así el CTO/CEO recibe un email cuando el flood
  apaga el servicio, sin tener que suscribirse al topic del
  kill-switch). Sin `ok_actions`: `budget-guard` ignora `OK` y la
  reactivación es manual.
- Por qué hace falta: con `CONTROL` apagado, `orders-http` no escribe en
  el ledger; con reserved concurrency 5 un flood puede costar ~USD 5–6/día
  y el Budget llega con 8–24 h de atraso. La alarma corta en ~2–3 min.

**I-D9 · Secretos en SSM `SecureString`: HMAC y webhook de Discord.**
- Mi default es "secretos por env var vía `.tfvars`". Acá uso SSM para los
  dos, porque cuesta USD 0 (parámetros Standard, clave `aws/ssm`, KMS
  dentro de las 20k requests gratis) y el valor **no** queda en la
  configuración visible del Lambda, ni en el estado de Terraform, ni en
  un `.tfvars`. Para la URL del webhook es especialmente importante: con
  ella cualquiera puede publicar en el canal de órdenes (RFC §12.3).
- Parámetros:
  - `/renovarte-ordenes/hmac-secret`;
  - **`/renovarte-ordenes/discord-webhook-url`** (nuevo).
- **Corrección de la revisión 1:** `value` + `ignore_changes = [value]`
  **no** alcanza para mantener el secreto fuera del estado. El provider
  refresca el valor descifrado y lo guarda en texto plano en
  `terraform.tfstate` en el siguiente `plan`/`apply`. En su lugar:
  - `value_wo = "PLACEHOLDER-cargar-con-put-parameter"` y
    `value_wo_version = 1`. Los atributos write-only nunca se guardan en
    el estado. Terraform crea el parámetro y no lo vuelve a tocar mientras
    no cambie `value_wo_version`.
  - El CTO/CEO carga los valores reales con `aws ssm put-parameter
    --overwrite`, leyéndolos con `read -rs` (sin eco, sin historial),
    nunca por chat ni git.
  - **I16 verifica** que la URL real no aparezca en el estado local
    después de un `terraform plan` (`grep -c discord.com
    terraform.tfstate` = 0). Si el provider la leyera igual, el fallback
    es que el parámetro lo cree el CTO/CEO por CLI y Terraform solo arme
    el ARN a partir del nombre.
  - Con el placeholder, `orders-http` falla la validación de host
    (RFC §6.1) y el canal Discord queda `fallido`/`config` → alerta
    `canal_fallido`. Es el comportamiento buscado hasta que se complete
    B24.
- IAM: `ssm:GetParameter` sobre los dos ARN para `orders-http`; **solo**
  sobre el del webhook para `discord-retention`. Sin `kms:Decrypt`
  explícito (clave `aws/ssm`; se valida en el smoke).
- **Rotación sin drift (cambio):** para que los contenedores calientes
  relean SSM, el backend proponía cambiar a mano una env var dummy. Eso
  pisa **todas** las env vars (`update-function-configuration
  --environment` reemplaza el mapa completo) y deja drift con Terraform.
  En su lugar, `var.config_revision` (entero, default `1`) alimenta la
  env var `CONFIG_REVISION` de `orders-http` y `discord-retention`.
  Rotar es: `put-parameter --overwrite` → subir `config_revision` en
  `terraform.tfvars` → `terraform apply` (solo cambia la configuración;
  `ignore_changes` protege concurrency y código). Aplica igual al HMAC
  (divergencia N2).

**I-D10 · Deploy: Terraform manual, código por OIDC con disparo manual.**
Aceptado por backend (RFC §13 #1).
- **Infra:** usuario IAM `renovarte-ordenes-terraform` con policy acotada
  por prefijo, estado local y apply en vivo con el humano (como la 0016).
- **Código:** `deploy.yml` con `workflow_dispatch` y guard `github.ref ==
  'refs/heads/main'`. Corre `pnpm gate` + `pnpm build`, asume por OIDC el
  rol `renovarte-ordenes-github-deploy-role` y hace
  `update-function-code` + `wait function-updated` sobre **los 3
  Lambdas**.
- Trust: `aud = sts.amazonaws.com`, `sub =
  repo:gucastillo-personal/renovarte-ordenes:ref:refs/heads/main`.
- Permisos: `lambda:UpdateFunctionCode`, `GetFunction` y
  `GetFunctionConfiguration` sobre los **3 ARN**. No puede tocar IAM, env
  vars, concurrency ni SSM.
- Los tres Lambdas llevan `ignore_changes = [filename,
  source_code_hash]`.
- El OIDC provider de GitHub es un singleton de la cuenta: lo crea el
  CTO/CEO en el bootstrap (o se reusa) y llega como
  `var.github_oidc_provider_arn`.
- **Opcional, gratis en repo público:** un environment `produccion` con
  "deployment branches: main" y el `sub` fijado a
  `environment:produccion`. Con un solo mantenedor aporta poco sobre el
  guard de `ref`; no lo incluyo por default.

**I-D11 · CI.** Con el repo público, los minutos de Actions son
ilimitados y el consumo deja de ser un tema.
- **`ci.yml`:** `on: pull_request` (**nunca** `pull_request_target`: en
  un repo público, eso daría permisos de escritura a PRs de forks),
  `permissions: { contents: read }`, `concurrency` con
  `cancel-in-progress` y `timeout-minutes: 10`.
  - Job `gate`: `pnpm gate` (lint + typecheck + test + `check:leak`) +
    `pnpm build`.
  - Job `terraform`: `fmt -check`, `init -backend=false`, `validate`, solo
    si el PR toca `terraform/**`.
  - `ci.yml` no usa secretos ni OIDC, así que un PR de un fork no puede
    obtener nada.
- **`check:leak` (B17):** además de lo del backend (costo/margen, URL de
  webhook de Discord), patrones de credenciales (`AKIA[0-9A-Z]{16}`,
  `-----BEGIN .*PRIVATE KEY-----`, `aws_secret_access_key`), IDs de
  cuenta AWS de 12 dígitos en `README.md`/`docs/`, y cualquier
  `*.tfvars`/`*.tfstate*` trackeado. Sin dependencias nuevas.
  `gitleaks` deja de hacer falta: el secret scanning con push protection
  de GitHub es gratis en repo público (I20).

**I-D12 · Repo público (decidido por el CTO/CEO).** En GitHub Free, un
repo público tiene gratis rulesets de `main`, secret scanning con push
protection y minutos ilimitados. Hay que activarlos a mano (I20).
Condiciones:
- el README y `docs/` no publican el ID de cuenta, ARNs reales, la URL
  del webhook ni el ID del canal, del servidor o del webhook de Discord.
  Los valores reales quedan en `terraform output` local y en SSM;
- `.tfvars`, `.tfstate*` y `iam-bootstrap-policy.json` siguen
  gitignoreados;
- los forks no pueden asumir el rol de deploy: el `sub` exige este repo y
  `main`, y `workflow_dispatch` requiere permiso de escritura.

**I-D13 · Alertas operativas: topic SNS separado + 3 alarmas** (nuevo).
- **Topic `renovarte-ordenes-alertas-operativas`**, distinto del del
  kill-switch: un canal caído o un borrado pendiente **no** tienen que
  apagar el servicio. Sin KMS. Policy con `SNS:Publish` solo para
  `cloudwatch.amazonaws.com` con `aws:SourceAccount`. Suscripción `email`
  a `var.alerts_email` (tfvars; default: el mismo
  `budget_notification_email`), que el CTO/CEO confirma con un clic.
- **Los emails de alarma no llevan datos personales:** CloudWatch manda el
  nombre de la alarma, la métrica y el umbral, nunca el contenido del log.
  Para el detalle, el runbook usa una consulta de Logs Insights
  (centavos).
- **Metric filters** (sin dimensiones, para que cada uno sea **una sola**
  custom metric; namespace `RenovArte/Ordenes`; `metric_value = "1"`):

  | Metric filter | Log group | Patrón |
  |---|---|---|
  | `canal-fallido` | `orders-http` | `{ $.evento = "canal_fallido" }` |
  | `borrado-no-programado` | `orders-http` | `{ $.evento = "borrado_no_programado" }` |
  | `retencion-sana` | `discord-retention` | `{ $.evento = "retencion_discord" && $.requieren_manual = 0 && $.pendientes_viejos = 0 }` |

- **Alarmas** (todas al topic de alertas operativas):

  | Alarma | Métrica / condición | `treat_missing_data` | Qué detecta |
  |---|---|---|---|
  | `-canal-degradado` | `canal-fallido` Sum ≥ 1 en 300 s, 1 de 1 | `notBreaching` | Un canal no entregó (AC-25) |
  | `-borrado-no-programado` | `borrado-no-programado` Sum ≥ 1 en 300 s, 1 de 1 | `notBreaching` | Un mensaje de Discord que no quedó en la cola de borrado (AC-29) |
  | `-retencion-sin-latido` | `retencion-sana` Sum < 1 en **24 de 24** períodos de 3.600 s | **`breaching`** | Cualquier día sin una corrida sana: el job no corrió (schedule o IAM roto), crasheó o timeouteó antes de la línea de resumen, o terminó con `requieren_manual > 0` o `pendientes_viejos > 0` |

- **Por qué un "latido" y no las 2 alarmas que proponía el backend**
  (`Errors > 0` + metric filter con `> 0`): las dos juntas no detectan
  el caso "el job no corrió nunca" (sin invocación no hay `Errors` ni
  línea de resumen), que es justamente el que deja mensajes con datos
  personales más de 60 días en el canal. El latido cubre los tres
  casos con **una** alarma, y avisa a más tardar ~25 h después de la
  última corrida sana, dentro del margen de 60–61 días. 24 × 3.600 s =
  86.400 s es el máximo que admite una alarma.
- **Riesgo de oscilación (a verificar en I16):** con una corrida por día
  y una ventana de exactamente 24 h, un job que un día corre unos minutos
  más tarde podría dejar una ventana sin datapoint y dar una falsa
  alarma. Si pasa, la salida es correr el job dos veces por día (06:00 y
  18:00 UTC): es idempotente, no borra antes de los 60 días (los buckets
  son por fecha) y cuesta USD 0. Eso cambia el schedule que pidió el
  backend, así que solo se hace con su OK.
- **Cuenta del free tier:** 4 alarm metrics (flood + 3) y 3 custom
  metrics. Los repos de la 0016 no crean ninguna alarma ni metric filter
  (revisado en su Terraform); I1 confirma el total de la cuenta. Si la
  cuenta ya tuviera 7 o más alarmas, se unen `canal-fallido` y
  `borrado-no-programado` en una sola métrica y una sola alarma (patrón
  con `||`), y quedan 3.
- Requisitos del backend para que esto funcione (divergencias N3 y N4):
  la línea `retencion_discord` en **toda** corrida que termina sin
  excepción (incluidas las vacías y las cortadas por tiempo), con los
  contadores como números JSON, y los logs como líneas JSON crudas.

### Divergencias con `## Backend` / RFC (para resolver antes de implementar)

Las 5 divergencias de la revisión 1 quedaron **aceptadas** por backend (RFC
§13). Nuevas en esta revisión (no reescribo `## Backend`):

- **N1 · SSM: `value_wo` en lugar de placeholder + `ignore_changes`**
  (I-D9). Es solo de infra y no le cambia nada al backend. El objetivo es
  el mismo: que el valor real no pase por Terraform. Lo señalo porque
  `## Backend` y el RFC §10.4 dicen "`ignore_changes = [value]`", y eso
  filtraría el HMAC y la URL del webhook al estado local.
- **N2 · Rotación del webhook/HMAC:** el runbook de B18 no tiene que
  indicar "forzar un cold start con una env var dummy" por CLI (pisa todas
  las env vars y deja drift). Procedimiento: `put-parameter --overwrite` →
  subir `config_revision` → `terraform apply` (I-D9). **Opcional para
  backend:** que `orders-http` relea SSM una vez ante `401`/`10015` de
  Discord, para no depender del apply si el webhook se borra.
- **N3 · Alarmas de retención y `requieren_manual` "pegajoso":**
  - la línea `retencion_discord` tiene que salir en **toda** corrida que
    termine sin excepción, incluidas las que no tienen nada que borrar y
    las que cortan por tiempo, con `requieren_manual` y
    `pendientes_viejos` como **números** (no strings). Si no, el latido
    da falsos positivos;
  - **hueco:** según RFC §10.3, un id con `webhook_id` viejo queda
    pendiente como `requieren_manual`. Después de que los propietarios lo
    borran a mano, el job no tiene forma de enterarse (el `DELETE` con el
    webhook nuevo sigue dando `10015`), así que la alarma quedaría en
    `ALARM` para siempre y taparía fallas nuevas. Hace falta un
    mecanismo de "resuelto". Propuesta: el job mueve esos ids a un ítem
    `BORRAR#MANUAL` (lo cubre el IAM `BORRAR#*`), los reporta en la
    corrida en que los detecta y el runbook da el comando para vaciarlo
    cuando se borraron a mano. La decisión es de `backend-agent`.
- **N4 · Formato de log:** los metric filters JSON solo matchean si la
  línea entera es JSON. `lib/log.ts` tiene que escribir con
  `process.stdout.write(JSON.stringify(obj) + "\n")` (una línea, `evento`
  en el primer nivel), no con `console.log`, que en el runtime Node
  antepone timestamp, requestId y nivel. Log format del Lambda: `Text`
  (default). Un test del logger puede fijarlo; I16 lo verifica con
  `aws logs test-metric-filter`.

### Costo mensual estimado (con la salvedad de B1)

| Recurso | Uso esperado (300 órdenes, ~5.000 req/mes) | Costo |
|---|---|---|
| Lambda (3 funciones, arm64) + Function URL | Dentro del Always Free (1M req, 400k GB-s); `discord-retention` son ~30 invocaciones de pocos segundos a 128 MB | USD 0 |
| DynamoDB on-demand | ~20k operaciones (+ ~1k del job de borrado) | < USD 0,01 |
| SES | ≤ 300 mails (USD 0,10/1.000) | ≤ USD 0,03 |
| Discord (webhook, envío y borrado) | Fuera de AWS | USD 0 |
| SSM Standard (2 parámetros) + KMS `aws/ssm` | Lecturas por cold start + 1 por día del job | USD 0 |
| SNS (2 topics, 1 suscripción email) | Pocos mensajes al mes; 1.000 emails gratis | USD 0 |
| EventBridge Scheduler (2 schedules) | ~31 invocaciones/mes | USD 0 |
| AWS Budget (sin acciones) | 1 | USD 0 |
| CloudWatch Logs (3 groups, 14 días) | Muy por debajo de 5 GB | USD 0 |
| CloudWatch: 4 alarm metrics + 3 custom metrics | Dentro de las 10 + 10 gratis | USD 0 |
| **Total AWS** | | **≈ USD 0,00–0,05/mes** |
| Peor caso si la cuenta ya agotó el free tier de CloudWatch | 4 × USD 0,10 + 3 × USD 0,30 | +USD 1,30/mes (las custom metrics, USD 0,90, no se ven en el Budget) |
| GitHub (repo público, Free) | Actions ilimitado, secret scanning gratis | USD 0 |
| Opción B: dominio | Registrador, fuera de AWS y fuera del Budget | ~USD 10–15/año (~USD 1/mes) |

**Encaje en el tope de USD 20:** el costo esperado es de centavos, lejos
del tope, y el peor caso con la opción B y sin free tier de CloudWatch es
de ~USD 2,50/mes. Las capas de protección son:
1. el ledger corta al 90 % (backend);
2. la reserved concurrency acota la tasa (I-D4);
3. la alarma de flood corta en minutos lo que el ledger no mide (I-D8);
4. el Budget al 100 % apaga la concurrency (I-D6);
5. el cupo global de mails deja SES en ≤ USD 0,10.

`discord-retention` queda fuera del kill-switch, pero su costo no depende
del tráfico (un schedule diario): no presiona el tope.

### Pasos manuales del CTO/CEO (resumen; detalle en `tasks.md`)

| Cuándo | Paso | Tarea |
|---|---|---|
| Antes del apply | Verificaciones de solo lectura de la cuenta (concurrency, SES sandbox, tag `Project`, OIDC, **alarmas y custom metrics existentes**, Terraform ≥ 1.11 local) | I1 |
| Antes del apply | Usuario IAM `renovarte-ordenes-terraform` + policy + perfil local; OIDC provider si no existe | I2 |
| Al crear el repo | Configuración de GitHub del repo público: ruleset de `main`, secret scanning + push protection, aprobación de workflows de forks | I20 |
| Al crear el repo | **Discord (B24):** canal nuevo y privado solo de órdenes, visible solo para los propietarios (`@everyone` sin "Ver canal"); 2FA en esas cuentas; nadie más con "Gestionar webhooks"/"Gestionar mensajes"; un webhook "RenovArte Órdenes" en ese canal (AC-30) | B24 |
| Apply | `terraform plan` → revisar → `apply` | I15 |
| Tras el apply | Clic en el mail de verificación de SES (vence en 24 h) | I15 |
| Tras el apply | **Clic en el mail de confirmación de la suscripción SNS de alertas operativas** | I15 |
| Tras el apply | `put-parameter --overwrite` del secreto HMAC (generado con `openssl rand -base64 32`) | I15 |
| Tras el apply | **`put-parameter --overwrite` de la URL del webhook de Discord** (leída con `read -rs`, nunca en chat ni git) | I15 / B24 |
| Tras el apply | Pasar `orders_api_url` a Vercel (solo Production) y el ARN del rol de deploy a las variables del repo | I15 |
| Operación | **Gmail (AC-31):** política de borrado de los mails de órdenes a los 60 días (a mano o con filtro/Apps Script de Google), fuera de los repos y de este Terraform | fuera de la spec técnica |
| Operación | Reactivar el servicio a mano tras un flood o un tope, si no se espera al día 1 | runbook (I13) |
| Operación | Rotar el webhook o el HMAC (`put-parameter` + `config_revision` + apply); tras rotar el webhook, borrar a mano los mensajes del webhook viejo de menos de 60 días | runbook (I13) |

### Coordinación cross-repo (sin estado remoto, como la 0016)

| Valor | Sale de | Va a | Quién |
|---|---|---|---|
| `orders_api_url` (output; termina en `/`) | `terraform output` de este repo | Env var de Vercel `NEXT_PUBLIC_ORDERS_API_URL` en `renovarte-catalogo`, **solo Production** | CTO/CEO al aplicar → `frontend-agent` (B20) |
| Dominio de producción del catálogo | `renovarte-catalogo` / Vercel | `var.allowed_origins` y `var.catalog_products_url` en `terraform.tfvars` | B20 → CTO/CEO |
| `github_oidc_provider_arn` | Bootstrap manual de la cuenta | `terraform.tfvars` | CTO/CEO |
| URL del webhook de Discord | Discord (B24) | Parámetro SSM, **nunca** tfvars, repo ni chat | CTO/CEO |

Ningún otro repo necesita ARNs de este y este no necesita ARNs de la 0016.
Se documenta en el README ("Coordinación de valores") con placeholders,
igual que en `renovarte-chat-gateway`.

### Estimate

**Tamaño M/L: ~14 a 19 h** de trabajo de devops (antes: 11 a 15), más
~1,5–2,5 h de sesión en vivo con el CTO/CEO (bootstrap, GitHub, SES,
confirmación de alertas, secretos y apply). El aumento sale del tercer
Lambda con su schedule y su IAM, de las alertas operativas (topic,
metric filters y alarmas) y de verificaciones nuevas post-apply. Son **20
tareas (I1–I20)** en `tasks.md`; I18–I20 son nuevas e I17 (opción B) es
condicional.
