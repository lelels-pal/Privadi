---
name: memory
description: Persistent cross-thread findings memory for any project. Use when Codex needs to recall past review findings, release blockers, audit notes, or follow-up work for the current repo; when a user asks what is still open; when a new review should be stored for later; or when a completed fix should automatically update a finding from open to resolved.
---

# Memory

Store and maintain a persistent findings ledger across threads. The ledger is keyed by the current project root, so the same repository can be recalled without the user re-pasting old review output.

Read [references/schema.md](references/schema.md) before changing the ledger format or statuses.

By default, the ledger lives inside the current repo at `.codex-memory/findings.json`. The skill is global; the data is project-local so it remains writable from sandboxed threads.

## Quick Start

Run the script from the current repo so the project root is inferred automatically:

```bash
python3 /Users/leopallorina/.codex/skills/memory/scripts/manage_findings.py summary
```

## Workflow

1. On any request about previous blockers, open issues, or release readiness for the current repo, run:

```bash
python3 /Users/leopallorina/.codex/skills/memory/scripts/manage_findings.py summary
```

2. When producing a new review, store the findings before finishing the turn:

```bash
python3 /Users/leopallorina/.codex/skills/memory/scripts/manage_findings.py upsert \
  --project-label "<repo-name>" \
  --id "1" \
  --severity "P0" \
  --title "Short finding title" \
  --details "Concrete explanation of the risk and what is missing." \
  --ref "/abs/path/File.swift#L123" \
  --source "2026-03-24 release review"
```

3. When a tracked finding is fixed in the same turn, mark it resolved before the final response:

```bash
python3 /Users/leopallorina/.codex/skills/memory/scripts/manage_findings.py resolve \
  --id "1" \
  --note "Implemented the cleanup flow and verified with tests."
```

4. When a later review shows the issue still exists or regressed, reopen it:

```bash
python3 /Users/leopallorina/.codex/skills/memory/scripts/manage_findings.py reopen \
  --id "1" \
  --note "Flow still missing on iPhone build."
```

## Rules

- Treat this skill as the source of truth for cross-thread findings memory.
- Update the ledger as part of the task. Do not leave it stale after landing a fix or completing a review.
- Use the current working directory as the project identity unless the user explicitly asks to target a different repo.
- Use the default project-local ledger unless the user explicitly asks for a custom `--db-path`.
- Keep finding IDs stable when possible so users can say "fix finding 1" and get a deterministic update.
- Preserve prior details and resolution notes; append state changes instead of deleting history.
- Be explicit that updates are automatic only when this skill is in use during the task. This skill is not a background watcher.

## Resources

### scripts/manage_findings.py

Use this to summarize, add, resolve, and reopen findings in the persistent ledger.

### references/schema.md

Use this for the allowed statuses, severity conventions, and ledger shape.
