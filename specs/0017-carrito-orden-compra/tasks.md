# 0017 — Carrito y orden de compra · Tasks

> **Enmienda 2026-10-05b (nombre y apellido + teléfono, ADR-0020):** en
> `## Backend` se ajustaron B3, B4, B9, B10, B11 (suma
> `lib/payload-hmac.ts`), B12, B15, B18, B19, B20 y B21; IDs sin
> renumerar. Ver RFC revisión 4.
>
> **Enmienda 2026-10-05 (recorte de datos del MVP):** el formulario pedía
> solo teléfono (desde 2026-10-05b pide además nombre y apellido), y se retiran el borrado automático a 60 días (AC-29/AC-31)
> y el aviso de privacidad. Los IDs no se renumeran: **B23 e I19 quedan
> retiradas** (tachadas), y B4, B9, B10, B11, B12, B16, B18, B19, I3, I5,
> I9, I11, I13, I15, I16, I18, F1, F2, F12, F13, F15 y F19 se ajustaron.
> Ver el `spec.md` (precisión 2026-10-05) y el RFC (revisión 3).
>
> Igual que `plan.md`: cada agente agrega tareas bajo su propio heading y
> no reescribe las de otro. `backend-agent` → `## Backend` (prefijo `B`);
> `devops-agent` → `## Infra`; `frontend-agent` → `## Frontend`. Las
> dependencias entre secciones se marcan con el ID de la tarea del otro
> agente cuando exista.

## Backend

Repo: `renovarte-ordenes` (público). Diseño:
[`rfc-servicio-ordenes.md`](./rfc-servicio-ordenes.md) (revisión 4;
2026-10-05b, ADR-0020: nombre y apellido + teléfono) y `plan.md`
`## Backend`. Nada de esto se ejecuta en modo diseño: crear el
repo, instalar dependencias, cada commit y cada push necesitan aprobación
humana (`CLAUDE.md`). Los IDs B1–B20 se mantienen (otras secciones los
referencian); B21–B24 son nuevas, de esta revisión.

### Estimate

**Tamaño L: ~23 a 30 h** (antes: 22 a 29 h; **+~1 h** por la revisión 4: validación y normalización del nombre en B4, `payload-hmac` derivado en B11, render del nombre en B9/B21 y tests de AC-9/AC-13/AC-18/AC-23/AC-27. Antes de eso: 16 a 22 h, ~2 h menos por retirar B23 y simplificar B4/B12).

| Bloque | Tareas | Horas |
|---|---|---|
| Preparación + bootstrap | B1–B3, B24 | ~2,5–3,5 h |
| Núcleo puro (validación, catálogo, precios, token, número, modelo, renders) | B4–B10, B21 | ~8–10 h |
| Estado y entrega (idempotencia por canal, SES, Discord, rate limit, ledger) | B11–B14, B22 | ~6–8 h |
| Handlers + budget-guard + leak (B23, retención, retirada) | B15–B17 | ~4–4,5 h |
| Cierre, smoke real y coordinación | B18–B20 | ~2–3 h |

**Riesgos que pueden mover el estimate:**

- Si el smoke test de la opción A (B19) cae en spam, se suma la opción B
  (dominio + DKIM). Del lado backend es ~1 h; el grueso cae en I17.
- Que los límites reales de Discord (B1) difieran de los supuestos, en
  especial el formato del 429 y los headers de rate limit.

### Tasks

#### Preparación + bootstrap

- [ ] **B1 — Verificar pricing y límites vigentes** (páginas oficiales):
  - SES: precio por 1.000, free tier y límites de sandbox; confirmar que
    el SDK v3 respeta `maxAttempts: 1` en `SendEmail`.
  - Lambda, DynamoDB on-demand, Function URL, EventBridge Scheduler y
    transferencia saliente (100 GB gratis).
  - **Discord:** que el webhook sea gratis; límites de `content` (2.000),
    adjuntos (tamaño), rate limit por webhook y por canal, forma del
    429 (`retry_after`, `X-RateLimit-*`), `?wait=true`, `DELETE
    /webhooks/{id}/{token}/messages/{id}`, códigos `10008`/`10015` y
    `allowed_mentions`/`flags`.
  - Anotar los valores con la fecha en el `README.md`, y ajustar el RFC
    §8/§10 y los costos unitarios del ledger (B14) si algo cambió.
  - Confirmar en Billing si el free tier de 12 meses sigue vigente.
- [ ] **B2 — Bootstrap del repo** (tras aprobación de creación, §II.6/§II.7):
  - `README.md` (**público:** sin ID de cuenta, ARNs reales ni URL o IDs
    de Discord), `CLAUDE.md` (reglas de `renovarte-chat-gateway/CLAUDE.md`
    más una sección "Datos personales": no loguear ni persistir
    contacto, ni la URL del webhook ni respuestas de Discord),
    `docs/runbook.md` vacío y `.gitignore`.
  - `package.json` con el mismo tooling que el gateway y `pnpm gate`.
  - Dependencias de runtime solo `@aws-sdk/client-sesv2`,
    `@aws-sdk/client-dynamodb`, `@aws-sdk/lib-dynamodb`,
    `@aws-sdk/client-ssm` y `@aws-sdk/client-lambda`. Discord sin
    librería (`fetch` nativo). Instalar con aprobación humana.
  - Agregar el repo como submódulo de `renovarte-parent`.
- [ ] **B3 — `src/wire.ts`:** tipos exactos del RFC §3 (`EstadoResponse`,
  `CrearOrdenRequest` con `contacto: { nombre, telefono }`,
  `CrearOrdenResponse`, `CampoOrden` con `"contacto.nombre"`), con los
  comentarios de límites (**1..100 líneas**) y de `token_vencido`
  (también < 3 s). Test de forma (`wire.test.ts`) con un JSON de ejemplo
  por variante. Sin ningún campo de Discord.
  → Desbloquea a `## Frontend`, que copia este archivo.
- [ ] **B24 — Preparación de Discord (manual del CTO/CEO; `backend-agent`
  solo la documenta en el runbook)** (nueva):
  - Crear en el servidor de RenovArte un canal **nuevo y privado**
    dedicado a órdenes, visible **solo para los propietarios**
    (`@everyone` sin "Ver canal"; acceso por rol o miembro explícito).
  - 2FA recomendado en las cuentas de los propietarios; si el servidor
    lo permite, 2FA obligatorio para la moderación.
  - Nadie más con "Gestionar webhooks" ni "Gestionar mensajes"; sin bots
    ni integraciones de terceros con lectura del canal.
  - Crear **un** webhook en ese canal ("RenovArte Órdenes") y cargar su
    URL en SSM con `aws ssm put-parameter --overwrite` (parámetro creado
    por `## Infra`), sin pegarla en el chat ni en ningún repo.
  - Crear un canal de prueba (o usar el mismo antes de producción) para
    B19.
  - ✔ Checklist firmada por el CTO/CEO en el runbook. Depende del
    parámetro SSM de `## Infra`; bloquea B19.

#### Núcleo puro (sin AWS ni Discord)

- [ ] **B4 — `lib/validate-order.ts`:**
  - Esquema estricto: clave desconocida → `no_permitido`.
  - Límites de tamaño (16 KB).
  - Honeypot `sitio_web`.
  - **Regla del nombre y apellido** (RFC §3.2.1, idéntica a `ux.md`):
    obligatorio; `normalize("NFC")` + recorte; vacío → `requerido`; medido
    en puntos de código tras recortar, `> 80` → `largo` y `< 2` →
    `formato`; al menos una letra `\p{L}`; **sin exigir más de una
    palabra**; espacios internos colapsados; CR/LF, `Cc`, U+2028/9, bidi
    y sustitutos sueltos → `formato`; no string → `formato`. El valor
    normalizado es el que usan el render y el HMAC. Nunca se incluye el
    valor en un error.
  - Regla del teléfono (RFC §3.2, idéntica a `ux.md`: obligatorio, 8..15
    dígitos tras quitar espacios, `-`, `(`, `)` y `+`); rechazar CR/LF,
    caracteres de control (`Cc`) y de control bidi (U+202A–U+202E,
    U+2066–U+2069). Las claves `email`, `direccion` y `localidad` dentro
    de `contacto` → `no_permitido` (esquema estricto); `contacto.nombre`
    **ya no** está entre las claves prohibidas.
  - Líneas: **1..100**, `producto_id` sin repetir, cantidad entera 1..20,
    precios enteros ≥ 0.
  - Tests por campo (AC-9, AC-17): tabla de vectores del nombre del
    `plan.md` (80/81, 1/2 caracteres, una palabra, alfabetos no latinos,
    NFC/NFD, solo dígitos/símbolos, CR/LF/tab/bidi) **compartida con
    `frontend-agent`** (F-tarea del formulario) para probar la paridad
    cliente/servidor.
