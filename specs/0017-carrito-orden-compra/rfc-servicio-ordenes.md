# RFC — Servicio de órdenes (spec 0017)

**Autor:** `backend-agent`. **Estado:** propuesta, revisión 2. Pendiente de
aprobación del CTO/CEO en el gate de Fase 3, junto con las secciones
`## Infra` (`devops-agent`) y `## Frontend` (`frontend-agent`) de
`plan.md`.

**Cambios de la revisión 2 (2026-09-30):**

- **Nuevo: doble canal de entrega.** Cada orden aceptada se entrega
  siempre por mail (SES) **y** por un mensaje a un canal privado de
  Discord vía webhook (§5, §10 y §10.2). Los dos canales llevan el mismo
  número de orden. La orden se acepta si **al menos un** canal confirmó
  la entrega (§5.3).
- **Idempotencia por canal** (§5): cada canal es at-most-once por
  separado, y un reintento reintenta solo el canal que falló de forma
  definitiva. Ya no se borra `IDEM#`, así que `orders-http` no necesita
  `dynamodb:DeleteItem`.
- Incorporadas las decisiones del CTO/CEO: remitente opción A con smoke
  test; repo `renovarte-ordenes` **público**; registro seudonimizado de
  90 días; alarma de flood aprobada, que `budget-guard` acepta con motivo
  `flood` (§8.4); Q-F1 → **máximo 100 líneas**; Q-F5 aprobado; la Ley
  25.326 queda como paso previo a producción.
- Q-F4 resuelto: un `form_token` de menos de 3 s responde
  `token_vencido` (§6.2).
- **Nuevo (decisión del CTO/CEO, 2026-09-30e): borrado automático de los
  mensajes de Discord a los 60 días** (AC-29), con un Lambda programado
  diario que borra por el propio webhook (§10.3). El canal lo ven solo
  los propietarios de RenovArte (paso manual, §7).
- Numeración de AC alineada con la spec enmendada por `product-agent`
  (AC-23 a AC-29).
- Aceptadas las divergencias de `devops-agent` (§13).

**Alcance:** arquitectura del repo nuevo `renovarte-ordenes`. Cubre el
contrato HTTP con `renovarte-catalogo`, la validación contra el catálogo
publicado, la idempotencia por canal, los destinos fijos, el anti-abuso,
los datos personales, el tope de USD 20/mes, el número de orden, los dos
canales de entrega y el borrado automático en Discord. La infraestructura pura (Terraform, IAM, CI, deploy,
nombres físicos) es de `devops-agent`; la §10.4 y la §13 dicen qué se le
pasa.

**Constitución:** no hay conflictos. `renovarte-catalogo` sigue siendo un
build estático (§II.4 de ese repo; AC-14). La orden se crea fuera de ese
repo, con el mismo patrón que la 0016 (nota de referencia en la
constitución del catálogo, sin enmienda). §II.5 root ($0 infra) tiene una
excepción acotada y aprobada en la spec (RNF-14, USD 20/mes); Discord no
suma costo. El repo nuevo cumple §II.6 (submódulo), §II.7 (`CLAUDE.md`
propio) y §III.11 (no se crea en esta fase). §I.1 (sin costo, margen ni
precio LACA): el único insumo de precios es el `products.json`
**público**, y un leak-audit en CI cubre los dos canales (§6.4).

---

## 1. Repo nuevo

**`renovarte-ordenes`, público** (decisión del CTO/CEO).

- Sigue la convención `renovarte-<capacidad>` y usa el término de negocio
  de la spec. El nombre es genérico a propósito, para poder sumar
  funcionalidad (por ejemplo, un estado de orden) sin renombrar.
- Al ser público: el README y los docs **no publican** el ID de cuenta,
  ARNs reales, la URL del webhook de Discord ni el ID del canal o del
  servidor. Van placeholders; los valores reales quedan en `terraform
  output` local y en SSM (I-D12 de `## Infra`). `check:leak` falla si
  aparece una URL de webhook de Discord (§6.4).
- Nace con `README.md`, `CLAUDE.md` (mismas reglas que
  `renovarte-chat-gateway/CLAUDE.md`, más una sección de **datos
  personales**, §7) y `docs/runbook.md`. Sin PRD ni `constitution.md`
  propios: la fuente es la PRD de `renovarte-catalogo` y esta spec.
- Se crea recién en Fase 4, con aprobación humana.

## 2. Stack

**AWS Lambda (Node.js 22, TypeScript) + DynamoDB + Amazon SES v2 + webhook
de Discord**, en la misma cuenta AWS que la 0016. Mismo tooling que
`renovarte-chat-gateway`: pnpm, vitest, eslint, tsc strict, `pnpm gate` =
lint + typecheck + test + check:leak.

- Dependencias de runtime: solo `@aws-sdk/*`. El webhook de Discord se
  llama con el `fetch`, `FormData` y `Blob` nativos de Node 22, **sin
  librería de Discord**. Los guards se escriben a mano.
- **Superficie HTTP:** Lambda Function URL (`AuthType NONE`) + reserved
  concurrency, adoptada por `devops-agent` (I-D1). La Function URL
  maneja CORS y el preflight (§6.4).
- **Tres Lambdas:** `orders-http` (las 2 rutas), `budget-guard` (§8.4) y
  `discord-retention` (borrado a los 60 días, §10.3).

## 3. Contrato HTTP con `renovarte-catalogo`

**El requerimiento de Discord no cambia el contrato.** El visitante no se
entera de cuántos canales hay; solo cambian dos límites documentados
(§3.2) y la semántica interna de `aceptada` (§5.3).

Base URL: la de la Function URL (termina en `/`), expuesta al catálogo
como `NEXT_PUBLIC_ORDERS_API_URL`. Es pública, no un secreto. Todas las
respuestas son JSON con `v: 1` y **un discriminante `resultado`**. El
cliente decide por `resultado`, nunca por el texto. Si el body no parsea
o no trae un `resultado` conocido, es **falla genérica**. Todas las
respuestas llevan `Cache-Control: no-store`. El handler **no** emite
headers `Access-Control-*` (§6.4).

### 3.1 `GET /v1/estado` — disponibilidad + token de formulario

Es barato: no escribe en DynamoDB, lee el flag de control desde una caché
en memoria de 30 s y firma un HMAC. Resuelve la pregunta #F de `ux.md` y
entrega el `form_token` anti-bot de §6.2.

```ts
// 200
type EstadoResponse =
  | { v: 1; resultado: "disponible"; form_token: string }
  | { v: 1; resultado: "tope_alcanzado" }
  | { v: 1; resultado: "no_disponible" }; // corte manual o por flood → el cliente lo trata como falla genérica
```

El cliente lo llama al montar `/carrito` si hay líneas. Si falla, **no
bloquea el formulario**: la garantía está en el POST. Antes de enviar, si
no tiene token o el que tiene está por vencer, pide uno nuevo.

### 3.2 `POST /v1/ordenes` — crear la orden

`Content-Type: application/json`. Body de 16 KB como máximo (100 líneas
ocupan ~7 KB: los `id` del catálogo tienen ≤ 9 caracteres). **Esquema
estricto:** cualquier clave no listada hace que la orden se rechace como
`invalida`, incluido cualquier intento de `to`, `cc`, `bcc`,
`destinatario`, `reply_to`, `webhook`, `canal`, etc. (AC-17).

```ts
interface CrearOrdenRequest {
  v: 1;
  idempotency_key: string;        // UUID v4 generado por el cliente (reglas en §5.1)
  form_token: string;             // de GET /v1/estado (§6.2)
  lineas: Array<{
    producto_id: string;          // `id` de products.json
    cantidad: number;             // entero 1..20 (ux.md #D)
    precio_visto: number;         // entero ARS: el precio_venta que el visitante tenía en pantalla
  }>;                             // 1..100 líneas (Q-F1), producto_id sin repetir
  total_visto: number;            // entero ARS = Σ precio_visto × cantidad, lo que el visitante vio
  contacto: {
    nombre: string;               // 2..100 caracteres tras trim
    email?: string;               // ≤254, forma x@y.zz
    telefono?: string;            // 8..15 dígitos tras quitar espacios, - ( ) +
    direccion: string;            // 4..200
    localidad: string;            // 2..100
  };                              // email y/o teléfono: al menos uno (AC-9)
  sitio_web?: "";                 // honeypot: debe venir ausente o vacío (§6.2)
}
```

