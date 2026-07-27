# FlowSpec Language Specification

**Status:** Draft
**Spec version:** 1.0
**Authors:** Constell
**Category:** AI Acceptance Testing Specification

---

## 1. Introduction

FlowSpec is a declarative specification language for AI-driven acceptance testing.

A FlowSpec document does **not** describe browser automation. It describes:

- user journeys (**Flows**)
- logical checkpoints within a journey (**Cases**)
- semantic user interactions (**Steps**)
- expected outcomes (**Assertions**)
- artifacts to capture (**Evidence**)

An **execution engine** — an AI browser agent, a Playwright adapter, a Selenium adapter, a mobile agent — consumes the document and decides *how* to perform the actions. FlowSpec is to AI acceptance testing what OpenAPI is to REST APIs: a framework-independent source of truth for expected behavior that developers, QA engineers, and AI agents all share.

### 1.1 Design principles

| Principle | Meaning |
|---|---|
| **Declarative** | Describes *what* should happen, never *how*. |
| **Semantic** | Targets are stable component names carried by a data attribute, never CSS selectors or XPath. |
| **Human readable** | A QA engineer can read and write a FlowSpec without programming knowledge. |
| **AI readable** | An LLM can execute a FlowSpec without additional prompting. |
| **Engine agnostic** | The same document runs on any conformant engine. |
| **Versioned** | Every document declares the spec version it targets. |

---

## 2. Conformance

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are to be interpreted as described in RFC 2119.

An implementation is a **conformant execution engine** if it:

1. accepts any valid FlowSpec 1.0 document,
2. executes the lifecycle defined in §12,
3. resolves targets as defined in §6,
4. supports all built-in actions (§7) and assertion types (§8), and
5. produces a report as defined in §13, written as defined in §14.

An engine that encounters an unknown action or assertion type **MUST** fail the containing case with status `error` — it **MUST NOT** silently skip it.

---

## 3. Document format

A FlowSpec document is a single JSON object (UTF-8). Documents live as plain `.json` files inside the `.flowspec/` directory (§3.2). The bare filename `.flowspec.json` is reserved for project configuration (§3.3) and is never a document.

### 3.1 Top-level structure