- [ ] **B5 — `lib/catalog.ts`:**
  - Fetch de `CATALOG_PRODUCTS_URL` (timeout de 3 s), caché de 5 min e
    `If-None-Match`/304; `forceRefresh()`; fallback a la copia válida de
    < 24 h; sin copia → `catalogo_no_disponible`.
  - Guard `isProduct` copiado y **allowlist**
    `id/nombre/presentacion/precio_venta`.
  - Tests con un fetch fake (200, 304, 5xx, JSON inválido, fila inválida,
    clave de costo ignorada).
- [ ] **B6 — `lib/price-check.ts`:** líneas vs. catálogo → `ok` o
  `{ lineas con problema, total_vigente }`; chequeo `total_visto === Σ`.
  Tests (AC-15).
- [ ] **B7 — `lib/form-token.ts`:**
  - Emitir y verificar HMAC-SHA256 con timestamp; ventana de 3 s–2 h;
    comparación en tiempo constante.
  - **Cualquier token fuera de ventana (vencido o de < 3 s), con firma
    ajena o malformado → `token_vencido`** (Q-F4).
  - Tests (AC-19).
- [ ] **B8 — `lib/order-number.ts`:** `RA-` + 5 dígitos con
  `crypto.randomInt`; reserva `NUM#` condicional con hasta 5 reintentos.
  Tests: formato, colisión → reintento, 5 colisiones → `falla`/`interno`.
- [ ] **B9 — `lib/order-model.ts` + `lib/render/text.ts` +
  `lib/mail/render.ts`** (ampliada):
  - Builder de `OrdenParaEntrega` por allowlist (nombre y presentación
    del catálogo, nunca spread).
  - `renderTextoPlano(orden)`: el texto completo, compartido por el mail
    y el adjunto de Discord.
  - `OrdenParaEntrega.contacto = { nombre, telefono }` (nombre ya
    normalizado). El nombre y el teléfono van **en el cuerpo, después de
    `LINEA_RELLENO`** (constante fija en `render/text.ts`: "Nueva orden
    recibida desde el sitio de RenovArte. Abrí el mensaje para ver el
    número de orden, los datos de contacto del cliente y los productos
    pedidos."; primer párrafo del HTML y primera línea del texto; sin
    datos personales ni variación por orden) y del número y la fecha;
    nunca en el asunto ni en ningún header.
  - Mail: asunto sin datos personales (ni nombre ni teléfono), HTML
    escapado (el nombre también), fecha y hora en
    `America/Argentina/Buenos_Aires`, formato `$ 64.320`.
  - Tests de contenido (AC-13: nombre y teléfono en el cuerpo, el asunto
    sin ninguno de los dos; el cuerpo en texto y HTML empieza con
    `LINEA_RELLENO` y dos órdenes distintas dan el mismo arranque; los
    primeros 153 caracteres no contienen nombre, teléfono ni número;
    nombre con `<script>`/`&`/comillas escapado en
    el HTML y literal en el texto) y de ausencia de tokens prohibidos
    (AC-16), con una clave de costo inyectada en el catálogo.
- [ ] **B10 — `lib/log.ts`:** logger JSON con allowlist de campos
  (incluye `canal`, `codigo`, `campo`, `http_status`; la línea de relleno
  es una constante del render y no pasa por el logger; **no** incluye el
  nombre ni el teléfono ni su largo). Test: nombre y teléfono canario,
  contacto, IP, body, URL del webhook y bodies de Discord se descartan
  (AC-18, AC-26); un error de validación se loguea solo con `campo` y
  `codigo`, nunca el valor.
- [ ] **B21 — `lib/discord/render.ts`** (nueva):
  - Primera línea fuera del bloque, solo con datos del servidor: número,
    total y cantidad de productos (**sin nombre ni teléfono**); después
    fecha y hora.
  - Contacto (`Nombre:` y `Teléfono:`) y productos dentro de un bloque de
    código; cada `` ` `` del texto → `ˋ` (U+02CB). El nombre nunca va en
    `username`.
  - Presupuesto: `content` ≤ 1.900 caracteres (encabezado + contacto
    ≤ ~400 con el nombre de 80); si no entran todas las
    líneas, `… y N productos más: ver el adjunto`; el total siempre se
    muestra.
  - Payload: `username`, `allowed_mentions: { parse: [] }`, `flags: 4`,
    `attachments: [{ id: 0, filename: "orden-RA-xxxxx.txt" }]`, y el
    adjunto = `renderTextoPlano(orden)`.
  - Tests (AC-16, AC-23): mismo número que el mail; adjunto idéntico a la
    parte de texto del mail; primera línea sin nombre ni teléfono; orden
    de 100 líneas con los campos al máximo (**nombre de 80 caracteres**) →
    `content` ≤ 2.000; un nombre `@everyone` o con
    `` ``` ``, `[link](http://x)` o `**` no rompe el bloque ni menciona;
    sin tokens prohibidos.

#### Estado y entrega

- [ ] **B11 — `lib/payload-hmac.ts` + `lib/idempotency.ts`** (reescrita por el doble canal; `payload-hmac.ts` nuevo, rev. 4):
  - `payload-hmac.ts` (RFC §5.4.1): clave derivada `HMAC(secreto,
    "payload-v1" ‖ idempotency_key)`; serialización canónica
    (`JSON.stringify` de un array de orden fijo: líneas ordenadas, total,
    **nombre normalizado y teléfono recortado**); 256 bits sin truncar;
    comparación en tiempo constante. Tests: cambiar nombre o teléfono →
    otra huella; misma carga con otra key → otra huella; el valor guardado
    no contiene el nombre ni el teléfono.
  - Reserva `IDEM#` con `mail_estado = discord_estado = "enviando"`,
    `payload_hmac`, `numero_orden` y `expira_en` (Number, epoch-segundos,
    +90 días). **No se guarda ningún dato personal, ni el nombre ni el
    teléfono.**
  - Lectura de una key existente: payload distinto → `invalida`; algún
    `entregado` → `aceptada` idempotente; claim condicional de cada canal
    `fallido` (`IF <canal>_estado = "fallido"`); si no hay nada que
    reclamar: `en_proceso` (< 30 s) o `estado_incierto`.
  - Persistencia por canal condicionada a `_intento_en`.
  - **Sin `DeleteItem`.**
  - Tests con un DynamoDB fake, incluidos claims concurrentes (AC-24) y
    reintento con la misma key pero otro nombre → `invalida`, sin envíos.
- [ ] **B12 — `lib/mail/ses-sender.ts`:**
  - SES v2 `SendEmail` con `Content.Simple` (nunca `Raw`: así el nombre no
    puede inyectar headers) y `ToAddresses = [ORDER_RECIPIENT]` (validado al
    arrancar), `FromEmailAddress = ORDER_SENDER_EMAIL`; **sin `ReplyTo`**
    (ya no hay email del visitante, RFC rev. 3).
  - Cliente con **`maxAttempts: 1`** y timeout de 4 s.
  - Clasificación: `MessageId` → `entregado`; 4xx o error antes de
    conectar → `fallido`; 5xx, timeout o socket cortado → `incierto`.
  - Tests (AC-11, AC-17, AC-20).
