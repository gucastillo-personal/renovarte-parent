---
type: provider
provider: discord
---

# Proveedor: Discord

Servicios, costo y repos que lo usan: entrada `providers.discord` de
[`manifest.yaml`](../../manifest.yaml).

## Para qué lo usamos

Webhooks a dos canales distintos, cada uno con su propio webhook:

- **Canal técnico**: resumen de cambios de precio (`renovarte-events`).
- **Canal privado de órdenes** (planeado, spec 0017): la orden completa,
  con datos de contacto, como segundo canal de entrega junto al mail.

## Riesgos y límites

- **Datos personales (Ley 25.326)**: el canal de órdenes guarda nombre,
  contacto y dirección del visitante. Solo lo ven los propietarios, los
  mensajes se borran a los 60 días y se recomienda 2FA en esas cuentas.
- Las URLs de los webhooks son **secretos**: nunca van en el navegador ni
  en el repo.
- Discord aplica rate limits a los webhooks. En el volumen actual no es un
  problema.