```json
{
  "spec": "1.0",
  "name": "Venue Landing Page",
  "description": "Acceptance tests for the venue landing page.",
  "version": "1.0.0",
  "author": "Constell",
  "tags": ["smoke", "production"],
  "baseUrl": "https://example.com",
  "targetAttribute": "data-constell",
  "variables": {},
  "setup": [],
  "flows": [],
  "cleanup": []
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `spec` | string | **yes** | FlowSpec version this document targets. `"1.0"`. |
| `name` | string | **yes** | Human-readable suite name. |
| `flows` | Flow[] | **yes** | One or more flows (§10). |
| `description` | string | no | What this suite covers. |
| `version` | string | no | Document version (semver recommended). |
| `author` | string | no | Author or team. |
| `tags` | string[] | no | Labels for filtering (`smoke`, `regression`, …). |
| `baseUrl` | string | no | Origin that relative `navigate` URLs resolve against (§7.4). |
| `targetAttribute` | string | no | HTML attribute that carries component names. Default `data-constell` (§6.1). |
| `variables` | object | no | Reusable values (§5). |
| `setup` | Step[] | no | Runs before **each** flow (§11). |
| `cleanup` | Step[] | no | Runs after **each** flow (§11). |
| `evidence` | string[] | no | Default evidence for all cases (§9). |

Engines **MUST** reject a document whose `spec` major version they do not support.

### 3.2 Project layout

A project keeps its documents in a `.flowspec/` directory alongside an optional `.flowspec.json` configuration file:

```
your-project/
├── .flowspec.json              # project configuration (optional)
├── .flowspec/
│   ├── venue-landing.json      # one document per page or area
│   ├── checkout.json
│   ├── admin/
│   │   └── users.json          # nesting is allowed
│   └── fixtures/               # reserved: files used by upload steps
│       └── floor-plan.pdf
└── flowspec-results/           # generated output — do not commit (§14)
```

The directory holds **source only**: the documents themselves and the fixtures they reference. Generated output never goes here — results are written to a separate directory (§14) that is safe to delete, whereas `.flowspec/` is committed alongside the application it describes.

- Runners **SHOULD** discover documents by globbing `.flowspec/**/*.json` when no explicit path is given, and **MUST** accept explicit paths so a single document can be run on its own.
- A document's **id** is its path relative to `.flowspec/` without the extension — `venue-landing`, `admin/users`. Ids are unique by construction, and they key the per-document results directories of §14.2.
- `.flowspec/fixtures/` is **reserved** and **MUST** be excluded from document discovery, so that a `.json` fixture is never mistaken for a document. Engines **MUST NOT** infer document-ness from a file's contents: a malformed document must fail loudly rather than be silently skipped as "not a document".
- Documents inside `.flowspec/` use a plain `.json` extension. A document kept elsewhere **SHOULD** use `.flowspec.json` as a suffix (`smoke.flowspec.json`) so it is recognisable; note this is a suffix on a named file, distinct from the bare `.flowspec.json` configuration file.

Nothing here is mandatory: a lone document file remains a valid, runnable FlowSpec.

### 3.3 Configuration

`.flowspec.json` holds what belongs to the **project and its environment** rather than to any one journey:

```json
{
  "spec": "1.0",
  "baseUrl": "http://localhost:5173",
  "targetAttribute": "data-testid",
  "include": [".flowspec/**/*.json"],
  "output": "flowspec-results",
  "evidence": ["screenshot", "console"]
}
```

| Field | Type | Description |
|---|---|---|
| `spec` | string | FlowSpec version the project targets. |
| `baseUrl` | string | Origin relative `navigate` URLs resolve against (§7.4). |
| `targetAttribute` | string | Attribute carrying component names (§6.1). |
| `include` | string[] | Globs identifying documents. Default `[".flowspec/**/*.json"]`. |
| `output` | string | Results directory (§14.1). Default `flowspec-results`. |
| `evidence` | string[] | Default evidence for every case (§9). |

Keeping `baseUrl` here is the point of the file: the origin differs between a laptop, CI, and staging, while the journeys do not. Committing an environment into a document couples the two; committing it into configuration — or overriding it at invocation — does not.

### 3.4 Resolution order

Where a setting can appear in more than one place, the **most specific wins**:

```
invocation (CLI flag, env)  →  document  →  .flowspec.json  →  spec default
```

- A document **MAY** override `baseUrl`, `targetAttribute`, and `evidence` when a particular suite genuinely differs — an admin subdomain, a legacy area with its own attribute convention.
- Engines **MUST** apply this order and **MUST** report the effective values in the run report, so a surprising result can be traced to the setting that produced it.

---

## 4. Metadata

The metadata fields (`spec`, `name`, `description`, `version`, `author`, `tags`) live at the top level of the document as shown in §3.1. Only `spec` and `name` are required. Everything else exists for humans and tooling — engines **MUST NOT** change behavior based on `tags`, though runners **MAY** use them to select which documents to execute.

---

## 5. Variables

`variables` is a flat map of names to string values.

```json
{
  "variables": {
    "customerName": "John Doe",
    "email": "john@example.com",
    "venue": "Birthday"
  }
}
```

### 5.1 Interpolation

Any string value in the document may reference a variable with `{{name}}`:

```json
{ "action": "fill", "target": "quote-name", "values": { "name": "{{customerName}}" } }
```

- Interpolation is plain string substitution; whitespace inside braces is ignored (`{{ email }}` ≡ `{{email}}`).
- Referencing an undefined variable is an **error**: the engine **MUST** fail document loading, before any execution.
- Engines **MAY** allow variables to be overridden at invocation time (CLI flags, environment). Overrides replace the document value; they cannot introduce names the document does not declare.

---

## 6. Targets

A **target** is the stable, semantic name of a UI component. Targets decouple the spec from markup: names survive redesigns; selectors do not.

Components under test declare their name with a **target attribute**:

```html
<button data-constell="quote-submit">Request a quote</button>
```

FlowSpec references it by name only:

```json
{ "action": "click", "target": "quote-submit" }
```

### 6.1 The target attribute

The attribute name is a property of the application under test, not of the journey being described, so documents declare it once at the top level:

```json
{
  "spec": "1.0",
  "name": "Venue Landing Page",
  "targetAttribute": "data-testid"
}
```

| | |
|---|---|
| **Field** | `targetAttribute` (string, optional) |
| **Default** | `data-constell` |
| **Constraint** | **MUST** be a valid HTML attribute name matching `^[A-Za-z][A-Za-z0-9_.:-]*$`. Engines **MUST** reject an invalid value at load time. |

Rules:

- Teams already using `data-testid`, `data-qa`, `data-test`, or a house convention adopt FlowSpec by declaring it — no markup migration required.
- A custom attribute **SHOULD** be `data-*` prefixed, so it stays a valid HTML5 custom attribute.
- Exactly one attribute applies per document. Fallback chains are deliberately excluded: two ways to name the same component is how a test suite starts drifting from its markup.
- Engines **MAY** allow the value to be overridden at invocation time (CLI flag, config), which takes precedence over the document. This mirrors variable overrides (§5) and lets one document run against environments whose markup differs.
- The attribute name is meaningless to non-DOM engines (§6.2), which ignore it.

### 6.2 Resolution

- DOM-based engines **MUST** resolve `target: "X"` to `[<targetAttribute>="X"]` — by default `[data-constell="X"]`.
- Non-DOM engines (mobile, desktop) **MUST** map the same names onto their platform's semantic identifiers (e.g. accessibility IDs), ignoring `targetAttribute`.
- If a target resolves to zero elements, the step or assertion referencing it fails.
- If a target resolves to multiple elements, engines **MUST** fail with an ambiguity error unless the assertion is `count` (§8), which operates on the full match set.

### 6.3 Naming convention

Names **SHOULD** be lowercase kebab-case, describe the component's *role* rather than its appearance, and remain stable across UI redesigns:

```
hero  gallery  package-list  package-card  package-price
quote-form  quote-name  quote-email  quote-submit
success-message  faq  footer
```

---

## 7. Steps

A **Step** is a single user interaction. Steps run in array order.

```json
{ "action": "click", "target": "quote-submit" }
```

| Field | Type | Required | Description |
|---|---|---|---|
| `action` | string | **yes** | One of the built-in actions below. |
| `target` | string | see below | Target name (§6). |
| `description` | string | no | Intent of the step, in plain language (§7.3). |
| `timeout` | number | no | Seconds to wait for the step to become possible. Default: engine-defined, **SHOULD** be 30. |
| *(action-specific)* | | | Additional fields per action. |

### 7.1 Built-in actions

| Action | `target` | Additional fields | Description |
|---|---|---|---|
| `navigate` | — | `url` (string, required) | Go to a URL. Relative URLs resolve against `baseUrl` (§7.4). |
| `click` | required | — | Click/tap the component. |
| `double-click` | required | — | Double-click the component. |
| `fill` | required | `values` (object, required) | Fill a form or field; see §7.2. |
| `select` | required | `value` (string, required) | Choose an option by visible label or value. |
| `hover` | required | — | Hover over the component. |
| `scroll` | optional | `to` (`"top"` \| `"bottom"`, default per target) | Scroll the target into view, or the page if no target. |
| `wait` | optional | `seconds` (number) — exactly one of `seconds`/`target` | Pause, or wait for target to become visible. |
| `upload` | required | `file` (string, required) | Attach a file by path, resolved per §7.5. |
| `download` | required | — | Trigger and await a download from the component. |
| `submit` | required | — | Submit the form component. |
| `refresh` | — | — | Reload the page. |
| `back` | — | — | Browser history back. |
| `forward` | — | — | Browser history forward. |
| `press-key` | optional | `key` (string, required) | Press a key (e.g. `"Enter"`, `"Escape"`), on the target if given. |
| `focus` | required | — | Focus the component. |
| `blur` | required | — | Remove focus from the component. |

AI-agent engines **MAY** fulfil an action through equivalent means (e.g. keyboard-driven form fill), provided the user-observable outcome is the same.

### 7.2 Fill

`fill` targets either a single field or a form component. When targeting a form, `values` keys are the target names of fields *within* it:

```json
{
  "action": "fill",
  "target": "quote-form",
  "values": {
    "quote-name": "{{customerName}}",
    "quote-email": "{{email}}"
  }
}
```

### 7.3 Step description

`description` states the step's **intent**, never its mechanics:

```json
{ "action": "click", "target": "cookie-accept", "description": "Dismiss the cookie banner" }
```

It serves two purposes: it appears in reports so a failure reads *"Dismiss the cookie banner — timed out"* rather than `click cookie-accept`, and AI engines **MAY** use it as a disambiguation hint when a target is genuinely ambiguous.

Engines **MUST NOT** change target resolution (§6) based on `description`, and authors **MUST NOT** use it to describe *how* to perform the action ("scroll down 200px, then click the blue button"). A description that explains mechanics is a spec smell — the mechanics belong to the engine.

### 7.4 URLs and multi-page journeys

`navigate` accepts either an absolute URL or a path. Paths resolve against the document's `baseUrl`:

```json
{
  "baseUrl": "https://example.com",
  "setup": [ { "action": "navigate", "url": "/birthday" } ]
}
```

- If `baseUrl` is absent, engines **MUST** require one at invocation and **MUST** reject the document at load time if neither is supplied and any `navigate` uses a relative URL.
- Engines **MUST** allow `baseUrl` to be overridden at invocation, so the same document runs against local, staging, and production. Environment-specific origins **SHOULD NOT** be hardcoded into a committed document.
- Absolute URLs bypass `baseUrl` entirely — use them for third-party pages (payment providers, identity providers) that a journey legitimately passes through.

**A journey may span any number of pages.** `navigate` is an ordinary step, so a flow can cross pages freely, and each case can assert against whichever page it lands on:

```json
{
  "id": "browse-then-quote",
  "cases": [
    {
      "id": "open-packages",
      "steps": [ { "action": "navigate", "url": "/packages" } ],
      "assertions": [ { "type": "visible", "target": "package-list" } ]
    },
    {
      "id": "open-venue",
      "steps": [ { "action": "click", "target": "package-card" } ],
      "assertions": [ { "type": "url", "expected": "/packages/", "match": "contains" } ]
    }
  ]
}
```

When *different flows* start on different pages, put the navigation in each flow's own `setup` rather than in a case (§11) — arriving at the starting page is a precondition, not part of the journey being tested.

### 7.5 File paths

The `file` path of an `upload` step resolves against the **project root** — the directory containing `.flowspec/`, or the working directory for a standalone document:

```json
{ "action": "upload", "target": "brochure-input", "file": ".flowspec/fixtures/floor-plan.pdf" }
```

- Paths **MUST NOT** be resolved relative to the document, so a nested document (`admin/users.json`) references fixtures the same way a top-level one does, with no `../` climbing.
- Absolute paths are permitted but **SHOULD NOT** be committed: they break on every other machine.
- Engines **MUST** fail the step with `error` if the file does not exist, and **SHOULD** validate declared upload paths at load time so a missing fixture is caught before a browser starts.

---

## 8. Assertions

Assertions validate expected outcomes after a case's steps complete.

```json
{ "type": "visible", "target": "success-message" }
```

| Type | `target` | Additional fields | Passes when |
|---|---|---|---|
| `exists` | required | — | Target resolves to at least one element. |
| `visible` | required | — | Target exists and is visible. |
| `hidden` | required | — | Target does not exist or is not visible. |
| `enabled` | required | — | Target is interactable. |
| `disabled` | required | — | Target is not interactable. |
| `checked` | required | — | Checkbox/radio is checked. |
| `unchecked` | required | — | Checkbox/radio is not checked. |
| `count` | required | `expected` (number, required) | Number of matching elements equals `expected`. |
| `text` | required | `expected` (string, required), `match` (`"exact"` \| `"contains"`, default `"contains"`) | Target's visible text matches. |
| `value` | required | `expected` (string, required) | Form field's value equals `expected`. |
| `attribute` | required | `name` (string, required), `expected` (string, required) | Attribute `name` equals `expected`. |
| `url` | — | `expected` (string, required), `match` (as `text`) | Current URL matches. |
| `title` | — | `expected` (string, required), `match` (as `text`) | Page title matches. |
| `console` | — | `level` (`"error"` \| `"warning"`, default `"error"`), `max` (number, default `0`) | At most `max` console entries at `level` since case start. |
| `network` | — | `status` (`"no-errors"`), or `url` + `expected` status code | No failed requests, or a specific request returned the expected status. |
| `performance` | — | `metric` (string, e.g. `"lcp"`), `max` (number, ms) | The metric is at or below `max`. |
| `accessibility` | optional | `standard` (string, default `"wcag2aa"`) | No violations at the given standard, scoped to target or page. |

Every assertion also accepts:

| Field | Type | Required | Description |
|---|---|---|---|
| `description` | string | no | The expectation in plain language, used as the failure message. |
| `timeout` | number | no | Seconds to retry until the assertion holds. Default: engine-defined, **SHOULD** be 5. |

`description` is what makes a report readable by someone who has not read the spec:

```json
{ "type": "visible", "target": "success-message", "description": "The confirmation banner appears" }
```

Engines **SHOULD** use `description` as the failure message when present, falling back to a generated one (`visible: success-message`) when absent.

All assertions in a case **MUST** be evaluated even if an earlier one fails, so a report shows every failed expectation, not just the first.

---

## 9. Evidence

Evidence is the set of artifacts captured when a case finishes.

| Value | Artifact |
|---|---|
| `screenshot` | Full-page screenshot. |
| `dom` | Serialized DOM snapshot. |
| `html` | Raw page HTML. |
| `a11y-tree` | Accessibility tree. |
| `network` | Network log since case start. |
| `console` | Console log since case start. |
| `reasoning` | AI agent's reasoning trace (AI engines only; others **MAY** omit). |
| `performance` | Performance metrics. |
| `timing` | Case execution time. |

Rules:

- `evidence` may be declared at document level (default for every case) and at case level (replaces the document default for that case).
- On any case **failure or error**, engines **MUST** capture at least `screenshot` and `console`, regardless of declared evidence.
- `timing` is always captured; declaring it is unnecessary.

```json
{ "evidence": ["screenshot", "dom", "console"] }
```

---

## 10. Flows and Cases

### 10.1 Flow

A **Flow** is a complete user journey — *Request Quote*, *Download Brochure*, *Book Appointment*.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | **yes** | Unique within the document. Kebab-case recommended. |
| `name` | string | no | Human-readable name. Defaults to `id`. |
| `description` | string | no | What the journey covers. |
| `cases` | Case[] | **yes** | The flow's checkpoints. |
| `edges` | Edge[] | no | Explicit graph structure (§10.3). |
| `setup` | Step[] | no | Preconditions for this flow only, after document setup (§11). |
| `cleanup` | Step[] | no | Teardown for this flow only, before document cleanup (§11). |

### 10.2 Case

A **Case** is a logical checkpoint within a flow: a group of steps plus the assertions that must hold afterward.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | **yes** | Unique within the flow. |
| `name` | string | no | Human-readable name. Defaults to `id`. |
| `description` | string | no | What this checkpoint verifies and why. |
| `steps` | Step[] | no | Interactions, in order. |
| `assertions` | Assertion[] | no | Evaluated after all steps. |
| `evidence` | string[] | no | Overrides the document default (§9). |

A case's **outcome** is:

- `passed` — all steps executed and all assertions held
- `failed` — steps executed but at least one assertion failed
- `error` — a step could not be executed (target missing, timeout, unknown action)
- `skipped` — never reached (§10.3)

### 10.3 Graph model

A flow is a directed graph: cases are the **nodes**, and `edges` define the paths between them.

**Linear flows (the common case).** When `edges` is omitted, the cases array defines an implicit linear chain: each case leads to the next, and execution stops at the first case that does not pass — subsequent cases are `skipped`.

**Branching flows.** `edges` declares transitions explicitly:

| Field | Type | Required | Description |
|---|---|---|---|
| `from` | string | **yes** | Source case `id`. |
| `to` | string | **yes** | Destination case `id`. |
| `when` | `"passed"` \| `"failed"` | no | Follow this edge only on the given outcome of `from`. Default: `"passed"`. |
| `label` | string | no | Human-readable branch condition, used when rendering the graph (§10.4). |

```json
{
  "edges": [
    { "from": "submit", "to": "success", "when": "passed", "label": "valid details" },
    { "from": "submit", "to": "validation-error", "when": "failed", "label": "invalid email" }
  ]
}
```

`when` describes the *mechanism* (which outcome routes here); `label` describes the *meaning* (why the journey branches). Diagrams read far better with the latter.

Rules:

- When `edges` is present, execution starts at the first case in `cases` and follows edges by outcome. Cases never reached are `skipped`.
- A `when: "failed"` edge makes the failure *expected*: if the failure path completes and passes, the flow **passes**. This is how negative paths (validation errors, empty states) are tested.
- An `error` outcome follows no edges; the flow ends immediately with status `error`.
- The graph **MUST** be acyclic, and every edge **MUST** reference existing case ids. Engines **MUST** validate this at load time.

### 10.4 Mermaid rendering

Because a flow is a directed graph, tooling can render it mechanically — one Mermaid edge per FlowSpec edge (or per implicit linear link):

```mermaid
flowchart TD
  open-form --> fill
  fill --> submit
  submit -->|valid details| success
  submit -->|invalid email| validation-error