En todos los campos de texto se rechazan CR/LF, los caracteres de control
(Unicode `Cc`) y los de control bidireccional (U+202A–U+202E,
U+2066–U+2069). Esto protege los headers del mail, el render de Discord
(§10.2) y la legibilidad de los dos canales.

El cliente **no** manda nombre, presentación ni subtotales de producto:
el servidor los toma del catálogo publicado. Tampoco puede mandar
destinatario, asunto, canal ni ningún otro campo de entrega.

Respuestas:

```ts
type CrearOrdenResponse =
  // 201 (primera vez) o 200 (reintento idempotente de la misma orden).
  // Significa: al menos un canal de entrega (mail o Discord) confirmó la orden (§5.3)
  | { v: 1; resultado: "aceptada"; numero_orden: string; recibida_en: string /* ISO-8601 UTC */ }

  // 409: no se entregó nada por ningún canal. El cliente actualiza las líneas y pide reenviar
  | { v: 1; resultado: "rechazada_por_catalogo";
      lineas: Array<
        | { producto_id: string; estado: "precio_cambiado"; precio_vigente: number }
        | { producto_id: string; estado: "no_disponible" }
      >;                          // solo las líneas con problema
      total_vigente: number;      // Σ precio_vigente × cantidad sobre las líneas disponibles
    }

  // 422: datos que el servidor rechaza (AC-9, defensa en profundidad)
  | { v: 1; resultado: "invalida";
      errores: Array<{ campo: CampoOrden | null; codigo: "requerido" | "formato" | "largo" | "contacto_requerido" | "token_vencido" | "no_permitido" }>;
    }                             // errores: [] → el cliente muestra el error general arriba del formulario
                                  // token_vencido = token fuera de su ventana de validez (vencido o de < 3 s, §6.2)

  // 503: tope mensual (AC-22). Sin "Reintentar" en la UI
  | { v: 1; resultado: "tope_alcanzado" }

  // 429 / 403 / 500 / 502 / 503: falla genérica reintentable (AC-20)
  | { v: 1; resultado: "falla"; codigo: "limite_frecuencia" | "envio_fallido" | "catalogo_no_disponible" | "en_proceso" | "estado_incierto" | "origen" | "mantenimiento" | "interno" };

type CampoOrden =
  | "contacto.nombre" | "contacto.email" | "contacto.telefono"
  | "contacto.direccion" | "contacto.localidad" | "contacto"   // "contacto" = falta email y teléfono
  | "lineas" | "total_visto" | "form_token";
```

**Diferencias con la revisión 1**, las únicas que ve `frontend-agent`:
`lineas` pasa de 1..30 a **1..100**, y se documenta que `token_vencido`
también cubre el token de menos de 3 s. Los tipos no cambian.

**Mapeo a los estados de `ux.md`:**

| `resultado` | Estado UX |
|---|---|
| `aceptada` | Confirmación (AC-10). `numero_orden` es exactamente el que va en el mail y en Discord (AC-13) |
| `rechazada_por_catalogo` | "Precio o producto cambiado al enviar" |
| `tope_alcanzado` | "Orden no enviada — tope" (sin Reintentar) |
| `invalida` con `campo` mapeable | Errores por campo + resumen |
| `invalida` con `campo: "form_token"`, `codigo: "token_vencido"` | **No se muestra**: el cliente pide un token nuevo, respeta su espera mínima de 3 s y reintenta **una sola vez**, con la misma `idempotency_key` |
| `invalida` sin campos mapeables | Error general arriba del formulario |
| `falla` (cualquier `codigo`), status 5xx sin body, timeout (15 s en el cliente), error de red | "Orden no enviada — falla" (reintentable) |

El `codigo` de `falla` sirve para diagnóstico y logs; `ux.md` no define
copy distinto por código y no hace falta.

**Invariante (AC-20):** el servidor **nunca** responde `aceptada` si
ningún canal tiene una confirmación positiva de entrega: un `MessageId`
de SES o un `id` de mensaje de Discord devuelto por `?wait=true`.

## 4. Validación contra el catálogo publicado (AC-15, AC-16)

Sin cambios respecto de la revisión 1.

### 4.1 Fuente

Es el mismo archivo público que consumen el navegador y el sync de
`renovarte-colibri-rag`: `https://<dominio de producción de
renovarte-catalogo>/data/products.json`, configurado con la env var
`CATALOG_PRODUCTS_URL`. No usa secretos y no cambia el schema de
`products.json`.

### 4.2 Por qué fetch en runtime con caché, y no snapshot empaquetado

Colibri-rag empaqueta `data/products.json` y lo actualiza con un PR de
sync cada 6 h más un redeploy manual. Para las órdenes eso rompería AC-15
en la dirección mala: después de cada republicación del catálogo, el
navegador tiene los precios nuevos y el servidor los viejos, y toda orden
honesta se rechazaría hasta que alguien mergee el sync y redeploye.

- `lib/catalog.ts` hace un GET del archivo (~512 KB) con **caché en
  memoria por contenedor de 5 min** y revalidación condicional
  (`If-None-Match`/ETag). Timeout de 3 s.
- **Refresco forzado ante discrepancia:** si alguna línea no coincide, se
  fuerza un refetch **una vez** y se vuelve a validar antes de rechazar.
- Guard copiado de colibri-rag (`isProduct`), sin import cruzado. Se
  extraen **solo** `id`, `nombre`, `presentacion` y `precio_venta`
  (allowlist). Aunque el archivo trajera una clave de costo por error, el
  servicio no la lee ni la puede renderizar en ningún canal.
- Si el fetch falla y no hay caché válida de menos de 24 h:
  `falla`/`catalogo_no_disponible`. **Nunca se acepta una orden sin
  catálogo contra el cual validar.**

### 4.3 Reglas

- `producto_id` inexistente → `no_disponible`.
- `precio_visto !== precio_venta` → `precio_cambiado` con
  `precio_vigente`.
- `total_visto !== Σ precio_visto × cantidad` → `invalida` con
  `campo: "total_visto"`.

Con al menos una línea con problema: `409 rechazada_por_catalogo` y no se
entrega nada por ningún canal. Rechazar en lugar de corregir, como
decidió `ux.md`.

**Q-F6 (confirmado):** `total_vigente` se calcula como Σ precio vigente ×
cantidad sobre las líneas disponibles (las que no tenían problema
aportan su `precio_visto`, que ya es el vigente). Es exactamente lo que
el cliente recalcula en local. Si alguna vez difiere, gana el total
local: el servidor vuelve a validar el próximo envío igual.

## 5. Entrega por dos canales e idempotencia por canal (AC-13, AC-20, AC-23, AC-24, AC-25)

### 5.1 Reglas del cliente (contrato para `frontend-agent`, sin cambios)

- `idempotency_key` nueva (`crypto.randomUUID()`) la primera vez que se
  toca "Enviar orden" para una combinación dada de líneas, total y
  contacto.
- "Reintentar envío" y el reintento automático por `token_vencido`
  **reusan la misma key**.
- Cualquier cambio de línea, cantidad o contacto (incluido aplicar precios
  tras un `rechazada_por_catalogo`) genera una key nueva.
- La key vive en memoria de la página.

### 5.2 Estado por canal

El ítem `IDEM#<key>` guarda un estado **por canal**, `mail_estado` y
`discord_estado`, con estos valores:

| Estado | Significado | ¿Se reintenta con la misma key? |
|---|---|---|
| `enviando` | Hay un envío en curso (con `<canal>_intento_en`) | No. Con < 30 s → `en_proceso`; con ≥ 30 s se trata como `incierto` |
| `entregado` | Confirmación positiva: `MessageId` de SES o `id` de mensaje de Discord (se guarda en `mail_message_id` / `discord_message_id`) | No, nunca |
| `fallido` | Rechazo **definitivo, sin entrega**: el proveedor respondió y la orden seguro no se publicó | **Sí**, solo ese canal |
| `incierto` | Resultado ambiguo: timeout, conexión cortada después de enviar o 5xx del proveedor | **No, nunca** (at-most-once) |

