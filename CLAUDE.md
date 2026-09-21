# Reglas de flujo de trabajo (renovarte-parent y submódulos)

Estas reglas aplican a cualquier sesión de Claude Code (o cualquier agente)
que trabaje en este proyecto — renovarte-parent y todos sus submódulos —, no
solo a la sesión que las escribió.

## Nunca commitear ni pushear directo a `main`

Ningún agente commitea ni pushea directo sobre `main` — ni en
`renovarte-parent` ni en ninguno de sus submódulos (`renovarte-catalogo`,
`renovarte-pipeline`, o cualquier otro repo de este proyecto), incluidos
cambios "chicos" como docs o config. Todo trabajo arranca creando una rama
dedicada (`feature/<slug>`, `hotfix/<slug>`, `chore/<slug>`, etc., la que
corresponda al tipo de cambio) y llega a `main` únicamente vía Pull
Request. Esto vale aunque el repo no tenga (todavía) un Ruleset de GitHub
que lo bloquee del lado del servidor — es una regla de proceso, no solo una
protección técnica — y es además de, no en lugar de, la aprobación humana
explícita que ya exige cada `git commit` y cada `git push` en la sección
siguiente.

## Nunca mergear Pull Requests

El merge final a `main` (en `renovarte-catalogo`, `renovarte-pipeline`, o
cualquier otro repo de este proyecto) lo tiene que ejecutar siempre una
persona humana, sin excepción, aunque todos los checks requeridos estén en
verde. No uses `gh pr merge` ni equivalentes.

## Aprobación humana obligatoria antes de actuar

- Ningún agente puede instalar herramientas, paquetes o dependencias (brew,
  npm, pnpm, pip, uv, vercel CLI, gh CLI, etc.) ni ejecutar scripts que no
  sean de solo lectura, sin pedir aprobación humana explícita antes de
  hacerlo.
- Antes de cada `git commit` y antes de cada `git push` hay que pedir
  aprobación humana explícita — no alcanza con que el humano haya aprobado
  la tarea en general; cada commit y cada push necesitan su propio ok.

## Toda modificación de UI/UX pasa siempre por el agente UX

En el flujo `/feature` (y en cualquier otro flujo de este proyecto que use
subagentes), cualquier cambio que toque una página, un layout, un patrón de
interacción o la experiencia visible por el usuario final — no solo
features nuevas, también ajustes o mejoras sobre pantallas existentes —
tiene que pasar por el `ux-agent` **antes** de que `frontend-agent` (o
cualquier otro agente especialista, como `ai-agent` cuando construye una UI
conversacional) entre en modo diseño o implementación sobre esa parte.
Ningún agente especialista debe decidir layout, jerarquía de información ni
patrones de interacción por su cuenta dentro de `plan.md`; eso es trabajo
del `ux-agent`. Esto aplica aunque el cambio parezca chico (por ejemplo,
reordenar o separar filtros/pills existentes).

## Todo entregable del agente UX necesita aprobación humana antes de avanzar

Cuando el `ux-agent` comparte su artefacto/maqueta (`ux.md` y/o el Artifact
visual), el diseño no se da por aprobado ni se pasa a `frontend-agent`/
`ai-agent` para implementarlo hasta que un humano lo revise y lo apruebe
explícitamente — igual que el resto de los gates de fase de `/feature`, el
silencio o un "ok" ambiguo no cuentan como aprobación. Esto aplica aunque
el `ux-agent` no haya encontrado ninguna divergencia respecto al plan
técnico existente.