```

Rendering rules for generators:

- Node labels **SHOULD** use each case's `name`, falling back to `id`.
- When a node has more than one outgoing edge, generators **SHOULD** label those edges with the edge's `label`, falling back to its `when` value.
- Single outgoing edges **SHOULD** be left unlabeled.

---

## 11. Setup and Cleanup

`setup` and `cleanup` are step arrays that establish and tear down the preconditions a flow needs. Both may be declared at two levels:

| Level | `setup` runs | `cleanup` runs |
|---|---|---|
| **Document** | before **every** flow | after **every** flow |
| **Flow** | before that flow only, immediately after document setup | after that flow only, immediately before document cleanup |

Order around each flow is therefore:

```
document setup → flow setup → cases → flow cleanup → document cleanup
```

Two levels exist because suites that span multiple pages need to share some preconditions while differing in others. Document setup holds what every flow needs — sign in, seed data, dismiss a cookie banner. Flow setup holds what only that journey needs, most often the page it starts on:

```json
{
  "baseUrl": "https://example.com",
  "setup": [ { "action": "navigate", "url": "/login" } ],

  "flows": [
    {
      "id": "request-quote",
      "setup": [ { "action": "navigate", "url": "/birthday" } ],
      "cases": []
    },
    {
      "id": "download-brochure",
      "setup": [ { "action": "navigate", "url": "/weddings" } ],
      "cases": []
    }
  ],

  "cleanup": [ { "action": "clear-storage" } ]
}
```

Rules:

- Cleanup at both levels runs even when the flow failed or errored. Cleanup failures **MUST** be reported but **MUST NOT** change the flow's result.
- A failing setup step at either level means the flow's preconditions were not met: its cases are `skipped` and the flow is `error`, not `failed` (§12). This keeps environment problems distinguishable from product bugs.
- Setup and cleanup steps are not cases: they produce no assertions and no case results, only reported step outcomes and evidence (§14.1).

In addition to the built-in actions of §7, setup and cleanup may use:

| Action | Fields | Description |
|---|---|---|
| `clear-storage` | — | Clear cookies, localStorage, and sessionStorage. |

Flows **MUST** be independent: engines **MAY** run them in any order, and a flow **MUST NOT** depend on state left behind by another flow.

---

## 12. Execution lifecycle

```
Load & validate document          (schema, variables, baseUrl, targetAttribute, graph integrity)
└─ for each flow:
   ├─ Run document setup
   ├─ Run flow setup
   ├─ Execute cases along the graph (§10.3)
   │   └─ for each case: run steps → evaluate assertions → collect evidence
   ├─ Run flow cleanup
   └─ Run document cleanup
