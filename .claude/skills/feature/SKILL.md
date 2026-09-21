---
name: feature
description: Run the product->design->specialist->tester pipeline for a business need given by the CTO/CEO, from a one-line idea to code ready for manual review and deploy. Use when the user describes a new need/feature/bug for renovarte-catalogo or renovarte-pipeline and wants it turned into a PRD, RFC, plan, implementation and test verification. Stops for explicit CTO/CEO approval between every phase — never advances on its own.
---

# `/feature` — need → PRD → UX (if applicable) → RFC/plan/estimate → code → tests → manual deploy

You (the orchestrator, running in the main thread of `renovarte-parent`) run
this pipeline by delegating to subagents defined in `.claude/agents/`:
`product-agent`, `ux-agent`, `frontend-agent`, `backend-agent`, `ai-agent`,
`tester-agent`. Each subagent starts with no memory of this conversation —
give each one a self-contained prompt with the need, the relevant repo(s),
and the file paths of anything from a previous phase it must read.

`frontend-agent`, `backend-agent`, and `ai-agent` are specialists, not a
single generalist — a feature may need one, two, or all three, decided by
its scope (see Phase 2). When more than one applies, they all write into
the *same* `specs/NNNN-slug/plan.md` and `tasks.md`, each under their own
`## Frontend` / `## Backend` / `## AI` heading — tell each specialist,
in its prompt, which other specialists are also active on this spec so
none of them overwrites another's section.

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

## Phase 1 — Product (PRD + spec)

Invoke `product-agent` with: the need in the CTO/CEO's own words, and a
pointer to `PLAN.md`/`README.md` for repo context if this is the first
feature run in the session. Let it decide which repo(s) it belongs to.

Post its report to the user: repo(s), PRD requirement IDs, spec number,
objective, acceptance criteria count, open questions. **Wait for approval.**

## Phase 2 — UX (only when the feature touches UI/UX)

Per this project's `CLAUDE.md`, run this phase — and do not let any
specialist skip straight to design — whenever the spec touches a page, a
layout, an interaction pattern, or anything visible to the end user, no
matter how small (reordering existing filters/pills counts). Skip this
phase only for changes with no visible surface at all (e.g. a pure
pipeline/data change with no UI implication).

Invoke `ux-agent` with the `specs/NNNN-slug/` path from phase 1. It
produces `ux.md` and, for anything with real visual/interactive behavior,
a review mockup via `Artifact`.

Post its report and the mockup link (if any) to the user. **Wait for
approval** — `frontend-agent` and `ai-agent` may not start design mode on
any UI-facing part of this spec until `ux.md` is explicitly approved.

## Phase 3 — Design (RFC + plan.md + tasks.md + estimate)

Decide scope from `spec.md`'s `Alcance` (and `ux.md`, if phase 2 ran):
which of `frontend-agent`, `backend-agent`, `ai-agent` apply. A feature can
need one, two, or all three (e.g. the budget-based product chat needs all
three: `ai-agent` for the prompt/model/contract, `backend-agent` if a
constitution §II.4 amendment or pipeline change is needed, `frontend-agent`
for the widget built to `ux.md`).

Invoke each applicable specialist in **design mode**, pointed at the same
`specs/NNNN-slug/` path, telling each which other specialists are also
active so they append under their own heading in the shared `plan.md`/
`tasks.md` rather than overwrite. Invoke specialists whose output others
depend on first — typically `ai-agent`/`backend-agent` (they usually define
the contract) before `frontend-agent` (which consumes it).

Post a combined report: RFC change (or why none is needed) — flagged
prominently, first, if any specialist reports this needs a constitution
§II.4 amendment (catalogo's first runtime backend) — the synthesized
estimate, and total task count. **Wait for approval** — this is the
CTO/CEO's chance to weigh in on scope/estimate and, when it applies, on
amending a stated non-negotiable invariant, before any code gets written.

## Phase 4 — Implementation

Invoke the same specialist(s) from phase 3, in **implement mode**, same
`specs/NNNN-slug/` path. Each works its own tasks in `tasks.md`, runs its
repo's gate, and the last one to finish updates `specs/README.md`.

Post a combined report: what got implemented, gate result(s) (real output,
not paraphrased) per specialist, tasks checked off, anything that diverged
from the plan. **Wait for approval** to move to independent testing.

## Phase 5 — Testing

Invoke `tester-agent` with the same `specs/NNNN-slug/` path. It independently
re-verifies every acceptance criterion and re-runs the full gate — it does
not take phase 4's report on faith.

Post its pass/fail table per AC, the gate result, any bug found, and its
go/no-go recommendation.

## After phase 5 — this skill's job is done

Do **not** deploy, merge, push, or open a PR. Summarize for the CTO/CEO
that the feature is code-complete and tester-verified, and that manual
final review + deploy is theirs to do (per this repo's own process — e.g.
`renovarte-catalogo`'s Vercel deploy, or `renovarte-pipeline`'s
`make publish-live` / merging its PR into `renovarte-catalogo`). If the
tester agent's recommendation was no-go, say so plainly instead of
presenting it as ready.

## If something breaks mid-pipeline

If a subagent reports a conflict with `constitution.md`, an ambiguity it
couldn't resolve, or a gate it can't get green, stop and surface that to
the user immediately rather than pushing forward or having the next
subagent paper over it. The CTO/CEO decides how to resolve it; only resume
the pipeline once they do.
