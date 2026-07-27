---
name: flowspec
description: Set up, author, review, and run FlowSpec documents — declarative, engine-agnostic acceptance tests for AI-driven testing. Use when writing or running acceptance tests, setting up FlowSpec in a project, documents in .flowspec/, the .flowspec.json project config, user-journey specs, or when the user mentions FlowSpec, flows, cases, or semantic UI testing.
---

# Writing FlowSpec documents

A FlowSpec document is a single JSON object describing user journeys, never automation. The full spec lives at [spec-final.md](https://github.com/daveconstell/flowspec/blob/main/public/spec-final.md); this is the working reference.

## Commands

Invoked as `/flowspec <args>`. Match the first word; anything else is treated as a description of the journey to author.

| Invocation | Do this |
|---|---|
| `/flowspec` (no args) | Report setup state (`.flowspec.json`, `.flowspec/` documents, `targetAttribute`) and this table. Change nothing. |
| `/flowspec init` | Bootstrap: § *Before authoring*. Detect settings, write `.flowspec.json`, create `.flowspec/`, gitignore the output dir, then ask which page the first document covers. Already set up → show the config and say so, don't overwrite. |
| `/flowspec new <page or journey>` | Author a new document into `.flowspec/<name>.json`. Bootstrap first if unconfigured. Verify or add every target in the markup (§ *Targets must exist*). |
| `/flowspec @doc.json` (a file, no verb) | Review it against § *Review checklist*, then apply the fixes. |
| `/flowspec review [@doc.json]` | § *Review checklist*. No file → every document in `.flowspec/`. Report findings; apply only the unambiguous fixes. |
| `/flowspec run [@doc.json] [--url X] [--headed]` | § *Running a document* — detect the browser tooling, drive it, write results, report in exit-code terms. No file → every document in `.flowspec/`. `--url` overrides `baseUrl`; `--headed` shows the browser. |
| `/flowspec add <journey> @doc.json` | Add a flow or case to an existing document, matching the ids and evidence conventions already in it. |
| `/flowspec targets [@doc.json]` | Resolve every target against the source and list the missing ones. Read-only — no edits, no browser. |
| `/flowspec spec <topic>` | Answer from this reference (actions, assertions, edges, evidence). No files touched. |

## Before authoring: is the project set up?

`.flowspec.json` or `.flowspec/` present → read the config and author into it. Neither → bootstrap first. **Detect before asking** — most of the configuration is already sitting in the repo:

| Setting | Detect from | Ask when |
|---|---|---|
| `targetAttribute` | grep the app source for `data-constell`, `data-testid`, `data-qa`, `data-test` — the convention already in use wins | nothing is annotated yet (propose `data-constell`), or two conventions are in genuine use |
| `baseUrl` | dev server port in `vite.config.*`, `next.config.*`, `package.json` scripts, `docker-compose.yml` | no dev server is discoverable |
| `output` | — | never — default `flowspec-results` |

Then write `.flowspec.json`, create `.flowspec/`, add `flowspec-results/` to `.gitignore`, and ask which page or journey the first document should cover — one document per page or area.

## Targets must exist in the markup

A document whose targets don't resolve errors on every step, so before writing `"target": "quote-submit"`, confirm the component carries the attribute — search the source for `<targetAttribute>="quote-submit"`. If it doesn't:

- **Add it.** A one-line attribute on the component is the fix, named by role (§ Rules 1). This is the normal path — annotate as you author.
- **Or stop and list.** If the source isn't yours to edit, report the components needing annotation instead of authoring against names that don't exist.

Never invent a target you have neither verified nor added.

## Project layout

```
.flowspec.json            # project config: baseUrl, targetAttribute, output
.flowspec/
├── venue-landing.json    # one document per page or area
├── admin/users.json      # nesting allowed; id is the path minus extension
└── fixtures/             # reserved — files for upload steps, never a document
flowspec-results/         # generated, gitignored
```

Settings resolve **invocation → document → `.flowspec.json` → spec default**. Put `baseUrl` in the config file, not in documents: the origin changes between laptop, CI, and staging; the journey does not.

```json
{
  "spec": "1.0",
  "baseUrl": "http://localhost:5173",
  "targetAttribute": "data-testid",
  "output": "flowspec-results"
}
```

## Document skeleton

```json
{
  "spec": "1.0",
  "name": "Suite name",
  "variables": { "email": "john@example.com" },
  "setup":   [ { "action": "navigate", "url": "/login" } ],
  "flows": [
    {
      "id": "flow-id",
      "setup": [ { "action": "navigate", "url": "/page" } ],
      "cases": []
    }
  ],
  "cleanup": [ { "action": "clear-storage" } ]
}
```

Required: `spec`, `name`, `flows`. Flows must be independent — engines may run them in any order.

**Setup/cleanup exist at two levels**, which is how one suite covers many pages:

```
document setup → flow setup → cases → flow cleanup → document cleanup
```

Document setup holds what every flow needs (sign in, seed data); flow setup holds what only that journey needs, usually the page it starts on. A failing setup step at either level makes the flow `error`, not `failed` — a precondition problem is not a product bug.

Within a flow, `navigate` is an ordinary step, so a single journey can cross as many pages as it likes.

## Rules

1. **Targets are semantic names** carried by a data attribute: `"target": "quote-submit"` → `[data-constell="quote-submit"]`. Never CSS or XPath. Lowercase kebab-case, named by role, stable across redesigns.
   The attribute defaults to `data-constell`; set the document's top-level `targetAttribute` to match an existing convention (`data-testid`, `data-qa`, …) instead of migrating markup. One attribute per document — no fallback chains. A name matching **more than one element is an error** (except in `count`), so a target must be unique on the page — a repeated component gets indexed names (`package-card-1`) or a `count` assertion.
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
| `navigate` | `url` — absolute, or a path resolved against `baseUrl` |
| `click`, `double-click`, `hover`, `submit`, `download`, `focus`, `blur` | `target` |
| `fill` | `target`, `values` (keys = field target names) |
| `select` | `target`, `value` |
| `upload` | `target`, `file` — resolved from the project root, e.g. `.flowspec/fixtures/x.pdf` |
| `press-key` | `key` (`target` optional) |
| `wait` | `seconds` or `target` (exactly one) |
| `scroll` | `target` or `to: "top" \| "bottom"` |
| `refresh`, `back`, `forward` | — |
| `clear-storage` | — · **setup/cleanup only** — clears cookies, localStorage, sessionStorage |

All steps accept optional `description` (intent) and `timeout` (seconds, default 30).

## Assertions

| Type | Required fields |
|---|---|
| `exists`, `visible`, `hidden`, `enabled`, `disabled`, `checked`, `unchecked` | `target` |
| `count` | `target`, `expected` (number) |
| `text` | `target`, `expected` (`match`: `"contains"` default, or `"exact"`) |
| `value` | `target`, `expected` — exact equality, no `match` |
| `attribute` | `target`, `name`, `expected` |
| `url`, `title` | `expected` (`match`: `"contains"` default, or `"exact"`) |
| `console` | `level` (`"error"` default, or `"warning"`), `max` (default 0) |
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

## Running a document — you are the engine

There is no reference runner. Asked to *run* a FlowSpec, drive a browser yourself and behave like a conformant engine.

### First: find the browser tooling

**Check what's actually available before the first step** — never assume a tool is there, and never fake a run because none is.

| Tooling | Detect by | Headed / headless |
|---|---|---|
| Chrome DevTools MCP | `navigate_page`, `take_snapshot`, `list_console_messages` tools available | headed by default (drives a real Chrome); server takes `--headless` |
| Playwright MCP | `browser_navigate`, `browser_click`, `browser_snapshot` tools available | headed by default; server takes `--headless` |
| Playwright in the project | `@playwright/test` in `package.json` | `--headed` flag, else headless |
| Cypress in the project | `cypress` in `package.json` + `cypress.config.*` | `cypress open` headed · `cypress run` headless |
| Puppeteer in the project | `puppeteer` in `package.json` | headless unless `headless: false` |

Take the first that exists, in that order: MCP tooling drives a browser with no code to write, a project runner needs a script. Prefer whatever the project already uses when it has one — a Cypress shop gets a Cypress run.

**Headless by default** — faster, and it's the CI-shaped path. Go headed when the user asks to watch, when a step needs a real profile, extension, or OS-level dialog, or when you're debugging a target that won't resolve and need to see the page. State which mode you used in the report.

**Nothing available?** Say so and stop — a run you can't perform is not a passing run. Then offer the choice rather than picking for the user:

- **Chrome DevTools MCP** — best fit, since FlowSpec's evidence types map onto it directly (console, network, performance, a11y tree): `claude mcp add chrome-devtools -- npx chrome-devtools-mcp@latest`
- **Playwright MCP** — accessibility-tree driven, lighter: `claude mcp add playwright -- npx @playwright/mcp@latest`
- **A project runner** — `npm i -D @playwright/test && npx playwright install chromium`, if the team wants the run reproducible in CI without an agent.

### Then: behave like an engine

- Per flow: `document setup → flow setup → cases → flow cleanup → document cleanup`. Cleanup runs even when the flow failed; a cleanup failure is reported but doesn't change the result.
- Resolve every target as `[<targetAttribute>="name"]`. When it doesn't resolve, that's a **target error** — never substitute a CSS selector, a text match, or a best guess. Silent improvisation is how a green run hides broken markup.
- Run a case's steps in order, then evaluate **all** its assertions even after one fails. A failed step is `error` and skips the rest of the case; a failed assertion is `failed`.
- Stop the flow at the first non-passing case unless an `edges` path covers that outcome.
- Capture `screenshot` + `console` on any failure, plus whatever `evidence` declares.
- Write results to the configured output in the layout below, overwriting the previous run, and report the outcome in exit-code terms: `0` passed · `1` a flow failed · `2` a flow errored or the document was invalid.

### Finally: report the results in full

Writing `report.json` is not reporting. **Every run ends with the detailed results in your reply**, whether it passed or failed — the user should never have to open a file to learn what happened. Read it back the way the report reads (flow and case `name`, the failing assertion's `description`), never as a narration of clicks.

```
venue-landing · 2 flows · 7 cases — FAILED (exit 1) · headless Chrome · 24.1s

✓ request-quote — Quote requests (4 cases, 11.3s)
    ✓ open-form         Form is reachable                          1.2s
    ✓ fill-details      Enter the visitor's contact details         3.1s
    ✓ submit            Send the quote request                     5.8s
    ✓ confirm           The confirmation banner appears            1.2s

✗ validate-email — Rejects a malformed address (3 cases, 12.8s)
    ✓ open-form         Form is reachable                          1.1s
    ✗ submit-invalid    Submitting a bad email is refused          9.4s
        assertion 2/3 · visible · target: email-error
        expected: The inline validation message appears
        actual:   no element matched [data-constell="email-error"] after 5s
        also failed: text · error-summary — expected "check the highlighted field"
        passed:   url — still on /quote
        console:  1 error — TypeError: v.email is undefined (quote.js:88)
        evidence: evidence/validate-email/submit-invalid/{screenshot.png,console.log}
    ⊘ recover           skipped — flow stopped at the first failure

Results → flowspec-results/report.json
```

The shape is a guide, not a format — adapt it to the run. What must be there every time:

- **A one-line verdict**: document, counts, outcome + exit code, browser mode, duration. Never bury the result.
- **Every case, including passing ones**, under its flow, with its `name` or `description` and duration — a run that only lists failures hides what was never exercised.
- **For each failure, enough to act without re-running**: which assertion (`n/m`, its type and target), expected vs. actual as the engine saw it, the *other* assertions in that case and how each fared (they're all evaluated), any console errors, and the relative evidence paths.
- **`error` distinguished from `failed`**, in those words: an unresolved target or a timed-out step is a broken run, an assertion that came back false is a product bug. Say which, and for a target error name the attribute and value that found nothing so the fix is a one-line markup change.
- **Skipped cases listed with why** — `flow stopped at the first failure`, or `precondition failed in setup`.
- **Setup/cleanup outcomes** when either misbehaved: a failed setup makes the flow `error` and is usually the whole story; a failed cleanup is reported but changes no result.

Then, at most a couple of lines on what to do next — the likely cause and the one file to look at. Not a fix applied unasked, and no green-washing: if you couldn't run a flow, say it was not run rather than folding it into the pass count.

## Where results land

Runs write to `flowspec-results/` (overridable), overwriting the previous run:

```
flowspec-results/
├── report.json                 # nested run → flows → cases → steps + assertions
├── report.xml                  # optional JUnit, for CI
└── evidence/<flow-id>/<case-id>/screenshot.png
```

When a run covers several documents, results nest per document id, mirroring the `.flowspec/` tree — `flowspec-results/admin/users/report.json` — with a run-level summary at the root.

- Evidence paths in `report.json` are **relative** to the results directory, so the whole folder zips and uploads as a self-contained bundle.
- A case's stable identity across runs is `<flow-id>/<case-id>` — use it to correlate flaky results.
- Exit codes: `0` passed · `1` a flow failed (product bug) · `2` a flow errored or the document was invalid (broken run).

## Review checklist

- `spec` and `name` present; every flow/case has a unique kebab-case `id`.
- Every `target` exists in the markup under the document's `targetAttribute`, and matches exactly one element.
- No CSS selectors or XPath anywhere in `target`.
- Every `{{variable}}` is declared in `variables`.
- `edges` reference existing case ids; no cycles; branching edges carry a `label`.
- Negative paths (validation errors) modeled as `when: "failed"` edges, not as expected-to-fail assertions.
- Assertion descriptions read as expectations (*"The confirmation banner appears"*), not restatements of the type (*"visible success-message"*).
- No `description` explains *how* — if it mentions pixels, selectors, or key sequences, rewrite it as intent.
- No environment-specific origin committed in a document — `baseUrl` belongs in `.flowspec.json` or the invocation.
- Flows that start on different pages navigate in their own `setup`, not in a first case.
