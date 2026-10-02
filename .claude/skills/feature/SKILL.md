---
name: feature
description: Run the context->product->design->specialist->tester->knowledge pipeline for a business need given by the CTO/CEO, from a one-line idea to code ready for manual review and deploy, with the knowledge base (manifest, notes, ADRs) updated at the end. Use when the user describes a new need/feature/bug for any repo in renovarte-parent's manifest.yaml and wants it turned into a PRD, RFC, plan, implementation and test verification. Stops for explicit CTO/CEO approval between every phase — never advances on its own.
---

# `/feature` — need → context → PRD → UX (if applicable) → RFC/plan/ADRs/estimate → code → tests → knowledge closure

You (the orchestrator, running in the main thread of `renovarte-parent`) run
this pipeline by delegating to subagents defined in `.claude/agents/`:
`product-agent`, `ux-agent`, `frontend-agent`, `backend-agent`, `ai-agent`,
`devops-agent`, `tester-agent`. Each subagent starts with no memory of this
conversation — give each one a self-contained prompt with the need, the
relevant repo(s), the **context pack** from Phase 0, and the file paths of
anything from a previous phase it must read.

`frontend-agent`, `backend-agent`, `ai-agent` and `devops-agent` are
specialists, not a single generalist — a feature may need one or several,
decided by its scope (see Phase 3). When more than one applies, they all
write into the *same* `specs/NNNN-slug/plan.md` and `tasks.md`, each under
their own `## Frontend` / `## Backend` / `## AI` / `## Infra` heading — tell
each specialist, in its prompt, which other specialists are also active on
this spec so none of them overwrites another's section.

**The CTO/CEO is the human running this session.** They already gave the
need in their own words (`args`, or the message that triggered this skill).
Do not paraphrase it away — pass their actual words to the product agent.

## The one hard rule

**Stop and wait for explicit approval before starting each next phase.**
After each phase, post the subagent's report to the user and ask plainly:
does this look right, and do you approve moving to the next phase? Do not
proceed on silence, on a vague "ok" that reads like acknowledgment rather
than approval, or on your own judgment that it looks fine. If the user
asks for changes instead of approving, send those changes back into the
*same* phase (re-invoke the same subagent with the feedback) — do not skip
ahead. This holds even if a later phase seems obviously fine to skip to;
the point of the gate is the CTO/CEO's own review, not just the artifact
being correct. This applies to **every** gate below, including the UX
gate — per this project's `CLAUDE.md`, `ux.md` is never treated as
approved on silence or an ambiguous "ok", even when `ux-agent` found no
divergence from the existing plan.

## Accepted ADRs are constraints

An ADR in `docs/decisions/` with status `Accepted` binds every phase. If a
subagent's design or implementation needs to contradict one, it stops and
reports **"requires supersede"** — it never contradicts the ADR silently
and never edits it to match. When that happens, surface it to the CTO/CEO
immediately (see "If something breaks"). Superseding is a decision of its
own: a new ADR with `supersedes:`, approved at the Phase 3 gate, with the old
one moved to `Superseded` in the same PR.

## Phase 0 — Context (orchestrator, no subagent, no gate)

Before invoking anyone, build the context pack following the
context-discovery order in `CLAUDE.md`. `PLAN.md` is history only.

1. [`manifest.yaml`](../../../manifest.yaml): which repos the need plausibly
   touches, their `responsibility`, the contracts they produce or consume,
   and the providers involved.
2. If the need continues an existing spec: its frontmatter and
   `## Decisiones relacionadas`.
3. ADRs in `docs/decisions/`: the ones those repos, contracts and providers
   point to (`foundational_decisions` in the manifest, and
   `grep -rl "<repo|contract|provider>" docs/decisions`). Keep only the ones
   that actually bear on the need.
4. `specs/constitution.md` and the `specs/constitution.md` of each repo
   involved.
5. The schema document of each contract involved (`contracts.<x>.schema`).

The context pack is a short list of **paths with one line each on why they
matter** — not copied content. Pass it in every subagent prompt from here
on, and update it if a later phase changes which repos are involved. Show
it to the CTO/CEO together with the Phase 1 report.

## Phase 1 — Product (PRD + spec)

Invoke `product-agent` with: the need in the CTO/CEO's own words and the
context pack. Let it decide which repo(s) it belongs to.

The spec it writes opens with the frontmatter defined in `specs/README.md`
and closes with `## Decisiones relacionadas` (the existing ADRs the feature
reuses or is constrained by). It also answers the detection checklist in
`docs/decisions/README.md` as **candidate decisions** — new architectural,
provider or contract decisions the feature will probably need.

Post its report to the user: repo(s), PRD requirement IDs, spec number,
objective, acceptance criteria count, related ADRs, candidate decisions,
open questions. **Wait for approval.**

## Phase 2 — UX (only when the feature touches UI/UX)

Per this project's `CLAUDE.md`, run this phase — and do not let any
specialist skip straight to design — whenever the spec touches a page, a
layout, an interaction pattern, or anything visible to the end user, no
matter how small (reordering existing filters/pills counts). Skip this
phase only for changes with no visible surface at all (e.g. a pure
pipeline/data change with no UI implication).

Invoke `ux-agent` with the `specs/NNNN-slug/` path from phase 1 and the
context pack. It produces `ux.md` and, for anything with real
visual/interactive behavior, a review mockup via `Artifact`.

