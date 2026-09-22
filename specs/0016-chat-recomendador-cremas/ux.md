# UX — 0016 Chat recomendador de combos ("Colibrí")

Nombre visible final: **Colibrí** (decisión de CTO/CEO). "ChatGPRenovarte"
fue solo el nombre de trabajo interno durante el diseño y no aparece en
ningún estado cara al usuario — ver Mapeo de contenido y Preguntas
abiertas.

**Mockup:** https://claude.ai/artifact/PxPUyoi2t4SfmDhu55Na5s

Este documento define layout, interacción, estados, accesibilidad y mapeo de
contenido para el chat conversacional descrito en
`specs/0016-chat-recomendador-cremas/spec.md`. No decide arquitectura técnica
(eso es del RFC de `frontend-agent`/`ai-agent`), pero sí define el **contrato
de interacción** que esa arquitectura tiene que poder servir — marcado
explícitamente donde aplica.

## Resumen de decisiones y por qué

- **Punto de entrada doble, mismo componente:** un botón flotante (FAB)
  persistente en todas las páginas (`layout.tsx`) + una tarjeta de invitación
  en la home, arriba del catálogo. Ambos abren el mismo panel de chat.
  AC-1 exige que se pueda abrir "desde el sitio" sin especificar dónde — un
  FAB global cubre categoría/producto/ofertas (donde también tiene sentido
  preguntar "¿qué me conviene?"), y la tarjeta en home cubre el momento en
  que el spec describe como el problema real ("el visitante que no sabe qué
  crema comprar" llega a la home sin plan).
- **Panel, no página dedicada:** un `dialog` modal (full-screen en mobile,
  drawer anclado a la derecha en desktop) en vez de una ruta `/chat`. Evita
  que Next.js tenga que prerenderizar una página cuyo contenido es 100%
  dinámico y sin SEO útil, y deja la navegación del catálogo intacta debajo
  (AC-11) sin un cambio de URL que la interrumpa.
- **Nivel de combo, no de producto:** las 3 opciones se renderizan con un
  layout nuevo (card de combo, lista de 2+ productos + total), explícitamente
  *no* reutilizando `ProductCard` tal cual — una card de combo no tiene una
  sola imagen/nombre/precio, tiene varios. Sí reutiliza su lenguaje visual
  (radios, tipografía de precio, bordes `beige-200`).
- **Tono "honesto", no e-commerce agresivo:** ninguna badge roja de "por
  encima del presupuesto", ninguna urgencia ("¡última oportunidad!"). La
  relación con el presupuesto se muestra como texto simple con el monto y la
  diferencia. Esto es una instrucción explícita de producto (proyecto de
  práctica, no optimización de conversión), no una preferencia estética mía.
- **Streaming visible pero con anuncio de accesibilidad diferido:** el texto
  se pinta token a token en pantalla, pero el `aria-live` solo anuncia el
  mensaje una vez completo — anunciar por token es un antipatrón conocido de
  accesibilidad en interfaces de LLM (lectura ilegible / interrumpida).

## Layout

### Punto de entrada 1 — FAB global

- Vive en `layout.tsx`, fuera de `<main>`, visible en todas las páginas
  (home, categoría, grupo, producto, ofertas).
- Mobile (~390px): círculo `h-14 w-14`, fijo `bottom-4 right-4` (con
  `env(safe-area-inset-bottom)` sumado al offset), `bg-sage-500`,
  ícono de chat (línea fina, mismo grosor que el line-art del logo) sin
  texto — el espacio no alcanza para label.
- Desktop (≥640px): mismo círculo pero con label visible al lado
  ("Chat") dentro de un contenedor `rounded-full` más ancho — incorpora el
  mismo tratamiento que el CTA "Ver catálogo" de `MissionSection`
  (`bg-sage-500 text-beige-50 hover:bg-sage-600`), no un widget flotante
  ajeno al sitio.
- El FAB **no** desaparece cuando el chat está deshabilitado (ver estado
  "no disponible" más abajo) — sigue siendo el punto de entrada, solo que al
  abrir el panel se ve el estado de no disponibilidad en vez del saludo.

### Punto de entrada 2 — tarjeta de invitación en home

- Ubicación: entre `MissionSection` y el encabezado "Catálogo" en
  `src/app/page.tsx` (después del `<div className="my-10 border-t ...">`
  actual, antes del `<h2>Catálogo</h2>`).
- Card `rounded-lg border border-beige-200 bg-beige-100 px-4 py-5 sm:px-6`
  (mismos tokens que `ProductCard`, para que se sienta del sitio y no un
  banner pegado). Contenido: un renglón de texto ("¿No sabés qué crema
  elegir? Contale a Colibrí tu tipo de piel y tu presupuesto.") +
  botón `bg-sage-500 text-beige-50 rounded-lg px-4 py-2` "Iniciar chat".
  Mismo componente trigger que el FAB (un solo `onClick` compartido).
- Ancho completo del contenedor (`max-w-6xl`), no compite en jerarquía con
  el `<h1>` de `MissionSection` (que sigue siendo lo primero que se lee).

### El panel de chat

- Es un `role="dialog" aria-modal="true"` — ver "Accesibilidad".
- **Mobile (~390px):** full-screen, `fixed inset-0 z-50 bg-beige-50`. De
  arriba a abajo:
  1. Header sticky `bg-beige-100 border-b border-beige-200`: título del
     chat a la izquierda, botón cerrar (×) a la derecha, `h-14`.
  2. Barra de resumen de datos capturados (condicional — ver Interacción),
     sticky justo debajo del header.
  3. Hilo de mensajes, scrollable, `flex-1`, `px-4 py-4`, fondo `beige-50`.
  4. Input sticky al fondo: `border-t border-beige-200 bg-beige-100`,
     textarea auto-expandible (máx. ~4 líneas) + botón enviar circular
     `bg-sage-500`, con padding extra por `safe-area-inset-bottom`.
- **Desktop (≥768px):** drawer anclado a la derecha, `w-[420px]
  max-w-[90vw] h-dvh`, `border-l border-beige-200 bg-beige-50`, con un
  scrim suave (`bg-sage-900/10`) sobre el resto de la página (clic afuera
  cierra, igual que Escape). Misma estructura interna que mobile (header /
  resumen / hilo / input), solo que dentro de un panel angosto en vez de
  ocupar toda la pantalla — **una sola columna siempre**, los combos nunca
  se muestran en grilla de 3 porque el panel nunca es lo bastante ancho
  para eso ni en desktop grande.
- El catálogo (grilla, nav, footer) sigue montado y funcional detrás del
  panel en todo momento — nunca se desmonta al abrir el chat (AC-11).

### Card de combo (el elemento nuevo, no existe hoy en el sitio)

Dentro de un turno de respuesta con recomendación, después del texto que
haya generado el modelo, se renderiza una lista ordenada (`<ol>`) de 3
cards, en orden ascendente de precio (más barato → medio → premium, AC-5),
cada una:

```
┌─────────────────────────────────────┐
│ MÁS BARATO                           │  ← eyebrow, text-xs uppercase
│                                       │     tracking-wide sage-600 —
│ Crema De Limpieza Con Fitoesteroles  │     texto, no badge de color
│   de Soja y Malva 160 g.             │
│ 160 g · $ 19.200                     │  ← cada producto: nombre (link),
│                                       │     presentación, precio — mismo
│ Emulsión Humectante Herbal x 100ml   │     lenguaje que ProductCard
│ 100 ml · $ 14.400                    │
│ ─────────────────────────────────    │
│ Total del combo: $ 33.600            │  ← text-lg font-semibold, como
│ Tu presupuesto: $ 50.000             │     ProductPrice size="lg"
│ $ 16.400 por debajo de tu presupuesto│  ← texto plano, no badge
└─────────────────────────────────────┘
```

- Contenedor: `rounded-lg border border-beige-200 bg-beige-100 p-4`, igual
  radio/borde que `ProductCard` — se siente del mismo sistema.
- El nombre de cada producto es un `<a>` a `/producto/[id]` real,
  **`target="_blank" rel="noopener"`** (confirmado por CTO/CEO, ex-Pregunta
  abierta #5) — abre en pestaña nueva a propósito:
  el chat no persiste historial entre sesiones (spec, "Out"), así que
  navegar en la misma pestaña perdería la conversación en curso solo para
  verificar un producto. Esto también refuerza AC-4 en la práctica: el
  visitante puede chequear cada producto contra la ficha real sin perder el
  chat.
- Precio de cada producto: mismo `precio_venta` que se ve en catálogo — la
  UI nunca formatea un precio que no vino tal cual en el payload
  estructurado (ver "Contrato de interacción" abajo).
- Relación con el presupuesto (AC-8/AC-9): una línea de texto simple debajo
  del total, no una badge de color. Tres variantes de texto, todas neutras:
  - Por debajo o igual: "`$ X por debajo de tu presupuesto`" (o "Coincide
    con tu presupuesto" si la diferencia es $0).
  - Premium por encima (esperado, nunca alarmante): "`$ X (N%) por encima
    de tu presupuesto — es la opción premium`".
  - Nunca se usa rojo/ícono de alerta para "por encima": es un
    comportamiento esperado de la opción premium (AC-9), no un error.

## Interacción

### Arranque de la conversación

1. Al abrir el panel (FAB o tarjeta de home), aparece de inmediato un
   mensaje de bienvenida **renderizado en el cliente, sin llamada al
   backend** (no consume presupuesto de LLM por abrir el chat): explica en
   una o dos oraciones qué hace el chat y qué necesita (tipo de piel +
   presupuesto) — cubre AC-2 como instrucción explícita, no solo como
   comportamiento implícito del modelo.
2. Debajo del mensaje de bienvenida, 2–3 chips de ejemplo (`rounded-full
   bg-sage-100 text-sage-700`, mismo componente visual que los chips de
   `CategoryNav`/`chip-styles.ts`) con prompts completos de muestra —p.ej.
   "Piel seca, presupuesto $50.000"— que autocompletan el input al
   tocarlos (no lo envían solos; el visitante puede editar antes de
   mandar). Solo aparecen mientras el hilo no tiene mensajes del usuario
   todavía; desaparecen apenas el visitante escribe su primer mensaje.
3. El input queda enfocado (foco entra al panel, ver Accesibilidad).

### Captura de tipo de piel y presupuesto (AC-2)

- Si el primer mensaje del visitante ya trae ambos datos ("tengo piel
  grasa y quiero gastar hasta $40.000"), el chat responde directo con la
  recomendación — no hay paso de formulario intermedio.
- Si falta alguno de los dos, el turno de respuesta del asistente es una
  pregunta de seguimiento en texto plano (burbuja normal, sin UI especial)
  pidiendo específicamente lo que falta. Esto es comportamiento del
  modelo/prompt (fuera de esta fase), pero la UI **no** debe tratarlo
  distinto de cualquier otro turno conversacional — no hay un "modo
  formulario" separado.
- **Confirmación no ambigua de lo capturado:** en cuanto el backend informa
  (de forma estructurada, no parseando prosa — ver contrato abajo) que ya
  tiene ambos datos, aparece la barra de resumen fija debajo del header:
  chip de solo lectura tipo `Piel: seca · Presupuesto: $ 50.000` con un
  link "Cambiar" al lado. Sirve para que el visitante (y quien lee con
  lector de pantalla) tenga un lugar único y no ambiguo donde confirmar qué
  entendió el chat, en vez de tener que releer la conversación. "Cambiar"
  no abre un formulario: enfoca el input con un placeholder tipo "Contame
  el nuevo tipo de piel o presupuesto" para que el visitante lo diga en su
  próximo mensaje (sigue siendo conversacional).
- La barra de resumen se actualiza (no se duplica) cada vez que el backend
  confirma un cambio en cualquiera de los dos valores.

### Streaming / carga

- **Antes del primer token:** en el lugar donde va a aparecer la respuesta,
  3 puntos `bg-sage-300` con animación de pulso (`motion-reduce:` sin
  animación, puntos estáticos) — mismo patrón de "escribiendo…" que
  cualquier chat, sin inventar un spinner distinto al resto del sitio.
- **Mientras llegan tokens:** el texto de la burbuja del asistente se va
  completando en vivo. El input y el botón de enviar quedan deshabilitados
  mientras haya un turno en curso (evita doble envío / carreras) — se
  reactivan al terminar el turno.
- **Cards de combo:** nunca se renderizan parciales. Si la respuesta trae
  texto libre + datos de combo, el texto puede ir apareciendo en streaming,
  pero las 3 cards solo se montan (con una transición simple de
  fade + translate-y-1, `motion-reduce:` sin transición) una vez que el
  payload estructurado de los 3 combos llegó completo. No hay estado
  intermedio de "card a medio llenar".
- **Conexión inicial del panel:** si abrir el panel implica un handshake
  con el transporte externo (WebSocket) y tarda, no se muestra ningún
  indicador de carga antes de los ~400ms (para no generar parpadeo en la
  mayoría de los casos, que van a ser instantáneos); pasado ese umbral, el
  saludo se reemplaza temporalmente por el mismo indicador de "escribiendo"
  de 3 puntos hasta que la conexión esté lista.

### Estado "sin recomendación" (AC-4/AC-6)

- Se renderiza como una burbuja de asistente más — **nunca** como una card
  de combo vacía ni como un error rojo. Mismo tratamiento tipográfico que
  cualquier respuesta de texto (`text-sage-900`), sin ícono de alerta.
- Copy sugerido (autoría UX, no literal del spec — el spec exige el
  comportamiento, no el texto exacto, así que esto queda para validación
  de producto): *"No tengo una recomendación para eso con los productos
  que tenemos hoy en el catálogo. Contame de otra forma tu tipo de piel o
  ajustá el presupuesto y lo intento de nuevo."* — reutiliza el mismo tono
  que el estado vacío de búsqueda ya existente en `CatalogView`
  ("No encontramos productos para «X»."), para que el sitio hable con una
  sola voz también acá.
- No hay botón de acción especial: el visitante sigue escribiendo en el
  mismo input, como cualquier turno.

### Estado "chat no disponible" (AC-13 / RNF-09, RNF-07)

Este es el estado que más necesitaba diseño explícito porque, sin uno, el
`frontend-agent` lo iba a improvisar como un error genérico.

- **Se descubre al intentar usar el chat, no antes.** El FAB y la tarjeta
  de home se ven siempre igual (no hay una versión "atenuada" del botón) —
  evita depender de un chequeo de disponibilidad previo que agregaría una
  llamada de red extra solo para decorar el punto de entrada (ver Pregunta
  abierta #1 sobre si esto vale la pena a futuro — propuesta aceptada por
  CTO/CEO como está, queda como mejora posible, no como requisito).
- **Al abrir el panel:** si el handshake inicial falla o el transporte
  responde "deshabilitado", el saludo y los chips de ejemplo **nunca
  llegan a aparecer** — se reemplazan directamente por el estado de no
  disponibilidad, ocupando el mismo espacio del hilo de mensajes:
  - Contenedor `rounded-lg bg-sage-50 px-5 py-8 text-center` (fondo suave
    `sage-50`, el mismo tono "informativo" que ya usa `MissionSection` de
    fondo — deliberadamente *no* el `border-dashed` que el sitio ya usa
    para "vacío/sin resultados", para no leerse como un error de búsqueda).
  - Un encabezado corto + un cuerpo de texto, sin ícono de alerta ni color
    de error. Dos variantes de copy (mismo tratamiento visual, texto
    distinto), condicionadas a que el backend pueda distinguir el motivo
    (ver Pregunta abierta #2):
    - Techo de gasto alcanzado: *"Colibrí llegó a su límite de
      uso por este mes. El resto del catálogo funciona con total
      normalidad — probá el chat de nuevo el mes que viene."*
    - Falla genérica de conexión (si no se puede distinguir el motivo, se
      usa esta variante como default): *"Colibrí no está
      disponible en este momento. Podés seguir navegando el catálogo con
      normalidad — probá de nuevo más tarde."*
  - El input se muestra pero deshabilitado (`disabled`, `bg-beige-100
    text-sage-400`), con placeholder "Chat no disponible por el momento" —
    así el visitante ve la superficie completa del chat, no una pantalla
    rota o a medio cargar.
  - El botón de cerrar (×) sigue funcionando siempre — el visitante vuelve
    al catálogo con un clic.
- **Si el techo se alcanza a mitad de una conversación ya iniciada:** el
  hilo existente (lo que ya se dijo) queda visible y scrollable tal cual
  estaba — no se borra. Solo la zona de input se reemplaza por el mismo
  aviso + input deshabilitado de arriba. Ningún mensaje previo del
  visitante ni del asistente desaparece.
- Ningún estado de "no disponible" bloquea, oculta o degrada el resto del
  sitio — la grilla, la nav, la búsqueda y la ficha de producto detrás del
  panel siguen 100% operables en paralelo (AC-11 se cumple estructuralmente
  porque el panel nunca desmonta el resto del árbol).

### Progresividad / JS

- El chat es, por naturaleza, una feature 100% dependiente de JS en vivo
  (WebSocket a un servicio externo) — a diferencia del carrusel de misión
  (spec 0011), acá no hay contenido estático previo que mostrar sin JS,
  porque no hay contenido: es una conversación que no existe hasta que se
  inicia. Esto no contradice la regla de "SSG, contenido visible sin JS"
  del resto del sitio, porque esa regla protege contenido *que ya existe*
  (misión, catálogo, fichas) — el catálogo entero (RF-01 a RF-04) sigue
  siendo 100% funcional sin JS/con JS roto, que es exactamente lo que pide
  AC-11.
- Con todo, el botón/tarjeta de entrada se renderiza siempre en el HTML
  (no aparece recién tras hidratar) siguiendo el mismo patrón ya usado en
  `MissionCarouselLive` (`useSyncExternalStore` / `useMounted`): el
  control está presente desde el primer render pero inerte
  (`tabIndex={-1}`, sin `onClick` funcional) hasta que hidrata, evitando
  parpadeo/CLS. Con JS deshabilitado permanentemente, el botón queda
  visible pero no interactivo — no es una promesa rota porque no hay
  ninguna versión "sin JS" del chat que se esté ocultando.

### Contrato de interacción con el transporte (para `frontend-agent`/`ai-agent`)

No es una decisión técnica de esta fase, pero el diseño de arriba **requiere**
que el cliente pueda distinguir, por mensaje/evento, entre:

1. Un turno conversacional de texto plano (pregunta de seguimiento, saludo,
   mensaje de "sin recomendación").
2. Un turno de recomendación con datos **estructurados** (no parseados de
   prosa) de los 3 combos: por combo, nivel, lista de `{producto_id,
   nombre, presentacion, precio_venta}` (2+ ítems) y total.
3. La confirmación estructurada de `tipo_piel` y `presupuesto` capturados
   (para la barra de resumen), independiente del texto libre que el modelo
   haya generado.
4. Una señal explícita de "deshabilitado por techo de gasto" vs. cualquier
   otra falla de conexión — si el transporte no puede distinguirlos, la UI
   colapsa a un único mensaje genérico (ver Pregunta abierta #2).

Si el runtime solo devuelve texto libre sin esta estructura, ninguno de los
estados de arriba (barra de resumen, cards de combo, distinción de
"sin disponible" por motivo) se puede construir de forma confiable, y el
`frontend-agent` va a terminar re-implementando un parser de prosa — exactamente
lo que este documento busca evitar.

## Estados y responsividad

| Estado | Mobile (~390px) | Desktop (≥768px) |
|---|---|---|
| Cerrado | Solo FAB + tarjeta de home visibles | Igual, FAB con label "Chat" |
| Abierto, vacío | Panel full-screen, saludo + chips de ejemplo | Drawer 420px + scrim, mismo contenido |
| Escribiendo (usuario) | Input activo, 1 columna | Igual |
| Esperando respuesta | 3 puntos de "escribiendo", input deshabilitado | Igual |
| Respuesta con combos | 3 cards apiladas en 1 columna, orden ascendente | Igual — el panel nunca es tan ancho como para grilla de 3 |
| Sin recomendación | Burbuja de texto plano | Igual |
| No disponible (al abrir) | Bloque `sage-50` reemplaza saludo, input deshabilitado | Igual |
| No disponible (a mitad de charla) | Hilo previo intacto, input deshabilitado | Igual |
| `prefers-reduced-motion` | Sin pulso en puntos de carga, sin fade/slide en cards, sin drawer-slide (aparece/desaparece sin animar) | Igual |

No hay un layout de escritorio "ancho" distinto (3 columnas, sidebar
propia): el chat es intencionalmente angosto en cualquier viewport porque
es una superficie conversacional, no una página de resultados.

## Accesibilidad

- **Estructura del panel:** `role="dialog" aria-modal="true"
  aria-labelledby="chat-title"`. Al abrir, el foco se mueve al primer
  elemento interactivo relevante (botón cerrar o input, a definir en
  implementación pero nunca al `body`). Al cerrar (botón ×, Escape, clic
  en el scrim en desktop), el foco vuelve exactamente al control que abrió
  el panel (FAB o botón de la tarjeta de home) — nunca se pierde en el
  `body`.
- **Foco atrapado** mientras el panel está abierto (Tab/Shift+Tab ciclan
  solo dentro del panel) — es una superficie modal en ambos breakpoints.
- **Hilo de mensajes:** `role="log" aria-live="polite" aria-relevant="additions"`
  en el contenedor del hilo. Cada mensaje nuevo se anuncia una vez —
  **nunca por token**: el indicador de "escribiendo" se anuncia una sola
  vez al empezar el turno ("Colibrí está escribiendo") vía un
  `role="status"` separado, y el contenido real del mensaje solo entra al
  DOM del `log` (y por lo tanto se anuncia) cuando el streaming visual
  terminó. Streaming por token es un patrón puramente visual, no de
  accesibilidad.
- **Prefijos para lectores de pantalla:** cada burbuja lleva un prefijo
  visualmente oculto (`sr-only`) — "Vos dijiste:" / "Colibrí
  respondió:" — para que el hilo se entienda linealizado sin depender de
  la posición visual (izquierda/derecha) de la burbuja.
- **Cards de combo:** `<ol>` con un `<li>` por combo; dentro de cada uno,
  un `<h3>` con el nivel ("Más barato" / "Medio" / "Premium" — texto, no
  solo color, ya es una convención existente del sitio en `OfferBadge`/
  `ProductPrice`) y un `<ul>` con los productos. El total lleva un prefijo
  `sr-only` ("Total del combo: ") antes del monto, mismo patrón que
  `ProductPrice` ya usa para "Precio anterior: ".
- **Barra de resumen (tipo de piel/presupuesto):** es parte del flujo de
  tab normal, no solo decorativa — el link "Cambiar" es un botón real
  enfocable, con `aria-label="Cambiar tipo de piel o presupuesto"`.
- **Estado "no disponible":** el bloque de aviso es `role="status"
  aria-live="polite"` (no `alert` — no es una emergencia ni un error del
  visitante, es información neutral), para que se anuncie apenas aparece
  sin que quien usa lector de pantalla tenga que explorar el panel para
  encontrarlo.
- **Contraste:** todo el texto nuevo usa los mismos tokens ya validados AA
  en `brand.md` (`sage-600` en adelante sobre `beige-50`/`beige-100`); no
  se introduce ningún color nuevo.
- **`prefers-reduced-motion`:** el pulso de "escribiendo", el fade/slide de
  las cards de combo y cualquier transición de apertura/cierre del panel
  respetan `motion-reduce:` (mismo patrón que `MissionSection` ya usa con
  `motion-reduce:scroll-auto`) — el contenido sigue apareciendo, solo sin
  animación.
- **Alt text:** el chat no introduce imágenes nuevas — confirmado por
  CTO/CEO que las cards de combo son solo texto (nombre/presentación/
  precio), sin thumbnail (ex-Pregunta abierta #6, ya resuelta). No hay
  `alt` que resolver en esta fase porque no hay `<img>` en la card de
  combo.

## Mapeo de contenido

El spec de esta feature es de producto/comportamiento, no trae copy
literal para el chat (a diferencia de specs con texto de marketing ya
escrito, como la 0011 de misión) — la voz conversacional del asistente la
define el prompt del modelo en la fase de RFC/implementación de
`ai-agent`, no este documento. Lo que sí está fijado acá, tomado
directamente del spec:

| Elemento en pantalla | Fuente |
|---|---|
| Etiquetas de nivel "Más barato" / "Medio" / "Premium" | Literal de AC-3/Alcance ("más barato / medio / premium") |
| Nombre, presentación y precio de cada producto en una card de combo | Verbatim de `products.json` (`nombre`, `presentacion`, `precio_venta`) — nunca generado por el modelo (AC-4) |
| Chip "Piel: X · Presupuesto: $Y" | Valores estructurados confirmados por el backend a partir de la conversación (AC-2) |
| Relación "$X por debajo/por encima de tu presupuesto" | Calculado en el cliente a partir de `precio_venta` sumado vs. presupuesto declarado (AC-8/AC-9) — no es texto libre del modelo |
| Copy de saludo inicial, chips de ejemplo, mensaje de "sin recomendación", mensaje de "no disponible" | **Autoría UX** (propuesta en este documento) — el spec exige el comportamiento (AC-2, AC-6, AC-13) pero no fija el texto; queda sujeto a validación del CTO/CEO como cualquier copy nuevo |
| "Colibrí" como nombre visible | Decisión de CTO/CEO (resuelve la ex-Pregunta abierta #1) — reemplaza al nombre de trabajo "ChatGPRenovarte", que no aparece cara al usuario en ningún estado |

## Preguntas abiertas

### Resueltas por CTO/CEO (esta pasada)

- ~~**Nombre visible del chat.**~~ **Resuelto: "Colibrí".** "ChatGPRenovarte"
  era el nombre de trabajo; se descarta como nombre cara al usuario y solo
  puede quedar como referencia interna al número de spec (0016) si hace
  falta nombrar la feature en conversación entre agentes. Todo label
  visible del mockup y de este documento ya usa "Colibrí" — encaja con el
  tono cálido/spa de `brand.md` (colibrí + lirio como los dos elementos del
  logo) mejor que la referencia humorística a "ChatGPT" del nombre de
  trabajo.
- ~~**Deep link de cada producto de un combo a `/producto/[id]` en pestaña
  nueva.**~~ **Resuelto: sí**, como se proponía — cada producto de una card
  de combo linkea a `/producto/[id]` real, `target="_blank" rel="noopener"`.
- ~~**¿Thumbnails de producto en las cards de combo, o solo texto?**~~
  **Resuelto: solo texto**, como se proponía — nombre/presentación/precio,
  sin imagen. No hay `alt` que resolver en esta fase porque no hay `<img>`
  en la card de combo.

### Siguen abiertas

1. **¿Chequeo de disponibilidad antes de abrir el panel?** El diseño actual
   descubre "no disponible" recién al abrir el panel (más simple, sin
   llamada de red extra en cada página solo para decorar el FAB) — CTO/CEO
   aceptó esta propuesta tal cual está, sin cambios. Si `ai-agent`/
   `backend-agent` puede exponer un healthcheck liviano sin costo de LLM, se
   podría atenuar visualmente el FAB antes de que el visitante ni siquiera
   abra el panel — lo dejo como mejora posible, no como requisito, para no
   inventar infraestructura que RNF-09/AC-13 no pidieron.
2. **¿El transporte puede distinguir "techo de gasto alcanzado" de
   "conexión caída por otro motivo"?** El diseño contempla las dos copias
   distintas (ver estado "no disponible"), pero si el backend solo expone
   un genérico "no disponible" sin motivo, colapso a un solo mensaje
   (la variante de falla genérica) — a confirmar en la fase de RFC.
3. **Copy exacto de los mensajes de "sin recomendación" y "no disponible".**
   Los textos de este documento son un borrador de trabajo de UX, no copy
   final aprobado — CTO/CEO indicó que se pule más adelante, no bloquea
   esta pasada. Como cualquier copy nuevo, necesita paso por CTO/CEO antes
   de implementarse tal cual.
4. **Contrato de datos estructurados** (ver "Contrato de interacción"
   arriba) — no es ambigüedad de UX sino una dependencia dura hacia el RFC
   técnico: sin turnos estructurados (combos, tipo de piel/presupuesto
   confirmados, motivo de no-disponibilidad) varios de los estados de este
   documento no se pueden construir de forma confiable y consistente con
   AC-4/AC-8/AC-9. Ya documentado para que `backend-agent`/`ai-agent` lo
   tomen en la Fase 3 — no requiere más trabajo de UX ahora.
