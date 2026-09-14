---
name: feature
description: Run the product->developer->tester pipeline for a business need given by the CTO/CEO, from a one-line idea to code ready for manual review and deploy. Use when the user describes a new need/feature/bug for renovarte-catalogo or renovarte-pipeline and wants it turned into a PRD, RFC, plan, implementation and test verification. Stops for explicit CTO/CEO approval between every phase — never advances on its own.
---

# `/feature` — need → PRD → RFC/plan/estimate → code → tests → manual deploy

You (the orchestrator, running in the main thread of `renovarte-parent`) run
this pipeline by delegating to three subagents defined in
`.claude/agents/`: `product-agent`, `developer-agent`, `tester-agent`. Each
subagent starts with no memory of this conversation — give each one a
self-contained prompt with the need, the relevant repo(s), and the file
paths of anything from a previous phase it must read.

**The CTO/CEO is the human running this session.** They already gave the
need in their own words (`args`, or the message that triggered this skill).
Do not paraphrase it away — pass their actual words to the product agent.

## The one hard rule

**Stop and wait for explicit approval before starting each next phase.**
There are four phases below. After each one, post the subagent's report to
the user and ask plainly: does this look right, and do you approve moving
to the next phase? Do not proceed on silence, on a vague "ok" that reads
like acknowledgment rather than approval, or on your own judgment that it
looks fine. If the user asks for changes instead of approving, send those
changes back into the *same* phase (re-invoke the same subagent with the
feedback) — do not skip ahead. This holds even if a later phase seems
obviously fine to skip to; the point of the gate is the CTO/CEO's own
review, not just the artifact being correct.

## Phase 1 — Product (PRD + spec)

Invoke `product-agent` with: the need in the CTO/CEO's own words, and a
pointer to `PLAN.md`/`README.md` for repo context if this is the first
feature run in the session. Let it decide which repo(s) it belongs to.

Post its report to the user: repo(s), PRD requirement IDs, spec number,
objective, acceptance criteria count, open questions. **Wait for approval.**

## Phase 2 — Design (RFC + plan.md + tasks.md + estimate)

Invoke `developer-agent` in **design mode** with: the exact `specs/NNNN-slug/`
path from phase 1, and an instruction that this is design-only — no code.

Post its report: RFC change (or why none is needed), the estimate (size +
time range + top risks), task count. **Wait for approval** — this is the
CTO/CEO's chance to weigh in on scope/estimate before any code gets
written, which is the point of splitting this from implementation.

## Phase 3 — Implementation

Invoke `developer-agent` in **implement mode** with the same `specs/NNNN-slug/`
path. It works `tasks.md`, runs the repo's gate, updates `specs/README.md`.

Post its report: what got implemented, gate result (real output, not
paraphrased), tasks checked off, anything that diverged from the plan.
**Wait for approval** to move to independent testing.

## Phase 4 — Testing

Invoke `tester-agent` with the same `specs/NNNN-slug/` path. It independently
re-verifies every acceptance criterion and re-runs the full gate — it does
not take phase 3's report on faith.

Post its pass/fail table per AC, the gate result, any bug found, and its
go/no-go recommendation.

## After phase 4 — this skill's job is done

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
