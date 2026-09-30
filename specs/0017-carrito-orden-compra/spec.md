# 0017 — Carrito y orden de compra (catálogo + combos de Colibrí → mail de RenovArte)

**Status:** Backlog
**PRD:** RF-15, RF-16, RF-17, RF-18, RF-19, RNF-10, RNF-11, RNF-12, RNF-13, RNF-14
(enmienda 2026-09-30, precisiones 2026-09-30b, 2026-09-30c, 2026-09-30d,
2026-09-30e y 2026-09-30f a
[PRD-catalogo-renovarte.md](../../renovarte-catalogo/docs/PRD/PRD-catalogo-renovarte.md))

> **Precisión (2026-09-30f):** el CTO/CEO decidió la retención en la
> casilla de Gmail (pregunta #12). Textual:
>
> > "sí, borrar los mails de Gmail a los 60 días"
>
> Interpretación registrada: los mails de órdenes en
> renovartebyjuli@gmail.com se borran a los **60 días**, igual que los
> mensajes de Discord (AC-29). Es una **política de retención y un paso
> operativo de RenovArte** (a mano, o automatizable más adelante con un
> filtro/Apps Script de Google fuera de los repos del proyecto), no
> código de esta spec — AC-31, de verificación manual. De la #12 quedan
> abiertos solo el texto del aviso de privacidad y la consulta
> profesional opcional.

> **Precisión (2026-09-30e):** el CTO/CEO decidió sobre la pregunta #12
> (Ley 25.326) de la precisión anterior. Textual:
>
> > "Borrado automatico de lso mensajes a los 60 dias, el canal solo lo
> > vamos a ver los propietarios"
>
> Interpretación registrada (reflejada en Alcance, Contexto, RNF-12,
> AC-29/AC-30 y Preguntas abiertas): (1) los mensajes de órdenes del canal
> privado de Discord se **borran automáticamente a los 60 días**;
> (2) el canal lo ven **solo los propietarios de RenovArte** (paso manual
> de configuración en Discord; 2FA recomendado en esas cuentas). Además,
> el CTO/CEO no objetó el default de falla parcial (#13): la orden se
> confirma si **al menos uno** de los dos canales la aceptó — queda
> resuelta. Siguen abiertos, como pasos antes de producción (no bloquean
> diseño): aviso de privacidad que mencione el canal, consulta
> profesional sobre AAIP/transferencia internacional, y retención en la
> casilla de Gmail (#12).

> **Precisión (2026-09-30d) — requerimiento nuevo en la gate de la Fase 3:**
> con spec (Fase 1) y UX (Fase 2) ya aprobados, el CTO/CEO sumó un canal
> secundario de entrega de la orden. Textual:
>
> > "spec 17 si llegaramos a tener problemas con email speam stc el
> > mecanismo secudnario es recivir la orden por el mismo canal de discort
> > para no perder la orden si teneso problemas ocn el mail"
>
> Ante la pregunta de si enviar a Discord siempre o solo si falla el mail,
> con o sin datos personales, y a qué canal:
>
> > "siempre a los dos, canal privado nuevo, de acuerdo con las propuestas"
>
> Interpretación acordada con el CTO/CEO (reflejada en Objetivo, Alcance,
> RF-18/RF-19, RNF-12 y AC-13, AC-16..AC-20, AC-23..AC-28):
> (1) cada orden aceptada se entrega **siempre por dos canales**: el mail a
> renovartebyjuli@gmail.com **y** un mensaje a un **canal privado nuevo de
> Discord de RenovArte, dedicado solo a órdenes** (webhook propio, no el
> canal técnico de la POC de eventos de la spec 0001). Motivo: si el mail
> cae en spam el servidor no se entera, así que un respaldo "solo si falla"
> no alcanzaría; (2) el mensaje de Discord lleva **la orden completa, datos
> de contacto incluidos** (nombre, email/teléfono, dirección, localidad);
> el canal es privado, solo con acceso de RenovArte; (3) **el mismo número
> de orden** identifica la orden en los dos canales, y **un reintento nunca
> duplica** ni el mail ni el mensaje de Discord; (4) **nunca costo ni
> margen** en ninguno de los dos canales; el webhook de Discord es un
> **secreto** (nunca en el navegador ni en el repo). Además, el CTO/CEO
> aprobó dos propuestas de la Fase 3 que tocan producto: (5) **registro
> seudonimizado** de la orden por **90 días**, sin datos personales; (6) el
> **email/teléfono** del visitante se guarda **solo en el almacenamiento de
> sesión de la pestaña** (se borra al salir de /carrito), para que la
> confirmación sobreviva a una recarga. **Punto Ley 25.326 (ver Riesgos y
> Pregunta #12):** Discord pasa a ser un segundo lugar, además de la
> casilla de Gmail, donde quedan datos personales del visitante, **sin
> plazo de borrado** salvo que alguien borre los mensajes.

> **Actualización (2026-09-30c):** el CTO/CEO resolvió la última pregunta
> bloqueante y dos no bloqueantes. Respuesta textual:
>
> > "Monto del tope mensual 20 usd , Qué quisiste decir con "todo local el
> > manejo de las ordenes local, para el envio de mail si es costo bajo
> > usar terceros.  exactamente nuestro instagran es renovarte_by_juli"
>
> Interpretación registrada: (1) tope de costo mensual del sistema de
> órdenes: **USD 20/mes** (RNF-14); el comportamiento al alcanzarlo
> (AC-22) no fue objetado y queda firme; (2) "todo local" = el **manejo de
> las órdenes** (creación, validación contra el catálogo, anti-abuso,
> registro) es propio, en el repo nuevo; para el **envío del mail** sí se
> permite un **proveedor de terceros de bajo costo** (dentro del tope),
> invocado desde el repo nuevo — la elección concreta es de la Fase 3;
> (3) Instagram confirmado: **@renovarte_by_juli**. No quedan preguntas
> que bloqueen la Fase 3.

> **Actualización (2026-09-30b):** el CTO/CEO respondió las 5 preguntas
> que bloqueaban diseño. Respuesta textual:
>
> > "1 si pidamos direccion y localidad 2 solo le damos un nuemro de orden ,
> > si tiene consulta scon la orden no puede mandar un email o contastacnos
> > por md directo de instagram 3 los mail deven salir deven llegar aca
> > renovartebyjuli@gmail.com de donde salir a defirnir lo que salga mas
> > barato si aprovamos un tope, todo local, nuevo repo que se encagar de
> > manejar la creacion de las ordenes, asi a futuro podemos expandir
> > funcionalidad"
>
> Interpretación registrada (ya reflejada en Alcance, Contexto y AC):
> (1) dirección y localidad pasan a ser datos obligatorios, además de
> nombre y medio de contacto; (2) sin copia de la orden al visitante por
> mail — en pantalla solo se le da el número de orden y se le indica que
> ante consultas escriba por email o por MD de Instagram a RenovArte;
> (3) casilla de destino: **renovartebyjuli@gmail.com**; el remitente se
> define en diseño, el que resulte más barato; (4) se aprueba un **tope de
> costo** para el envío de órdenes (excepción a `constitution.md §II.5`,
> como RNF-09 del chat) — **el monto todavía no está definido** (RNF-14,
> sigue abierto y bloquea la Fase 3); (5) solución **propia, no de
> terceros**: un **repo nuevo dedicado a la creación/gestión de órdenes**,
> pensado para sumar funcionalidad a futuro; su forma técnica se decide en
> la Fase 3. Quedan abiertas: el monto del tope (bloquea Fase 3, no UX) y
> preguntas no bloqueantes (usuario de Instagram, email de contacto
> visible, etc.).

> **Por qué vive en el root y no en `renovarte-catalogo/specs/`:** la parte
> visible (carrito, botón de "agregar", formulario de orden, confirmación)
> es de `renovarte-catalogo`, pero la creación de la orden y su envío por
> mail viven en un **repo nuevo** dedicado a órdenes (decisión del CTO/CEO,
> 2026-09-30b), porque por `constitution.md §II.4` de `renovarte-catalogo`
> (y RNF-08/RNF-10 de su PRD) no pueden vivir en ese repo. Toca 2 repos,
> uno de ellos nuevo → `specs/constitution.md §III.8`. La numeración 0017
> es la siguiente libre tanto acá como en `renovarte-catalogo/specs/` (se
> mantiene alineada, como hizo la 0016).

## Necesidad original (CTO/CEO, textual)

> "queremos sumar un carrito de compre que genere una orden de compra ,
> tanto desde el menu de catalgo de productos como desde las opciones.
> porpuesta por nuestro bot. actualmente no ofrecemos esto, quersmo que el
> usuario pueda generar su orden de compara , el envio y la forma de pago
> se maneja despues por el momento no aceptamos medios de pagos dentro de
> la app no deben la forma de envio tambien lo coordinamos despeus lo
> importeat ahora es que se pueda generar la orden. el pedido o la orden
> debe llegar a una casilla de mail propia de renovarte"

## Problema

Hoy el visitante puede ver el catálogo y recibir combos recomendados por
Colibrí, pero **no tiene ninguna forma de decir "quiero esto"** dentro del
sitio: RenovArte "actualmente no ofrece esto". Quien ya eligió productos
(navegando el catálogo o aceptando un combo del bot) tiene que salir del
sitio y armar el pedido a mano por otro canal, y RenovArte no recibe el
pedido de forma ordenada en un lugar propio. Lo importante ahora, en
palabras del CTO/CEO, "es que se pueda generar la orden" y que esa orden
"llegue a una casilla de mail propia de RenovArte". Pago y envío se
coordinan después, fuera de la app.

## Objetivo

Que un visitante pueda juntar productos en un carrito — desde el catálogo
o agregando un combo propuesto por Colibrí — y generar una orden de compra
que RenovArte recibe por mail en renovartebyjuli@gmail.com **y, siempre,
también en un canal privado de Discord** (para no perder la orden si el
mail cae en spam), con lo necesario para contactarlo y coordinar pago y
envío por fuera del sitio.

## Alcance

### In

- **Carrito en `renovarte-catalogo`**, accesible desde cualquier página
  del sitio, sin login ni cuenta.
- **Agregar productos al carrito desde el catálogo:** al menos desde la
  ficha de producto; si también desde la card de la grilla lo define el
  `ux-agent` (ver Preguntas abiertas, no bloqueante).
- **Agregar un combo propuesto por Colibrí al carrito:** cada una de las 3
  opciones (más barato / medio / premium) se puede agregar completa con
  una sola acción — todos sus productos, 1 unidad de cada uno.
- **Editar el carrito:** ver los productos (nombre, presentación, precio
  unitario, cantidad, subtotal) y el total; cambiar cantidades; quitar
  productos; vaciarlo.
- **El carrito sobrevive a la navegación** dentro del sitio (ir de la
  ficha a la grilla, abrir/cerrar el chat) y a recargar la página, en el
  mismo navegador del mismo dispositivo.
- **Generar la orden:** desde el carrito, el visitante completa sus datos
  de contacto — **obligatorios: nombre, al menos un medio de contacto
  (email y/o teléfono), dirección y localidad** (decisión CTO/CEO
  2026-09-30b; si email y teléfono son ambos obligatorios o alcanza con
  uno queda como pregunta no bloqueante #6) — y confirma. Al confirmar:
  - Se crea la orden en el repo nuevo de órdenes y RenovArte recibe un
    mail en **renovartebyjuli@gmail.com** con: número de orden,
    fecha/hora, datos de contacto del visitante (incluidas dirección y
    localidad), cada producto (nombre, presentación, cantidad, precio
    unitario, subtotal) y total.
  - **Además, siempre** (no solo si el mail falla — 2026-09-30d), la
    misma orden completa, con el **mismo número de orden** y los mismos
    datos (contacto incluido), llega como mensaje a un **canal privado
    nuevo de Discord de RenovArte, dedicado solo a órdenes** (distinto del
    canal técnico de la POC de eventos de la spec 0001), visible **solo
    para los propietarios** de RenovArte; cada mensaje de orden se
    **borra automáticamente a los 60 días** (2026-09-30e).
  - Un reintento (del visitante o del sistema) **nunca duplica** la orden:
    ni un segundo mail ni un segundo mensaje de Discord para el mismo
    pedido.
  - El visitante ve una confirmación en pantalla con **el número de
    orden**, un texto claro de que **pago y envío se coordinan después**
    (RenovArte lo contacta), y los canales para consultas sobre la orden:
    **email de RenovArte y MD de Instagram a @renovarte_by_juli**.
  - **El visitante no recibe copia de la orden por mail** (decisión
    CTO/CEO 2026-09-30b).
  - El carrito queda vacío.
  - Si el visitante recarga la página de confirmación, sigue viendo su
    número de orden. Para eso, en su navegador puede quedar **solo** el
    medio de contacto (email/teléfono) y **solo durante la sesión de esa
    pestaña**, mientras esté en /carrito; al salir de /carrito o cerrar la
    pestaña se borra (2026-09-30d).
- **Registro de órdenes seudonimizado** en el repo nuevo: cada orden queda
  registrada **hasta 90 días y sin datos personales** del visitante
  (2026-09-30d); los datos de contacto viven solo en la casilla de mail y
  en el canal privado de Discord.
- **Precios de la orden = precios del catálogo publicado vigente** (el
  mismo `precio_venta` que se ve en grilla/ficha/combos). La orden que
  llega por mail no puede traer un producto o precio que no exista en el
  catálogo publicado, aunque alguien manipule el navegador. Ni el mail ni
  el mensaje de Discord contienen costo, margen ni precio de lista de LACA.
- **Si la orden no se puede enviar** (servicio caído, error de red, tope
  de costo alcanzado), el visitante lo ve explícitamente, **no pierde su
  carrito**, y puede reintentar. Nunca se muestra "orden enviada" si
  RenovArte no la recibió.
- **Tope de costo** del sistema de órdenes (RNF-14): **USD 20/mes**,
  excepción aprobada por el CTO/CEO a `constitution.md §II.5`.
- El resto del sitio (grilla, filtro, búsqueda, ficha — RF-01..RF-04 — y
  el chat Colibrí — RF-14) sigue funcionando igual, con o sin el
  mecanismo de envío de órdenes disponible.

### Out

- **Pagos dentro de la app** (Mercado Pago, tarjeta, transferencia con
  comprobante, etc.) — decisión explícita del CTO/CEO: "no aceptamos
  medios de pagos dentro de la app". Tampoco se muestra ni se elige forma
  de pago en el formulario.
- **Definición/cálculo de envío** (costo, zona, método, retiro en local)
  — decisión explícita del CTO/CEO: "la forma de envío también lo
  coordinamos después". Dirección y localidad se piden como **dato de
  contacto** para coordinar después, no para calcular ni elegir envío.
- **Copia de la orden al visitante por mail**, o cualquier otro mail
  saliente hacia el visitante (decisión CTO/CEO 2026-09-30b).
- Stock/disponibilidad en tiempo real y reserva de stock al generar la
  orden.
- Cuentas de usuario, login, historial de órdenes del visitante,
  seguimiento de estado de la orden.
- Panel de administración de órdenes (listado, estados, búsqueda) — la
  orden llega por mail y se gestiona desde ahí, por fuera del sitio. El
  repo nuevo se piensa para "expandir funcionalidad a futuro", pero
  ninguna funcionalidad futura (estados, panel, pagos) entra en esta spec.
- Servicios de terceros que **reemplacen el manejo de las órdenes**
  (form builders, servicios de formularios-a-mail tipo Formspree/EmailJS
  llamados desde el navegador, o similares) — el CTO/CEO eligió que el
  manejo de órdenes sea propio, en el repo nuevo. **Sí está permitido**
  (2026-09-30c) un proveedor de terceros de bajo costo para el *envío del
  mail*, invocado desde el repo nuevo y dentro del tope de RNF-14; cuál,
  se decide en la Fase 3.
- Carrito compartido entre dispositivos/navegadores.
- Descuentos, cupones, precio especial por combo o monto mínimo de
  compra. Un combo agregado al carrito vale la suma de sus productos,
  igual que en la card de Colibrí.
- Que Colibrí agregue al carrito o genere la orden por conversación
  ("agregalo al carrito" escrito en el chat) — el agregado desde el chat
  es una acción explícita del visitante sobre la card del combo, no
  lenguaje natural interpretado por el bot. Cambios de comportamiento del
  bot (prompts, RAG) quedan fuera.
- Notificaciones por WhatsApp/SMS, o integración con CRM/facturación.
- Usar Discord como **panel de gestión** de órdenes (estados, reacciones
  que cambien algo, bots interactivos, comandos) — el mensaje es solo una
  copia de entrega/respaldo de la orden (2026-09-30d).
- Reusar el canal/webhook técnico de la POC de eventos (spec 0001) para
  las órdenes.
- Enviar a Discord **solo cuando falla el mail** (descartado por el
  CTO/CEO: "siempre a los dos").
- Analytics/conversión del carrito (mismo criterio que la 0016).
- Cualquier cambio en `renovarte-pipeline` o en el schema de
  `products.json`.

## Contexto de arquitectura y dependencias (no decide el diseño)

- **Repo nuevo dedicado a órdenes (decisión CTO/CEO 2026-09-30b).** La
  creación de la orden, su validación contra el catálogo (RNF-11), la
  protección anti-abuso (RNF-12) y el envío del mail viven en un **repo
  nuevo**, responsable de "manejar la creación de las órdenes" y pensado
  para "a futuro expandir funcionalidad". Nombre tentativo, stack y
  hosting (p.ej. AWS como `renovarte-chat-gateway`/`renovarte-colibri-rag`)
  se definen en la Fase 3. Como todo repo nuevo: submódulo de
  `renovarte-parent` (`constitution.md §II.6`), con su propio `CLAUDE.md`
  (§II.7), y no se crea ni se aprovisiona en modo diseño (§III.11).
  Esto mantiene `renovarte-catalogo` estático (`constitution.md §II.4` del
  repo, RNF-08/RNF-10) sin enmienda, y respeta "un repo, una
  responsabilidad" (§II.4 del root): no se reusa `renovarte-chat-gateway`.
- **Manejo propio vs. envío de mail (2026-09-30c):** creación,
  validación contra el catálogo, anti-abuso y registro de la orden son
  propios del repo nuevo ("el manejo de las ordenes local"). El envío del
  mail puede delegarse a un proveedor de terceros de bajo costo ("para el
  envio de mail si es costo bajo usar terceros"), siempre invocado desde
  el repo nuevo (nunca desde el navegador) y con el destinatario fijo
  server-side (AC-17). Proveedor y remitente: Fase 3, "lo que salga más
  barato". El destinatario está fijo: renovartebyjuli@gmail.com.
- **Tope de costo (RNF-14): USD 20/mes** para el costo del sistema de
  órdenes (repo nuevo + proveedor de mail) — excepción explícita y
  acotada a esta feature al invariante "$0 infraestructura"
  (`constitution.md §II.5`, RNF-01), aprobada por el CTO/CEO; es
  independiente del tope de USD 20/mes del LLM (RNF-09), no lo comparte
  ni lo hereda. Comportamiento al alcanzarlo: AC-22. El mecanismo de
  medición/corte es de la Fase 3.
- **Combos de Colibrí:** el envelope `combo_recommendation` que ya llega
  al widget (spec 0016) trae, por producto, `producto_id`, `nombre`,
  `presentacion` y `precio_venta`. A priori esto alcanza para agregar el
  combo al carrito **sin cambios** en `renovarte-chat-gateway` ni
  `renovarte-colibri-rag` — a confirmar en diseño. Este spec no modifica
  nada de `specs/0016-chat-recomendador-cremas/`; sí amplía el alcance que
  la 0016 (y la PRD §4.2) dejaban fuera ("Compra, carrito o checkout
  desde el chat"), ahora acotado a *carrito + orden*, sin checkout/pago.
- **Datos personales:** primera feature del proyecto que recibe datos
  personales del visitante (nombre, contacto, dirección, localidad). No
  existen hoy en ningún repo; RNF-12 fija que no se publican ni se
  commitean. *(2026-09-30d)* Lugares donde pueden quedar, y por cuánto:
  (a) casilla de Gmail de RenovArte — borrado a los 60 días como
  política operativa de RenovArte (2026-09-30f, AC-31); (b) **canal privado de Discord de órdenes — borrado automático a
  los 60 días** (2026-09-30e, AC-29), visible solo para los propietarios
  de RenovArte (AC-30); (c) navegador del visitante — solo
  email/teléfono, solo en la sesión de la pestaña mientras está en
  /carrito; (d) registro del repo nuevo — **ningún dato personal**
  (seudonimizado), 90 días; (e) en tránsito por el proveedor de mail. Ver
  Riesgos (Ley 25.326).
- **Canal secundario Discord (2026-09-30d):** la entrega a Discord es
  server-side desde el repo nuevo, por un webhook **propio del canal de
  órdenes**, tratado como secreto (nunca en el navegador ni commiteado).
  Webhooks de Discord no tienen costo, así que no presiona el tope de
  RNF-14. Cómo se garantiza la no-duplicación ante reintentos, y cómo se
  representa una orden larga si no entra en un solo mensaje de Discord
  (sin perder contenido ni duplicar la orden), es de la Fase 3.
  *(2026-09-30e)* El mecanismo del borrado automático a los 60 días
  (AC-29) también es de la Fase 3; la restricción de acceso al canal
  (AC-30) es un paso manual de configuración en Discord, no código.
- **Dirección de destino vs. email de contacto visible:** como el
  CTO/CEO quiere que el visitante pueda escribir por email ante
  consultas, la dirección de RenovArte puede ser pública. La protección
  de RNF-12 **no** es ocultar renovartebyjuli@gmail.com, sino que el
  destinatario del mail de la orden quede fijado del lado del repo de
  órdenes y **no pueda ser elegido ni alterado desde el navegador** (el
  endpoint no acepta destinatario arbitrario → no sirve como relay de
  spam). Email de contacto que se muestra en la confirmación: propuesta
  por defecto, el mismo renovartebyjuli@gmail.com (Pregunta abierta #3).
- **UI/UX:** todo lo visible (dónde vive el acceso al carrito, cómo se
  agrega desde grilla/ficha/card de combo, formulario, confirmación,
  estados de error) pasa por el `ux-agent` antes de cualquier diseño de
  frontend, y su entregable necesita aprobación humana (`CLAUDE.md`).

## Acceptance criteria

1. **AC-1 (RF-15):** Desde la ficha de un producto, el visitante lo agrega
   al carrito sin login ni cuenta; el carrito refleja ese producto con su
   nombre, presentación y el mismo precio que se ve en la ficha.
2. **AC-2 (RF-15):** El carrito es accesible desde cualquier página del
   sitio (home, categoría, grupo, ofertas, ficha) y muestra en todo
   momento cuántos productos contiene.
3. **AC-3 (RF-15):** En el carrito el visitante puede aumentar y disminuir
   la cantidad de un producto, quitarlo, y vaciar el carrito; subtotales
   por producto y total se actualizan de forma consistente (subtotal =
   precio unitario × cantidad; total = suma de subtotales).
4. **AC-4 (RF-15):** Agregar al carrito un producto que ya está en él
   incrementa su cantidad en vez de duplicar la línea.
5. **AC-5 (RF-15):** El contenido del carrito se mantiene al navegar entre
   páginas del sitio, al abrir/cerrar el chat y al recargar la página, en
   el mismo navegador.
6. **AC-6 (RF-16):** En una respuesta de Colibrí con los 3 combos, cada
   combo ofrece una acción para agregarlo al carrito; al usarla, todos los
   productos de ese combo quedan en el carrito (1 unidad de cada uno,
   sumándose a lo que ya hubiera), con el mismo nombre y precio que
   mostraba la card del combo.
7. **AC-7 (RF-16):** Agregar un combo al carrito no cierra el chat ni
   borra la conversación en curso.
8. **AC-8 (RF-17):** Con el carrito vacío no se puede generar una orden.
9. **AC-9 (RF-17):** Para generar la orden el visitante tiene que
   completar nombre, al menos un medio de contacto (email y/o teléfono),
   dirección y localidad; si falta alguno o tiene un formato inválido, la
   orden no se envía y se le indica qué corregir.
10. **AC-10 (RF-17):** Al confirmar una orden válida, el visitante ve una
    confirmación con el número de orden, un texto que aclara que RenovArte
    lo va a contactar para coordinar pago y envío, y los canales para
    consultas sobre la orden (email de RenovArte y MD de Instagram a
    @renovarte_by_juli); el carrito queda vacío.
11. **AC-11 (RF-17):** El visitante no recibe ningún mail como
    consecuencia de generar la orden (no hay copia al cliente).
12. **AC-12 (RF-17):** En ningún paso del flujo se pide, muestra ni
    procesa un medio de pago, ni se pide elegir o se calcula un costo o
    método de envío.
13. **AC-13 (RF-18)** *(modificado 2026-09-30d)***:** Por cada orden
    confirmada llega exactamente un mail a renovartebyjuli@gmail.com —
    también cuando hubo reintentos (AC-24) —, con: el mismo número de
    orden que vio el visitante, fecha/hora, sus datos de contacto
    (incluidas dirección y localidad), cada producto (nombre,
    presentación, cantidad, precio unitario, subtotal) y el total —
    coincidiendo con lo que el visitante tenía en el carrito al confirmar.
    (Excepción: el caso de falla parcial de AC-25, donde el mail no pudo
    entregarse y la orden llegó solo por Discord.)
14. **AC-14 (RNF-10):** `renovarte-catalogo` no incorpora ningún endpoint,
    proceso o servicio de backend propio para crear o enviar órdenes —
    sigue siendo un build estático; la creación y el envío se resuelven en
    el repo nuevo de órdenes (verificable igual que AC-12 de la 0016).
15. **AC-15 (RNF-11):** Si una orden llega al repo de órdenes con un
    producto inexistente en el catálogo publicado vigente o con un precio
    distinto de su `precio_venta` publicado (p.ej. manipulando el
    navegador), esa orden no llega a la casilla de RenovArte con ese dato
    adulterado — se rechaza o se corrige al precio publicado (cuál de las
    dos, lo decide el diseño) y el visitante lo ve reflejado.
16. **AC-16 (RNF-11)** *(modificado 2026-09-30d)***:** Ni el mail ni el
    mensaje de Discord de la orden contienen costo, margen ni precio de
    lista de LACA (mismo invariante que RNF-03 / `constitution.md §I.1`).
17. **AC-17 (RNF-12)** *(modificado 2026-09-30d)***:** Una solicitud al
    repo de órdenes que intente indicar o alterar el destinatario (o
    agregar destinatarios, CC/BCC) o el canal/webhook de Discord no
    produce ningún mail hacia una dirección distinta de
    renovartebyjuli@gmail.com ni ningún mensaje fuera del canal privado de
    órdenes — ambos destinos se fijan del lado del servidor, nunca desde
    el navegador.
18. **AC-18 (RNF-12)** *(modificado 2026-09-30d)***:** Los datos de
    contacto del visitante no quedan expuestos públicamente (ni en
    archivos públicos del sitio, ni en ningún repo, ni en el registro de
    órdenes — AC-27) y solo viajan hacia el repo de órdenes, la casilla
    de RenovArte y el canal privado de Discord de órdenes; en el propio
    navegador del visitante rige AC-28.
19. **AC-19 (RNF-12)** *(modificado 2026-09-30d)***:** El envío de
    órdenes tiene una protección anti-abuso verificable: un mismo origen
    no puede generar un volumen arbitrario de órdenes/mails/mensajes de
    Discord en poco tiempo (umbral a definir en diseño), y un envío
    automatizado trivial (sin pasar por el formulario) no llega ni a la
    casilla ni al canal de Discord.
20. **AC-20 (RNF-13)** *(modificado 2026-09-30d)***:** Si el envío falla
    por completo (ninguno de los dos canales aceptó la orden) o el repo de
    órdenes no está disponible, el visitante ve un mensaje explícito de
    que la orden **no** se envió, su carrito queda intacto y puede
    reintentar; nunca se muestra la confirmación de AC-10 sin que la orden
    haya sido aceptada para entrega por al menos uno de los dos canales
    (ver AC-25).
21. **AC-21 (RNF-13):** Con el envío de órdenes caído o deshabilitado
    (incluido Discord caído), la grilla, filtro, búsqueda, ficha
    (RF-01..RF-04) y el chat Colibrí (RF-14) siguen funcionando con
    normalidad.
22. **AC-22 (RNF-14):** Si el costo mensual acumulado del sistema de
    órdenes alcanza el tope de USD 20/mes, no se genera gasto adicional;
    el visitante que intenta generar una orden ve el mismo tratamiento de
    AC-20 (orden no enviada, carrito intacto) más los canales de contacto
    alternativos (email / MD de Instagram a @renovarte_by_juli), y el
    resto del sitio sigue funcionando (AC-21).
23. **AC-23 (RF-19)** *(nuevo 2026-09-30d)***:** Por cada orden
    confirmada, además del mail, llega **siempre** (aunque el mail se haya
    entregado bien) la orden al canal privado de Discord de órdenes de
    RenovArte, con el **mismo número de orden** que vio el visitante y que
    figura en el mail, fecha/hora, datos de contacto (nombre,
    email/teléfono, dirección, localidad), cada producto (nombre,
    presentación, cantidad, precio unitario, subtotal) y el total — el
    mismo contenido que el mail. Nada de la orden llega al canal técnico
    de la POC de eventos (spec 0001).
24. **AC-24 (RF-18, RF-19)** *(nuevo 2026-09-30d)***:** Si la misma orden
    se reenvía (el visitante reintenta tras un error o un corte de red,
    hace doble clic en confirmar, o el sistema reintenta una entrega), no
    se genera un segundo mail ni un segundo mensaje de Discord para ese
    pedido, ni un número de orden nuevo: RenovArte ve una sola orden por
    canal y el visitante ve el mismo número de orden.
25. **AC-25 (RF-19, RNF-13)** *(nuevo 2026-09-30d)***:** Si uno solo de
    los dos canales acepta la orden (p.ej. el proveedor de mail falla pero
    Discord no, o al revés), la orden **no se pierde**: el visitante ve la
    confirmación de AC-10 (resuelto 2026-09-30e, Pregunta #13) y la falla del
    otro canal queda registrada — sin datos personales — de forma que
    RenovArte pueda detectarla. Si ninguno de los dos la acepta, aplica
    AC-20.
26. **AC-26 (RNF-12)** *(nuevo 2026-09-30d)***:** La dirección del webhook
    de Discord de órdenes no aparece en el sitio, en el bundle ni en el
    tráfico inspeccionable desde el navegador, ni commiteada en ningún
    repo.
27. **AC-27 (RNF-12)** *(nuevo 2026-09-30d)***:** El registro de órdenes
    del repo nuevo conserva cada orden como máximo 90 días y no contiene
    datos personales del visitante en claro (ni nombre, ni email, ni
    teléfono, ni dirección, ni localidad): se puede ubicar una orden por
    su número, pero no identificar desde ahí a quién pertenece. Pasados 90
    días, la orden ya no está en el registro.
28. **AC-28 (RNF-12, RF-17)** *(nuevo 2026-09-30d)***:** Tras confirmar,
    recargar la página de confirmación sigue mostrando el número de orden.
    Del formulario, en el navegador del visitante solo puede quedar el
    medio de contacto (email/teléfono), solo para esa pestaña y mientras
    permanezca en /carrito: al salir de /carrito o cerrar la pestaña, no
    queda ningún dato de contacto guardado en el navegador. Nombre,
    dirección y localidad no se guardan en el navegador, y el carrito
    persistido (AC-5) nunca contiene datos de contacto.
29. **AC-29 (RNF-12, RF-19)** *(nuevo 2026-09-30e)***:** Cada mensaje de
    orden publicado en el canal privado de Discord se borra
    automáticamente a los 60 días de publicado, sin intervención manual:
    pasado ese plazo, la orden (y sus datos de contacto) ya no aparece en
    el canal. Si una orden ocupó más de un mensaje, se borran todos.
30. **AC-30 (RNF-12)** *(nuevo 2026-09-30e)***:** El canal de Discord de
    órdenes solo es visible para los propietarios de RenovArte: una cuenta
    del servidor de Discord que no sea de un propietario no puede ver el
    canal ni su historial. Verificación manual (paso de configuración de
    Discord, no código), con 2FA recomendado en las cuentas de los
    propietarios.
31. **AC-31 (RNF-12)** *(nuevo 2026-09-30f)***:** Política de retención
    de la casilla: los mails de órdenes en renovartebyjuli@gmail.com no
    permanecen más de 60 días (tampoco en la papelera). Verificación
    manual, como AC-30: es un paso operativo de RenovArte (a mano, o un
    filtro/Apps Script de Google configurado fuera de los repos del
    proyecto), no código de esta spec ni algo que verifique el tester
    automatizado.

## Preguntas abiertas

### Resueltas por el CTO/CEO (2026-09-30b)

- ~~Datos de contacto~~ → nombre + medio de contacto + **dirección y
  localidad**, obligatorios.
- ~~Copia al visitante~~ → **no**; solo número de orden en pantalla y
  canales de consulta (email / MD de Instagram).
- ~~Casilla de destino y remitente~~ → destino
  **renovartebyjuli@gmail.com**; remitente a definir en diseño, el más
  barato.
- ~~$0 vs. tope~~ → **se aprueba un tope**.
- ~~Topología~~ → **repo nuevo propio** dedicado a crear/gestionar
  órdenes; forma técnica en Fase 3.

### Resueltas por el CTO/CEO (2026-09-30c)

- ~~Monto del tope y comportamiento al alcanzarlo~~ → **USD 20/mes**
  (RNF-14); comportamiento de AC-22 aceptado sin objeciones.
- ~~Lectura de "todo local"~~ → manejo de órdenes propio en el repo nuevo;
  envío del mail puede ser un proveedor de terceros de bajo costo,
  invocado desde el repo nuevo (ver Alcance/Out y Contexto).
- ~~Usuario de Instagram~~ → **@renovarte_by_juli**.

### Resueltas por el CTO/CEO (2026-09-30d)

- ~~¿Discord siempre o solo si falla el mail?~~ → **siempre a los dos**.
- ~~¿Con o sin datos personales?~~ → **orden completa, con datos de
  contacto** ("de acuerdo con las propuestas").
- ~~¿Qué canal?~~ → **canal privado nuevo**, dedicado a órdenes (no el
  de la POC de eventos de la spec 0001).
- ~~Propuestas de Fase 3 que tocan producto~~ → aprobadas: registro
  seudonimizado 90 días (AC-27) y medio de contacto solo en la sesión de
  la pestaña mientras está en /carrito (AC-28).

### Resueltas por el CTO/CEO (2026-09-30e)

- ~~#12 (parcial) — plazo de borrado en Discord~~ → **borrado automático
  a los 60 días** (AC-29).
- ~~#12 (parcial) — acceso al canal~~ → **solo los propietarios** de
  RenovArte (AC-30; 2FA recomendado).
- ~~#13 — falla parcial~~ → sin objeción al default: se confirma si **al
  menos uno** de los dos canales aceptó la orden (AC-20/AC-25).

### Resueltas por el CTO/CEO (2026-09-30f)

- ~~#12 (parcial) — retención en la casilla de Gmail~~ → **borrar los
  mails de órdenes a los 60 días**, como política operativa (AC-31).

### Bloquean la Fase 3 (diseño/RFC)

Ninguna. (Lo que queda de #12 no bloquea el diseño, pero son pasos antes
de salir a producción.)

### No bloquean diseño (tienen default propuesto; se ajustan en UX/implementación)

3. **Email de contacto visible** en la confirmación: default propuesto,
   el mismo renovartebyjuli@gmail.com (compatible con RNF-12
   reformulado, ver Contexto).
4. **Agregar desde la card de la grilla**, además de la ficha: lo decide
   el `ux-agent` (AC-1 solo exige la ficha).
5. **Combo en la orden: ¿agrupado o aplanado?** Default: aplanado — el
   carrito y el mail listan productos individuales; sin línea ni precio
   especial de combo.
6. **Email y teléfono: ¿ambos obligatorios o alcanza con uno?** Default:
   al menos uno de los dos (AC-9). Como el visitante no recibe mail,
   RenovArte necesita al menos una vía para contactarlo.
7. **Formato del número de orden** (secuencial, fecha+sufijo, aleatorio
   corto): decisión de diseño; producto solo exige que sea el mismo en
   pantalla y en el mail (AC-10/AC-13) y fácil de dictar por
   Instagram/teléfono.
8. **AC-15 — rechazar vs. corregir** una orden con precio adulterado o
   desactualizado: decisión de diseño/UX, siempre que el mail nunca
   refleje un precio distinto del publicado y el visitante vea el precio
   final antes o en la confirmación.
9. **Aviso de privacidad/consentimiento** sobre el uso de los datos
   (ahora incluye dirección; Ley 25.326, Argentina): default — una línea
   en el formulario ("usamos estos datos solo para contactarte por este
   pedido"); copy final sujeto a aprobación del CTO/CEO. *(2026-09-30d)*
   El copy debería mencionar que el pedido se recibe por mail y por un
   canal privado de mensajería de RenovArte (ver #12).
10. **Vencimiento del carrito guardado** en el navegador: default — sin
    vencimiento; si un producto del carrito ya no existe en el catálogo
    vigente, se le muestra al visitante y no se incluye en la orden
    (coherente con AC-15).
11. **Nombre del repo nuevo:** tentativo, a definir en Fase 3.
12. **Ley 25.326 — datos personales en Discord y Gmail (2026-09-30d,
    actualizada 2026-09-30e/f), pasos antes de producción:** con el canal
    secundario, Discord es **un segundo lugar (además de Gmail) donde
    quedan datos personales del visitante** (nombre, email/teléfono,
    dirección, localidad), en un servicio de terceros fuera de Argentina.
    **Ya decidido:** borrado automático de los mensajes de Discord a los
    60 días (AC-29) y canal visible solo para los propietarios, con 2FA
    recomendado (AC-30) — 2026-09-30e; borrado de los mails de órdenes en
    Gmail a los 60 días como política operativa (AC-31) — 2026-09-30f.
    **Sigue abierto, antes de producción (no bloquea diseño):** (a) el
    **texto del aviso de privacidad** del formulario (#9), que mencione
    que los datos se reciben por mail y por un canal privado de
    mensajería de RenovArte, solo para coordinar el pedido; (b)
    **consulta profesional opcional** sobre la inscripción de la base
    ante la AAIP y la transferencia internacional (Gmail y Discord) —
    esta spec no es asesoramiento legal. Nota: lo que Discord o Google conserven internamente tras un
    borrado queda fuera del control de RenovArte.
13. ~~**Falla parcial (un canal sí, el otro no)**~~ → **resuelta
    2026-09-30e** (sin objeción del CTO/CEO): la orden se confirma al
    visitante si **al menos uno** de los dos canales la aceptó, y la falla
    del otro queda registrada sin datos personales (AC-25). Si el sistema
    reintenta automáticamente el canal faltante, y cómo se entera
    RenovArte de la falla, es de la Fase 3.

**Conflictos con `constitution.md`:** ninguno abierto. §II.4 de
`renovarte-catalogo` se respeta porque la creación/envío de órdenes vive
en un repo nuevo (RNF-10, AC-14), no en el catálogo; el carrito es estado
del navegador. §II.5 ($0 infra) tiene una excepción explícita y acotada a
esta feature aprobada por el CTO/CEO (RNF-14, USD 20/mes). El
repo nuevo tiene que cumplir §II.6/§II.7 (submódulo + `CLAUDE.md` propio)
y §III.11 (no se crea en modo diseño). *(2026-09-30d)* El canal de
Discord no cambia esto: la entrega a Discord es server-side desde el repo
nuevo, sin costo, y no toca `renovarte-catalogo`.

## Riesgos (2026-09-30d)

| Riesgo | Mitigación |
|---|---|
| El mail de la orden cae en spam y RenovArte no se entera (el servidor lo ve como "entregado") | Entrega **siempre** duplicada a un canal privado de Discord (RF-19, AC-23) |
| Datos personales del visitante acumulados en Discord (y en Gmail) — Ley 25.326 | *(2026-09-30e)* Borrado automático en Discord a los 60 días (AC-29); canal visible solo para los propietarios, 2FA recomendado (AC-30); registro propio sin datos personales y 90 días (AC-27); *(2026-09-30f)* mails de órdenes en Gmail borrados a los 60 días, política operativa (AC-31). Antes de producción: texto del aviso de privacidad y consulta profesional opcional AAIP/transferencia internacional (Pregunta #12) |
| *(2026-09-30f)* El borrado de Gmail depende de un paso manual y puede olvidarse | AC-31 de verificación manual; automatizable más adelante con un filtro/Apps Script de Google, fuera de los repos del proyecto |
| El borrado automático de Discord falla en silencio y los datos quedan más de 60 días | AC-29 es verificable; cómo se detecta una falla del borrado, Fase 3 |
| Filtración del webhook: cualquiera podría publicar mensajes falsos en el canal de órdenes | Webhook como secreto server-side (AC-26); si se filtra, se regenera desde Discord |
| Doble entrega por reintentos (doble clic, corte de red, reintento del sistema) genera órdenes duplicadas | AC-24: mismo número de orden, un mail y un mensaje por orden |
| Un canal cae y el otro no: orden confirmada que llega por un solo lado, o bloqueo innecesario | AC-25: se confirma con "al menos uno" (resuelto 2026-09-30e, Pregunta #13) |
| Uso accidental del canal técnico de la POC (spec 0001), con otra audiencia | Canal y webhook nuevos y exclusivos para órdenes (AC-23) |
