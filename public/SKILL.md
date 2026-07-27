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
4. **Branching:** `{ "from": "submit", "to": "validation-error", "when": "failed", "label": "invalid email" }` — a `when: "failed"` edge makes the failure *expected*; if that path passes, the flow passes. `label` is what diagrams show. Graph must be acyclic.
5. **All assertions in a case are evaluated** even after one fails. A step failure (missing target, timeout) is an `error` and skips the rest of the case.
6. **Evidence** (`screenshot`, `dom`, `html`, `a11y-tree`, `network`, `console`, `reasoning`, `performance`): document-level default, case-level override. Screenshots + console are always captured on failure automatically — don't declare evidence just for that.
7. **Describe intent, never mechanics.** `description` is optional on cases, steps, and assertions, and it becomes the failure message in reports — write it so someone who has never read the spec understands the failure. `"Dismiss the cookie banner"` ✅ · `"scroll 200px then click the blue button"` ❌ (that's the engine's job).

## Naming and describing

| Level | `name` | `description` |
|---|---|---|
| Document | **required** | optional |
| Flow | optional | optional |
| Case | optional | optional |
| Step | — | optional — intent, used in reports and as an AI disambiguation hint |
| Assertion | — | optional — the expectation, used as the failure message |
| Edge | — | `label`: human-readable branch condition for diagrams |

Names default to `id` when absent. Engines carry names and descriptions through into the report, so a failure reads *"The confirmation banner appears — failed"* instead of `visible: success-message`.

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

All steps accept optional `description` (intent) and `timeout` (seconds, default 30).

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

Assertions accept optional `description` (failure message) and `timeout` (retry-until, default 5s).

## Minimal complete case

```json
{
  "id": "submit",
  "name": "Submit Quote",
  "description": "Valid details produce a confirmation and no console errors.",
  "steps": [
    { "action": "fill", "target": "quote-form",
      "description": "Enter the visitor's contact details",
      "values": { "quote-name": "{{customerName}}", "quote-email": "{{email}}" } },
    { "action": "submit", "target": "quote-form",
      "description": "Send the quote request" }
  ],
  "assertions": [
    { "type": "visible", "target": "success-message",
      "description": "The confirmation banner appears" },
    { "type": "console", "level": "error", "max": 0,
      "description": "No console errors during submission" }
  ]
}
```

## Where results land

Runs write to `flowspec-results/` (overridable), overwriting the previous run:

```
flowspec-results/
├── report.json                 # nested run → flows → cases → steps + assertions
├── report.xml                  # optional JUnit, for CI
└── evidence/<flow-id>/<case-id>/screenshot.png
```

- Evidence paths in `report.json` are **relative** to the results directory, so the whole folder zips and uploads as a self-contained bundle.
- A case's stable identity across runs is `<flow-id>/<case-id>` — use it to correlate flaky results.
- Exit codes: `0` passed · `1` a flow failed (product bug) · `2` a flow errored or the document was invalid (broken run).

## Review checklist

- `spec` and `name` present; every flow/case has a unique kebab-case `id`.
- No CSS selectors or XPath anywhere in `target`.
- Every `{{variable}}` is declared in `variables`.
- `edges` reference existing case ids; no cycles; branching edges carry a `label`.
- Negative paths (validation errors) modeled as `when: "failed"` edges, not as expected-to-fail assertions.
- Assertion descriptions read as expectations (*"The confirmation banner appears"*), not restatements of the type (*"visible success-message"*).
- No `description` explains *how* — if it mentions pixels, selectors, or key sequences, rewrite it as intent.