Clasificación por proveedor (§10.1 y §10.2 tienen el detalle):

| Resultado | Mail (SES v2) | Discord (webhook) |
|---|---|---|
| `entregado` | 200 con `MessageId` | 200 con `id` (`?wait=true`) |
| `fallido` | 4xx con respuesta (`MessageRejected`, `AccessDenied`, throttling de SES, etc.); error antes de conectar (DNS, conexión rechazada); configuración ausente | 400, 401, 403, 404, 413; 429 (una request rate-limitada no se procesa); error antes de conectar; URL ausente o inválida en SSM |
| `incierto` | 5xx, timeout (4 s), socket cortado después de enviar | 5xx, timeout (4 s), socket cortado después de enviar, 2xx sin body parseable |

**Crítico para at-most-once:** el cliente SES se configura con
**`maxAttempts: 1`**. El SDK v3 reintenta solo 5xx y timeouts por
default, y eso podría duplicar el mail sin que el servicio se entere. El
cliente de Discord tampoco reintenta, salvo el caso acotado de 429 de la
§10.2.

### 5.3 Semántica de `aceptada`: al menos un canal entregado

**Decisión: la orden es `aceptada` si al menos un canal quedó
`entregado`.** El canal que falló queda registrado en el ítem y genera
una alerta operativa (§5.5). Es lo que fijan AC-20 y AC-25 de la spec
enmendada, y el CTO/CEO no lo objetó.

Justificación:

1. **La promesa al visitante es que RenovArte recibió la orden** (AC-10,
   AC-20), y eso es cierto con un solo canal entregado. El segundo canal
   es redundancia pedida por el CTO/CEO para no perder órdenes si el mail
   cae en spam; no es una condición de validez.
2. **Exigir los dos convierte la redundancia en fragilidad.** La
   disponibilidad pasa a ser el producto de las dos (A_mail × A_discord)
   en lugar de 1 − (1 − A_mail)(1 − A_discord). Un webhook borrado, una
   caída de Discord o un 429 bloquearían todas las órdenes, aunque el
   mail haya llegado.
3. **Exigir los dos genera falsos negativos que terminan en duplicados de
   negocio.** Si el mail llegó y Discord falló, el visitante vería "Tu
   orden no se envió" y probablemente la volvería a hacer (con otra key,
   si editó algo) o escribiría por Instagram. RenovArte recibiría la
   misma orden dos veces por vías distintas. AC-20 prohíbe confirmar lo
   que no llegó, no confirmar lo que sí llegó.
4. **El costo de un canal caído es operativo, no de negocio:** la orden
   está completa en el otro canal, y la alerta avisa para arreglar la
   configuración (por ejemplo, regenerar el webhook).

Resultado agregado de un intento:

| Mail | Discord | Respuesta | Qué hace un reintento con la misma key |
|---|---|---|---|
| `entregado` | cualquiera | `201`/`200 aceptada` | Devuelve `200 aceptada` con el mismo número; no envía nada |
| cualquiera | `entregado` | `201`/`200 aceptada` | Ídem |
| `fallido` | `fallido` | `502 falla`/`envio_fallido` | Reintenta **los dos** canales |
| `fallido` | `incierto` (o al revés) | `502 falla`/`envio_fallido` | Reintenta **solo** el `fallido`; si entrega → `aceptada` |
| `incierto` | `incierto` | `502 falla`/`estado_incierto` | No reintenta nada; siempre responde `estado_incierto` |
| alguno `enviando` < 30 s, ninguno `entregado` | | `falla`/`en_proceso` | El reintento posterior ve el estado final |

Con la respuesta `aceptada`, el canal que no entregó **no se repara
automáticamente**: el visitante no va a reintentar y no hay un proceso de
fondo. Queda la alerta (§5.5) y, si hace falta, RenovArte ve la orden en
el canal que sí la recibió. Un reintentador asíncrono se descartó por
costo y complejidad (necesitaría un scan o un índice, más un schedule)
para un caso que no pierde la orden.

### 5.4 Algoritmo del servidor

Con el orden de operaciones de §6.5:

1. Solo se reserva la key **después** de pasar todas las validaciones.
   `invalida` y `rechazada_por_catalogo` no la consumen.
2. **Reserva:** `PutItem IDEM#<key>` con `attribute_not_exists(pk)`,
   `mail_estado = discord_estado = "enviando"`, los dos `_intento_en`,
   `payload_hmac` (HMAC-SHA256 del payload canónico), `numero_orden`,
   `creado_en` y `expira_en` (Number, epoch-segundos, +90 días).
3. **Si la key ya existe:**
   - `payload_hmac` distinto → `invalida` con `errores: []` (el cliente
     violó la regla de la key; no se envía nada).
   - Algún canal `entregado` → `200 aceptada` con el mismo
     `numero_orden`, sin enviar.
   - Si no, para cada canal en `fallido` se hace un **claim
     condicional**: `UpdateItem SET <canal>_estado = "enviando",
     <canal>_intento_en = :ahora IF <canal>_estado = "fallido"`. Solo
     una request concurrente gana el claim, así que dos reintentos
     simultáneos no duplican. Los canales reclamados se envían en el
     paso 4.
   - Si no hay nada que reclamar: algún `enviando` con < 30 s →
     `en_proceso`; si no, `estado_incierto`.
4. **Envío en paralelo** (`Promise.allSettled`) de los canales en
   `enviando` de esta request, con **timeout de 4 s por canal**. Los dos
   usan el mismo modelo de orden ya validado (§9.1) y, por lo tanto, el
   mismo `numero_orden`.
5. **Persistencia por canal apenas termina cada envío:** un `UpdateItem`
   por canal (`<canal>_estado` + `<canal>_message_id` o
   `<canal>_codigo`), condicionado a que el canal siga `enviando` con el
   mismo `_intento_en`. Escribir cada canal por separado, y no uno solo
   al final, achica la ventana en la que un crash deja un canal
   entregado marcado como `enviando`.
6. Si Discord quedó `entregado`: se programa su borrado a los 60 días
   (`UpdateItem BORRAR#<fecha> ADD`, §10.3). Si esa escritura falla, la
   orden sigue aceptada y se emite `evento: "borrado_no_programado"` con
   alerta (el `discord_message_id` queda en `IDEM#` para el borrado
   manual del runbook).
7. Se agrega el resultado según la tabla de §5.3. Si es `aceptada` por
   primera vez: incremento del ledger (§8.2) y del contador de órdenes
   aceptadas por IP (§6.3), y respuesta `201`.

**Presupuesto de tiempo:** catálogo 3 s (normalmente caché) + DynamoDB
~0,1 s + envíos en paralelo 4 s (+ hasta 1,5 s por un 429 de Discord,
solo si quedan > 6 s de Lambda). Entra en el timeout de 10 s del Lambda,
por debajo de los 15 s del cliente.

**El ítem `IDEM#` ya no se borra nunca:** los reintentos se resuelven
por estado de canal y el número de orden se mantiene entre reintentos.
Por eso `orders-http` **ya no necesita `dynamodb:DeleteItem`** (§13).

### 5.5 Alerta de canal degradado

Cada canal que termina `fallido` o `incierto` emite **una línea de log
estructurada** con `evento: "canal_fallido"`, `canal`
(`mail`/`discord`), `codigo` (por ejemplo `http_404`, `timeout`,
`config`), `numero_orden` y `resultado` agregado de la orden. Nunca
contenido. Si la orden igual quedó `aceptada`, se agrega
`orden_aceptada: true` para distinguir "degradado" de "perdido".

`devops-agent` convierte esa línea en una alarma (metric filter →
alarma → **un topic SNS de alertas operativas, distinto del del
kill-switch** → email al CTO/CEO). No puede ser el topic de
`budget-guard`: un canal caído no tiene que apagar el servicio.

Resultado: un reintento nunca duplica ni el mail ni el mensaje de
Discord. El único caso degenerado es que los **dos** canales queden
`incierto` (o un crash del Lambda entre un envío y su `UpdateItem`). Ahí
se pierde la confirmación al visitante, pero la orden no se duplica, y
con dos canales independientes es mucho menos probable que antes.

