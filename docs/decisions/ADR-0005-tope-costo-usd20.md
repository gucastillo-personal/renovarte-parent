---
id: ADR-0005
title: "Excepción de costo: tope de USD 20/mes con ledger propio + kill-switch"
status: Accepted
date: 2026-09-21
deciders: CTO/CEO
level: L3
repos: ["[[repo-renovarte-chat-gateway]]", "[[repo-renovarte-colibri-rag]]", "[[repo-renovarte-ordenes]]"]
domains: ["[[domain-colibri]]", "[[domain-ordenes]]"]
providers: ["[[provider-aws]]", "[[provider-anthropic]]"]
origin: "[[specs/0016-chat-recomendador-cremas/spec|0016]]"
supersedes: []
extends: []
superseded_by:
constitution: ["§II.5 $0 infraestructura por defecto (excepción explícita)"]
cost_impact: "≤ USD 20/mes por feature (chat y órdenes, topes independientes)"
personal_data: false
reversibility: alta
retroactive: true
detail: "specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md §5; specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md §8"
---

# ADR-0005 — Excepción de costo: tope de USD 20/mes con ledger propio + kill-switch

## Contexto

El proyecto tiene $0 de infraestructura como regla (constitution §II.5).
El chat de la spec [0016](../../specs/0016-chat-recomendador-cremas/spec.md)
llama a la API de Claude, que cobra por uso; el CTO/CEO fijó un techo de
**USD 20/mes** con apagado automático (RNF-09, AC-13). La spec 0017
(órdenes) adoptó el mismo techo para su propio gasto en AWS (RNF-14,
AC-22), como tope independiente.

## Problema

¿Cómo permitimos un gasto acotado sin abrir la puerta a un gasto sin
límite, y cómo lo medimos si una parte se factura fuera de AWS?

## Restricciones

- Constitution §II.5: cualquier excepción al $0 es explícita, acotada a
  la feature que la necesita y aprobada por el CTO/CEO en su spec. Nunca
  se hereda.
- AWS Budgets solo ve gasto de AWS, nunca la factura de Anthropic, y se
  actualiza con 8 a 24 h de retraso.
- El resto del catálogo no se puede degradar cuando el tope corta (RNF-07).

## Decisión

Cada feature con costo tiene su **propio tope de USD 20/mes**, aprobado
en su spec, y se protege con capas:

1. **Ledger propio en DynamoDB** (`período = YYYY-MM`, UTC): cada
   operación suma su costo (para Claude, los tokens reales × el precio
   público del modelo; para órdenes, costos unitarios conservadores ×2).
   Al llegar al umbral, se apaga un **flag de control** que el servicio
   lee antes de gastar, y el cliente muestra el texto de "tope alcanzado".
2. **Kill-switch** (`budget-guard`): apaga el servicio por completo ante
   un AWS Budget al 100 % o una alarma de flood, aunque se pierda el texto
   específico del tope.
3. **Reactivación** el día 1 de cada mes (EventBridge Scheduler) o a mano,
   según el runbook.

Los topes de chat y órdenes son **independientes**: uno no consume el del
otro.

## Alternativas consideradas

| Opción | A favor | En contra | Por qué no |
|---|---|---|---|
| Solo AWS Budgets + Budget Actions | Nativo, sin código | No ve el gasto de Anthropic; 8–24 h de retraso | No cumple AC-13 por sí solo; queda como capa secundaria |
| Límite de gasto en la consola de Anthropic | Sin código | Corte opaco: el usuario ve errores, no un estado claro; no cubre AWS | Sin control del comportamiento observable |
| **Ledger propio + flag + kill-switch** | Corte en tiempo real con el texto correcto; cubre los dos proveedores | Código y tablas propias que mantener | Elegida |

## Por qué

El ledger es la única fuente que ve el gasto de Claude en tiempo real
(`usage` de la propia API) y deja controlar qué ve el visitante. Las
capas de AWS cubren lo que el ledger no puede: bugs que generan gasto de
AWS fuera de lo contabilizado, como un loop de reconexión o un flood.

## Consecuencias

- La excepción no se hereda: una feature nueva con costo necesita su
  propio tope, aprobado en su spec, y su propio ADR o `extends` de este.
- El conector LLM necesita permiso de escritura acotado sobre el ledger
  del gateway (contrato de tabla en RFC transporte §5.1).
- Recursos con tags por proyecto para que los Budgets filtren bien.

## Trade-offs y riesgos

- El ledger estima: si cambia el precio del modelo y no se actualiza, el
  corte se desvía. Mitigación: el precio es configuración y hay un margen
  conservador.
- El kill-switch al 100 % pierde el texto del tope (respuesta de error
  genérica). Se acepta por ser un caso extremo.
- La reactivación automática del día 1 fue una inferencia de "techo
  mensual" en la 0016, confirmada por el CTO/CEO en la 0017.

## Salida / reversión

Alta: subir o bajar el tope es cambiar una env var (`BUDGET_CAP_USD`).
Eliminar la excepción es apagar la feature.

## Detalle técnico

[`rfc-transporte-websocket.md`](../../specs/0016-chat-recomendador-cremas/rfc-transporte-websocket.md)
§5 (chat) y `specs/0017-carrito-orden-compra/rfc-servicio-ordenes.md` §8
(órdenes; por ahora solo en la rama `feature/carrito-orden-compra`).

## Notas posteriores