Post its report and the mockup link (if any) to the user. **Wait for
approval** — `frontend-agent` and `ai-agent` may not start design mode on
any UI-facing part of this spec until `ux.md` is explicitly approved.

## Phase 3 — Design (RFC + plan.md + tasks.md + ADRs + estimate)

Decide scope from `spec.md`'s `Alcance` (and `ux.md`, if phase 2 ran): which
of `frontend-agent`, `backend-agent`, `ai-agent`, `devops-agent` apply. A
feature can need one or several (e.g. the budget-based product chat, spec
0016, needed `ai-agent` for the prompt/model/contract, `backend-agent` for
the WebSocket transport, `devops-agent` for the infra across both new repos,
and `frontend-agent` for the widget built to `ux.md`).

Invoke each applicable specialist in **design mode**, pointed at the same
`specs/NNNN-slug/` path with the context pack, telling each which other
specialists are also active so they append under their own heading in the
shared `plan.md`/`tasks.md` rather than overwrite. Invoke specialists whose
output others depend on first — typically `ai-agent`/`backend-agent` (they
usually define the contract) before `frontend-agent` (which consumes it).

Every decision a specialist makes is classified with the levels in
`docs/decisions/README.md`:

- **L1** → a row in a `### Decisiones` table under the specialist's own
  section of `plan.md`, ID `D-NNNN-n`.
- **L2/L3** → an ADR draft in `docs/decisions/` from `_template.md`, status
  `Proposed`, `origin` = this spec. Before invoking specialists, tell each
  one the next free ADR number(s) it may use, so parallel drafts don't
  collide.

Post a combined report, in this order:

1. Anything that **requires supersede** of an `Accepted` ADR or amends a
   constitution invariant — first and prominently, if any.
2. **ADRs proposed**, one line each (decision, level, cost impact).
3. RFC change (or why none is needed), the synthesized estimate, and total
   task count.

**Wait for approval**, and get it **ADR by ADR**: each approved ADR moves
from `Proposed` to `Accepted`; a rejected one goes back to its specialist
with the CTO/CEO's feedback. This is the CTO/CEO's chance to weigh in on
scope, estimate and every architectural decision before any code gets
written.

## Phase 4 — Implementation

Invoke the same specialist(s) from phase 3, in **implement mode**, same
`specs/NNNN-slug/` path and context pack. Each works its own tasks in
`tasks.md`, runs its repo's gate (the `gate` field of that repo in the
manifest), and the last one to finish updates `specs/README.md`.

If implementation has to depart from an `Accepted` ADR, the specialist
stops and reports it — same as a conflict with `constitution.md`. The ADR is
never "fixed" to match the code.

Post a combined report: what got implemented, gate result(s) (real output,
not paraphrased) per specialist, tasks checked off, anything that diverged
from the plan or from an ADR. **Wait for approval** to move to independent
testing.

## Phase 5 — Testing

Invoke `tester-agent` with the same `specs/NNNN-slug/` path and the context
pack. It independently re-verifies every acceptance criterion, re-runs the
gate of every repo touched, and checks the result against the constitutions
and the `Accepted` ADRs involved — it does not take phase 4's report on
faith.

Post its pass/fail table per AC, the gate result, any bug found, and its
go/no-go recommendation. **Wait for approval** to close knowledge.

## Phase 6 — Knowledge closure (orchestrator, no subagent)

Bring the knowledge base in line with what was actually built. Do this
yourself — you have the full context of the run. Touch only what changed:

1. **`manifest.yaml`**: new repos, contracts or providers; status changes
   (`planned` → `in-development` → `production`); `foundational_decisions`
   for the ADRs this feature created.
2. **Notes** in `docs/repos/`, `docs/domains/`, `docs/contracts/`,
   `docs/providers/`: one new note per new manifest entry (same structure
   as the existing ones), and updates where a "qué no hace", a risk or a
   limit changed. New terms go to `docs/glossary.md`.
3. **Flows**: `docs/arquitectura-general.md` and the `docs/flujo-*.md`
   documents, if a flow changed.
4. **The spec**: frontmatter `status` and `closed`, and its row in
   `specs/README.md`.
5. **ADRs**: real findings from implementation or testing that do not
   change a decision go as a dated line in `## Notas posteriores`
   (append-only). A finding that does change a decision is not a note — stop
   and propose a superseding ADR instead.
6. **L1 decisions** (`D-NNNN-n`) that another repo or feature now depends on
   get promoted to an ADR.

Post the list of files changed and a one-line summary of each. **Wait for
approval.** Committing and pushing these changes follows `CLAUDE.md`: a
dedicated branch, a PR, and explicit approval for each commit and each push.

## After phase 6 — this skill's job is done

Do **not** deploy or merge. Summarize for the CTO/CEO that the feature is
code-complete, tester-verified and documented, and that manual final review
+ deploy is theirs to do (per each repo's own process — the `deploy` field
of the manifest, e.g. `renovarte-catalogo`'s Vercel deploy, or merging the
pipeline's publish PR into `renovarte-catalogo`). If the tester agent's
recommendation was no-go, say so plainly instead of presenting it as ready.

## If something breaks mid-pipeline

If a subagent reports a conflict with `constitution.md` or with an
`Accepted` ADR ("requires supersede"), an ambiguity it couldn't resolve, or
a gate it can't get green, stop and surface that to the user immediately
rather than pushing forward or having the next subagent paper over it. The
CTO/CEO decides how to resolve it; only resume the pipeline once they do.