## 6. Anti-abuso (AC-17, AC-19)

### 6.1 Destinos fijos (AC-17)

**Mail, en tres capas (sin cambios):**

1. **Código:** el destinatario es la constante `ORDER_RECIPIENT`, leída
   de la env var `ORDER_RECIPIENT_EMAIL` (renovartebyjuli@gmail.com). El
   request no tiene ningún campo que llegue a `Destination`.
   `ses-sender.ts` arma `ToAddresses: [ORDER_RECIPIENT]`, sin CC ni BCC.
2. **IAM:** `ses:SendEmail` solo sobre las identidades verificadas, con
   condición `ses:Recipients` = renovartebyjuli@gmail.com y
   `ses:FromAddress` = remitente (`Null` incluido, I-D7).
3. **SES sandbox:** no se pide acceso de producción.

**Discord:** el destino es el webhook cuya URL vive **solo** en SSM
(`SecureString`). El request no tiene ningún campo que llegue al
webhook, al canal, al `username` ni a un `thread_id`. Al cargar, la URL
se valida contra
`^https://discord\.com/api/webhooks/\d{17,20}/[A-Za-z0-9_-]{60,80}$`
(si no coincide, el canal queda `fallido` con `codigo: "config"`), así que
un error de configuración no puede mandar datos a otro host. El webhook
está atado a un solo canal por construcción de Discord.

**Reply-To:** `Reply-To` con el email del visitante cuando lo dejó y pasó
la validación. No es destinatario ni forma parte de `ses:Recipients`.
Los campos no admiten CR/LF, así que no hay inyección de headers. Se
omite si el CTO/CEO no lo quiere (§11).

### 6.2 Envío automatizado trivial (AC-19, segunda mitad)

- **Origin:** el header `Origin` tiene que estar en `ALLOWED_ORIGINS`
  (solo el dominio de producción del catálogo). Si no, `403
  falla`/`origen`. Es independiente de CORS, que solo protege
  navegadores.
- **`form_token`:** HMAC firmado por el servidor con su timestamp de
  emisión, obtenido de `GET /v1/estado`. Es válido **entre 3 s y 2 h**
  de antigüedad, medida con el reloj del servidor. Es stateless.
  - **Q-F4, resuelto:** un token fuera de la ventana **por cualquiera de
    los dos lados** (de menos de 3 s o de más de 2 h) responde
    `invalida` con `campo: "form_token"` y `codigo: "token_vencido"`. No
    se agrega un código nuevo:
    - el manejo del cliente ya es el correcto: pide un token nuevo,
      espera sus 3 s mínimos (regla que el cliente ya tiene) y reintenta
      una vez con la misma key;
    - un código `token_prematuro` le daría a un bot una pista sobre la
      ventana mínima.
  - Recomendación al cliente: esperar **3,5 s** desde la emisión, no 3 s
    justos. Absorbe diferencias de milisegundos entre contenedores y la
    latencia del GET.
  - Firma inválida o token malformado: el mismo `codigo`. El cliente
    reintenta una vez y después muestra el error general, que es lo que
    corresponde.
- **Honeypot `sitio_web`:** si llega con contenido, `invalida` con
  `errores: []`, sin pista del motivo.
- **Esquema estricto y tamaño:** claves desconocidas → `invalida`; más
  de 16 KB → rechazo.

Sin CAPTCHA. Cloudflare Turnstile queda como escalamiento (§11).

### 6.3 Volumen desde un mismo origen (AC-19, primera mitad)

Contadores en DynamoDB con `UpdateItem ADD` condicional y TTL. La IP
nunca se guarda en claro: se guarda `HMAC(secreto, ip)`.

| Límite | Default | Al excederlo |
|---|---|---|
| POST por IP | 20 / hora | `429 falla`/`limite_frecuencia` |
| Órdenes **aceptadas** por IP | 3 / hora, 10 / día | `429 falla`/`limite_frecuencia` |
| **Órdenes globales** (todo el sistema, cubre los dos canales) | 50 / día, 1000 / mes | `503 falla`/`limite_frecuencia` + log de alerta |

- El cupo global pasa a contar **órdenes** (una `idempotency_key`), no
  mails. Se consume **una sola vez por key**, en la reserva (§5.4 paso
  2), y los reintentos de la misma key no consumen más. Ya no se
  devuelve cupo ante una falla, porque la key no se libera. Así el cupo
  protege las dos casillas (el Gmail y el canal de Discord) aunque el
  atacante rote IPs.
- Todos los valores son env vars. Riesgo de CGNAT en §12.
- La reserved concurrency (§8.3) limita el paralelismo.

### 6.4 CORS y leak

- **CORS lo configura la Function URL, no el handler** (divergencia 2 de
  `devops-agent`, aceptada): `AllowOrigins` es solo el dominio de
  producción del catálogo; `AllowMethods` es `GET, POST`; `AllowHeaders`
  es `content-type`; sin credenciales; `MaxAge` 3600. El servicio
  responde el preflight sin invocar el Lambda. El handler **no** emite
  `Access-Control-*` (los headers duplicados rompen el navegador) ni
  rutea `OPTIONS`; un test lo verifica.
- **`pnpm check:leak`** falla el build si aparece alguno de estos:
  - tokens de costo, margen o precio LACA en `src/`, en el render de
    ejemplo del mail **y del mensaje de Discord**, o en los JSON de
    ejemplo del contrato (AC-16);
  - un email literal distinto de la constante del destinatario en
    `src/`, salvo fixtures de test (AC-17);
  - una **URL de webhook de Discord** con forma real
    (`discord(app)?\.com/api/webhooks/\d+/`) en cualquier archivo
    trackeado, incluidos los fixtures (los tests usan un host falso)
    (AC-26);
  - los patrones de credenciales que agrega `devops-agent` (I-D11).

### 6.5 Orden de las operaciones en `POST /v1/ordenes`

Primero los chequeos más baratos, y la entrega al final:

1. Tamaño y JSON válido → `Origin` → flag de control (caché de 30 s):
   si está apagado, `tope_alcanzado` o `mantenimiento` según el motivo
   (§8.4), **sin escrituras**.
2. Rate limit por IP (1 `UpdateItem`).
3. Esquema, honeypot, `form_token` y reglas de contacto → `invalida`.
4. Si la key ya existe (§5.4 paso 3), respuesta idempotente o claim de
   canales `fallido`.
5. Catálogo (§4) → `rechazada_por_catalogo`.
6. Cupo global de órdenes (condicional).
7. Reserva de la key (`IDEM#`) y del número de orden (`NUM#`, §9).
8. Envío en paralelo por mail y Discord → `UpdateItem` por canal →
   programación del borrado en Discord (§10.3) → agregado (§5.3) →
   ledger (§8.2) → `201`.

## 7. Datos personales (AC-18, AC-26, AC-27, AC-29, Ley 25.326)

Principio: **el servicio procesa los datos personales en memoria y no los
guarda.** El registro de la orden se guarda seudonimizado durante 90 días
(decisión del CTO/CEO). **Hay dos copias completas, las dos fuera de
AWS**: el mail en la casilla de RenovArte y el mensaje (más su adjunto)
en el canal privado de Discord. La segunda es una decisión explícita del
CTO/CEO para no perder órdenes si el mail cae en spam, y se borra sola a
los 60 días (§10.3).

