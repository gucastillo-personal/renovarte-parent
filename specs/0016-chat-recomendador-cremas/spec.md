# 0016 — Chat recomendador de combos ("Colibrí")

**Status:** Backlog
**PRD:** RF-14, RNF-06, RNF-07, RNF-08, RNF-09 (enmienda 2026-09-21,
precisión 2026-09-21, enmienda 2026-09-21b a
[PRD-catalogo-renovarte.md](../../renovarte-catalogo/docs/PRD/PRD-catalogo-renovarte.md))

> **Actualización (2026-09-21b):** el CTO/CEO resolvió la última pregunta
> abierta (techo de costo de uso de la API de Claude): **USD 20/mes**, con
> auto-deshabilitación del chat al alcanzarlo (RNF-09, AC-13 abajo). No
> quedan preguntas abiertas para esta feature — pasa a fase de diseño/RFC.
> El CTO/CEO también confirmó el encuadre de esta feature como ejercicio
> de aprendizaje (practicar RAG/embeddings/integración con LLMs), no una
> herramienta de optimización de ventas — ver "Alcance / Out".

> **Actualización (2026-09-21):** el CTO/CEO resolvió 5 de las 6 preguntas
> abiertas que dejó la primera versión de este spec (backend runtime,
> definición de "combo", presupuesto vs. premium, topología de repos, y
> tipo de piel/`renovarte-pipeline`). Este documento ya refleja esas
> decisiones en las secciones correspondientes — no quedan reabiertas.

## Problema

