---
type: domain
domain: colibri
---

# Dominio: Colibrí (chat recomendador)

El chat del sitio. El visitante cuenta su tipo de piel y su presupuesto, y
Colibrí le propone **3 combos de cremas reales** del catálogo (más barato,
medio y premium, con 2 o más productos cada uno).

## Reglas que lo definen

- "Más barato" y "medio" ≤ presupuesto; "premium" ≤ presupuesto × 1,20.
  Lo garantiza el código, no el LLM.
- Se hace **una sola llamada al modelo por turno**. El resto del texto sale
  de plantillas.
- **Tope de USD 20/mes**: al llegar al tope, el chat se apaga solo.
- Toda recomendación se verifica contra el catálogo publicado antes de
  mostrarla.

## Dónde se ve funcionando

- [Flujo 3 — chat Colibrí](../arquitectura-general.md#flujo-3--chat-colibrí-spec-0016-en-producción-desde-2026-09-29)
- Spec: [0016](../../specs/0016-chat-recomendador-cremas/spec.md), con
  `ux.md` y los dos RFCs en la misma carpeta.