| Dato | Dónde queda | Cuánto tiempo |
|---|---|---|
| Nombre, email, teléfono, dirección, localidad | **(1)** El mail (Gmail de RenovArte). **(2)** El mensaje y el adjunto `.txt` en el canal privado de Discord. Nunca en DynamoDB, logs ni respuestas | (1) Lo que RenovArte conserve en su casilla. (2) **Se borra automáticamente entre 60 y 61 días después de publicado** (AC-29, §10.3); el adjunto se va con el mensaje |
| Registro de la orden: `numero_orden`, `creado_en`, estado por canal, `mail_message_id`, `discord_message_id`, códigos de falla, líneas (`producto_id`, `cantidad`, `precio_unitario`), total, `payload_hmac` | DynamoDB `IDEM#<key>` | **90 días** por TTL (`expira_en` Number, epoch-segundos) |
| Número de orden reservado | DynamoDB `NUM#RA-xxxxx`, sin datos personales | Sin TTL, para no reusar números (§9) |
| Mensajes de Discord pendientes de borrar | DynamoDB `BORRAR#YYYY-MM-DD`: solo pares `webhook_id:message_id` (identificadores numéricos de Discord, sin datos personales) | Hasta que se borran; TTL de seguridad de 30 días después de la fecha de borrado |
| IP | Solo `HMAC(secreto, ip)` en los contadores de rate limit | TTL de 24 h |
| Logs | JSON con **allowlist** de campos (`numero_orden`, `resultado`, `codigo`, `canal`, `http_status`, latencias, `idempotency_key`). **Nunca** el body, el contacto, la IP en claro, la URL del webhook ni el **body de respuesta de Discord** (con `?wait=true`, Discord devuelve el mensaje completo, con los datos de contacto) | 14 días en CloudWatch |

- **Secretos**, en SSM Parameter Store `SecureString` (gratis, clave
  administrada por AWS), leídos en el cold start con dos `GetParameter`
  en paralelo:
  - el secreto HMAC (form token, IP, payload);
  - **la URL del webhook de Discord**, que incluye el token del webhook.
    Quien la tenga puede publicar en el canal (spam o phishing dirigido
    al negocio) y borrar los mensajes que creó el propio webhook. No
    permite leer el canal.
  - Ninguno se commitea (§I.2) ni llega al navegador: el catálogo solo
    conoce la URL pública de la Function URL.
  - Si se rota el webhook (se borra y se crea otro en Discord), se
    actualiza el parámetro. Los contenedores tibios siguen con la URL
    vieja hasta su próximo cold start, y mientras tanto Discord queda
    `fallido` (404) con alerta, pero sin perder órdenes. El runbook
    indica forzar un cold start (por ejemplo, actualizando una env var
    dummy).
- **El visitante no recibe ningún mail ni mensaje** (AC-11).
- **Asunto y primera línea de Discord sin datos personales:** `Nueva orden
  RA-48271 · $ 64.320 · 3 productos`. Así la notificación push de
  Discord y la vista previa de Gmail no muestran datos personales en la
  pantalla bloqueada.