Generate report
```

Failure semantics, in one place:

| Situation | Result |
|---|---|
| Undefined variable, invalid schema, cyclic graph, invalid `targetAttribute`, relative URL with no `baseUrl` | Document rejected at load; nothing runs. |
| Setup step fails (document or flow level) | Flow preconditions unmet; all its cases `skipped`, flow = `error`. Both cleanup levels still run. |
| Step fails (target missing, timeout) | Remaining steps and assertions in the case are skipped; case = `error`. |
| Assertion fails | Remaining assertions still evaluated; case = `failed`. |
| Case fails/errors, no matching edge | Downstream cases `skipped`; flow = case's outcome. |
| Case fails, `when: "failed"` edge exists | Execution continues along that edge (§10.3). |
| Cleanup step fails | Reported; flow result unchanged. |
| Flow fails | Remaining flows still run (flows are independent). |

---

## 13. Reporting

An execution produces a JSON report:

```json
{
  "status": "passed",
  "spec": "1.0",
  "name": "Venue Landing Page",
  "startedAt": "2026-07-27T12:00:00Z",
  "duration": 7.42,
  "summary": { "flows": 4, "cases": 18, "assertions": 91, "failed": 0, "errors": 0, "skipped": 0 },
  "flows": [
    {
      "id": "request-quote",
      "name": "Request Quote",
      "description": "Visitor requests a quote.",
      "status": "passed",
      "duration": 3.1,
      "cases": [
        {
          "id": "submit",
          "name": "Submit Quote",
          "description": "Submits valid details and expects the confirmation panel.",
          "status": "passed",
          "duration": 1.4,
          "steps": [
            {
              "action": "submit",
              "target": "quote-form",
              "description": "Send the quote request",
              "status": "passed"
            }
          ],
          "assertions": [
            {
              "type": "visible",
              "target": "success-message",
              "description": "The confirmation banner appears",
              "status": "passed"
            }
          ],
          "evidence": { "screenshot": "evidence/request-quote/submit/screenshot.png" }
        }
      ]
    }
  ]
}
```

- `status` at every level is `passed` | `failed` | `error` | `skipped`. A parent's status is the worst of its children (`error` > `failed` > `passed`; `skipped` children don't degrade a parent).
- Durations are seconds.
- `evidence` maps each collected artifact to a path relative to the results directory (§14.4).
- Engines **MAY** add engine-specific fields; consumers **MUST** ignore fields they don't recognize.

### 13.1 Human-readable output

Names and descriptions exist to make this report legible, so engines **MUST** carry them through:

- Every flow and case in the report **MUST** include its `name` (falling back to `id`) and its `description` when the document declares one.
- Every reported step and assertion **MUST** include its `description` when declared.
- A failed assertion's message **SHOULD** be its `description`, falling back to a generated one (§8).

A reader who has never opened the FlowSpec document **SHOULD** be able to understand a failure from the report alone.

---

## 14. Results output

§13 defines the *shape* of a result. This section defines *where* it lands, so that CI pipelines, dashboards, and flake trackers work against any conformant engine rather than being rewritten per engine.

### 14.1 Directory layout

Engines write results to a single **results directory**, which **SHOULD** default to `flowspec-results/` and **MUST** be overridable by the user:

```
flowspec-results/
├── report.json                              # the report defined in §13
├── report.xml                               # optional JUnit XML (§14.5)
└── evidence/
    └── <flow-id>/
        ├── _setup/                          # evidence from setup steps, if any
        │   └── screenshot.png
        └── <case-id>/
            ├── screenshot.png
            ├── dom.html
            └── console.log
