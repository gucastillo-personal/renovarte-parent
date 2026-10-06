# UX — 0017 Carrito y orden de compra

**Mockup:** https://claude.ai/artifact/AUebBaKqEXBV3xsJwDgiFL

> **Enmienda 2026-10-05 (recorte de datos del MVP, ADR-0020):** el
> formulario pide **dos campos obligatorios: "Nombre y apellido" (un solo
> input) y teléfono**, en ese orden. Ya no hay email, dirección ni
> localidad. La confirmación, los banners y los `noscript` muestran el
> **teléfono de RenovArte (1130579528)**. Se retira el aviso de privacidad.
> El mockup de arriba **todavía muestra el formulario anterior**
> (nombre, email/teléfono, dirección, localidad) y no se actualizó en esta
> revisión; donde este documento y el mockup difieran, rige este documento.
> El copy nuevo de esta enmienda es propuesta, sujeta a aprobación del
> CTO/CEO como todo copy nuevo.

Prototipo de revisión operable (no es la implementación): ficha, grilla, chat
con combos, carrito, formulario, confirmación y estados de error, en ancho
móvil (390px) y escritorio, con y sin JS. El selector "Al enviar" simula cada
resultado del envío (OK, falla, tope, precio cambiado).

Este documento define layout, interacción, estados, accesibilidad y mapeo de
contenido para `specs/0017-carrito-orden-compra/spec.md` (22 AC). Aplica solo
a `renovarte-catalogo`. No decide arquitectura del repo de órdenes (Fase 3),
pero sí fija el **contrato de interacción** que ese repo y el cliente tienen
que poder servir (sección al final).

## Resumen de decisiones y por qué

- **El carrito es una página, `/carrito`, no un drawer.** Tres motivos:
  (1) el chat ya es un modal (`role="dialog" aria-modal`); un drawer de
  carrito abierto desde dentro del chat sería un modal sobre otro modal;
  (2) el formulario tiene 5 campos y estados de error. En 390px eso pide
  una página con scroll propio, no un panel; (3) una URL real funciona con
  el botón "atrás", se puede recargar (AC-5) y el acceso del header es un
  `<a href="/carrito">` que navega aun antes de hidratar. La página se
  prerenderiza estática (shell SSG) y el contenido sale del estado del
  navegador, así que no agrega backend (AC-14, `constitution.md §II.4`).
- **Acceso al carrito en el header, arriba a la derecha**, y el **header
  pasa a ser sticky**. El chat ocupa abajo a la derecha (FAB); el carrito
  arriba a la derecha. Nunca se superponen, y es la ubicación que cualquier
  visitante busca. El sticky es lo que hace cumplir el "en todo momento" de
  AC-2: en móvil, la grilla es larga y un header no sticky desaparece a los
  dos scrolls, junto con el contador.
- **El formulario (nombre y apellido + teléfono) vive en la misma página
  que el carrito** (sin paso intermedio "Continuar"). En móvil va debajo de las líneas y el total; en
  escritorio va en una columna derecha sticky. Un paso menos, y quien
  edita cantidades ve el total al lado de lo que va a enviar.
- **Pregunta abierta #4 (agregar desde la card de la grilla): no, en esta
  pasada.** Solo desde la ficha (AC-1) y desde el combo (AC-6). Detalle en
  "Agregar desde la grilla" más abajo.
- **AC-15 / pregunta #8 (rechazar vs. corregir): rechazar y volver a
  mostrar.** Nunca corregir en silencio. Como el visitante no recibe copia
  por mail (AC-11), el único momento en que ve el total es en pantalla; si el
  servidor enviara un total que el visitante nunca vio, esa diferencia no
  quedaría registrada en ningún lado del lado del visitante.
- **La confirmación está pensada para alguien que no va a recibir ningún
  mail.** Número de orden grande, botón "Copiar número", la frase "Guardalo
  o sacale una captura" y el resumen de lo pedido en pantalla.
- **Los estados de "no enviada" siempre dejan una salida.** Además de
  reintentar, muestran los canales de consulta y un botón "Copiar detalle
  del pedido" para pegarlo en un mail o MD. Esto es lo que vuelve útil
  AC-22 ("más los canales de contacto alternativos"): el visitante puede
  hacer el pedido igual, a mano, sin reescribirlo.