- **Configuración del canal de Discord: paso manual del CTO/CEO, no
  código** (decisión 2026-09-30e: "el canal solo lo vamos a ver los
  propietarios"; tarea B24, documentada en el runbook):
  - canal **privado**, visible **solo para los propietarios de
    RenovArte** (`@everyone` sin "Ver canal"; acceso solo por rol o por
    miembro explícito);
  - 2FA recomendado en las cuentas de los propietarios y, si el servidor
    lo permite, 2FA obligatorio para la moderación;
  - nadie más con "Gestionar webhooks" ni "Gestionar mensajes" en ese
    canal;
  - sin bots ni integraciones de terceros con acceso de lectura al canal;
  - un solo webhook en el canal, el de órdenes. Su URL se copia una vez a
    SSM y no se pega en el chat ni en ningún repo.
- **Ley 25.326, a confirmar por el CTO/CEO antes de producción** (no soy
  abogado; decidido que no bloquea el diseño):
  1. **Deber de información (art. 6):** sumar un texto corto de privacidad
     (trabajo de UX/Frontend) que informe responsable, finalidad, carácter
     de los datos y derechos de acceso, rectificación y supresión.
  2. **Registro ante la AAIP (art. 21):** aplica a las bases que forman la
     casilla y **ahora también el canal de Discord**, no a este servicio.
  3. **Transferencia internacional (art. 12):** SES, Gmail **y Discord**
     (Discord Inc., EE.UU.) procesan fuera de Argentina. Mencionarlo en el
     texto de privacidad.
  4. **Supresión:** si un cliente pide borrar sus datos antes de los 60
     días, hay que borrar el mail y el mensaje de Discord a mano (los
     propietarios pueden borrar mensajes del canal). Después de los 60
     días, el mensaje de Discord ya no existe; el mail sigue la política
     de la casilla.

## 8. Tope de USD 20/mes (RNF-14, AC-22)

Todo el gasto del sistema es de AWS. **Discord no cobra:** los webhooks y
los servidores son gratis, sin límite de mensajes pagos a este volumen.
Por eso AWS Budgets sigue viendo el costo real completo. El retraso de
Budgets (8 a 24 h) obliga a varias capas.

### 8.1 Costo esperado (referencia)

A una escala generosa de 300 órdenes y ~5.000 requests por mes:

- **SES:** USD 0,10 / 1.000 mails → USD 0,03 (free tier de 3.000/mes los
  primeros 12 meses).
- **Discord:** USD 0. El egress de AWS a internet es de ~2–20 KB por
  mensaje; incluso 1.000 órdenes/mes son < 20 MB, dentro de los 100 GB
  mensuales gratis de transferencia saliente. La invocación no dura más,
  porque los envíos van en paralelo.
- **Lambda:** Always Free (1M invocaciones, 400k GB-s).
- **DynamoDB on-demand:** ~USD 0,01. Discord suma 1 `UpdateItem` por
  orden (§5.4 paso 5).
- **Borrado a los 60 días (§10.3):** 1 invocación diaria de
  `discord-retention` (~30/mes) + EventBridge Scheduler (14M gratis/mes)
  + unas pocas lecturas y escrituras de DynamoDB por día → USD 0.
- **Function URL, SSM Standard (2 parámetros), CloudWatch Logs:** USD 0.

**Total esperado: < USD 0,10/mes**, igual que antes.

### 8.2 Capa 1: ledger propio, corte en tiempo real con el copy de tope

- Ítem `LEDGER#YYYY-MM` (UTC) con `gasto_estimado_usd`, que suma costos
  unitarios **conservadores** (inflados ×2, configurables): por request
  procesada (Lambda + DynamoDB, que ahora incluye el `UpdateItem` extra
  de Discord) y por mail enviado (SES). Discord tiene costo unitario 0,
  así que no suma una variable nueva.
- Si el valor devuelto es `>= BUDGET_CAP_USD × BUDGET_STOP_RATIO` (USD
  18), el Lambda escribe `CONTROL = { habilitado: false, motivo:
  "tope_alcanzado" }`.
- Con el flag apagado, `GET /v1/estado` y `POST /v1/ordenes` responden
  según el motivo (§8.4) **leyendo el flag cacheado, sin escribir en
  DynamoDB y sin entregar por ningún canal**.

### 8.3 Capa 2: techo estructural (infra)

Reserved concurrency de 5 en `orders-http` (I-D4), o sin reserva si la
cuota de la cuenta es 10 (I-D4 caso b). Con 5 invocaciones en paralelo
como máximo, tampoco hay forma de saturar el rate limit del webhook
(§10.2).

### 8.4 Capa 3: kill-switch (`budget-guard`), por Budget o por flood

`budget-guard` escucha **un solo topic SNS** (I-D6) al que publican dos
fuentes:

| Fuente | Cómo se reconoce | Motivo en `CONTROL` |
|---|---|---|
| AWS Budget al 100 % ACTUAL | `Message` en texto plano de AWS Budgets que menciona el nombre del budget (`BUDGET_NAME`) | `presupuesto` |
| Alarma de flood de CloudWatch (I-D8, **aprobada**) | `Message` JSON con `AlarmName === FLOOD_ALARM_NAME` y `NewStateValue === "ALARM"` | `flood` |
| Alarma con `NewStateValue` `OK` o `INSUFFICIENT_DATA` | Ídem, otro estado | **Se ignora**: no hay reactivación automática al bajar el tráfico |
| Mensaje que no coincide con ninguno | — | `desconocido`. **Fail-safe:** se apaga igual y se loguea, porque el topic solo acepta publicaciones de Budgets y CloudWatch de la cuenta (topic policy de I-D6) y el error barato es apagar |

Al recibir un disparador válido (idempotente):

1. `CONTROL = { habilitado: false, motivo }`.
2. **`PutFunctionConcurrency(orders-http, 0)`**. Gasto cero literal; el
   cliente ve la falla genérica, no el copy de tope. Es aceptable, porque
   solo pasa ante abuso o un bug.

Mapeo del motivo a las respuestas, para cuando `CONTROL` está apagado y
la concurrency no está en 0 (por ejemplo, el ledger cortó al 90 %, o
alguien reactivó la concurrency a mano sin tocar `CONTROL`):

| `motivo` | `GET /v1/estado` | `POST /v1/ordenes` |
|---|---|---|
| `tope_alcanzado`, `presupuesto` | `tope_alcanzado` | `503 tope_alcanzado` |
| `flood`, `desconocido`, `manual` | `no_disponible` | `503 falla`/`mantenimiento` |

Un flood no es un tope de costo: no corresponde el copy "no podemos
recibir órdenes este mes".

**Reactivación** (decisión del CTO/CEO: manual o el día 1):

- **Automática:** EventBridge Scheduler, el día 1 a las 00:00 UTC, invoca
  `budget-guard` con `{ "mode": "reset" }`. Habilita `CONTROL` con
  cualquier motivo y restaura la concurrency:
  - `ORDERS_HTTP_RESERVED_CONCURRENCY` numérica →
    `PutFunctionConcurrency(n)`;
  - vacía (cuenta sin reserva posible, I-D4 caso b) →
    **`DeleteFunctionConcurrency`** (divergencia 3, aceptada).
- **Manual:** runbook. Se invoca el mismo `{ "mode": "reset" }` a mano
  después de revisar la causa, con el orden: primero `CONTROL`, después
  la concurrency.

`budget-guard` sigue sin tocar el ledger ni las órdenes (IAM con
`LeadingKeys = ["CONTROL"]`, I-D5). Tope **independiente** del de la
0016.

## 9. Número de orden

**Formato: `RA-` + 5 dígitos aleatorios** (`RA-48271`), único con
`PutItem NUM#RA-xxxxx` + `attribute_not_exists` y hasta 5 reintentos.
Solo dígitos (se dictan sin ambigüedad), aleatorio (no revela volumen).
Sin cambios respecto de la revisión 1.

El número se asigna **una vez por `idempotency_key`** y se reusa en
todos los reintentos y en los dos canales: la respuesta, el asunto y el
cuerpo del mail, la primera línea del mensaje de Discord y el nombre del
adjunto (`orden-RA-48271.txt`) muestran el mismo string (AC-10, AC-13).

### 9.1 Modelo único de orden

Los dos canales se renderizan desde **un mismo objeto inmutable**,
`OrdenParaEntrega`: número, fecha y hora, contacto validado, líneas con
nombre y presentación **tomados del catálogo**, cantidad, precio unitario,
subtotal y total. Se construye con un builder de allowlist, nunca con un
spread del `Product` del catálogo.

- `renderMail(orden)` y `renderDiscord(orden)` son puras y no reciben
  nada más.
- `renderTextoPlano(orden)` es la **misma función** para la parte
  `text/plain` del mail y para el adjunto `.txt` de Discord, así que la
  orden completa es idéntica en los dos canales.
- Un test verifica que las dos salidas contienen el mismo `numero_orden`,
  el mismo total y las mismas líneas, y que ninguna contiene tokens
  prohibidos (AC-16).

**Contenido del mail (sin cambios):**

- **Asunto:** `Nueva orden RA-48271 · $ 64.320 · 3 productos`.
- **Cuerpo** (texto plano + HTML simple): número; fecha y hora en
  `America/Argentina/Buenos_Aires`; contacto (nombre, email y/o teléfono,
  dirección, localidad); tabla de productos (nombre, presentación,
  cantidad, unitario, subtotal); total; pie "Pago y envío a coordinar con
  el cliente. Orden generada desde el sitio."
- Pesos con formato `$ 64.320`. En la parte HTML, todo el texto se
  escapa.

## 10. Canales de entrega

### 10.1 Mail: Amazon SES (sin cambios de fondo)

> **Salvedad de verificación:** esta sesión no tiene acceso a la web. Los
> precios y límites de SES y de Discord salen de mi conocimiento
> (actualizado a mediados de 2026) y **no los verifiqué hoy**. B1 los
> confirma antes de implementar. `devops-agent` sí verificó en la web
> los datos de Lambda y Budgets que figuran en `## Infra`.

**Recomendación aprobada: Amazon SES.** Es ~USD 0 a este volumen, no
agrega secretos (usa el rol IAM), fija el destinatario por IAM y sandbox,
y su gasto entra en el Budget. La tabla comparativa de la revisión 1
(Resend, Brevo, Mailgun/Postmark/MailerSend y Gmail SMTP, este último
descartado por el radio de impacto de una app password) sigue valiendo y
no se repite.

**Remitente: opción A, aprobada.** renovartebyjuli@gmail.com verificado
en SES como remitente **y** destinatario ("RenovArte Órdenes
<renovartebyjuli@gmail.com>").

- Riesgo: `From: @gmail.com` que no sale de servidores de Google no
  alinea DMARC, y puede ir a spam. **Ahora ese riesgo está mitigado
  estructuralmente por Discord:** aunque el mail caiga en spam, la orden
  llega al canal.
- Mitigaciones que se mantienen: un filtro en la casilla (asunto `Nueva
  orden RA-` → "Nunca enviar a spam") y el **smoke test real** (B19).
  Si el mail cae en spam con el filtro puesto → opción B (dominio propio
  con DKIM, MAIL FROM y DMARC, ~USD 1/mes fuera del Budget; I17).

Cliente SES: SES v2 `SendEmail`, **`maxAttempts: 1`** y timeout de 4 s
(§5.2).

### 10.2 Discord: webhook a un canal privado de órdenes (AC-23)

**Mecanismo:** `POST <webhook_url>?wait=true`, `multipart/form-data`,
con un campo `payload_json` y un archivo `files[0]`. Con `?wait=true`,
Discord responde `200` con el objeto del mensaje, y su `id` es la
confirmación positiva de entrega. Sin `wait`, responde `204` y no hay
forma de confirmar, así que siempre se usa `wait`.

**Sin idempotencia del lado de Discord.** El endpoint de webhooks no
acepta un `nonce` ni una idempotency key, a diferencia del endpoint de
mensajes de bots. Por eso la idempotencia es propia (§5): un timeout es
`incierto` y no se reenvía nunca.

**Límites de Discord** (sin verificar hoy; B1):

| Límite | Valor | Cómo se respeta |
|---|---|---|
| `content` | 2.000 caracteres | El render corta con presupuesto de caracteres (ver formato) |
| Embeds | 10 por mensaje, 6.000 caracteres en total, 25 campos | **No se usan embeds:** 100 líneas no entran (~110 caracteres por línea ≈ 11.000). El texto plano es más legible en el celular y más simple de testear |
| Adjuntos | Hasta ~10 MB por archivo sin boost | El `.txt` de una orden de 100 líneas pesa ~15 KB |
| Rate limit por webhook | ~5 requests cada 2 s, y ~30 mensajes por minuto por canal | Holgado: 50 órdenes/día de cupo global, 3/hora por IP y concurrency 5 |
| 429 | Header `Retry-After` y `retry_after` en el body | Si `retry_after ≤ 1,5 s` y al Lambda le quedan > 6 s: se espera y se reintenta **una vez** (seguro, porque un 429 no se procesa). Si no: `fallido`, reintentable con la misma key |
| Requests inválidas | ~10.000 cada 10 min → bloqueo temporal por IP en Cloudflare | Imposible a este volumen; no hay bucles de reintento. Un 401/404 por webhook borrado deja `fallido` y alerta, pero no reintenta solo |

**Formato del mensaje** (una sola request = un solo mensaje, así que el
envío es atómico):

- `username: "RenovArte Órdenes"` (sin avatar);
- `allowed_mentions: { parse: [] }`: nada del texto puede notificar a
  nadie (`@everyone`, `@here`, roles o usuarios);
- `flags: 4` (`SUPPRESS_EMBEDS`): ninguna URL escrita por el visitante
  genera una vista previa, que además sería un fetch a un tercero;
- `content` con esta forma:

  ````
  **Nueva orden RA-48271** · $ 64.320 · 3 productos
  Recibida el 30/09/2026 a las 14:32 (hora de Argentina)
  ```
  CONTACTO
  Nombre:     Ana Pérez
  Email:      ana@example.com
  Teléfono:   —
  Dirección:  Av. Siempre Viva 742
  Localidad:  Rosario

  PRODUCTOS
  2 × Crema hidratante facial · 50 ml
      $ 12.000 c/u · subtotal $ 24.000
  1 × …

  TOTAL: $ 64.320
  ```
  Pago y envío a coordinar con el cliente. Detalle completo en el adjunto.
  ````

- **Todo el texto del visitante y del catálogo va dentro del bloque de
  código.** Ahí Discord no interpreta markdown, links ni menciones. Lo
  único que puede romper el bloque es una comilla invertida, así que el
  render reemplaza cada `` ` `` por `ˋ` (U+02CB). CR/LF y caracteres de
  control ya los rechaza la validación (§3.2). La primera línea, fuera
  del bloque, solo tiene datos generados por el servidor.
- **Presupuesto de caracteres:** encabezado + contacto ocupan ≤ ~1.000
  caracteres en el peor caso (nombre 100, email 254, dirección 200 y
  localidad 100). Las líneas de producto se agregan en orden mientras el
  total quede ≤ 1.900; si no entran todas, se cierra con `… y N
  productos más: ver el adjunto`. El total siempre se muestra.
- **Adjunto `orden-RA-48271.txt`, siempre:** es `renderTextoPlano(orden)`,
  el mismo texto que la parte `text/plain` del mail. Garantiza la orden
  completa aunque tenga 100 líneas y deja algo para copiar o reenviar.
- Timeout de 4 s. El body de la respuesta solo se parsea para extraer
  `id`; **nunca se loguea** (§7).

### 10.3 Borrado automático de los mensajes de Discord a los 60 días (AC-29)

**Mecanismo elegido: una "cola por fecha" en DynamoDB + un Lambda
programado diario (`discord-retention`) que borra con el propio webhook**
(`DELETE /webhooks/{webhook_id}/{token}/messages/{message_id}`). Un
webhook puede borrar los mensajes que él mismo creó, sin bot ni token de
bot.

**Registro (en `orders-http`, §5.4 paso 6):** cuando Discord queda
`entregado`, se hace `UpdateItem pk = BORRAR#<fecha> ADD ids
:{"<webhook_id>:<message_id>"}` (String Set).

- `<fecha>` = fecha UTC de `creado_en + 61 días`. Como el job corre una
  vez por día, esto garantiza que el mensaje se borra **entre 60 y 61
  días** después de publicado, nunca antes de los 60.
- El `webhook_id` (numérico, no secreto) se guarda para detectar el caso
  de un webhook rotado (ver fallas).
- Con el cupo global de 50 órdenes por día, un bucket tiene como máximo
  ~50 ids (~2 KB), muy lejos del límite de 400 KB por ítem.
- `expira_en` del bucket = fecha + 30 días (TTL de seguridad, §7).
- También queda `discord_message_id` en `IDEM#` (90 días), para el
  borrado manual si el registro en `BORRAR#` falló.

**Job (`discord-retention`, EventBridge Scheduler diario, 06:00 UTC =
03:00 de Argentina):**

1. Lee el cursor `BORRAR#CURSOR` (el bucket pendiente más viejo; si no
   existe, hoy − 7 días).
2. Recorre los buckets desde el cursor hasta hoy. Para cada id:
   - `DELETE` al webhook → `204`: borrado. Se saca el id del set
     (`UpdateItem DELETE ids`).
   - `404` con código de Discord `10008` (Unknown Message): alguien ya lo
     borró a mano. Se da por borrado.
   - `webhook_id` distinto del webhook vigente, o `404` con código
     `10015` (Unknown Webhook): el webhook fue rotado o borrado y ya no
     puede borrar ese mensaje. Queda pendiente con alerta **"borrado
     manual requerido"** (runbook: los propietarios lo borran a mano
     buscando por número de orden o por fecha).
   - `429`: se espera `retry_after` y se sigue (una sola espera por id);
     si no alcanza el tiempo, queda para la próxima corrida.
   - `5xx`, timeout o error de red: queda pendiente para la próxima
     corrida. **Borrar es idempotente** (un segundo `DELETE` sobre un
     mensaje ya borrado da `10008`), así que acá no hay riesgo de
     duplicar nada y se puede reintentar sin límite.
3. Un bucket que queda vacío se borra (`DeleteItem`) y el cursor avanza.
4. **Rate limit:** los `DELETE` van **en serie**, respetando
   `X-RateLimit-Remaining` / `X-RateLimit-Reset-After` (se espera si
   `Remaining` llega a 0). Tope de 200 borrados por corrida
   (`BORRADO_MAX_POR_CORRIDA`) y corte limpio si quedan < 10 s de
   Lambda; lo que sobra se hace al día siguiente. El volumen real
   esperado es de ~1 a 10 borrados por día.
5. **Si el job no corrió** (por ejemplo, un día de falla de AWS), la
   corrida siguiente recupera todo desde el cursor. El retraso máximo es
   de 1 día por corrida perdida.

**Fallas y alertas (sin datos personales):**

- Al terminar, el job loguea una sola línea con `evento:
  "retencion_discord"`, `borrados`, `ya_borrados`, `pendientes`,
  `pendientes_viejos`, `requieren_manual` y `bucket_mas_viejo` (una
  fecha). **Nunca** loguea la URL del webhook, ids de mensajes,
  contenido ni cuerpos de respuesta. El `DELETE` no devuelve contenido
  (204).
- Alerta si `pendientes_viejos > 0` (ids de un bucket de más de 2 días:
  se reintentaron al menos 2 días seguidos sin éxito), si
  `requieren_manual > 0`, o si el Lambda termina con error (métrica
  `Errors` > 0). Va al topic de **alertas operativas** (§5.5), nunca al
  del kill-switch.
- `borrado_no_programado` (desde `orders-http`, §5.4 paso 6) también
  alerta.

**Independiente del tope:** el job corre aunque `CONTROL` esté apagado o
`orders-http` esté en concurrency 0. Borrar datos personales es una
obligación, y el costo es ~0. `budget-guard` no lo toca.

**Alternativas descartadas:**

- **TTL de DynamoDB + Streams → Lambda.** Parece más "automático", pero:
  - el TTL de DynamoDB no es puntual: AWS borra los ítems vencidos
    "típicamente en unos días", así que el plazo de 60 días no quedaría
    garantizado;
  - si el borrado en Discord falla, el ítem **ya no existe** y el stream
    retiene el evento solo 24 h. Después se pierde el rastro del mensaje,
    que quedaría para siempre en el canal;
  - agrega un stream, una event source mapping con filtro y una DLQ para
    no perder fallas. Es más infraestructura para un resultado peor.
- **Scan diario de `IDEM#` buscando `creado_en` de hace 60 días.** Un
  scan lee toda la tabla (contadores, ledger, `NUM#` sin TTL), y su
  costo crece con el tiempo. Con los buckets por fecha, el job lee solo
  lo que tiene que borrar.
- **Bot de Discord que borre por antigüedad del canal.** Necesita un
  token de bot con permiso "Gestionar mensajes" (más poder que el
  webhook), un segundo secreto y, para listar mensajes, acceso de
  lectura al canal. Descartado.

**Costo:** USD 0 (§8.1). Sin límites pagos de Discord.

### 10.4 Qué necesita de infra (resumen; detalle en §13)

- Un parámetro SSM `SecureString` nuevo (por ejemplo,
  `/renovarte-ordenes/discord-webhook-url`), con valor placeholder e
  `ignore_changes = [value]`, igual que el HMAC. El CTO/CEO carga el valor
  real con `put-parameter --overwrite`.
- Env var `DISCORD_WEBHOOK_PARAM` (el nombre, no el valor) en
  `orders-http`.
- `ssm:GetParameter` sobre ese ARN, sumado al statement existente.
- **Egress:** ninguno nuevo. El Lambda no está en una VPC, así que ya
  sale a internet (igual que el fetch al catálogo). No hace falta NAT.
- **IAM nuevo: ninguno.** Se **quita** `dynamodb:DeleteItem` de
  `orders-http` (§5.4).
- Una alarma de canal degradado sobre la línea de log `canal_fallido`,
  hacia un topic de **alertas operativas** separado del kill-switch
  (§5.5).
- **Para el borrado a los 60 días (§10.3):** un Lambda nuevo
  `discord-retention`, un schedule diario, su rol IAM y 2 alarmas más
  (detalle en §13).

## 11. Decisiones del CTO/CEO

**Tomadas (2026-09-30):**

1. Remitente: **opción A** con smoke test real; opción B si cae en spam.
2. Repo **`renovarte-ordenes`, público**.
3. Registro seudonimizado: **90 días**.
4. Alarma de flood → kill-switch con motivo `flood`; reactivación manual
   o el día 1.
5. Q-F5: email y teléfono en `sessionStorage` del lado del cliente,
   aprobado. No afecta al contrato.
6. Q-F1: **máximo 100 líneas** por orden.
7. Ley 25.326: no bloquea el diseño; se resuelve antes de producción.
8. **Doble canal** mail + Discord, con la orden completa y los datos de
   contacto en Discord.
9. **Falla parcial:** aceptada si al menos un canal entregó (AC-20,
   AC-25). Sin objeciones.
10. **Borrado automático de los mensajes de Discord a los 60 días**
    (AC-29), y **canal visible solo para los propietarios** (paso manual
    de configuración).

**Pendientes (no bloquean el diseño):**

1. **Umbrales anti-abuso** de §6.3.
2. **Kill-switch al 100 % real:** OK con perder el copy de tope en ese
   caso extremo.
3. **Reply-To con el email del visitante** (§6.1): sí (propuesta) o no.
4. **Retención del mail en la casilla** (Ley 25.326): política del
   negocio, fuera de este servicio.

## 12. Riesgos

1. **Entregabilidad del mail con la opción A** (§10.1): puede caer en
   spam. Ahora la orden llega igual por Discord; se mantienen el filtro,
   el smoke test y el fallback a la opción B.
2. **Discord como tercero sin SLA:** una caída o un cambio de límites o
   de API deja el canal `fallido`/`incierto`. No se pierden órdenes (hay
   mail) y la alerta de §5.5 avisa.
3. **Filtración de la URL del webhook:** quien la tenga puede publicar en
   el canal (spam o phishing dirigido a RenovArte). Mitigación: SSM,
   `check:leak`, logs sin URL y runbook de rotación (borrar y recrear el
   webhook y actualizar SSM). No expone los mensajes existentes.
4. **Datos personales en Discord** (§7): más superficie para la Ley
   25.326 (art. 12 y art. 21). Queda acotada a 60 días por el borrado
   automático (§10.3). El caso residual es un webhook rotado antes de los
   60 días: sus mensajes ya no se pueden borrar por API y el job alerta
   para que se borren a mano.
5. **El job de borrado falla varios días seguidos:** los mensajes quedan
   más de 60 días. Alerta a partir del segundo día sin éxito y
   recuperación automática desde el cursor.
6. **Pricing y límites sin verificar hoy** (SES, Discord): B1.
7. **Ambos canales `incierto`** (§5.5): el visitante ve "no se envió"
   aunque la orden pudo haber llegado. Es mucho menos probable que antes
   (hacen falta dos fallas ambiguas independientes) y nunca duplica.
8. **Catálogo inaccesible:** no se aceptan órdenes
   (`catalogo_no_disponible`), mientras el resto del sitio sigue
   funcionando (AC-21).
9. **CGNAT y falsos positivos de rate limit** (§6.3): umbrales holgados y
   configurables.
10. **Lag de AWS Budgets:** cubierto por el ledger (90 %), la alarma de
   flood y la reserved concurrency.
11. **Deriva de precios entre build y caché** (§4.2): cubierta por el
    refresco forzado ante discrepancia.

## 13. Respuesta a las divergencias de `devops-agent`

| # | Divergencia (`## Infra`) | Respuesta |
|---|---|---|
| 1 | Deploy: no existe un patrón OIDC en la 0016 | **Aceptada.** Terraform manual con estado local (usuario IAM acotado) y código por OIDC con `workflow_dispatch` solo desde `main` (I-D10). Corregido en `## Backend` |
| 2 | CORS lo maneja la Function URL | **Aceptada.** El handler no emite `Access-Control-*` ni rutea `OPTIONS`, y un test lo verifica (§6.4). Sigue el chequeo de `Origin` |
| 3 | Reset sin reserva → `DeleteFunctionConcurrency` | **Aceptada** (§8.4). `ORDERS_HTTP_RESERVED_CONCURRENCY` vacía → `Delete`; numérica → `Put(n)` |
| 4 | Alarma de flood → `budget-guard` | **Aceptada y aprobada por el CTO/CEO** (§8.4): reconoce el mensaje de CloudWatch por `AlarmName`, motivo `flood`, ignora `OK` y es fail-safe ante un formato desconocido. Env vars nuevas en `budget-guard`: `FLOOD_ALARM_NAME` y `BUDGET_NAME` |
| 5a | `expira_en` Number en epoch-segundos | **Aceptada** para todos los ítems con TTL (`IDEM#`, `RL#`, `CUPO#`, `LEDGER#`) |
| 5b | Con throttle o concurrency 0, la URL responde sin body del contrato y probablemente sin CORS | **Aceptada.** El cliente lo ve como error de red → falla genérica (AC-20) |
| 5c | La URL base termina en `/` | **Aceptada.** El handler rutea por `rawPath` exacto (`/v1/estado`, `/v1/ordenes`); `//v1/...` → 404 con `falla`/`interno` |

**Cambios nuevos que esta revisión le pasa a `devops-agent`** (además de
§10.4):

- **Quitar** `dynamodb:DeleteItem` (y su condición `LeadingKeys
  IDEM#*`) del rol de `orders-http`: ya no se libera `IDEM#`.
- `orders-http`: env var `DISCORD_WEBHOOK_PARAM` y `ssm:GetParameter`
  sobre el parámetro nuevo.
- `budget-guard`: env vars `FLOOD_ALARM_NAME` y `BUDGET_NAME`.
- Alarma `canal_fallido` (metric filter sobre el log group de
  `orders-http`, patrón `{ $.evento = "canal_fallido" }`) → topic SNS de
  alertas operativas **nuevo y separado** → email. Umbral sugerido: ≥ 1
  en 5 min. Métrica y alarma entran en las 10 gratis (confirmar en I1
  que hay lugar para 2 alarmas).
- Runbook de infra: cargar y rotar el webhook de Discord en SSM y forzar
  un cold start. **Al rotar, avisar que los mensajes del webhook viejo
  de menos de 60 días hay que borrarlos a mano** (§10.3).
- **Lambda nuevo `discord-retention`** (§10.3): Node 22 arm64, mismo zip,
  timeout 60 s, 128 MB, sin reserved concurrency, log group con 14 días.
  Env vars: `ORDERS_TABLE`, `DISCORD_WEBHOOK_PARAM`,
  `BORRADO_MAX_POR_CORRIDA=200`. No va en el kill-switch.
- **Schedule** `cron(0 6 * * ? *)` UTC → `discord-retention` (mismo rol de
  Scheduler que el reset, ampliado a este ARN, o uno propio).
- **IAM de `discord-retention`:** logs de su propio group; DynamoDB
  `GetItem`, `UpdateItem` y `DeleteItem` **solo** con `LeadingKeys` en
  `BORRAR#*` (incluye `BORRAR#CURSOR`); `ssm:GetParameter` sobre el
  parámetro del webhook. Nada más.
- **IAM de `orders-http`:** su `UpdateItem` ya cubre `BORRAR#<fecha>`;
  no hace falta nada nuevo.
- **Deploy por OIDC (I11):** el rol de deploy suma el ARN del tercer
  Lambda en `UpdateFunctionCode`/`GetFunction*`.
- **2 alarmas más** hacia el topic de alertas operativas: `Errors` > 0
  de `discord-retention` en 1 día, y un metric filter sobre
  `{ $.evento = "retencion_discord" && ($.requieren_manual > 0 ||
  $.pendientes_viejos > 0) }` (más `borrado_no_programado`). En total
  son 4 alarmas (flood, canal fallido, 2 de retención), dentro de las 10
  gratis si la cuenta tiene lugar (I1).