Hoy el visitante que no sabe qué crema comprar tiene que navegar el
catálogo por su cuenta (categoría, búsqueda por nombre) sin ninguna guía
sobre qué producto le conviene según su tipo de piel o cuánto quiere
gastar. El CTO/CEO quiere resolver eso con un chat conversacional embebido
en el sitio ("Colibrí") que, a partir de tipo de piel y
presupuesto, arme un combo de cremas recomendado en 3 niveles de precio.
Además del valor para el visitante, el CTO/CEO fue explícito en que esto
es también un ejercicio para practicar RAG/embeddings y comunicación con
LLMs vía API (cuenta de Anthropic/Claude ya existente) — esa motivación de
aprendizaje es parte legítima del "por qué" de esta feature, no un
efecto secundario a ignorar, y es análoga a la de `renovarte-events` (POC
de arquitectura event-driven, mismo patrón de "sumar algo útil al negocio
mientras se practica una tecnología nueva").

## Objetivo

Que un visitante sin conocimiento previo de la marca pueda, conversando en
lenguaje natural, decir su tipo de piel y presupuesto, y recibir 3 combos
de cremas reales del catálogo (más barato / medio / premium) para elegir,
sin tener que navegar categorías o comparar productos manualmente.

## Alcance

### In

- Un punto de entrada visible al chat embebido en `renovarte-catalogo`
  (widget o página dedicada — el patrón concreto de UI lo define el
  `ux-agent` en la fase siguiente, no esta spec).
- Captura conversacional de dos datos del visitante: tipo de piel y
  presupuesto (en lenguaje natural o guiado — el detalle de interacción
  también es de UX).
- Respuesta del chat con **3 opciones nombradas y distinguibles**
  (más barato / medio / premium), cada una con nombre(s) de producto,
  precio y a qué nivel corresponde.
- Cada una de las 3 opciones es un **combo**: un paquete de **2 o más**
  productos reales agrupados (p.ej. limpiador + crema día + protector
  solar) — nunca un único producto mostrado a distinto precio por nivel.
- Toda recomendación se construye **exclusivamente** con productos
  realmente publicados en el catálogo vigente (`products.json`) — mismo
  nombre y mismo `precio_venta` que se ve en la grilla/ficha de producto.
  Nunca un producto, precio o combinación inventada por el modelo.
- Cada una de las 3 opciones ordenada de forma ascendente por precio
  total del combo (más barato < medio < premium).
- Las opciones "más barato" y "medio" respetan el presupuesto declarado
  por el visitante como techo (precio total del combo ≤ presupuesto). La
  opción "premium" puede superar el presupuesto, pero nunca en más de un
  20% por encima del monto indicado por el visitante — es un límite duro,
  no una sugerencia de copy.
- El tipo de piel se infiere razonando sobre los campos ya públicos de
  cada producto (`nombre`, `descripcion`, `tags`) — no depende de ningún
  campo estructurado nuevo de tipo de piel en `products.json`.
- Un mensaje explícito de "no tengo una recomendación para eso" cuando no
  hay datos suficientes o no hay productos que matcheen razonablemente el
  pedido — en vez de inventar una respuesta para no dejar el chat vacío.
- El resto del catálogo (grilla, filtro, búsqueda, ficha de producto — RF-01
  a RF-04) sigue funcionando igual, con o sin el chat disponible.

### Out

- Optimización de conversión/ventas, analytics de negocio (funnels,
  métricas de conversión del chat) y A/B testing de combos. El CTO/CEO
  encuadró explícitamente esta feature como ejercicio de aprendizaje
  (practicar RAG/embeddings/integración con LLMs vía API), no como una
  herramienta para optimizar ventas — ese encuadre se mantiene mientras el
  techo de gasto (RNF-09) siga en USD 20/mes. La fase de diseño no debe
  invertir esfuerzo en estas capacidades.
- Compra, carrito o checkout desde el chat (sigue fuera de alcance de todo
  el PRD, §4.2).
- Historial de conversación persistido entre sesiones, cuentas de usuario o
  login.
- Derivación a un humano (WhatsApp, teléfono, email) iniciada desde el
  chat.
- Panel de administración para configurar prompts, revisar conversaciones
  o ajustar embeddings.
- Entrada o salida por voz.
- Cualquier conversación fuera del propósito de recomendar cremas del
  catálogo de RenovArte (el chat no es un asistente de propósito general).
- Multi-proveedor más allá de lo que ya está público hoy (mismo límite que
  el resto del PRD).
- Agregar campos estructurados nuevos de tipo de piel (o de cualquier otro
  tipo) a `products.json`, ni ningún cambio en `renovarte-pipeline` — esta
  feature no toca ese repo en esta fase; si el matching por inferencia
  resulta pobre en la práctica, evaluar un campo nuevo sería una
  iteración futura, no parte de este spec.
- Decidir el diseño técnico detallado de los 2 proyectos nuevos (nombres,
  repos concretos, stack, dónde viven) — el *conteo* (uno para el
  transporte del chat, otro para la conexión/RAG con el LLM) ya está
  confirmado y documentado como contexto en la sección siguiente, pero la
  arquitectura interna de cada uno es una decisión de diseño técnico de la
  fase de RFC (`developer-agent`/`ai-agent`/`backend-agent`), no de este
  spec de producto.
- Construir o elegir el mecanismo concreto de RAG/embeddings — es
  implementación, no un criterio de aceptación observable de producto; lo
  único exigible a nivel producto es el resultado (AC-4: solo productos
  reales).

## Contexto de arquitectura y dependencias

Estas decisiones ya están tomadas por el CTO/CEO y acotan el diseño
técnico de la fase de RFC, sin definirlo:

- **Todo el runtime en vivo del chat** (transporte por WebSocket, conexión
  al LLM, RAG) vive en **2 proyectos nuevos**, fuera de este repo.
  `renovarte-catalogo` se mantiene **100% estático**: nunca aloja un
  backend/runtime propio, y solo agrega un cliente en el navegador que
  consume esos servicios externos — el mismo patrón que ya usa hoy para
  consumir `products.json` generado externamente por `renovarte-pipeline`.
  Esto resuelve, sin necesidad de enmendar `constitution.md §II.4` ("no
  database, no runtime backend"), la tensión que planteaba la versión
  anterior de este spec: la invariante nunca se viola porque el runtime
  nunca vive en `renovarte-catalogo`. La fase de RFC/diseño no debe
  volver a cuestionar este punto; solo define el detalle interno de esos
  2 proyectos (nombres, repos, stack).
- Los nombres, repos concretos y stack de esos 2 proyectos nuevos **no se
  definen acá** — quedan para el RFC de diseño técnico. El precedente más
  cercano en este proyecto es `renovarte-events` (repo nuevo por
  capability nueva, con `README.md`/`CLAUDE.md` propios, sin PRD/
  constitution formal por ser un POC).
- `renovarte-pipeline` y el schema de `products.json` **no cambian** para
  esta feature (ver "Out").
- **Techo de gasto mensual de la API del LLM: USD 20/mes** (RNF-09). Al
  alcanzarlo, el chat se deshabilita automáticamente y deja de generar
  gasto adicional (AC-13); el resto del catálogo no se ve afectado
  (RNF-07). El mecanismo concreto para medir el gasto acumulado y ejecutar
  el corte (dónde vive ese control, con qué mecanismo/servicio, con qué
  frecuencia se revisa) es una decisión de diseño técnico de la fase de
  RFC (`ai-agent`/`backend-agent`), no de este spec de producto — solo el
  número y el comportamiento observable (AC-13) están definidos acá.

## Acceptance criteria

1. **AC-1 (RF-14):** Un visitante puede abrir el chat desde el sitio sin
   necesidad de login ni cuenta.
2. **AC-2 (RF-14):** El chat le pide al visitante (o acepta que indique
   directamente) tipo de piel y presupuesto antes de dar una
   recomendación.
3. **AC-3 (RF-14):** Dado un tipo de piel y presupuesto, el chat responde
   con exactamente 3 opciones etiquetadas como más barato / medio /
   premium, cada una mostrando producto(s), precio y su nivel.
4. **AC-4 (RF-14):** Cada producto mencionado en cualquiera de las 3
   opciones corresponde a un producto realmente publicado en el catálogo
   vigente, con el mismo nombre y el mismo precio que se ve en la
   grilla/ficha de ese producto — verificable comparando la respuesta del
   chat contra `products.json` al momento de la conversación.
5. **AC-5 (RF-14):** El precio total de las 3 opciones está ordenado en
   forma ascendente (más barato < medio < premium).
6. **AC-6 (RF-14):** Si no hay productos que permitan armar una
   recomendación razonable para los datos dados, el chat lo comunica
   explícitamente en vez de responder con un combo inventado o
   inconsistente.
7. **AC-7 (RF-14):** Cada una de las 3 opciones está compuesta por 2 o más
   productos reales del catálogo — ninguna opción es un único producto.
8. **AC-8 (RF-14):** El precio total de las opciones "más barato" y
   "medio" no supera el presupuesto indicado por el visitante (precio
   total del combo ≤ presupuesto).
9. **AC-9 (RF-14):** El precio total de la opción "premium" no supera el
   presupuesto indicado por el visitante en más de un 20% (premium ≤
   presupuesto × 1.20).
10. **AC-10 (RNF-06):** Ninguna respuesta del chat, ni el tráfico de red
    visible desde el navegador, expone una API key/credencial de terceros
    (LLM) ni el costo/margen real de RenovArte.
11. **AC-11 (RNF-07):** Con el chat deshabilitado o caído, la grilla,
    filtro, búsqueda y ficha de producto (RF-01 a RF-04) siguen
    funcionando con normalidad.
12. **AC-12 (RNF-08):** `renovarte-catalogo` no incorpora ningún endpoint,
    proceso o servicio de backend propio para servir el chat — toda
    llamada al transporte del chat o al LLM sale desde el navegador hacia
    los servicios externos, verificable en que el repo no suma runtime de
    servidor propio (más allá del build estático ya existente).
13. **AC-13 (RNF-09):** Si el gasto mensual acumulado de la API del LLM
    alcanza el techo definido (USD 20/mes), el chat se deshabilita
    automáticamente (deja de generar gasto adicional) y el resto del
    catálogo (grilla, filtro, búsqueda, ficha de producto — RF-01 a RF-04)
    sigue funcionando con normalidad, sin degradación.

## Preguntas abiertas

Ninguna. Las preguntas sobre conflicto con `constitution.md §II.4`,
taxonomía de tipo de piel, definición de "combo", relación presupuesto/
premium y topología de repos que dejaba la primera versión de este spec,
y la última pregunta pendiente (techo de costo de uso de la API de
Claude) ya están resueltas por el CTO/CEO y reflejadas en "Alcance",
"Contexto de arquitectura y dependencias" y AC-13 arriba. Esta spec queda
lista para pasar a fase de diseño/RFC sin preguntas abiertas.

**Conflictos con `constitution.md`:** ninguno bloqueante. El conflicto
original con `constitution.md §II.4` ("No database, no runtime backend")
está resuelto sin necesidad de enmendar esa invariante — ver "Contexto de
arquitectura y dependencias" arriba: el runtime del chat nunca vive en
`renovarte-catalogo`. El techo de gasto de USD 20/mes (RNF-09) es una
excepción explícita y acotada al chat al invariante "$0 infraestructura"
(`constitution.md §II.5` / RNF-01), aprobada por el CTO/CEO — el resto del
catálogo sigue en $0 sin cambios; no requiere reabrir esta spec, pero la
fase de RFC debería dejarlo anotado si en algún momento se toca
`constitution.md` directamente.