- [ ] **B22 — `lib/discord/webhook.ts` + `lib/delivery.ts`** (nueva):
  - Webhook: carga la URL de SSM en el cold start (en paralelo con el
    HMAC) y la valida contra
    `^https://discord\.com/api/webhooks/\d{17,20}/[A-Za-z0-9_-]{60,80}$`;
    si no coincide → `fallido`/`config` sin request.
  - `POST ?wait=true` multipart (`payload_json` + `files[0]`), con un
    timeout de 4 s. 200 con `id` → `entregado`; 400/401/403/404/413 o
    error antes de conectar → `fallido`; 429 → una espera si
    `retry_after ≤ 1,5 s` y quedan > 6 s, si no `fallido`; 5xx, timeout
    o 2xx sin `id` → `incierto`.
  - **Nunca** loguea ni relanza la URL o el body; los errores se mapean a
    códigos.
  - `delivery.ts`: envío en paralelo (`Promise.allSettled`) de los canales
    reclamados; persistencia por canal apenas termina cada uno; agregado
    según RFC §5.3; `canal_fallido` por cada canal que no entregó (con
    `orden_aceptada`). Sin programación de borrado (AC-29 retirado).
  - Tests con fetch fake y DynamoDB fake (AC-20, AC-23, AC-24, AC-25,
    AC-26): la matriz completa de estados de la tabla de §5.3.
- [ ] **B13 — `lib/rate-limit.ts`:**
  - HMAC de la IP; contadores `RL#` por hora y por día (POST y
    aceptadas).
  - **Cupo global de órdenes** `CUPO#dia`/`CUPO#mes`, consumido una vez
    por key en la reserva; sin devolución.
  - Umbrales por env var. Tests (AC-19).
- [ ] **B14 — `lib/ledger.ts` + `lib/control.ts`:**
  - `LEDGER#YYYY-MM` con `ADD` atómico y costos unitarios conservadores
    (el costo por request incluye el `UpdateItem` extra de Discord; costo
    unitario de Discord = 0).
  - Corte a `BUDGET_CAP_USD × BUDGET_STOP_RATIO` → `CONTROL` apagado con
    motivo `tope_alcanzado`.
  - Lectura de `CONTROL` con caché de 30 s y mapeo de motivo a respuesta
    (`tope_alcanzado` vs. `no_disponible`/`mantenimiento`).
  - Tests (AC-22).

#### Handlers

- [ ] **B15 — `handlers/http.ts`:**
  - Routing por `rawPath` exacto (`/v1/estado`, `/v1/ordenes`) sobre el
    evento de Function URL (payload v2).
  - **Sin headers `Access-Control-*` ni ruta `OPTIONS`** (CORS lo maneja
    la Function URL); test que lo verifica.
  - `Origin` contra `ALLOWED_ORIGINS`; cold start que lee los dos
    secretos de SSM.
  - Orden de operaciones del RFC §6.5; `Cache-Control: no-store`.
  - Suite de integración con puertos fake (mailer, Discord, DynamoDB,
    catálogo) que cubre la tabla "Cómo se verifica" de `plan.md`,
    incluidas las aserciones de **cero escrituras y ningún canal con el
    flag apagado** y de **ningún dato personal (nombre ni teléfono
    canario) ni URL de webhook en escrituras ni logs**, también en los
    caminos `invalida`, `rechazada_por_catalogo` y canal fallido.
- [ ] **B16 — `handlers/budget-guard.ts`** (ampliada):
  - Parseo del mensaje SNS: Budget (texto que menciona `BUDGET_NAME`) →
    motivo `presupuesto`; alarma de CloudWatch (`AlarmName ===
    FLOOD_ALARM_NAME`, `NewStateValue === "ALARM"`) → motivo `flood`;
    `OK`/`INSUFFICIENT_DATA` → se ignora; formato desconocido → motivo
    `desconocido`, se apaga igual (fail-safe).
  - Disparador válido → `CONTROL` apagado + `PutFunctionConcurrency(0)`.
  - `{ mode: "reset" }` → `CONTROL` habilitado con cualquier motivo +
    `PutFunctionConcurrency(n)` si `ORDERS_HTTP_RESERVED_CONCURRENCY`
    tiene valor, o `DeleteFunctionConcurrency` si está vacía.
  - Idempotente. Tests con los mensajes SNS reales de ejemplo de los dos
    tipos, a coordinar con I9/I10 (AC-22).
- ~~**B23 — `handlers/discord-retention.ts` + `lib/discord/retention-queue.ts`**
  (AC-29)~~ — **RETIRADA el 2026-10-05** (recorte de datos del MVP). El
  diseño está en el historial de git (commit `8371ac9`) por si se retoma.
- [ ] **B17 — `src/leak-audit.ts` + `pnpm check:leak`:**
  - Tokens de costo, margen y precio LACA en `src/`, en un mail
    renderizado de ejemplo, en un **mensaje de Discord renderizado de
    ejemplo** (con su adjunto) y en los JSON de ejemplo del contrato.
  - Emails literales en `src/` distintos del placeholder del destinatario.
  - **URLs de webhook de Discord reales** (`discord(app)?\.com/api/webhooks/\d+/`)
    en cualquier archivo trackeado (AC-26).
  - Más los patrones de credenciales y `*.tfvars`/`*.tfstate` de I12.
  - Corre en `pnpm gate` (AC-16, AC-17, AC-26).

#### Cierre y coordinación

- [ ] **B18 — `dev/local-server.ts` + docs:**
  - Harness HTTP local con el mismo contrato: mailer fake y Discord fake
    que imprimen lo que enviarían, catálogo fixture,
    `ALLOWED_ORIGINS=http://localhost:3000`, y flags para forzar la falla
    de un canal o de los dos (para probar AC-20/AC-25 desde el
    frontend).
  - `README.md` (cómo correrlo, env vars, contrato, sin datos reales) y
    `docs/runbook.md`:
    - reactivar a mano `CONTROL`/concurrency después de un tope o un
      flood;
    - qué hacer ante `estado_incierto` y `canal_fallido`;
    - rotar el webhook de Discord;
    - checklist de B24;
    - filtro de Gmail de la opción A;
    - supresión de datos a pedido del cliente: borrar a mano el mail y el
      mensaje de Discord (no hay borrado automático);
    - requisito si algún día se exporta a CSV/planilla: neutralizar los
      valores que empiecen con `=`, `+`, `-`, `@`, tab o CR (hoy no hay
      exportación).
- [ ] **B19 — Smoke test real** (después del deploy de `## Infra` y de
  B24, con aprobación humana):
  - Una orden de prueba contra el entorno real: mail en SES sandbox a
    renovartebyjuli@gmail.com **y** mensaje en el canal de Discord.
  - Verificar con el CTO/CEO: el mail llegó **a la bandeja de entrada**
    (no a spam), con headers SPF/DKIM/DMARC revisados; el asunto y la
    primera línea de Discord **sin nombre ni teléfono**; el mensaje de
    Discord tiene el **mismo número**, el nombre, el teléfono, el adjunto
    completo y ninguna mención (probar con un nombre de prueba con `@everyone`);
    el número coincide con la respuesta.
  - Reintentar con la misma key → sin segundo mail ni segundo mensaje.
  - Falla parcial real: con el parámetro del webhook apuntando a un
    webhook borrado → `aceptada` por mail + alerta `canal_fallido`
    recibida por email. Después restaurar el parámetro.
  - Si el mail cae en spam con el filtro puesto → escalar a la opción B
    (I17).
- [ ] **B20 — Coordinación cross-repo:**
  - Pasar a `frontend-agent` la URL real y la versión final de `wire.ts`
    (1..100 líneas; `token_vencido` para < 3 s; `contacto.nombre`).
  - Pasar a `devops-agent` los valores reales de `ALLOWED_ORIGINS` y
    `CATALOG_PRODUCTS_URL`.
  - Registrar en la PRD de `renovarte-catalogo` los requisitos que este
    repo resuelve (RF-17/18/19, RNF-11..14) apuntando a este RFC.
  - Proponer a quien toque `renovarte-catalogo` la nota de referencia en
    su `specs/constitution.md` (no es enmienda).

## Frontend

Repo: `renovarte-catalogo` (rama `feature/carrito-orden-compra`). Diseño:
`plan.md` `## Frontend` (revisión 3, 2026-10-05b, ADR-0020), construido sobre
`ux.md` (aprobado), la spec enmendada (31 AC) y el contrato de `## Backend` /
RFC §3 y §5 (revisión 4: `lineas` 1..100, `token_vencido` también para token
< 3 s, `contacto = { nombre, telefono }`).

Reglas:

