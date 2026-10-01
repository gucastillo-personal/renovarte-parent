---
type: provider
provider: vercel
---

# Proveedor: Vercel

Servicios, costo y repos que lo usan: entrada `providers.vercel` de
[`manifest.yaml`](../../manifest.yaml).

## Para qué lo usamos

Hosting del sitio estático `renovarte-catalogo`. Cada build lee el
`products.json` versionado en el repo. El deploy a producción lo hace a
mano el CTO/CEO.

## Riesgos y límites

- Plan gratuito: solo sirve contenido estático. Funciones o un backend en
  Vercel irían contra la invariante "no runtime backend" del catálogo y
  necesitarían un ADR.
- El `products.json` publicado en el dominio de producción es lo que
  sincroniza `renovarte-colibri-rag` (`PRODUCTS_URL`). Si cambia el
  dominio, hay que actualizar esa variable.