- **Mismo tono que 0016:** sin urgencia, sin rojo. Los avisos informativos
  (precio cambió, producto retirado) usan el tratamiento neutro `sage-50`
  que ya usa el chat para "no disponible". Los errores del visitante
  (formulario) y "tu orden no se envió" sí se marcan como error, con ícono,
  texto en negrita y borde más grueso, sin inventar un color nuevo (ver
  Pregunta abierta #A).

## Layout

### Header (todas las páginas) — cambia

- `layout.tsx`: el `<header>` actual pasa a `sticky top-0 z-30` (el panel
  del chat es `z-50` y el FAB `z-40`, así que el chat sigue quedando por
  encima). Mismos tokens: `bg-beige-100 border-b border-beige-200`, mismo
  `py-3`.
- Contenido: `justify-between` → wordmark a la izquierda (sin cambios) y el
  **acceso al carrito** a la derecha:
  - Un `<a href="/carrito">`, alto mínimo 44px, `rounded-full`, hover
    `bg-sage-100`, `text-sage-800`.
  - Ícono de bolsa en línea fina (`stroke-width 1.5`, mismo trazo que el
    ícono del FAB y el line-art del logo).
  - Móvil (<640px): solo ícono. Escritorio (≥640px): ícono + label
    "Carrito" (`font-medium`), como el FAB, que muestra "Chat" desde `sm`.
  - **Contador:** círculo `min-w-5 h-5 rounded-full bg-sage-600
    text-beige-50 text-xs font-semibold tabular-nums`, sobre la esquina
    superior derecha del ícono (posicionado en absoluto, así su aparición
    no mueve nada: sin CLS). Se usa `sage-600` y no `sage-500` porque el
    texto es de 12px y `sage-500` no llega a AA (ver #B). Con 0 productos
    no se muestra; con más de 99, "99+".
  - **Qué cuenta:** la **suma de unidades** de productos disponibles (2
    cremas iguales + 1 emulsión = 3), sin contar líneas de productos que ya
    no están en el catálogo. Es la lectura más común de "cuántos productos"
    en AC-2, y después de agregar un combo de 3 el número sube 3, lo que
    coincide con el mensaje de confirmación del combo.
  - Al subir el número, el contador hace una escala breve (320ms; sin
    animación con `prefers-reduced-motion`).
- No se agrega ningún `ul > li` dentro de `<main>` en la home (el test e2e
  `main ul > li` cuenta cards del catálogo, ver comentario en
  `MissionSection.tsx`). El acceso vive en el `<header>`, fuera de `<main>`.

### Ficha de producto `/producto/[id]` — cambia

Orden en la columna de info, de arriba hacia abajo (lo existente sin
cambios salvo lo marcado):

1. Chips de categoría/grupo/oferta (sin cambios).
2. `h1` nombre, presentación, `ProductPrice size="lg"` (sin cambios).
3. **Nuevo — zona de agregar**, inmediatamente debajo del precio y
   **antes** de la descripción:
   - Botón primario **"Agregar al carrito"**: `bg-sage-500 text-beige-50
     rounded-lg px-5 py-3 font-medium`, ancho completo en móvil y ancho
     automático desde `md`.
   - Debajo, una línea de estado (`text-sm text-sage-700`), vacía mientras
     el producto no está en el carrito. Cuando está: "✓ En tu carrito: 2 ·
     **Ver carrito**" (link a `/carrito`). Refleja siempre la cantidad real
     de esa línea, también al volver a la ficha más tarde o si se cambió la
     cantidad desde el carrito.
   - Sin selector de cantidad en la ficha: cada toque suma 1 (AC-4) y la
     cantidad se edita en el carrito. Un stepper acá duplicaría el control
     y haría ambigua la acción ("¿agregar 2 o poner 2?").
4. Descripción, "← Volver al catálogo" (sin cambios).

No hay barra fija "Agregar" al pie en móvil. La descarté porque el FAB del
chat ocupa esa esquina y una barra fija lo taparía o quedaría tapada. En
390px el botón queda cerca del primer scroll, pegado al precio.

### Agregar desde la grilla (pregunta abierta #4) — no, en esta pasada

La grilla y `ProductCard` quedan **sin cambios**. Motivos, en orden de peso:

1. **Estructura:** `ProductCard` es un único `<a>` que envuelve toda la
   card. Un botón adentro es HTML inválido (contenido interactivo dentro de
   `<a>`) y rompe la semántica para lectores de pantalla. Agregarlo obliga a
   rediseñar la card (link en imagen y nombre, botón aparte) y a cambiar el
   patrón de hover y foco de toda la grilla.
2. **Teclado:** son dos tab stops por card en lugar de uno. Con el catálogo
   completo, recorrer la grilla con Tab cuesta el doble.
3. **Producto:** en skincare, la ficha es donde está la descripción (tipo
   de piel, uso). Pasar por la ficha antes de agregar reduce pedidos
   equivocados, que en este modelo RenovArte tiene que corregir a mano por
   mail o Instagram. Quien no sabe qué elegir ya tiene el camino rápido: el
   combo de Colibrí, con una sola acción.
4. **Riesgo:** AC-21 exige que la grilla siga igual; no tocarla es la forma
   más segura de cumplirlo.

Es reversible: si el CTO/CEO lo quiere, el diseño sería un botón
secundario de ícono ("+ bolsa") al pie de la card, a la derecha del
precio, con la card reestructurada. Eso merece su propia pasada de UX
(ver Pregunta abierta #C).

### Card de combo en el chat (`ChatComboCard`) — cambia

Se agrega un bloque al final de cada card, debajo del total y de la
relación con el presupuesto (todo lo existente queda igual):

```
┌─────────────────────────────────────┐
│ MÁS BARATO                           │
│ Crema De Limpieza …   160 g · $19.200│
│ Emulsion Humectante … 100 ml · $14.400│
│ ─────────────────────────────────    │
│ $ 33.600                             │
│ Tu presupuesto: $ 50.000             │
│ $ 16.400 por debajo de tu presupuesto│
│ ┌─────────────────────────────────┐ │
│ │    Agregar combo al carrito      │ │  ← nuevo, botón primario, ancho completo
│ └─────────────────────────────────┘ │
│ ✓ Agregaste los 2 productos de este  │  ← aparece después de agregar
│   combo, 1 de cada uno. Tu carrito   │
│   tiene 5 productos.  Ver carrito    │
└─────────────────────────────────────┘
```

- Botón **"Agregar combo al carrito"**, primario (`bg-sage-500`), ancho
  completo de la card. El panel es siempre de una columna (0016), así que
  los 3 botones quedan apilados, uno por card, sin ambigüedad.
- Al usarlo: se agregan todos los productos del combo, 1 unidad de cada uno,
  sumando a lo que ya hubiera (AC-4, AC-6). **El panel no se cierra, no
  navega y no toca el hilo** (AC-7).
- Debajo del botón aparece una línea de confirmación (fade corto, sin
  animación con reduced-motion): "✓ Agregaste los N productos de este combo,
  1 de cada uno. Tu carrito tiene X productos." + link **"Ver carrito"**. El
  número total está dentro del mensaje porque, en escritorio, el drawer de
  420px tapa el contador del header, y en móvil el panel es de pantalla
  completa. Sin esa línea, el visitante no tendría ninguna señal visible
  de que el carrito cambió.
- El **mismo botón** (mismo nodo, así no se pierde el foco) cambia su texto
  a **"Agregar otra vez"**. Volver a agregar suma otra unidad de cada
  producto. Esta decisión evita dos cosas: dejar el botón igual (y que un
  doble toque duplique sin darse cuenta) y deshabilitarlo (que impediría un
  uso legítimo).
- **"Ver carrito"** es navegación en la misma pestaña (`<Link
  href="/carrito">`), cierra el panel **sin** devolver el foco al FAB y
  lleva el foco al `h1` del carrito. La conversación **no se pierde**:
  `ChatProvider` vive en el root layout y la navegación cliente no lo
  desmonta, así que al reabrir el FAB desde `/carrito` el hilo (y el estado
  "Agregado" de las cards) sigue ahí. Esto es un requisito para
  implementación (ver Contrato). Es distinto de los links de producto del
  combo, que siguen abriendo en pestaña nueva (0016): ir a verificar un
  producto es una consulta lateral; ir al carrito es el paso siguiente.
- Si el combo trae un producto que ya no está en el catálogo publicado (caso
  raro, porque el RAG lee el catálogo vigente), se agrega igual y el
  carrito lo marca como no disponible al abrirse (ver Estados). No se
  bloquea el botón por eso.

### Página `/carrito` — nueva

Ruta estática nueva, `<title>` "Tu carrito — RenovArte". `noindex` sugerido
(no tiene contenido útil para SEO).

**Móvil (~390px), de arriba abajo:**

1. `h1` **"Tu carrito"** (Cormorant, `text-3xl`), y a la derecha en la misma
   línea "N productos" (`text-sage-600`).
2. Aviso de revalidación (condicional, ver Estados).
3. Lista de líneas (`<ul>`), cada una separada por `border-b
   border-beige-200`:
   ```
   [img 64]  Crema Humectante Con Aceite De Palta X 160g   ← link a la ficha, font-semibold sage-800
             160 g · $ 32.160 c/u                          ← sage-600, tabular-nums
             [ − | 2 | + ]   Quitar             $ 64.320   ← stepper, text button, subtotal font-semibold
   ```
   - Miniatura 64px (72px desde `md`), `rounded-lg border-beige-200`, con
     la `imagen` del producto. Es decorativa: `alt=""`, porque el nombre
     está al lado. Si la presentación viene vacía (hay productos así en
     `products.json`), se omite junto con su separador.
   - Stepper: dos botones de 44×40px con "−" y "+" y la cantidad en medio.
     "−" se deshabilita en 1 (para sacar una línea se usa "Quitar", que es
     una acción explícita y se puede deshacer). "+" se deshabilita en el
     máximo por línea (ver #D).
   - "Quitar" es un botón de texto subrayado. Quitar una línea la reemplaza
     por una fila "Quitaste {nombre}. **Deshacer**", que queda hasta la
     próxima acción en el carrito (sin temporizador: un límite de tiempo
     perjudica a quien navega con lector o teclado).
4. "Vaciar carrito", botón de texto al pie de la lista. Al tocarlo **no**
   vacía: se reemplaza en el mismo lugar por "¿Vaciar el carrito? Se quitan
   todos los productos. [Sí, vaciar] [Cancelar]" (sin `confirm()` nativo).
5. "← Seguir comprando", link a `/`.
6. **Resumen**: caja `rounded-lg border-beige-200 bg-beige-100 p-4`:
   - "Total (N productos)" a la izquierda y el monto a la derecha
     (`text-2xl font-semibold tabular-nums`).
   - "No se cobra nada en este paso. RenovArte te contacta para coordinar
     el pago y el envío." (`text-sm`). Esto es la aclaración de AC-12: no
     hay campo, selector ni costo de pago o envío en ningún paso.
7. **"Tus datos"** (formulario, dentro de la misma caja de resumen,
   separado por un `border-t`), ver "Formulario".
8. Botón **"Enviar orden"**, primario, ancho completo.
9. Padding inferior de `main` de al menos 104px en esta página, así el FAB
   del chat (que sigue presente) nunca tapa el botón de envío ni el último
   campo al final del scroll.

**Escritorio (≥768px):** dos columnas, `grid-cols-[1fr_380px] gap-10`.
Izquierda: `h1`, aviso, líneas, deshacer/vaciar y "Seguir comprando".
Derecha: la caja de resumen y el formulario, `sticky top-[88px]` (debajo del
header sticky). El total queda a la vista mientras se edita cualquier línea.
Con el campo de nombre la columna es ~90px más alta: el `sticky` aplica solo
si la ventana tiene alto suficiente (`@media (min-height: 760px)`); en
ventanas más bajas la columna fluye normal, para que el botón "Enviar orden"
nunca quede fuera de alcance.

**Carrito vacío (AC-8):** en lugar de líneas y formulario, un bloque con el
mismo tratamiento de "sin resultados" de la búsqueda (`border-dashed
border-beige-300`, texto centrado `sage-600`): "Tu carrito está vacío." +
botón primario **"Ver catálogo"** (a `/#catalogo`) + botón de texto
"¿No sabés qué elegir? Pedile un combo a Colibrí" (abre el chat). No hay
formulario ni botón de enviar, así que no se puede generar una orden
vacía. Si el carrito solo tiene líneas no disponibles, se muestran las
líneas, y en lugar del formulario: "No hay productos disponibles para
generar una orden. Quitá los que ya no están y agregá otros desde el
catálogo."

### Formulario "Tus datos"

- `h2` "Tus datos" (Cormorant) + bajada: "Solo necesitamos tu nombre y tu
  teléfono. Te llamamos o te escribimos para coordinar el pago y el envío."
  *(2026-10-05, ADR-0020)*
- Dos campos obligatorios, en este orden (el nombre primero: es lo que se
  dice al saludar, y el teléfono queda pegado al botón de envío). Label
  visible arriba, nunca solo placeholder, y **sin placeholder** (el hint
  visible ya muestra el ejemplo). Sin `fieldset`/`legend`: son dos campos
  sueltos y el `h2` ya los titula:

| # | Campo (label) | Tipo / atributos | Hint visible |
|---|---|---|---|
| 1 | Nombre y apellido | `type="text"`, `name="nombre"`, `autocomplete="name"`, `autocapitalize="words"`, `spellcheck="false"`, `enterkeyhint="next"`, `maxlength="80"` | "Para saber a quién llamar. Ej.: Ana Pérez" |
| 2 | Teléfono | `type="tel"`, `name="telefono"`, `autocomplete="tel"`, `inputmode="tel"`, `enterkeyhint="done"` | "Con código de área. Ej.: 11 5555 5555" |

- **Teclado móvil:** el nombre abre el teclado de texto con mayúscula
  inicial por palabra; el teléfono abre el teclado numérico/telefónico. Un
  solo campo de nombre es una decisión del owner por rapidez: no se parte
  en nombre y apellido separados ni se exige "dos palabras" (ver #J).
- Inputs: `rounded-lg border border-beige-300 bg-beige-50 px-3 py-2.5
  text-base` (16px, para que iOS no haga zoom al enfocar), ancho completo,
  separados por `gap-4`. Un asterisco no reemplaza a la palabra: ambos son
  obligatorios y el bloque lo dice una vez en la bajada ("Solo necesitamos…"),
  sin marcar "(opcional)" en ningún campo porque no hay opcionales.
- **Sin aviso de privacidad** *(retirado 2026-10-05, pregunta #9)*. Tampoco
  hay checkbox de consentimiento.
- No hay campos de pago, envío, cupón ni comentario (AC-12, Alcance/Out).

**Validación (AC-9):**

- Se valida **al enviar**, no mientras se escribe. Después del primer
  intento fallido, cada campo se revalida al salir de él (blur), y su error
  desaparece apenas se corrige.
- Reglas (el cliente solo ayuda; el repo de órdenes vuelve a validar):
  - **Nombre y apellido:** obligatorio; tras recortar espacios al principio
    y al final, de 2 a 80 caracteres y con al menos una letra (cualquier
    alfabeto, con tildes, `ñ`, apóstrofos y guiones). No se exige más de
    una palabra.
  - **Teléfono:** obligatorio, de 8 a 15 dígitos; acepta espacios, guiones,
    paréntesis y `+`. Se ignoran los espacios al principio y al final.
  - Un nombre vacío o de solo espacios cuenta como vacío (primer error).
- Al fallar: arriba del formulario aparece un **resumen de errores** ("Revisá
  estos datos antes de enviar:" y una lista con un ítem por campo con error,
  en el orden del formulario, donde cada ítem lleva al campo), y el foco va
  a ese resumen. Si hay un solo error, el resumen igual aparece (mismo
  patrón siempre). Además, cada campo con error muestra el mensaje debajo,
  con ícono y `font-semibold`, y el input pasa a borde de 2px `sage-800`
  con `aria-invalid="true"`.
- Copy de errores (qué pasó y cómo se arregla):
  - Nombre vacío: "Dejanos tu nombre y apellido para saber a quién llamar."
  - Nombre inválido (sin letras, o más de 80 caracteres): "Revisá el nombre:
    escribilo con letras y hasta 80 caracteres (ej.: Ana Pérez)."
  - Teléfono vacío: "Dejanos un teléfono para contactarte."
  - Teléfono inválido: "Revisá el teléfono: escribilo con código de área, solo números (ej.: 11 5555 5555)."
- **Qué se guarda en el navegador:** el carrito sigue en `localStorage`. El
  **nombre y apellido y el teléfono** se guardan **solo en `sessionStorage`
  de la pestaña** (ADR-0020; AC-28): sobreviven a una recarga, a un error de
  envío y a editar el carrito, y se pierden al cerrar la pestaña. Nunca en
  `localStorage`, nunca entre visitas (RNF-12 / AC-18: no dejar datos
  personales en un dispositivo compartido sin que el visitante lo sepa).
  Se guardan al salir de cada campo (blur) y al enviar, no en cada tecla. Al
  confirmarse la orden, el formulario se vacía; lo único de contacto que
  queda en `sessionStorage` es lo que la confirmación necesita para
  mostrarse tras una recarga (nombre y teléfono), hasta cerrar la pestaña.

## Interacción

### Agregar desde la ficha

1. Toque en "Agregar al carrito" → +1 de ese producto (crea la línea o suma
   a la existente, AC-4), con el `precio_venta` que se ve en la ficha (AC-1).
2. La línea de estado pasa a "✓ En tu carrito: N · Ver carrito"; el
   contador del header sube y hace la escala breve.
3. Anuncio (live region del sitio): "Agregaste {nombre} al carrito. En tu
   carrito: N."
4. El foco **queda en el botón**. No hay toast ni modal que se abra; seguir
   navegando no requiere cerrar nada.

### Agregar un combo desde el chat

Descrito en "Card de combo". El anuncio sale de una live region **dentro
del diálogo** (ver Accesibilidad).

### Editar el carrito

- **+ / −:** cambian la cantidad al instante, recalculan subtotal y total
  (AC-3) y el foco queda en el mismo botón. Si ese botón se deshabilita
  (llegó a 1 o al máximo), el foco pasa al otro botón del stepper.
  Anuncio: "{nombre}: N unidades. Total $ X."
- **Quitar:** la línea se reemplaza por la fila de deshacer; el foco va a
  "Deshacer". Anuncio: "Quitaste {nombre} del carrito. Total $ X."
  "Deshacer" la reinserta en la misma posición y devuelve el foco a su
  "Quitar".
- **Vaciar:** confirmación en el mismo lugar (foco a "Cancelar", la opción
  segura); "Sí, vaciar" deja el estado de carrito vacío con foco en el
  `h1`. Anuncio: "Vaciaste el carrito."
- **Persistencia (AC-5):** el carrito se guarda en el navegador en cada
  cambio y se lee al cargar cualquier página. Si el visitante tiene el
  sitio abierto en dos pestañas, el contador de la otra pestaña se
  actualiza solo (evento `storage`).

### Revalidación contra el catálogo vigente (pregunta #10, AC-15)

Cada vez que se abre `/carrito`, cada línea se contrasta con el catálogo
publicado (`products.json` del build vigente):

- **Precio distinto** → la línea pasa al precio vigente y muestra una nota
  debajo: "El precio cambió: antes $ 13.900, ahora $ 14.400."
- **Producto que ya no existe** → la línea queda visible pero atenuada
  (texto `sage-600`, miniatura al 50%), con "Ya no está en el catálogo" en
  lugar del precio y "No se incluye en la orden", y solo la acción
  "Quitar". No suma al total ni al contador y no se envía.
- Si hubo cualquiera de los dos, arriba de la lista aparece un aviso neutro
  (`rounded-lg bg-sage-50`, `role="status"`): **"Actualizamos tu carrito con
  el catálogo vigente."** y una lista, por ejemplo "1 precio cambió desde
  que lo agregaste." / "1 producto ya no está en el catálogo y no se va a
  incluir en la orden."
- Sin vencimiento del carrito (default de #10).

### Enviar la orden

1. "Enviar orden" → validación (arriba). Si pasa:
2. **Enviando:** el botón muestra "Enviando orden…" con `aria-disabled`,
   los dos inputs (nombre y teléfono) pasan a `readonly` y el stepper, "Quitar" y "Vaciar" se
   deshabilitan. Así lo que se envía es exactamente lo que se ve (AC-13).
   Debajo: "Estamos enviando tu orden a RenovArte. No cierres esta
   página." Anuncio: "Enviando tu orden…". Un segundo toque no reenvía.
3. Resultados posibles (cada uno se puede probar en el mockup):
   - **Recibida** → confirmación (abajo).
   - **Falla / servicio caído (AC-20)** → ver Estados.
   - **Tope alcanzado (AC-22)** → ver Estados.
   - **Precio o producto cambiado en el servidor (AC-15)** → ver Estados.
4. Nunca se muestra la confirmación sin una respuesta positiva del repo de
   órdenes que signifique "mail aceptado para entrega" (AC-20). Un timeout
   se trata como falla, nunca como éxito.

### Confirmación (AC-10, AC-11)

Reemplaza el contenido de `/carrito` (misma URL). El carrito queda vacío y
el contador del header desaparece. Columna única centrada (`max-w-2xl`):

1. `h1` **"Tu orden fue enviada a RenovArte"**. El foco va acá.
2. Bloque destacado `bg-sage-50 rounded-lg`: eyebrow "NÚMERO DE ORDEN"
   (mayúsculas con tracking amplio, como "SPA DE PIEL"), el número en
   `text-4xl font-semibold tabular-nums` con tracking leve, seleccionable
   de un toque, y el botón **"Copiar número"** (el label pasa a "Copiado"
   por 1,6 s; si el portapapeles falla, se selecciona el texto). Debajo:
   **"Guardalo o sacale una captura: no te vamos a mandar la orden por
   mail."**
3. `h2` "Qué sigue": "RenovArte va a contactar a {nombre y apellido} al
   {teléfono} para coordinar el pago y el envío. En el sitio no se cobra
   nada." *(2026-10-05, ADR-0020: nombre y teléfono)*. El nombre se
   muestra como texto plano (escapado); si el visitante lo escribió largo,
   el texto corta línea sin desbordar (`break-words`).
4. `h2` "¿Tenés una consulta sobre tu orden?": Teléfono de RenovArte
   **1130579528** (link `tel:` + botón "Copiar"; *pendiente:* si RenovArte
   confirma que es WhatsApp, se suma un link a `wa.me` con el número en
   formato internacional), Email
   **renovartebyjuli@gmail.com** (link `mailto:` con asunto
   "Consulta por orden {número}" + botón "Copiar", porque `mailto:` no
   funciona en todos los dispositivos) e Instagram, por mensaje directo,
   **@renovarte_by_juli** (link a `https://ig.me/m/renovarte_by_juli`, que
   abre el MD directo; `target="_blank" rel="noopener"`). Nota: "Mencioná
   el número {número} en tu mensaje."
5. `h2` "Lo que pediste": lista de solo lectura (nombre · presentación × N
   y subtotal) y el total. Como no hay copia por mail, esta pantalla es el
   único registro del visitante (para la captura).
6. Botón primario "Volver al catálogo".

La confirmación sobrevive a una recarga **en la misma pestaña** (estado de
sesión, no persistente). Al navegar a otra página y volver a `/carrito`, se
ve el carrito vacío. No es historial de órdenes (Out); es para no perder el
número por un toque accidental en recargar.

### Progresividad / JS

El carrito depende de JS (estado del navegador), igual que el chat. El
catálogo sigue 100% funcional sin JS (AC-21). Mismo patrón
`useMounted` que `ChatFab`/`MissionCarouselLive`:

- **Header:** el acceso al carrito está en el HTML desde el primer render y
  es un link real (navega sin JS). El contador aparece recién al hidratar,
  posicionado en absoluto, sin CLS.
- **Ficha:** el botón "Agregar al carrito" está en el HTML desde el primer
  render pero inerte (`tabIndex=-1`, `pointer-events-none`) hasta hidratar.
  En un `<noscript>` debajo: "Para usar el carrito necesitás JavaScript
  habilitado. También podés pedir este producto llamando al 1130579528,
  escribiendo a renovartebyjuli@gmail.com o por mensaje directo en
  Instagram a @renovarte_by_juli."
- **`/carrito` sin JS:** el shell estático muestra `h1` "Tu carrito" y en
  `<noscript>`: "Para ver tu carrito y enviar una orden necesitás
  JavaScript habilitado en tu navegador. También podés hacer tu pedido
  llamando al 1130579528, escribiendo a renovartebyjuli@gmail.com o por
  mensaje directo en Instagram a @renovarte_by_juli." + "← Volver al catálogo". Con JS, antes
  de leer el estado, se ve solo el `h1` (sin un "vacío" que parpadee a
  "lleno").

## Estados y responsividad

| Estado | Móvil (~390px) | Escritorio (≥768px) |
|---|---|---|
| Header, carrito vacío | Ícono sin contador; `aria-label` "Carrito, vacío" | Ícono + "Carrito", sin contador |
| Header, con productos | Ícono + contador de unidades | Ícono + "Carrito" + contador |
| Ficha, no está en el carrito | Botón ancho completo, línea de estado vacía | Botón ancho automático |
| Ficha, ya está en el carrito | "✓ En tu carrito: N · Ver carrito" | Igual |
| Combo recién agregado | Confirmación dentro de la card y botón "Agregar otra vez"; el panel sigue abierto | Igual (el drawer tapa el header, por eso el total va en el mensaje) |
| Carrito con productos | 1 columna: líneas → total → formulario → enviar | 2 columnas; resumen y formulario sticky a la derecha |
| Carrito vacío | Bloque punteado + "Ver catálogo" + "Pedile un combo a Colibrí"; sin formulario | Igual, 1 columna |
| Carrito revalidado | Aviso `sage-50` arriba y nota en cada línea afectada | Igual |
| Solo líneas no disponibles | Líneas atenuadas; en lugar del formulario, texto explicando por qué no se puede enviar | Igual |
| Errores de formulario | Resumen arriba del formulario (foco ahí) y error en cada campo | Igual, en la columna derecha |
| Enviando | Botón "Enviando orden…", todo en solo lectura | Igual |
| Orden no enviada (falla) | Banner arriba del botón (foco ahí), con Reintentar, canales y "Copiar detalle" | Igual |
| Orden no enviada (tope) | Banner de tope, sin Reintentar, con canales y "Copiar detalle" | Igual |
| Precio cambió en el servidor | Aviso arriba de la lista (foco ahí) y líneas actualizadas; hay que volver a enviar | Igual |
| Confirmada | Columna centrada: número, qué sigue, canales, resumen | Igual, `max-w-2xl` |
| Sin JS | Links del header funcionan; botón de agregar inerte con aviso `noscript`; `/carrito` muestra aviso y canales | Igual |
| `prefers-reduced-motion` | Sin escala del contador, sin fade en la confirmación del combo | Igual |

### Orden no enviada — falla o servicio caído (AC-20)

- Banner arriba del botón "Enviar orden", `rounded-lg border-[1.5px]
  border-sage-700 bg-beige-50`, con ícono de alerta en línea fina:
  - Título: **"Tu orden no se envió"**
  - "No pudimos comunicarnos con RenovArte. Tu carrito y tus datos siguen
    acá: podés intentar de nuevo."
  - Botón **"Reintentar envío"** (reenvía con los mismos datos).
  - "Si sigue sin funcionar, podés hacer el pedido por teléfono, email o
    Instagram:" y los canales (teléfono 1130579528 + Copiar, email +
    Copiar, Instagram MD).
  - Botón **"Copiar detalle del pedido"**: copia un texto plano ("Pedido
    RenovArte / - {nombre} ({presentación}) x{N}: $ X / Total: $ Y"). No
    incluye el nombre ni el teléfono del visitante (quien lo pega en un
    mensaje ya se identifica; así el texto copiado no lleva datos
    personales al portapapeles). Si el
    portapapeles falla, muestra el texto en un `textarea` de solo lectura
    ya seleccionado.
- `role="alert"` y el foco va al banner: es el resultado directo de la
  acción del visitante y cambia lo que tiene que hacer.
- El carrito, los datos del formulario y el número de ítems quedan
  intactos. No se genera número de orden.

### Orden no enviada — tope mensual alcanzado (AC-22)

- Mismo banner, con otro contenido:
  - **"Tu orden no se envió"**
  - "Este mes llegamos al límite de órdenes que podemos recibir desde el
    sitio. Tu carrito sigue guardado. Mientras tanto, podés hacer tu pedido
    por teléfono, por email o por mensaje directo en Instagram:" + canales.
  - "Copiar detalle del pedido" + "Para pegarlo en tu mensaje."
  - **Sin "Reintentar"**: no va a funcionar hasta el mes siguiente, y
    ofrecerlo sería prometer algo falso.
- Variante opcional (si la Fase 3 lo permite a costo ~0): el aviso aparece
  **al abrir `/carrito`**, antes de completar el formulario, con título "Por
  ahora no podemos recibir órdenes desde el sitio" y `role="status"`. En esa
  variante no se muestra el formulario (no tiene sentido pedir datos que no
  se van a poder enviar). Ver Pregunta abierta #F. El comportamiento al
  enviar (arriba) tiene que existir igual, como garantía.
- El resto del sitio no cambia: el header, la ficha (el botón de agregar
  sigue funcionando, porque armar el carrito no cuesta nada) y el chat
  (AC-21).

### Precio o producto cambiado al enviar (AC-15, pregunta #8)

Caso: el catálogo se republicó entre que el visitante abrió `/carrito` y
tocó "Enviar", o alguien manipuló el navegador.

- El repo de órdenes **rechaza** la orden y devuelve los precios y la
  disponibilidad vigentes. No se manda ningún mail.
- El cliente actualiza las líneas (notas por línea, igual que en la
  revalidación) y muestra el aviso de arriba con: "Los precios se
  actualizaron mientras completabas tus datos. Revisá el total y volvé a
  enviar la orden." El foco va a ese aviso. Los datos del formulario se
  mantienen.
- El visitante vuelve a tocar "Enviar orden" con el total nuevo a la
  vista. Así se cumple "el visitante ve el precio final antes de la
  confirmación" sin corregir nada a sus espaldas.
- Si la manipulación fue maliciosa, el visitante honesto no se entera de
  nada distinto; el atacante solo ve el precio real.

## Accesibilidad

- **Header:** el acceso es un `<a>` con `aria-label` dinámico ("Carrito,
  vacío" / "Carrito, 3 productos"); el contador visual es `aria-hidden`
  (el número ya está en el label). `aria-current="page"` en `/carrito`.
- **Live regions:**
  - Sitio: una sola región `role="status" aria-live="polite"` `sr-only`,
    fuera de `<main>` (en el layout), para "Agregaste…", cambios de
    cantidad, "Quitaste…", "Vaciaste…" y "Enviando…". Una sola región evita
    anuncios duplicados o que se pisen.
  - **Dentro del chat:** el panel es `aria-modal`, así que los lectores
    ignoran lo que está fuera del diálogo, incluida la región del sitio. El
    anuncio del combo ("Combo Más barato: agregaste los 2 productos…") sale
    de una región `role="status"` propia **dentro del diálogo**, hermana
    del hilo y **no dentro del `role="log"`**. Si estuviera adentro del log,
    se anunciaría dos veces o como un mensaje nuevo de la conversación. La
    línea visible "✓ Agregaste…" dentro de la card es texto normal, no una
    live region.
- **Card de combo:** el botón tiene `aria-describedby` apuntando al `h3` del
  nivel, y un sufijo `sr-only` "(N productos)". Un lector oye "Agregar
  combo al carrito (2 productos), Más barato" y no tres botones idénticos.
- **Líneas del carrito:** `<ul aria-label="Productos en tu carrito">`. El
  stepper es `role="group" aria-label="Cantidad de {nombre}"` con botones
  "Restar una unidad" / "Sumar una unidad" y la cantidad en `<output>`.
  Todos los "Quitar" llevan el nombre del producto en `sr-only` ("Quitar
  Crema Humectante…"). Los subtotales llevan el prefijo `sr-only`
  "Subtotal: ", el mismo patrón que "Precio anterior: " de `ProductPrice`.
- **Foco:** nunca queda en `body`. Las reglas están en cada interacción de
  arriba: botón que se deshabilita → el otro del stepper; "Quitar" →
  "Deshacer"; "Vaciar" → "Cancelar"; error de validación → resumen; falla
  de envío → banner; confirmación → `h1`; "Ver carrito" desde el chat →
  `h1` del carrito.
- **Formulario:** `<label for>` visible en cada campo ("Nombre y apellido",
  "Teléfono"); los hints y los errores se asocian con `aria-describedby`
  (hint y error, en ese orden); `aria-invalid` en los campos con error;
  `autocomplete="name"` y `autocomplete="tel"` (WCAG 1.3.5, propósito del
  campo). Orden de foco = orden visual: … "Vaciar" → nombre → teléfono →
  "Enviar orden". Enter en el teléfono envía el formulario; Enter en el
  nombre pasa al teléfono (no envía). `novalidate` en el `<form>` (los mensajes son
  los nuestros, no los del navegador). El resumen de errores es un
  contenedor con `tabindex="-1"`, etiquetado por su título, y cada ítem es
  un botón que enfoca el campo.
- **Banners de envío:** `role="alert"` para "no se envió" (el visitante
  tiene que enterarse ya); `role="status"` para avisos neutros
  (revalidación, tope avisado al entrar).
- **Contraste:** el texto nuevo usa `sage-600` o más oscuro sobre
  `beige-50`/`beige-100` (AA según `brand.md`). El contador usa `sage-600`
  (ver #B sobre `sage-500`).
- **Tamaño táctil:** 44px mínimo en el acceso del header, los botones del
  stepper (44×40) y los botones primarios.
- **`prefers-reduced-motion`:** se respeta en todas las animaciones
  nuevas.

## Mapeo de contenido

| Elemento en pantalla | Fuente |
|---|---|
| Nombre, presentación y precio en el carrito, la confirmación y el detalle copiado | `products.json` vigente (`nombre`, `presentacion`, `precio_venta`), nunca texto libre (AC-1, AC-6, AC-15) |
| Campos obligatorios: "Nombre y apellido" y teléfono | ADR-0020 (2026-10-05). `spec.md` (precisión 2026-10-05b, AC-9) ya está alineada |
| ~~Aviso de privacidad~~ | Retirado 2026-10-05 (pregunta #9) |
| Número de orden, aclaración de que pago y envío se coordinan después, canales de consulta | AC-10 |
| Teléfono 1130579528, renovartebyjuli@gmail.com e Instagram como canales visibles | Pregunta #3 (resuelta 2026-10-05) |
| @renovarte_by_juli, por MD de Instagram | Alcance, AC-10 y AC-22 (confirmado 2026-09-30c) |
| "Guardalo o sacale una captura: no te vamos a mandar la orden por mail." | Deriva de AC-11 (sin copia al visitante) |
| Todo el resto del copy (labels, hints, errores, avisos, banners, estados vacíos, "Copiar detalle del pedido") | **Autoría UX**: propuesta de este documento, sujeta a aprobación del CTO/CEO como cualquier copy nuevo |

## Contrato de interacción (para la Fase 3)

No decide arquitectura, pero el diseño de arriba **requiere**:

1. **Respuestas del repo de órdenes distinguibles** por el cliente, no por
   texto:
   - `aceptada` → con el **número de orden** (el mismo que va en el mail,
     AC-13), solo después de que el mail fue aceptado para entrega (AC-20).
   - `rechazada_por_catalogo` → con, por línea, el precio vigente y/o
     "no disponible", para poder actualizar el carrito y pedir que se
     vuelva a enviar (AC-15).
   - `tope_alcanzado` → distinto de cualquier otra falla (AC-22: sin
     "Reintentar" y con otro copy).
   - `invalida` → datos de contacto que el servidor rechaza (defensa en
     profundidad; el cliente muestra los mismos errores por campo si puede
     mapearlos, y si no, un error general arriba del formulario).
   - Cualquier otra cosa (5xx, timeout, red) → falla genérica,
     reintentable.
   Si el servidor no puede distinguir `tope_alcanzado`, todo cae a la falla
   genérica (se pierde el copy específico de AC-22). Mismo trato que 0016,
   pregunta #2.
2. **Idempotencia del reintento:** "Reintentar envío" puede dispararse
   después de un timeout en el que la orden sí llegó. El diseño supone que
   un reintento de la misma orden no genera un segundo mail (AC-13:
   "exactamente un mail"). Cómo se logra lo decide la Fase 3.
3. **Estado del chat entre navegaciones:** "Ver carrito" desde el combo
   navega en la misma pestaña; el estado de la conversación (hilo y
   "agregado" por card) tiene que sobrevivir a la navegación cliente
   (`ChatProvider` en el root layout; no se debe resetear por cambio de
   ruta).
4. **(Opcional) chequeo de disponibilidad** barato para la variante "tope
   avisado al entrar" (pregunta #F).
5. El carrito guarda por línea `{producto_id, cantidad}` y el precio que el
   visitante vio (para detectar "el precio cambió"). Lo que se envía a la
   orden es lo que el visitante tenía en pantalla; el servidor decide con
   el catálogo.

## Tensiones con la spec

- **AC-2 "en todo momento":** se cumple haciendo el header sticky, que es
  un cambio en todas las páginas (60px fijos arriba en móvil). Si el CTO/CEO
  prefiere no fijar el header, la alternativa es leer "en todo momento"
  como "en todas las páginas y siempre actualizado": el contador desaparece
  al scrollear y vuelve al subir. Recomiendo el sticky. Ver #G.
- **AC-2, qué cuenta "cuántos productos":** decidí unidades, no líneas.
  Conviene fijarlo en el AC para que el test no dependa de una
  interpretación.
- **AC-15 "se rechaza o se corrige":** este diseño elige **rechazar y
  volver a mostrar**. Sugiero cerrar la frase del AC en ese sentido cuando
  la Fase 3 lo confirme.
- **AC-12 vs. la frase "No se cobra nada en este paso":** mencionar el pago
  para aclarar que no se cobra no es "mostrar un medio de pago". Lo dejo
  explícito para que el tester no lo lea como violación.

## Preguntas abiertas

Ninguna bloquea la Fase 3; todas tienen un default aplicado en el mockup.

- **#A — Color de error.** `brand.md` no tiene token de error, y lo resolví
  sin color nuevo (ícono, negrita, borde 2px `sage-800`). Funciona, pero un
  error se distingue menos que con un tono dedicado. ¿Se agrega un token de
  error apagado (por ejemplo un ladrillo desaturado que pase AA) a
  `brand.md`, o se mantiene todo en salvia? Default: todo en salvia.
- **#B — Contraste del botón primario (existente).** `beige-50` sobre
  `sage-500` da ~3,2:1: no llega a AA (4,5:1) para texto de 16px normal.
  Ya pasa hoy con "Ver catálogo", "Iniciar chat" y el FAB, y los nuevos
  "Agregar al carrito" y "Enviar orden" lo heredan. Pasar el fondo de los
  primarios a `sage-600` (~5,3:1) lo resolvería en todo el sitio. Esta spec
  no lo cambia (sería un cambio de marca); lo marco para que se decida
  aparte. En el contador ya uso `sage-600`.
- **#C — Agregar desde la grilla.** Resuelto en esta pasada: no (ver
  motivos arriba). ¿El CTO/CEO está de acuerdo, o lo quiere igual? Si lo
  quiere, necesita una pasada de UX sobre `ProductCard`.
- **#D — Máximo por línea.** Propuse 20 unidades por producto, con la nota
  "Máximo 20 unidades por producto. Si necesitás más, contalo cuando
  RenovArte te contacte." Es una protección contra un "99" por error, no
  una regla de stock. ¿Está bien 20, otro número o sin máximo?
- **#E — Consentimiento.** Apliqué el default de #9 (una línea
  informativa, sin checkbox). Si la lectura legal de la Ley 25.326 pide
  consentimiento expreso, se agrega un checkbox obligatorio arriba del
  botón; el layout ya tiene lugar.
- **#F — ¿Avisar el tope antes de completar el formulario?** Solo si la
  Fase 3 puede exponer un chequeo barato. Si no, el tope se descubre al
  enviar (el formulario pierde ese esfuerzo, pero el carrito queda y el
  detalle se puede copiar).
- **#G — Header sticky.** Ver Tensiones. Default del mockup: sticky.
- **#H — Formato del número de orden (#7).** Requisitos de UX: de 8
  caracteres o menos visibles, un prefijo fijo y solo dígitos (o un
  alfabeto sin 0/O/1/I/L), fácil de dictar por teléfono o escribir en un
  MD. El mockup usa `RA-48271` como ejemplo. La generación la decide la
  Fase 3.
- **#J — Nombre y apellido en un solo campo (ADR-0020).** Aplicado como
  decidió el owner. Consecuencias que conviene aceptar: (1) no se puede
  garantizar que haya apellido, así que la validación solo exige 2
  caracteres con una letra (default; la alternativa es exigir 2 palabras,
  que rechaza nombres de una sola palabra); (2) el nombre se muestra tal
  cual en la confirmación, sin saludar solo por el nombre de pila porque no
  se puede separar; (3) tope de 80 caracteres propuesto, hay que
  coordinarlo con el límite del repo de órdenes (la validación servidor
  tiene que coincidir). ¿Conformes?
- **#K — Copia del pedido sin datos personales.** "Copiar detalle del
  pedido" no incluye nombre ni teléfono (ver Estados). Si RenovArte prefiere
  que los incluya para pegarlo directo en un mensaje, es un cambio de una
  línea. Default: no los incluye.
- **#I — Pregunta #5 (combo agrupado o aplanado):** apliqué el default,
  aplanado. El carrito lista productos individuales y no recuerda de qué
  combo vinieron. Agregar dos combos que comparten un producto suma esa
  línea (AC-4).
