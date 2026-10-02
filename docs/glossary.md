---
type: glossary
---

# Glosario — RenovArte

Términos del dominio y del proceso tal como se usan en specs, RFCs y
código. Cada definición es corta y linkea a la nota que lo explica.

## Negocio y catálogo

| Término | Significado |
|---|---|
| **RenovArte** | El negocio: reventa de productos de Serlaca/LACA con catálogo web propio |
| **Serlaca** | Proveedor comercial. Su API entrega catálogo y costo. Ver [provider-serlaca-laca](./providers/provider-serlaca-laca.md) |
| **LACA** | Marca/lista de precios del proveedor. Publica un PDF mensual con precio profesional, ABC y de catálogo |
| **`products.json`** | El catálogo publicado, sin datos sensibles. Lo leen todos los consumidores. Ver [contract-products-json](./contracts/contract-products-json.md) |
| **Categoría / grupo** | Clasificación del producto en el catálogo. Los grupos de alto nivel los arma el pipeline (spec 0001 de pipeline) |
| **Oferta** | Descuento manual (`data/offers.json`) que se aplica sobre el precio ya resuelto. Se publica como `precio_regular` + `descuento_pct` |

## Precios

| Término | Significado |
|---|---|
| **Costo** | Lo que paga RenovArte al proveedor. **Sensible**: nunca sale de `renovarte-pipeline` |
| **Margen** | Porcentaje sobre el costo (`MARGIN_PERCENT_*`). **Sensible** |
| **Precio profesional** | Precio de revendedor del PDF de LACA. Es en la práctica el costo de RenovArte. **Sensible**: nunca se commitea ni se publica |
| **Precio ABC** | Precio sugerido de venta del PDF de LACA. Es la fuente primaria del precio de venta |
| **Precio catálogo** | Otro precio sugerido del PDF de LACA. Hoy no se usa como precio de venta |
| **Piso de margen** | `precio_venta = max(precio_abc, costo × (1 + margen))`. Ver [domain-precios](./domains/domain-precios.md) |
| **`precio_venta`** | El precio publicado que ve el visitante |
| **Leak / `check:leak`** | Chequeo automático de que ningún dato sensible quedó en lo publicado. Corre en el pipeline y en el catálogo |

## Colibrí (chat)

| Término | Significado |
|---|---|
| **Colibrí** | El chat recomendador del sitio (spec 0016). Ver [domain-colibri](./domains/domain-colibri.md) |
| **Turno** | Un mensaje del visitante y la respuesta del sistema. Cada turno hace como máximo una llamada al LLM |
| **Tipo de piel / presupuesto** | Los dos datos ("slots") que Colibrí necesita para recomendar |
| **Combo** | Conjunto de 2 o más productos reales que entra en el presupuesto. Siempre se ofrecen 3: más barato, medio y premium (premium ≤ presupuesto × 1,20) |
| **`no_recommendation`** | Respuesta cuando no se puede armar un combo válido |
| **Guardrails** | Verificación final contra el catálogo real antes de responder |
| **RAG / retrieval** | Búsqueda de productos elegibles con embeddings (Voyage AI) sobre el catálogo sincronizado |
| **`ChatEnvelope`** | Formato de los mensajes del WebSocket. Ver [contract-chat-envelope](./contracts/contract-chat-envelope.md) |

## Órdenes

| Término | Significado |
|---|---|
| **Orden** | Pedido confirmado desde el carrito. Sin pago ni envío en el sitio (spec 0017). Ver [domain-ordenes](./domains/domain-ordenes.md) |
| **Doble canal** | Entrega de la orden por mail y por el canal privado de Discord. Se acepta con al menos un canal |
| **Número de orden** | Identificador único, el mismo en los dos canales |
| **Seudonimización** | El registro de la orden se guarda 90 días sin datos personales (Ley 25.326) |

## Costo y operación

| Término | Significado |
|---|---|
| **$0 infra** | Regla por defecto del proyecto: todo dentro de free tiers (constitution root §II.5) |
| **Tope USD 20/mes** | Excepción de costo para chat y órdenes (RNF-09 / RNF-14) |
| **Ledger** | Tabla propia (DynamoDB) donde se acumula el gasto real de cada mes |
| **Kill-switch / `budget-guard`** | Lambda que apaga el chat o las órdenes (flag de control) al llegar al tope |
| **Best-effort** | Un paso que, si falla, no bloquea el flujo principal (ej. el evento de cambio de precio) |

## Proceso (SDD)

| Término | Significado |
|---|---|
| **PRD** | Documento de requisitos de un repo (`<repo>/docs/PRD/`). Numera los requisitos como RF/RNF |
| **RF / RNF** | Requisito funcional / no funcional de una PRD (ej. RF-15, RNF-09) |
| **Spec** | `specs/NNNN-slug/spec.md`: qué cambia una feature y sus criterios de aceptación |
| **AC** | Criterio de aceptación de una spec (ej. AC-13). Lo verifica `tester-agent` |
| **RFC** | Diseño técnico de una superficie nueva (repo o sistema) dentro de una spec |
| **`plan.md` / `tasks.md`** | Cómo se construye la feature y las tareas, con una sección por agente especialista |
| **ADR** | Registro de una decisión y su por qué. Ver [decisions](./decisions/README.md) |
| **L0–L3** | Nivel de una decisión, que define si necesita ADR. Ver [decisions](./decisions/README.md#qué-va-a-adr-y-qué-no) |
| **Constitution** | Invariantes no negociables: [root](../specs/constitution.md) y una por repo |
| **Gate** | Aprobación humana explícita entre fases de `/agentic-sdd:feature` |
| **Manifest** | [`manifest.yaml`](../manifest.yaml): composición del sistema |