- Nada se ejecuta en modo diseño.
- Sin dependencias nuevas.
- Cada commit y cada push necesitan aprobación humana (`CLAUDE.md`).
- Orden pensado para que `pnpm gate` quede verde después de cada tarea:
  toda UI nueva llega con su test, y el servicio de órdenes se mockea
  hasta F20.
- **Dependencia de `ux-agent` (Q-F2):** F7, F9, F12, F14 (y el caso de
  tope de F17) no construyen su parte visible afectada hasta tener la
  respuesta de `ux-agent`
  aprobada por un humano. La lógica pura de esas tareas sí puede
  avanzar.

### Estimate

**Tamaño L: ~29 a 37 h, 20 tareas (F1–F20)** (+~1 h por la revisión 3: campo
"Nombre y apellido", vectores compartidos con B4 y borrador en
`sessionStorage`). Detalle por bloque en
`plan.md` `## Frontend` > Estimate.

### Tasks

#### Base pura (sin UI visible)

- [ ] **F1 — `src/lib/contact.ts` + guardia de AC-14.**
  - Constantes de email e Instagram, y los helpers `mailtoConsulta(numero)`
    e `INSTAGRAM_DM_URL`.
  - **Enmienda 2026-10-05:** suma `RENOVARTE_TELEFONO` (`1130579528`) y
    `telefonoHref()` (`tel:`), con su test. El 2026-10-07 el CTO/CEO confirmó que es WhatsApp: suma
    `whatsappHref()` (`wa.me` con el número en formato internacional), con
    su test, para el link de `ux.md` (consulta de la confirmación). (F1 ya estaba commiteada con
    email e Instagram; el teléfono entra en un commit aparte.)
  - `tests/unit/no-runtime-backend.test.ts`: falla si aparece bajo `src/`
    un `route.(ts|js)`, un `middleware.*`/`proxy.*` o `"use server"`.
  - ✔ Los dos tests en verde; gate verde.
- [ ] **F2 — `src/lib/orders/wire.ts`** (depende de **B3**; mientras B3 no
  cierre, se copian los tipos del RFC §3 textualmente).
  - Guards `isEstadoResponse` / `isCrearOrdenResponse`.
  - `tests/unit/orders-wire.test.ts`: un JSON de ejemplo por variante, y
    un `resultado` desconocido o un body malformado → `false`.
  - Tipos del RFC §3 **revisión 4** (`lineas` 1..100, `MAX_LINEAS = 100`
    como constante documental; **`contacto` = `{ nombre, telefono }`**,
    `CampoOrden` con **`"contacto.nombre"`** y `"contacto.telefono"`, sin
    `email`/`direccion`/`localidad` ni `contacto_requerido`; ADR-0020).
  - El test de wire incluye un `invalida` con `campo: "contacto.nombre"`
    (`requerido`, `formato` y `largo`) y la respuesta `aceptada` **sin**
    nombre.
  - ✔ Test en verde; cuando cierre B3, el diff contra el `src/wire.ts` de
    `renovarte-ordenes` queda vacío salvo el comentario de cabecera.
- [ ] **F3 — `src/lib/cart/model.ts`.**
  - Operaciones puras con `MAX_POR_LINEA = 20`; `addProduct`/`addCombo`
    topean en 20 y devuelven un flag `topeado` (cómo se muestra lo decide
    Q-F2c). **Sin tope de líneas** en el cliente (Q-F1 cerrada).
  - `tests/unit/cart-model.test.ts` (AC-3, AC-4, AC-6):
    - agregar suma sin duplicar;
    - `addCombo` agrega 1 de cada producto;
    - límites de cantidad;
    - quitar y restaurar en la misma posición;
    - vaciar;
    - subtotal y total;
    - unidades sin contar las no disponibles;
    - `parseStored` con JSON corrupto o de otra versión → vacío.
  - ✔ Test en verde.
- [ ] **F4 — `src/lib/cart/store.ts`.**
  - Store externo con un `Storage` inyectable, clave
    `renovarte:carrito:v1`, evento `storage` y `getServerSnapshot` vacío.
  - `tests/unit/cart-store.test.ts` (AC-5, AC-18, AC-28): persiste, notifica,
    sincroniza la otra pestaña, y nunca serializa claves que no sean de
    `CartLine` (una línea con `nombre`/`telefono` de contacto extra no los
    escribe en `localStorage`).
  - ✔ Test en verde.
- [ ] **F5 — `src/lib/cart/revalidate.ts` + `src/lib/cart/catalog-slim.ts`.**
  - `revalidateCart` y `applyRechazoCatalogo`.
  - Proyección por allowlist de 5 campos.
  - `tests/unit/cart-revalidate.test.ts` (AC-15) y
    `tests/unit/catalog-slim.test.ts` (AC-16: exactamente 5 claves,
    aunque el `Product` traiga campos extra).
  - ✔ Tests en verde.

#### Header, ficha y shell de `/carrito`

- [ ] **F6 — `CartProvider` + header sticky + `CartHeaderLink`.**
  - `layout.tsx`: `CartProvider` (con los ids del catálogo) envuelve a
    `ChatProvider`; live region del sitio fuera de `<main>`.
  - Header `sticky top-0 z-30 justify-between`.
  - `tests/unit/cart-header-link.test.tsx`: `aria-label` "Carrito,
    vacío" / "Carrito, N productos"; contador `aria-hidden`; "99+";
    label "Carrito" desde `sm`.
  - ✔ Test en verde; `catalog.spec.ts` y `chat.spec.ts` siguen verdes
    con el header sticky.
- [ ] **F7 — `AddToCartButton` en la ficha** (**depende de `ux-agent`**:
  Q-F2(c), qué se ve al agregar con la línea ya en 20).
  - Botón inerte antes de hidratar, línea de estado, anuncio, foco que
    queda en el botón y `<noscript>`; sin `ul > li`.
  - `tests/unit/add-to-cart-button.test.tsx`.
  - e2e `tests/e2e/cart.spec.ts`:
    - AC-1: nombre, presentación y precio iguales a la ficha;
    - AC-4: dos toques → × 2;
    - AC-2: link y contador en home, categoría, grupo, ofertas y ficha,
      y visibles después de scrollear.
  - ✔ Tests en verde.
- [ ] **F8 — Página `/carrito` (shell + lectura).**
  - `src/app/carrito/page.tsx`: SSG, title "Tu carrito", `robots`
    noindex, mapa reducido del catálogo, `noscript` y padding inferior
    ≥ 104px.
  - `CartView` con la revalidación al montar, `CartLineItem` (incluida la
    variante no disponible), `CartNotice` de revalidación, `CartSummary`,
    `CartEmpty` y el estado "solo no disponibles".
  - Layout de 1 columna en móvil y `grid-cols-[1fr_380px]` con la columna
    derecha `sticky top-[88px]` desde `md`.
  - Tests de markup (AC-8: vacío sin `<form>`).
  - e2e:
    - `localStorage` sembrado con un precio viejo o un id inexistente →
      aviso y notas (AC-15);
    - recarga y navegación conservan el carrito (AC-5);
    - `aria-current` en el header.
  - ✔ Tests en verde; `pnpm build` lista `/carrito` como estática.
