---
type: provider
provider: github
---

# Proveedor: GitHub

Servicios, costo y repos que lo usan: entrada `providers.github` de
[`manifest.yaml`](../../manifest.yaml).

## Para qué lo usamos

- **Repos**: el superproyecto y todos los submódulos. Todo cambio entra por
  PR y lo mergea una persona (ver [`CLAUDE.md`](../../CLAUDE.md)).
- **Actions**:
  - CI de cada repo.
  - `publish` de `renovarte-pipeline`: abre el PR con el `products.json`
    nuevo en `renovarte-catalogo`.
  - Sync programado del catálogo en `renovarte-colibri-rag`: cada 6 h,
    también abre PR.

## Riesgos y límites

- `publish` necesita `CATALOGO_PAT` para abrir PRs en otro repo. Es el
  único secreto del pipeline en CI.
- Las Actions abren PRs pero **nunca hacen auto-merge**.
- La protección de ramas está detallada por repo. Hoy está configurada en
  `renovarte-catalogo` y `renovarte-pipeline`.
