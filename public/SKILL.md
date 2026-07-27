---
name: flowspec
description: Author and review FlowSpec documents — declarative, engine-agnostic acceptance tests for AI-driven testing. Use when writing acceptance tests, .flowspec.json files, user-journey specs, or when the user mentions FlowSpec, flows, cases, or semantic UI testing.
---

# Writing FlowSpec documents

A FlowSpec document is a single JSON object (`.flowspec.json`) describing user journeys, never automation. The full spec lives at `/spec-final.md`; this is the working reference.

## Document skeleton

```json
{
  "spec": "1.0",
  "name": "Suite name",
  "variables": { "email": "john@example.com" },
  "setup":   [ { "action": "navigate", "url": "/page" } ],
  "flows":   [ { "id": "flow-id", "cases": [] } ],
  "cleanup": [ { "action": "clear-storage" } ]
}
```

Required: `spec`, `name`, `flows`. Setup/cleanup run before/after **each** flow; flows must be independent.

## Rules

1. **Targets are semantic names**, matching `data-constell` attributes: `"target": "quote-submit"` → `[data-constell="quote-submit"]`. Never CSS or XPath. Lowercase kebab-case, named by role, stable across redesigns.
2. **Variables** interpolate with `{{name}}`. Referencing an undefined variable fails at load.
3. **Cases run in array order** (linear chain) unless the flow declares `edges`. Execution stops at the first non-passing case; the rest are `skipped`.
4. **Branching:** `{ "from": "submit", "to": "validation-error", "when": "failed" }` — a `when: "failed"` edge makes the failure *expected*; if that path passes, the flow passes. Graph must be acyclic.
5. **All assertions in a case are evaluated** even after one fails. A step failure (missing target, timeout) is an `error` and skips the rest of the case.
6. **Evidence** (`screenshot`, `dom`, `html`, `a11y-tree`, `network`, `console`, `reasoning`, `performance`): document-level default, case-level override. Screenshots + console are always captured on failure automatically — don't declare evidence just for that.

## Actions

| Action | Required fields |
|---|---|
| `navigate` | `url` |
| `click`, `double-click`, `hover`, `submit`, `download`, `focus`, `blur` | `target` |
| `fill` | `target`, `values` (keys = field target names) |
| `select` | `target`, `value` |
| `upload` | `target`, `file` |
| `press-key` | `key` (`target` optional) |
| `wait` | `seconds` or `target` (exactly one) |
| `scroll` | `target` or `to: "top" \| "bottom"` |
| `refresh`, `back`, `forward` | — |

All steps accept optional `timeout` (seconds, default 30).

## Assertions

| Type | Required fields |
|---|---|
| `exists`, `visible`, `hidden`, `enabled`, `disabled`, `checked`, `unchecked` | `target` |
| `count` | `target`, `expected` (number) |
| `text`, `value` | `target`, `expected` (`match`: `"contains"` default, or `"exact"`) |
| `attribute` | `target`, `name`, `expected` |
| `url`, `title` | `expected` |
| `console` | `level` (default `"error"`), `max` (default 0) |
| `network` | `status: "no-errors"` or `url` + `expected` |
| `performance` | `metric` (e.g. `"lcp"`), `max` (ms) |
| `accessibility` | optional `target`, `standard` (default `"wcag2aa"`) |

Assertions accept optional `timeout` (retry-until, default 5s).

## Minimal complete case

```json
{
  "id": "submit",
  "steps": [
    { "action": "fill", "target": "quote-form",
      "values": { "quote-name": "{{customerName}}", "quote-email": "{{email}}" } },
    { "action": "submit", "target": "quote-form" }
  ],
  "assertions": [
    { "type": "visible", "target": "success-message" },
    { "type": "console", "level": "error", "max": 0 }
  ]
}
```

## Review checklist

- `spec` and `name` present; every flow/case has a unique kebab-case `id`.
- No CSS selectors or XPath anywhere in `target`.
- Every `{{variable}}` is declared in `variables`.
- `edges` reference existing case ids; no cycles.
- Negative paths (validation errors) modeled as `when: "failed"` edges, not as expected-to-fail assertions.