- [ ] **F9 — Edición del carrito** (**depende de `ux-agent`**: Q-F2(d),
  ubicación y copy de la nota de #D).
  - `QuantityStepper`, `CartUndoRow` y `CartClearControl`, con las reglas
    de foco de ux.md y los anuncios.
  - e2e AC-3: +/−, "−" deshabilitado en 1, "+" en 20 con traspaso de
    foco, Quitar → Deshacer en la misma posición, Vaciar → Cancelar / Sí
    con foco en el `h1`; la segunda pestaña actualiza el contador.
  - ✔ Tests en verde.

#### Cliente de órdenes, formulario y envío

- [ ] **F10 — `src/lib/orders/client.ts`.**
  - `fetchEstado` / `crearOrden` con los puertos `fetch`, `now`,
    `schedule` y `cancel` (defaults como **wrappers flecha**) y timeout de
    15 s.
  - Normalización a `OrderOutcome` y builder tipado del body.
  - `tests/unit/orders-client.test.ts`:
    - cada `resultado`;
    - 500, 502 sin body, JSON inválido, `resultado` desconocido,
      `falla`/`mantenimiento` (flood), `falla`/`en_proceso`, error de red,
      timeout (timer fake) y URL sin configurar → `falla`, nunca
      `aceptada` (AC-20);
    - GET `no_disponible` → outcome distinto de `tope_alcanzado`;
    - el body tiene solo las claves de `CrearOrdenRequest` (sin
      `nombre`/`presentacion` ni `to`/`cc`/`bcc`/`reply_to`/`webhook`/
      `canal`) (AC-17); un payload de 100 líneas se arma bien;
    - regresión: los timers default invocados sin `this` no lanzan.
  - ✔ Test en verde.
- [ ] **F11 — `src/lib/orders/checkout.ts`.**
  - Reducer del envío, huella del payload (suma el **nombre normalizado**
    además del teléfono), `idempotency_key` (reusa con la misma huella,
    nueva ante cualquier cambio —incluido el de nombre o teléfono— o después
    de un 409) y
    ciclo del `form_token` (espera si tiene < 3,5 s —
    `TOKEN_ESPERA_MIN_MS = 3500`—, renueva si tiene más de 1 h 50 min,
    un solo reintento silencioso ante `token_vencido`, vencido o
    prematuro).
  - Guard síncrono de doble envío (AC-24): un `SUBMIT` durante
    `enviando` no produce un segundo efecto.
  - Guarda la `idempotency_key` y la huella (hash, **sin** nombre ni teléfono
    en claro) del envío en curso en `sessionStorage`
    (`renovarte:envio-en-curso:v1`, decisión de la gate 2026-10-01, AC-24);
    se borra al terminar el envío.
  - `tests/unit/checkout.test.ts`: los casos anteriores, más dos `SUBMIT`
    seguidos → un solo envío; segundo `token_vencido` → falla genérica;
    cambiar solo el nombre → key nueva; cambiar solo el teléfono → key
    nueva; "Ana  Pérez" y "Ana Pérez" → misma huella; nunca se envía la
    misma key con otro nombre (el servidor respondería `invalida` con
    `errores: []`).
  - ✔ Test en verde.
- [ ] **F12 — `validate-contact.ts` + `contact-draft.ts` + `OrderForm` +
  `FormErrorSummary`** (**depende de `ux-agent`**: Q-F2(a), copy del error
  general; el resto del formulario sale de `ux.md` y puede avanzar).
  - Reglas y copy textual de ux.md "Formulario" y "Validación" (ADR-0020:
    **dos campos obligatorios, "Nombre y apellido" y teléfono**, en ese
    orden); validación al enviar y después por blur; resumen enfocable con
    un ítem por campo, en el orden del formulario.
  - **Nombre:** `name="nombre"`, `type="text"`, `autocomplete="name"`,
    `autocapitalize="words"`, `spellcheck="false"`, `enterkeyhint="next"`,
    `maxlength="80"`, hint "Para saber a quién llamar. Ej.: Ana Pérez".
    Reglas: tras recortar, 2 a 80 caracteres y al menos una letra; sin
    exigir más de una palabra; vacío o solo espacios → copy de nombre vacío;
    sin letras o > 80 → "Revisá el nombre…". `normalizeNombre()` exportada
    (NFC, recorte, colapso de espacios internos).
  - **Teléfono:** `type="tel"`, `autocomplete="tel"`, `inputmode="tel"`,
    `enterkeyhint="done"`, 8 a 15 dígitos.
  - Cada campo con `label` visible, **sin** placeholder, `aria-describedby`
    (hint y error) y `aria-invalid`; `novalidate`; honeypot inerte. **Sin**
    `fieldset`/`legend` y **sin** aviso de privacidad (retirado).
  - Mapeo de errores del servidor: `contacto.nombre` `requerido` → copy de
    nombre vacío; `formato` y `largo` → "Revisá el nombre…";
    `contacto.telefono` como antes; `errores: []` → error general.
  - `contact-draft.ts` (AC-28): `{ nombre, telefono }` en `sessionStorage`
    (`renovarte:contacto-borrador:v1`) al salir de cada campo y al enviar,
    nunca por tecla ni en `localStorage`; se lee al montar para
    rehidratar; allowlist de 2 claves.
  - `tests/unit/fixtures/nombre-vectores.ts`: los vectores de la tabla de
    AC-9 de `## Backend` (B4), copiados textualmente con la fuente anotada
    (plan.md `## Frontend`, "Paridad cliente/servidor del nombre"). B4 y esta
    tarea comparten los mismos vectores.
  - `tests/unit/validate-contact.test.ts`: recorre el fixture (mismo
    veredicto que el servidor: `requerido`/`formato`/`largo`/ok), el copy
    textual de cada error, el orden de errores y las reglas del teléfono.
    `tests/unit/contact-draft.test.ts`: solo 2 claves, JSON corrupto →
    nada.
  - `tests/unit/order-form.test.tsx`:
    - AC-9: dos campos en el orden nombre, teléfono, con los atributos de
      arriba; labels visibles; sin placeholder; sin `fieldset`/`legend`; sin
      email, dirección ni localidad;
    - AC-12: sin campos de pago, envío, cupón ni comentario;
    - AC-19: honeypot fuera de pantalla, `aria-hidden`, `tabIndex={-1}`.
  - e2e:
    - enviar vacío → resumen con **dos** ítems, enfocado, y **cero** POST;
    - solo nombre vacío → un ítem; cada ítem enfoca su campo;
    - nombre de 81 caracteres (por `fill`, salteando `maxlength` con
      `evaluate`) → "Revisá el nombre…" y cero POST;
    - "Madonna" y "Ana Pérez" pasan la validación;
    - corregir un campo al perder el foco borra su error;
    - tipear nombre y teléfono, recargar → los campos vuelven; `localStorage`
      sin ellos (AC-28).
  - ✔ Tests en verde.
- [ ] **F13 — Envío, falla y tope al enviar.**
  - `playwright.config.ts`: `NEXT_PUBLIC_ORDERS_API_URL=https://ordenes.test`.
  - Helper e2e `page.route()` con headers CORS; verificar el preflight
    en la versión instalada y documentarlo en el archivo, como el caveat
    de `routeWebSocket` en `chat.spec.ts`.
  - Estado "Enviando…": nombre y teléfono `readonly`, stepper/Quitar/Vaciar
    deshabilitados y sin doble envío.
  - `OrderSendBanner` (falla / tope), `ContactChannels` (con el teléfono), `CopyButton` y
    `order-text.ts`.
  - Tests unit de markup del banner y de `order-text`
    (`tests/unit/order-text.test.ts`: con un nombre y un teléfono canario,
    el texto copiado **no** los contiene; solo productos y total, AC-28).
  - e2e:
    - AC-20: 500, abort y timeout con `page.clock` → banner enfocado,
      carrito y datos intactos, y "Reintentar" con la **misma**
      `idempotency_key` (bodies capturados);
    - AC-22: tope al enviar → sin "Reintentar", con canales;
    - AC-24: doble clic (`dblclick` y dos `click` sin esperar) en "Enviar
      orden" → **un** POST; POST abortado → "Reintentar" → mock `200
      aceptada` con el mismo `RA-48271`, misma key en los dos bodies;
    - AC-17: body capturado con solo las claves del contrato, con
      `contacto = { nombre, telefono }` y el nombre normalizado;
    - un `invalida` del servidor con `contacto.nombre` (`requerido`,
      `formato`, `largo`) → error del nombre con el copy correcto;
    - nombre o teléfono cambiado después de una falla → "Reintentar" manda
      una `idempotency_key` **nueva**; sin cambios, la **misma**;
    - AC-28: "Copiar detalle del pedido" no contiene el nombre ni el teléfono
      canarios.
  - ✔ Tests en verde.
- [ ] **F14 — Rechazo por catálogo + `GET /v1/estado` al montar**
  (**depende de `ux-agent`**: Q-F2(b), bajada de la variante "tope al
  entrar"; el 409 sale de `ux.md` y puede avanzar).
  - 409 → `applyRechazoCatalogo`, aviso enfocado, formulario intacto y
    key nueva al reenviar.
  - Al montar con líneas disponibles:
    - `tope_alcanzado` → variante "Por ahora no podemos recibir órdenes
      desde el sitio" sin formulario;
    - `no_disponible` (manual o `flood`) o error → sin cambios.
  - e2e AC-15 (409 → reenvío con key distinta y precio nuevo; total
    igual a `total_vigente`), AC-22 (tope al entrar) y GET `no_disponible`
    al entrar → formulario visible; al enviar, renovación de token con
    `no_disponible` → falla genérica.
  - ✔ Tests en verde.
- [ ] **F15 — Confirmación.**
  - `OrderConfirmation`: número, "Copiar número", "Qué sigue" con el
    **nombre y apellido** y el teléfono dados ("RenovArte va a contactar a
    {nombre} al {teléfono}…"; el nombre como texto plano y `break-words`),
    canales con `tel:` (1130579528), `mailto` más asunto e `ig.me`, "Lo que
    pediste" y "Volver al catálogo"; foco en el `h1`.
  - El nombre **no viene en la respuesta** `aceptada`: se toma del estado
    del formulario (normalizado, el mismo valor enviado) y, tras una
    recarga, del `confirmation-store`.
  - Vaciar el carrito y el formulario; borrar el borrador de `contact-draft`.
  - `src/lib/orders/confirmation-store.ts` (AC-28, Q-F5 aprobada): se
    escribe solo después de `aceptada`, por allowlist
    `{numero_orden, lineas, total, nombre, telefono}`; el `CartProvider`
    borra la confirmación, el borrador y la key en curso al navegar o al
    montar fuera de `/carrito`.
  - `tests/unit/order-confirmation.test.tsx` (AC-10: nombre y teléfono en
    "Qué sigue"; un nombre con `<script>` o muy largo sale escapado) y
    `tests/unit/confirmation-store.test.ts` (nunca otro dato que nombre y
    teléfono aunque se le pase un contacto con `email`/`direccion`/
    `localidad`; JSON corrupto → nada).
  - e2e AC-10 / AC-28 / AC-18:
    - 201 (respuesta sin nombre) → confirmación `RA-48271` con el nombre y
      el teléfono tipeados, contador oculto;
    - recarga en `/carrito` → mismo número y mismo "contactar a {nombre} al
      {teléfono}";
    - `sessionStorage` con **solo nombre y teléfono** como datos de contacto
      y sin borrador;
    - navegar a `/` → ninguna clave de contacto en `sessionStorage`;
      `page.goto('/')` (carga completa) → tampoco; volver a `/carrito` →
      vacío;
    - página nueva del mismo contexto → sin confirmación;
    - `localStorage` nunca con datos de contacto (canarios de nombre y
      teléfono).
  - ✔ Tests en verde.

#### Chat

- [ ] **F16 — Reducer y provider del chat.**
  - Acción `COMBO_ADDED` y estado `combosAgregados` en
    `src/lib/chat/reducer.ts`.
  - `closeChat({ restoreFocus })`, con default sin cambio de
    comportamiento.
  - `ChatAnnouncer` dentro del diálogo, fuera del `role="log"`.
  - `tests/unit/chat-reducer.test.ts` ampliado (AC-7: no toca `isOpen`
    ni `messages`).
  - ✔ Test en verde; `chat.spec.ts` sigue verde.
- [ ] **F17 — `ChatComboAddToCart` en `ChatComboCard`** (el caso "combo
  con una línea ya en 20" usa la respuesta de `ux-agent` a Q-F2(c) de F7).
  - Botón "Agregar combo al carrito" → "Agregar otra vez" (mismo nodo),
    confirmación "✓ Agregaste…", "Ver carrito" (cierra sin devolver el
    foco y enfoca el `h1` de `/carrito`), `aria-describedby` y sufijo
    `sr-only`.
  - `tests/unit/chat-combo-card.test.tsx` ampliado (los casos existentes
    siguen igual).
  - e2e en `chat.spec.ts`:
    - AC-6: líneas con el mismo nombre y precio que la card; "Agregar
      otra vez" suma;
    - AC-7: el panel sigue abierto, "Ver carrito" y reabrir el FAB
      conservan el hilo y el estado "agregado".
  - ✔ Tests en verde.

#### Cierre

- [ ] **F18 — Robustez transversal (e2e).**
  - AC-21: con `https://ordenes.test/**` abortado, la grilla, el filtro,
    la búsqueda, la ficha y el chat funcionan.
  - Sin JS (`javaScriptEnabled: false`): el link del header navega y se
    ven los avisos `noscript` en la ficha y en `/carrito`.
  - `reducedMotion: "reduce"`: sin escala ni fade.
  - Viewport de 390px sin scroll horizontal en `/carrito` y en la ficha.
  - AC-26: `scripts/check-leak.mjs` suma el patrón
    `/discord(?:app)?\.com\/api\/webhooks/i` a `FORBIDDEN`; `pnpm
    check:leak` sigue en verde (el catálogo nunca referencia Discord).
  - ✔ Tests en verde; `check:leak` en verde con el patrón nuevo.
- [ ] **F19 — Docs.**
  - `README.md`: sección "Carrito y órdenes (spec 0017)", con la env var,
    el comportamiento sin ella y el desarrollo contra el harness de B18.
  - `.env.local.example`: `NEXT_PUBLIC_ORDERS_API_URL`.
  - Nota de referencia de la 0017 en `specs/constitution.md` §II.4 (no
    es una enmienda).
  - ✔ Revisión humana del texto.
- [ ] **F20 — Gate y smoke real** (depende de **B18**, **B20** y de
  `## Infra`).
  - `pnpm gate` completo en verde.
  - Revisión manual a 390px y a escritorio contra `ux.md` y el mockup.
  - Smoke local contra `dev/local-server.ts` de B18 con
    `NEXT_PUBLIC_ORDERS_API_URL=http://localhost:<puerto>`: `aceptada`,
    409 y tope.
  - Después del deploy, junto con B19 y con aprobación humana: una orden
    real desde producción; el número en pantalla coincide con el del
    mail y el del mensaje de Discord (AC-13/AC-23, verificado por el
    CTO/CEO; el frontend solo muestra el número recibido).
  - ✔ Salida real del gate adjunta en el reporte; smoke confirmado por
    el CTO/CEO.

## Infra

Repo: `renovarte-ordenes` (**público**). Diseño: `plan.md` `## Infra`,
revisión 2 (decisiones I-D1…I-D13, divergencias N1–N4). Prefijo de tareas
`I`. Los IDs I1–I17 se mantienen; I18–I20 son nuevas. Nada de esto se
ejecuta en modo diseño.
- Cada instalación, commit y push necesita aprobación humana
  (`CLAUDE.md`).
- `devops-agent` **nunca** corre `terraform apply`/`destroy`: lo hace el
  CTO/CEO en vivo.
- `terraform validate` no necesita credenciales.

### Estimate

**Tamaño M/L: ~12 a 17 h** (antes: 11 a 15 h; ~2 h menos por retirar I19 y reducir I18), más ~1,5–2,5 h de sesión
en vivo con el CTO/CEO.

| Bloque | Tareas | Horas |
|---|---|---|
| Verificaciones y bootstrap manual (AWS + GitHub) | I1–I2, I20 | ~1,5–2 h (+ sesión en vivo) |
| Terraform (datos, cómputo, URL, SES, IAM, SSM, budget, flood, OIDC) | I3–I11 | ~7–9 h |
| Terraform nuevo: alertas operativas (`discord-retention`/I19, retirada) | I18 | ~1,5–2 h |
| CI/CD | I12 | ~1–1,5 h |
| Docs, validate y gate | I13–I14 | ~1,5–2 h |
| Apply, verificación post-apply y cierre | I15–I16 | ~1,5–2,5 h (en vivo) |
| Opción B (solo si falla B19) | I17 | ~1,5–2 h + propagación DNS |

**Riesgos que pueden mover el estimate:**

- Cuota de concurrencia de la cuenta en 10 (I1): el aumento puede tardar
  días, y si no llega hay que aplicar sin reserva (I-D4).
- Que `value_wo` no evite que el valor llegue al estado (I16): se pasa al
  fallback de parámetros creados por CLI (~0,5 h).
- Que la alarma de latido oscile (I16): segundo schedule diario, con OK
  de backend.
- Escalar a la opción B.

### Tasks

#### Verificaciones y bootstrap (manuales, con el CTO/CEO)

- [ ] **I1 — Verificaciones de cuenta** (solo lectura, con el CTO/CEO, sin
  crear nada). Complementa B1:
  - `aws lambda get-account-settings` → `ConcurrentExecutions`. Si es 10,
    elegir entre (a) pedir el aumento en Service Quotas y esperar, o (b)
    aplicar con `orders_http_reserved_concurrency = null` (I-D4).
  - `aws sesv2 get-account` en `us-east-1` → confirmar
    `ProductionAccessEnabled=false` (sandbox) y la cuota de envío.
  - Billing → Cost allocation tags → que `Project` esté **activa**.
  - `aws iam list-open-id-connect-providers` → si ya existe
    `token.actions.githubusercontent.com`, reusarlo.
  - `aws cloudwatch describe-alarms` → que la cuenta tenga **≤ 6
    alarmas** (hacen falta 4 más dentro de las 10 gratis; si hay 7 u 8,
    se unen las dos alarmas de `orders-http`, I-D13).
    `aws cloudwatch list-metrics --namespace` de namespaces propios →
    **≤ 7 custom metrics** (hacen falta 3).
  - `terraform version` local ≥ 1.11 (por `value_wo`, I-D9).
  - Free tier de 12 meses de la cuenta (lo mismo que en la 0016): el
    CTO/CEO confirmó el 2026-10-07 que **vence el 2027-03-16**. Después
    de esa fecha, el gasto esperado sigue < USD 0,10/mes (Lambda y
    DynamoDB tienen cuota gratis permanente) y el peor caso de
    CloudWatch del `plan.md` suma ~USD 1,30/mes, muy por debajo del tope
    de USD 20 (RNF-14).
- [ ] **I2 — Bootstrap IAM y OIDC** (manual del CTO/CEO en consola/CLI,
  con aprobación). `devops-agent` escribe `terraform/iam-bootstrap-policy.json`,
  gitignoreado igual que en la 0016. La policy va acotada al prefijo
  `renovarte-ordenes-*` en:
  - roles y policies IAM, y `iam:PassRole`;
  - funciones Lambda (las 3): `*FunctionConcurrency`,
    `*FunctionUrlConfig`, `AddPermission`/`RemovePermission`,
    `*FunctionEventInvokeConfig` si hiciera falta, y el resto de lo que
    usa Terraform;
  - tabla DynamoDB (incluidos TTL y `UpdateTable` para deletion
    protection);
  - SNS (los 2 topics): `Create/Delete/GetTopicAttributes/SetTopicAttributes/Subscribe/Unsubscribe/GetSubscriptionAttributes`;
  - Budgets, Scheduler (los 2 schedules) y alarmas de CloudWatch
    (`alarm:renovarte-ordenes-*`);
  - log groups `/aws/lambda/renovarte-ordenes-*`, incluidos
    `logs:PutMetricFilter`/`DeleteMetricFilter`;
  - SSM `parameter/renovarte-ordenes/*`.
  Excepciones de scope, a declarar explícitamente:
  - SES: la identidad es el propio email, así que se acota al **ARN exacto**
    (`identity/renovartebyjuli@gmail.com`, más el dominio si llega la
    opción B), no por prefijo.
  - `logs:DescribeLogGroups` solo admite `log-group:*`;
    `logs:DescribeMetricFilters` se confirma al escribir la policy (si no
    admite ARN, va con `*` y se declara).
  - `lambda:GetFunctionCodeSigningConfig` y `sts:GetCallerIdentity`
    necesitan `*` (igual que en la 0016).
  El CTO/CEO crea el usuario `renovarte-ordenes-terraform`, le asocia la
  policy y configura un perfil local. Si hace falta, crea el OIDC provider
  de GitHub (`aud = sts.amazonaws.com`): es un singleton de la cuenta y no
  lo gestiona este repo (I-D10).
- [ ] **I20 — Configuración del repo público en GitHub** (nueva; manual
  del CTO/CEO, USD 0, justo después de B2):
  - Ruleset sobre `main`: PR obligatorio, sin force push ni borrado, check
    requerido `gate` (y `terraform` cuando corra), mismo patrón que
    `renovarte-catalogo`/`renovarte-pipeline`.
  - Settings → Code security: **secret scanning** y **push protection**
    activados.
  - Settings → Actions: "Require approval for all external
    contributors" para workflows de PRs de forks; permisos del
    `GITHUB_TOKEN` por default en solo lectura.
  - Variable del repo (no secreto) `AWS_DEPLOY_ROLE_ARN`: se carga en I15.
  - ✔ Captura o checklist en el PR de I12.

#### Terraform

- [ ] **I3 — Esqueleto `terraform/`:**
  - `versions.tf` (`aws ~> 6.28` por `invoked_via_function_url`,
    `archive ~> 2.4`, Terraform **`>= 1.11`** por `value_wo`);
  - `providers.tf` (`us-east-1`, `default_tags Project=renovarte-ordenes`);
  - `locals.tf`: nombres físicos (incluidos `flood_alarm_name` y
    `budget_name`, que usan tanto los recursos como las env vars de
    `budget-guard`);
  - `variables.tf`: `project_name`, `aws_region`,
    `order_recipient_email`, `order_sender_email`, `allowed_origins`
    (lista), `catalog_products_url`, `orders_http_reserved_concurrency`
    (default 5, nullable), `aws_budget_limit_usd` (20),
    `budget_notification_email` (sin default), **`alerts_email`** (default
    = `budget_notification_email`), `flood_invocations_per_minute` (300),
    **`config_revision`** (1), `sender_domain`
    (""), `github_repo`, `github_oidc_provider_arn`, y los umbrales y
    costos unitarios del ledger con los defaults del RFC;
  - `terraform.tfvars.example` con placeholders (sin emails ni IDs
    reales: el repo es público).
  - Entradas de `.gitignore` como en la 0016, más `*.tfvars` salvo
    `.example` e `iam-bootstrap-policy.json`.
  - Depende de B2 (el repo existe).
- [ ] **I4 — `dynamodb.tf`** (I-D5): tabla `-datos` on-demand, `pk` S, TTL
  `expira_en` y `deletion_protection_enabled = true`.
- [ ] **I5 — `lambda.tf` + `logs.tf`** (I-D3, I-D4):
  - `archive_file` de `dist/`;
  - log groups con retención de 14 días (`orders-http` y `budget-guard`);
  - `orders-http` y `budget-guard` `nodejs22.x` arm64, log format `Text`,
    con timeout, memoria y env vars de la tabla I-D3 (incluidas
    `DISCORD_WEBHOOK_PARAM` y `CONFIG_REVISION` en `orders-http`, y
    `FLOOD_ALARM_NAME`/`BUDGET_NAME` desde `locals` en `budget-guard`),
    `depends_on` los log groups;
  - `reserved_concurrent_executions` en `orders-http`;
  - `ignore_changes = [reserved_concurrent_executions, filename,
    source_code_hash]` (solo `filename`/`source_code_hash` en los otros).
  - Para `plan`/`apply` depende de B2/B15/B16/B23 (`pnpm build`);
    `validate` no lo necesita.
- [ ] **I6 — `function-url.tf`** (I-D1, I-D2):
  - `aws_lambda_function_url` NONE/BUFFERED con el bloque `cors`;
  - 2 `aws_lambda_permission` (`InvokeFunctionUrl` +
    `InvokeFunction` con `invoked_via_function_url = true`);
  - output `orders_api_url`.
- [ ] **I7 — `ses.tf` + `iam.tf` (roles de `orders-http` y
  `budget-guard`)** (I-D5, I-D7, I-D9):
  - identidad de email SES v2 (opción A); los recursos de la opción B van
    con `count` según `sender_domain`;
  - rol `orders-http`: logs de su propio group; DynamoDB `GetItem`/
    `PutItem`/`UpdateItem` **sin `DeleteItem`**; `ses:SendEmail` con las
    condiciones `Recipients`/`FromAddress`/`Null`; `ssm:GetParameter`
    sobre **los dos** parámetros (HMAC y webhook);
  - rol `budget-guard`: logs, DynamoDB `LeadingKeys=["CONTROL"]` y
    `*FunctionConcurrency` sobre `orders-http`.
  - Cubre AC-17 del lado de infra.
- [ ] **I8 — `ssm.tf`** (I-D9): dos `aws_ssm_parameter` SecureString
  (`/renovarte-ordenes/hmac-secret` y
  `/renovarte-ordenes/discord-webhook-url`) con **`value_wo`**
  placeholder y `value_wo_version = 1` (no `value` + `ignore_changes`,
  que filtra el valor real al estado: N1). Los nombres salen como env
  vars `HMAC_SECRET_PARAM` y `DISCORD_WEBHOOK_PARAM`.
- [ ] **I9 — `budget.tf` + `scheduler.tf`** (I-D6):
  - budget COST de USD 20 con filtro por tag;
  - notificación del 80 % por email y del 100 % por SNS **y email**;
  - topic SNS del kill-switch con la policy para `budgets.amazonaws.com`
    y `cloudwatch.amazonaws.com`;
  - suscripción + permiso Lambda para `budget-guard`;
  - schedule de reset mensual + **un** rol de Scheduler con
    `lambda:InvokeFunction` sobre `budget-guard` (el Lambda
    `discord-retention` y su schedule diario se retiraron, I19).
  - Coordinar con B16 el formato del mensaje SNS del Budget.
- [ ] **I10 — `alarm.tf`** (I-D8; aprobada por el CTO/CEO y aceptada por
  backend): alarma `Invocations` Sum de 60 s > 300 sobre `orders-http`,
  con `alarm_actions` = [topic del kill-switch, topic de alertas
  operativas de I18] y sin `ok_actions`. Nombre desde `locals` (el mismo
  que `FLOOD_ALARM_NAME`). Coordinar con B16 el mensaje de ejemplo.
- [ ] **I11 — `github-oidc.tf`** (I-D10):
  - rol `renovarte-ordenes-github-deploy-role`, con trust sobre
    `var.github_oidc_provider_arn`, `aud` y `sub` fijados a este repo y
    `refs/heads/main`;
  - inline policy con `lambda:UpdateFunctionCode`, `GetFunction` y
    `GetFunctionConfiguration` sobre **los 2 ARN** (`orders-http` y
    `budget-guard`);
  - output del ARN del rol, que va como **variable** (no secreto) del
    repo en GitHub.
- [ ] **I18 — `alerts.tf`: alertas operativas** (nueva; I-D13; reducida el
  2026-10-05):
  - topic `renovarte-ordenes-alertas-operativas` sin KMS, policy con
    `SNS:Publish` solo para `cloudwatch.amazonaws.com` +
    `aws:SourceAccount`, suscripción `email` a `var.alerts_email`;
  - 1 `aws_cloudwatch_log_metric_filter` sin dimensiones, namespace
    `RenovArte/Ordenes`, `metric_value = "1"`: `canal-fallido` (log group
    de `orders-http`);
  - 1 alarma: `-canal-degradado` (≥ 1 en 300 s, `notBreaching`) hacia este
    topic. Se quitan `borrado-no-programado` y `retencion-sin-latido`
    (retención retirada).
  - Depende de que el backend emita `canal_fallido` (B16/B22 +
    `lib/log.ts`).
- ~~**I19 — `discord-retention.tf`: Lambda de borrado**~~ — **RETIRADA el
  2026-10-05** (AC-29 retirado). Ya no se crean el Lambda, su log group,
  su rol, su schedule ni sus alarmas. El diseño está en el historial de
  git (commit `8371ac9`).

#### CI/CD

- [ ] **I12 — Workflows** (I-D11, I-D10):
  - `ci.yml`: `on: pull_request` (nunca `pull_request_target`),
    `permissions: { contents: read }`, gate + build; job de Terraform solo
    si cambió `terraform/**`; `concurrency` y `timeout-minutes`.
  - `deploy.yml`: `workflow_dispatch`, guard `ref == main`,
    `permissions: { id-token: write, contents: read }`,
    `aws-actions/configure-aws-credentials` con `vars.AWS_DEPLOY_ROLE_ARN`,
    gate, build, zip, `update-function-code` + `wait function-updated` ×
    **3**.
  - Extender `check:leak` (B17) con patrones de credenciales, IDs de
    cuenta de 12 dígitos en `README.md`/`docs/` y `*.tfvars`/`*.tfstate`
    trackeados.
  - Sin `gitleaks`: lo reemplaza el secret scanning con push protection
    de GitHub (I20).

#### Docs y validación

- [ ] **I13 — README y runbook (infra):**
  - README: "Terraform" (prerrequisito `pnpm build`, Terraform ≥ 1.11,
    pasos) y "Coordinación de valores" (tabla de `plan.md`) con
    placeholders: **sin** ID de cuenta, ARNs reales, URL del webhook ni
    IDs de canal, servidor o webhook de Discord.
  - `docs/runbook.md`, secciones de infra:
    - verificar la identidad SES y confirmar la suscripción de alertas;
    - cargar y rotar el secreto HMAC y la URL del webhook
      (`read -rs` + `put-parameter --overwrite` → subir
      `config_revision` → `apply`; N2);
    - qué significa cada alarma (flood y canal degradado) y la consulta de Logs Insights
      para ver el detalle sin datos personales;
    - reactivar a mano (`put-function-concurrency` o
      `delete-function-concurrency` + `CONTROL`) después del Budget o
      del flood;
    - cambiar la reserved concurrency (I-D4);
    - no hacer `apply` que toque concurrency con el kill-switch activo;
    - pasar a la opción B.
- [ ] **I14 — `terraform fmt -check`, `terraform init -backend=false` y
  `terraform validate` en verde, más `pnpm gate` del repo.**
  - Output real en el PR.
  - `init` descarga providers: necesita aprobación humana, como en la
    0016.

#### Apply y cierre (en vivo, con el CTO/CEO)

- [ ] **I15 — Primer apply**, con aprobación explícita del CTO/CEO, en
  este orden:
  1. `pnpm build`.
  2. `terraform plan` → revisar.
  3. `apply`.
  4. El CTO/CEO hace clic en el mail de verificación de SES
     (renovartebyjuli@gmail.com, vence en 24 h).
  5. El CTO/CEO confirma la suscripción email del topic de alertas
     operativas.
  6. `put-parameter --overwrite` del secreto HMAC (generado localmente).
  7. `put-parameter --overwrite` de la URL del webhook de Discord (B24).
     Antes de este paso, toda orden de prueba dispara `canal-degradado`:
     es lo esperado.
  8. Pasar `orders_api_url` a `frontend-agent` (Vercel, solo Production)
     y el ARN del rol de deploy a `AWS_DEPLOY_ROLE_ARN` (I20).
  - Depende de B15–B17, B24 (canal y webhook creados), I1–I14, I18 e
    I20.
  - Desbloquea B19.
- [ ] **I16 — Verificación post-apply** (sin gasto relevante):
  - `aws iam simulate-principal-policy` sobre el rol de `orders-http` con
    `ses:Recipients` = otro email → **denied**, y con el destinatario fijo
    → allowed (AC-17, capa IAM).
  - `curl -X OPTIONS` con el `Origin` de producción y con uno ajeno →
    headers CORS solo en el primero.
  - `aws sns publish` de un mensaje de prueba con la forma del Budget →
    `budget-guard` deja la concurrency en 0 y `CONTROL` apagado. Después,
    `aws lambda invoke` de `budget-guard` con `{"mode":"reset"}` → vuelve
    a 5 o sin reserva (AC-22, capa infra).
  - `aws logs test-metric-filter` con líneas de ejemplo del backend
    (`canal_fallido`) → matchea (N4).
  - `grep -c 'discord.com' terraform.tfstate` y un grep del secreto HMAC
    después de un `terraform plan` → **0** (N1). Si aparece: fallback
    de I-D9.
  - Verificar la retención de 14 días en los 2 log groups.
  - **Al mes:** en Cost Explorer, confirmar si SES aparece con
    `Project=renovarte-ordenes` y documentar el resultado (I-D6).
- [ ] **I17 — (Condicional: solo si B19 falla con la opción A) Opción
  B:**
  - el CTO/CEO compra el dominio;
  - `sender_domain` en tfvars → apply;
  - cargar en el registrador los 3 CNAME DKIM, MX + TXT de MAIL FROM y
    DMARC `p=none`;
  - esperar la verificación;
  - actualizar `order_sender_email` → apply;
  - repetir B19.
