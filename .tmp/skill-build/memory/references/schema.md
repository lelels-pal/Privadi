# Findings Ledger Schema

## Purpose

Persist review findings across threads by project root.

## Project Key

- Use the resolved current working directory as the project key.
- Store a human-friendly `project_label` separately.
- Store the ledger at `<project-root>/.codex-memory/findings.json` by default.

## Finding Fields

- `id`: Stable user-facing identifier such as `1`, `2`, or `security-1`
- `severity`: `P0`, `P1`, `P2`, or `P3`
- `title`: Short summary
- `details`: Full explanation
- `status`: `open`, `resolved`, `accepted`, or `blocked`
- `refs`: Absolute file references or other concrete pointers
- `source`: Where the finding came from
- `created_at`
- `updated_at`
- `resolved_at`
- `resolution_note`
- `history`: Append-only event log

## Update Rules

- `upsert` creates or refreshes a finding and preserves `created_at`.
- `resolve` sets `status=resolved`, updates `resolved_at`, and appends a history event.
- `reopen` sets `status=open`, clears `resolved_at`, and appends a history event.
- Never delete findings unless the user explicitly asks.