```

Rules:

- Engines **MUST NOT** write outside the results directory.
- The directory **MUST** be safe to delete and regenerate: a run **MUST NOT** depend on artifacts from a previous run.
- A run **MUST** overwrite the previous run's results rather than accumulating timestamped directories. Archiving history is CI's job, not the engine's.

### 14.2 Runs covering multiple documents

A large site is normally split across several documents — one per page or area. When a single run executes more than one, results **MUST** nest under a directory per document so they cannot overwrite each other:

```
flowspec-results/
├── report.json                 # run-level summary across all documents
├── venue-landing/              # mirrors .flowspec/venue-landing.json
│   ├── report.json
│   ├── report.xml
│   └── evidence/…
└── admin/
    └── users/                  # mirrors .flowspec/admin/users.json
        ├── report.json
        ├── report.xml
        └── evidence/…
```

- The per-document directory is the document's **id** (§3.2) — its path under `.flowspec/` without the extension. The results tree therefore mirrors the source tree, and ids cannot collide because file paths cannot.
- For a document run from outside `.flowspec/`, the id is its filename without extension. Engines **MUST** fail the run if two such documents collide, rather than silently overwriting.
- Each per-document `report.json` is exactly the report of §13, with evidence paths relative to *its own* document directory. A single document's results therefore have the same shape whether it ran alone or alongside others.
- The run-level `report.json` at the root carries the aggregate `status`, `duration`, and `summary`, plus a `documents` array of `{ id, name, status, summary }`. It **MUST NOT** duplicate per-flow detail.
- Documents are independent. A failing document **MUST NOT** prevent the others from running, and engines **MAY** execute them in parallel.

For a run covering exactly one document, the nesting is omitted — the layout of §14.1 applies as written.

Artifact filenames need no counters or hashes because a case is visited at most once per run — the acyclicity requirement of §10.3 guarantees `evidence/<flow-id>/<case-id>/` is collision-free.

### 14.3 Artifact filenames

| Evidence | Filename |
|---|---|
| `screenshot` | `screenshot.png` |
| `dom` | `dom.html` |
| `html` | `page.html` |
| `a11y-tree` | `a11y-tree.json` |
| `network` | `network.json` |
| `console` | `console.log` |
| `reasoning` | `reasoning.md` |
| `performance` | `performance.json` |

### 14.4 Path references and portability

Evidence paths in `report.json` **MUST** be relative to the results directory:

```json
{ "evidence": { "screenshot": "evidence/request-quote/submit/screenshot.png" } }
```

Absolute paths **MUST NOT** be used. This is what makes the results directory a self-contained bundle: it can be zipped, uploaded as a CI artifact, or attached to a pull request, and every reference still resolves.

Engines that upload evidence to remote storage **MAY** instead emit absolute `https:` URIs. A report **MUST NOT** mix the two styles.

### 14.5 Case identity and CI integration

A case's **fully-qualified id** is `<flow-id>/<case-id>` — for example `request-quote/submit`. It is stable across runs and is the key that flake trackers and history dashboards **SHOULD** use to correlate a case with its previous results.

Engines **SHOULD** additionally emit JUnit XML as `report.xml`, since it is the format CI systems already understand:

| JUnit | FlowSpec |
|---|---|
| `<testsuite name>` | Flow `name`, falling back to `id` |
| `<testcase classname>` | Flow `id` |
| `<testcase name>` | Case `name`, falling back to `id` |
| `<failure message>` | The failed assertion's `description` (§13.1) |
| `<error message>` | The failing step's `description` and reason |
| `<skipped>` | Cases with status `skipped` |

### 14.6 Exit codes

A conformant runner **MUST** exit with:

| Code | Meaning |
|---|---|
| `0` | Every flow passed. |
| `1` | At least one flow failed — the application under test did not meet expectations. |
| `2` | At least one flow errored, or the document was invalid — the run itself did not complete. |

The distinction between `1` and `2` matters in CI: `1` is a product bug, `2` is a broken test run or environment, and pipelines usually treat them differently.

---

## 15. Versioning and extensibility

- The `spec` field uses `major.minor`. Minor versions are backward compatible; engines supporting `1.x` **MUST** accept any `1.y ≤ x` document.
- Unknown *document* fields are reserved: engines **MUST** ignore unrecognized top-level and object-level fields (forward compatibility), but **MUST** reject unknown `action` and assertion `type` values (§2).

Candidate features deliberately **out of scope** for 1.0: loops, parallel execution, imports/shared flows, AI-generated flows, visual regression, Lighthouse audits, API testing, database assertions, native desktop support.

---

## 16. Complete example

```json
{
  "spec": "1.0",
  "name": "Venue Quote Flow",
  "description": "A visitor requests a quote from the venue landing page.",
  "version": "1.0.0",
  "author": "Constell",
  "tags": ["smoke"],
  "baseUrl": "https://example.com",

  "variables": {
    "customerName": "John Doe",
    "email": "john@example.com"
  },

  "setup": [
    { "action": "navigate", "url": "/birthday" }
  ],

  "flows": [
    {
      "id": "request-quote",
      "name": "Request Quote",
      "description": "A visitor opens the quote form and submits valid details.",
      "cases": [
        {
          "id": "open-form",
          "name": "Open Form",
          "description": "The quote form is reachable from the landing page.",
          "steps": [
            {
              "action": "click",
              "target": "quote-button",
              "description": "Open the quote form"
            }
          ],
          "assertions": [
            {
              "type": "visible",
              "target": "quote-form",
              "description": "The quote form is shown"
            }
          ]
        },
        {
          "id": "submit",
          "name": "Submit Quote",
          "description": "Valid details produce a confirmation and no console errors.",
          "steps": [
            {
              "action": "fill",
              "target": "quote-form",
              "description": "Enter the visitor's contact details",
              "values": {
                "quote-name": "{{customerName}}",
                "quote-email": "{{email}}"
              }
            },
            {
              "action": "submit",
              "target": "quote-form",
              "description": "Send the quote request"
            }
          ],
          "assertions": [
            {
              "type": "visible",
              "target": "success-message",
              "description": "The confirmation banner appears"
            },
            {
              "type": "console",
              "level": "error",
              "max": 0,
              "description": "No console errors during submission"
            }
          ],
          "evidence": ["screenshot", "dom", "console"]
        }
      ]
    }
  ],

  "cleanup": [
    { "action": "clear-storage" }
  ]
}
```

Rendered flow:

```mermaid
flowchart LR
  open-form --> submit
```
