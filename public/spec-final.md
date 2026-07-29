# FlowSpec Language Specification

**Status:** Draft
**Spec version:** 1.0
**Authors:** Constell
**Category:** AI Acceptance Testing Specification

---

## 1. Introduction

FlowSpec is a declarative specification language for AI-driven acceptance testing.

A FlowSpec document does **not** describe browser automation. It describes one **Flow** — a feature a user moves through, like signing in — as:

- **Cases** — the distinct paths through that flow, each an independent scenario
- **Steps** — how to reproduce that path, as semantic user interactions
- **Assertions** — what must be true at the end of it
- **Evidence** — artifacts to capture

```
login_flow.json                       ← the flow: signing in
├── valid-credentials                 ← a case: a path through it
│   ├── steps: fill the form, submit  ← how to reproduce the path
│   └── assertions: lands on /dashboard
├── inactive-account
└── invalid-credentials
```

Every case is a path a real user can take, and every case is expected to **pass** — including the sad ones. "Failed login due to an inactive account" is not a failing test; it is a case whose expected outcome is a refusal, and it passes when the refusal appears.

One flow, one file: `login_flow.json`, `request_quote_flow.json`. A suite is a directory of them.

An **execution engine** — an AI browser agent, a Playwright adapter, a Selenium adapter, a mobile agent — consumes the document and decides *how* to perform the actions. FlowSpec is to AI acceptance testing what OpenAPI is to REST APIs: a framework-independent source of truth for expected behavior that developers, QA engineers, and AI agents all share.

### 1.1 Design principles

| Principle | Meaning |
|---|---|
| **Declarative** | Describes *what* should happen, never *how*. |
| **One flow per file** | A document is a feature journey. No container layer, no nesting to navigate. |
| **Cases are paths** | Each case is an independent scenario through the flow — happy or sad — and every one is expected to pass. |
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

A FlowSpec document is a single JSON object (UTF-8) describing exactly one flow. Documents live as plain `.json` files inside the `.flowspec/` directory (§3.2). The bare filename `.flowspec.json` is reserved for project configuration (§3.3) and is never a document.

### 3.1 Top-level structure

The top level **is** the flow. There is no wrapper.

```json
{
  "spec": "1.0",
  "name": "Request Quote",
  "description": "A visitor requests a quote from the venue landing page.",
  "version": "1.0.0",
  "author": "Constell",
  "tags": ["smoke", "production"],
  "baseUrl": "https://example.com",
  "targetAttribute": "data-constell",
  "variables": {},
  "setup": [],
  "cases": [],
  "cleanup": [],
  "evidence": ["screenshot", "console"]
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `spec` | string | **yes** | FlowSpec version this document targets. `"1.0"`. |
| `name` | string | **yes** | Human-readable name of the feature this flow covers. |
| `cases` | Case[] | **yes** | The paths through the flow (§10). |
| `description` | string | no | What this flow covers. |
| `version` | string | no | Document version (semver recommended). |
| `author` | string | no | Author or team. |
| `tags` | string[] | no | Labels for filtering (`smoke`, `regression`, …). |
| `baseUrl` | string | no | Origin that relative `navigate` URLs resolve against (§7.4). |
| `targetAttribute` | string | no | HTML attribute that carries component names. Default `data-constell` (§6.1). |
| `variables` | object | no | Reusable values (§5). |
| `setup` | Step[] | no | Preconditions, run before **each** case (§11). |
| `cleanup` | Step[] | no | Teardown, run after **each** case (§11). |
| `evidence` | string[] | no | Default evidence for all cases (§9). |

The flow has no `id` field: its id is its filename (§3.2), so it cannot collide with another flow's and cannot drift out of sync with the file it lives in.

Engines **MUST** reject a document whose `spec` major version they do not support.

### 3.2 Project layout

A project keeps its flows in a `.flowspec/` directory alongside an optional `.flowspec.json` configuration file:

```
your-project/
├── .flowspec.json              # project configuration (optional)
├── .flowspec/
│   ├── login_flow.json         # one journey per file
│   ├── request_quote_flow.json
│   ├── checkout_flow.json
│   ├── admin/
│   │   └── invite_user_flow.json   # nesting is allowed
│   └── fixtures/               # reserved: files used by upload steps
│       └── floor-plan.pdf
└── flowspec-results/           # generated output — do not commit (§14)
```

The directory holds **source only**: the flows themselves and the fixtures they reference. Generated output never goes here — results are written to a separate directory (§14) that is safe to delete, whereas `.flowspec/` is committed alongside the application it describes.

- Filenames **SHOULD** name the journey and carry a `_flow` suffix — `login_flow.json`, `request_quote_flow.json` — so a flow is recognisable as one wherever it is opened, listed, or linked. Ids *inside* a document (cases, targets) remain lowercase kebab-case (§6.3).
- Runners **SHOULD** discover flows by globbing `.flowspec/**/*.json` when no explicit path is given, and **MUST** accept explicit paths so a single flow can be run on its own.
- A flow's **id** is its path relative to `.flowspec/` without the extension — `login_flow`, `admin/invite_user_flow`. Ids are unique by construction, and they key the per-flow results directories of §14.2.
- `.flowspec/fixtures/` is **reserved** and **MUST** be excluded from discovery, so that a `.json` fixture is never mistaken for a flow. Engines **MUST NOT** infer flow-ness from a file's contents: a malformed document must fail loudly rather than be silently skipped as "not a flow".
- Flows inside `.flowspec/` use a plain `.json` extension. A flow kept elsewhere **SHOULD** use `.flowspec.json` as a suffix (`smoke.flowspec.json`) so it is recognisable; note this is a suffix on a named file, distinct from the bare `.flowspec.json` configuration file.

Nothing here is mandatory: a lone flow file remains a valid, runnable FlowSpec.

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
| `include` | string[] | Globs identifying flows. Default `[".flowspec/**/*.json"]`. |
| `output` | string | Results directory (§14.1). Default `flowspec-results`. |
| `evidence` | string[] | Default evidence for every case (§9). |

Keeping `baseUrl` here is the point of the file: the origin differs between a laptop, CI, and staging, while the journeys do not. Committing an environment into a flow couples the two; committing it into configuration — or overriding it at invocation — does not.

Configuration is also what a per-file layout needs: with no container document to hold shared settings, the project file is where `targetAttribute` and `baseUrl` are stated once for every flow.

### 3.4 Resolution order

Where a setting can appear in more than one place, the **most specific wins**:

```
invocation (CLI flag, env)  →  flow document  →  .flowspec.json  →  spec default
```

- A flow **MAY** override `baseUrl`, `targetAttribute`, and `evidence` when that journey genuinely differs — an admin subdomain, a legacy area with its own attribute convention.
- Engines **MUST** apply this order and **MUST** report the effective values in the run report's `config` block (§13), so a surprising result can be traced to the setting that produced it.

---

## 4. Metadata

The metadata fields (`spec`, `name`, `description`, `version`, `author`, `tags`) live at the top level of the document as shown in §3.1. Only `spec` and `name` are required. Everything else exists for humans and tooling — engines **MUST NOT** change behavior based on `tags`, though runners **MAY** use them to select which flows to execute.

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
- Variables are scoped to their flow. A value shared by several journeys is repeated in each, or supplied at invocation — flows do not import from one another (§15).
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

The attribute name is a property of the application under test, not of the journey being described, so it normally lives in `.flowspec.json` (§3.3). A flow **MAY** declare its own:

```json
{
  "spec": "1.0",
  "name": "Request Quote",
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
- Exactly one attribute applies per flow. Fallback chains are deliberately excluded: two ways to name the same component is how a test suite starts drifting from its markup. (Engine-side detection when the configured attribute is absent from the page entirely is a different mechanism — §6.2.)
- Engines **MAY** allow the value to be overridden at invocation time (CLI flag, config), which takes precedence over the document. This mirrors variable overrides (§5) and lets one flow run against environments whose markup differs.
- The attribute name is meaningless to non-DOM engines (§6.2), which ignore it.

### 6.2 Resolution

- DOM-based engines **MUST** resolve `target: "X"` to `[<targetAttribute>="X"]` — by default `[data-constell="X"]`.
- Non-DOM engines (mobile, desktop) **MUST** map the same names onto their platform's semantic identifiers (e.g. accessibility IDs), ignoring `targetAttribute`.
- If a target resolves to zero elements, the step or assertion referencing it fails.
- Exception — configuration mismatch: if `[<targetAttribute>]` matches **nothing on the page at all**, the configured attribute is wrong, not the component. Engines **SHOULD** then probe the well-known conventions (`data-constell`, `data-testid`, `data-qa`, `data-test`) and, when exactly one is present on the page, resolve the flow's targets against it for the rest of the run, reporting the substitution in the report's `warnings` (§13). If none or several are present, the run errors as usual. This is a whole-flow correction, not a per-target fallback chain (§6.1): a missing target under an attribute the page *does* use still fails.
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
| `select` | required | `value` (string, required) | Choose an option: match by visible label first, falling back to the underlying value. |
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

`navigate` accepts either an absolute URL or a path. Paths resolve against the flow's `baseUrl`:

```json
{
  "baseUrl": "https://example.com",
  "setup": [ { "action": "navigate", "url": "/birthday" } ]
}
```

- If `baseUrl` is absent, engines **MUST** require one at invocation and **MUST** reject the document at load time if neither is supplied and any `navigate` uses a relative URL.
- Engines **MUST** allow `baseUrl` to be overridden at invocation, so the same flow runs against local, staging, and production. Environment-specific origins **SHOULD NOT** be hardcoded into a committed flow.
- Absolute URLs bypass `baseUrl` entirely — use them for third-party pages (payment providers, identity providers) that a journey legitimately passes through.

**A path may span any number of pages.** `navigate` is an ordinary step, so a case's steps can cross pages freely and assert against whichever page they end on:

```json
{
  "spec": "1.0",
  "name": "Checkout",
  "cases": [
    {
      "id": "pay-by-card",
      "steps": [
        { "action": "click", "target": "cart-checkout" },
        { "action": "fill", "target": "address-form", "values": { "address-postcode": "SW1A 1AA" } },
        { "action": "click", "target": "address-continue" },
        { "action": "fill", "target": "payment-form", "values": { "payment-card": "4242424242424242" } },
        { "action": "click", "target": "payment-submit" }
      ],
      "assertions": [ { "type": "visible", "target": "order-confirmation" } ]
    }
  ]
}
```

Crossing three pages does not make three cases. A case is one path *end to end*, however many pages it walks through — its steps are the reproduction steps for that path, and its assertions describe where it ends up. Splitting a single path into several cases breaks the independence of §10.2.

The page a path *starts* on belongs in `setup`, not in the steps of every case (§11) — arriving there is a precondition, not part of what is being tested.

### 7.5 File paths

The `file` path of an `upload` step resolves against the **project root** — the directory containing `.flowspec/`, or the working directory for a standalone flow:

```json
{ "action": "upload", "target": "brochure-input", "file": ".flowspec/fixtures/floor-plan.pdf" }
```

- Paths **MUST NOT** be resolved relative to the document, so a nested flow (`admin/invite_user_flow.json`) references fixtures the same way a top-level one does, with no `../` climbing.
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
| `network` | — | `status` (`"no-errors"`), or `url` + `expected` (number — exact HTTP status code) | No failed requests, or the most recent request whose URL contains `url` returned exactly `expected`. |
| `performance` | — | `metric` (see below), `max` (number) | The metric is at or below `max`. |
| `accessibility` | optional | `standard` (string, default `"wcag2aa"`) | No violations at the given standard, scoped to target or page. |

`performance` metrics for 1.0 are `lcp`, `fcp`, `ttfb`, `inp` (milliseconds) and `cls` (unitless score). Engines **MAY** support additional metrics, but a metric an engine does not recognise is an unknown-type error (§2) — never a silent pass.

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

- `evidence` may be declared at flow level (default for every case) and at case level (replaces the flow default for that case).
- On any case **failure or error**, engines **MUST** capture at least `screenshot` and `console`, regardless of declared evidence.
- `timing` is always captured; declaring it is unnecessary.

```json
{ "evidence": ["screenshot", "dom", "console"] }
```

---

## 10. Cases

A flow is the document (§3.1). What a flow contains is its cases — the distinct paths a user can take through the feature.

### 10.1 Case

A **Case** is one path through the flow: the steps that reproduce it, plus the assertions that must hold at the end of it.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | **yes** | Unique within the flow. Lowercase kebab-case, naming the path. |
| `name` | string | no | Human-readable name. Defaults to `id`. |
| `description` | string | no | What this path is and why it matters. |
| `steps` | Step[] | no | The reproduction steps for this path, in order (§7). |
| `assertions` | Assertion[] | no | Evaluated after all steps (§8). |
| `evidence` | string[] | no | Overrides the flow default (§9). |

A case's **outcome** is:

- `passed` — all steps executed and all assertions held
- `failed` — steps executed but at least one assertion failed
- `error` — a step could not be executed (target missing, timeout, unknown action), or setup failed

A case with neither steps nor assertions is valid and trivially `passed`; engines **SHOULD** note it in the report's `warnings` (§13), since an empty case usually means an unfinished flow.

### 10.2 Cases are independent

Cases are **siblings, not a sequence**. Each one is a self-contained scenario: it starts from the state `setup` establishes, walks its own path, and ends with its own assertions.

```json
{
  "spec": "1.0",
  "name": "Login",
  "setup": [ { "action": "navigate", "url": "/login" } ],
  "cases": [
    { "id": "valid-credentials",   "steps": [], "assertions": [] },
    { "id": "inactive-account",    "steps": [], "assertions": [] },
    { "id": "invalid-credentials", "steps": [], "assertions": [] }
  ]
}
```

Rules:

- Engines **MUST** run **every** case, whatever the others did. One case failing tells you nothing about the next path — a chain that stops at the first failure hides the rest of the feature.
- A case **MUST NOT** depend on state left behind by another. `setup` runs before each case (§11), so each starts from the same place.
- Order in the array is presentation only — it fixes the reading and reporting order. Engines **MAY** execute cases in any order or in parallel.
- Case ids **MUST** be unique within the flow. Engines **MUST** validate this at load time.

The flow's status is the worst of its cases (§13). There is no routing between cases and no graph to declare: a path that needs a different route is a different case, and a feature that needs a different starting point is a different flow.

### 10.3 Sad paths are ordinary cases

The valuable cases are usually the ones where the user does not get what they wanted. Each is a case like any other, and each is **expected to pass**:

| Case | Steps reproduce | Assertions expect |
|---|---|---|
| `valid-credentials` | correct email and password, submit | lands on `/dashboard`, account menu visible |
| `inactive-account` | a dormant account's credentials, submit | `login-error` visible reading *"account is not active"*, still on `/login` |
| `invalid-credentials` | a wrong password, submit | `login-error` visible, password field cleared, still on `/login` |

`inactive-account` is not a failing test. It fails only when the application *lets the dormant user in*, or shows the wrong message, or crashes — which is exactly the bug it exists to catch.

Authors **MUST NOT** describe a sad path as an expected failure. A case's status is a verdict on the application, never on the path being tested: `failed` always means the application did not do what the case said it should.

---

## 11. Setup and Cleanup

`setup` and `cleanup` are step arrays that establish and tear down the state a case needs. They are declared once, at the top level, and run **around each case**:

```
for each case:  setup → steps → assertions → evidence → cleanup
```

Per-case, not per-flow, is what makes the independence of §10.2 real. In the login flow, `valid-credentials` signs a user in; without a fresh `setup` the next case would start from a signed-in browser and test nothing it claims to. This is the `beforeEach` / `afterEach` every test framework converged on, for the same reason.

Setup holds whatever a path cannot start without: the page it begins on, a sign-in, seeded data, a dismissed cookie banner.

```json
{
  "spec": "1.0",
  "name": "Request Quote",
  "baseUrl": "https://example.com",

  "setup": [
    { "action": "clear-storage" },
    { "action": "navigate", "url": "/birthday" }
  ],

  "cases": [],

  "cleanup": [ { "action": "clear-storage" } ]
}
```

Rules:

- Cleanup runs even when the case failed or errored. Cleanup failures **MUST** be reported in the report's `warnings` (§13) but **MUST NOT** change any result.
- A failing setup step means that case's preconditions were not met: the case is `error`, not `failed` (§12), and its steps and assertions do not run. This keeps environment problems distinguishable from product bugs. The remaining cases are still attempted — a precondition that broke once usually breaks for all of them, and reporting that is more useful than stopping.
- Setup and cleanup steps are not cases: they produce no assertions and no case results, only reported step outcomes and evidence (§14.1).
- Preconditions shared by several flows are repeated in each flow's `setup`. This is deliberate: a few duplicated navigate-and-sign-in steps cost less than a shared fixture that silently changes what a flow tests. Imports are out of scope for 1.0 (§15).

In addition to the built-in actions of §7, setup and cleanup may use:

| Action | Fields | Description |
|---|---|---|
| `clear-storage` | — | Clear cookies, localStorage, and sessionStorage. |

Flows **MUST** be independent of one another too: engines **MAY** run them in any order or in parallel, and a flow **MUST NOT** depend on state left behind by another.

---

## 12. Execution lifecycle

```
Load & validate the flow      (schema, unique case ids, variables, baseUrl, targetAttribute)
├─ for each case:
│   ├─ Run setup
│   ├─ Run the case's steps, in order
│   ├─ Evaluate every assertion
│   ├─ Collect evidence
│   └─ Run cleanup
└─ Generate report
```

A run covering several flows repeats this per flow, in any order, and aggregates the reports (§14.2).

Failure semantics, in one place:

| Situation | Result |
|---|---|
| Undefined variable, invalid schema, duplicate case id, invalid `targetAttribute`, relative URL with no `baseUrl` | Flow rejected at load; nothing runs. |
| Setup step fails | That case's preconditions unmet; case = `error`, its steps and assertions do not run. Cleanup still runs, remaining cases still attempted. |
| Step fails (target missing, timeout) | Remaining steps and assertions in that case are skipped; case = `error`. |
| Assertion fails | Remaining assertions still evaluated; case = `failed`. |
| Case fails or errors | Remaining cases still run; flow = worst case outcome. |
| Cleanup step fails | Reported in `warnings`; no result changes. |
| Flow fails | Remaining flows still run (flows are independent). |

---

## 13. Reporting

Executing a flow produces a JSON report. Its top level is the flow, mirroring the document:

```json
{
  "status": "passed",
  "spec": "1.0",
  "id": "login_flow",
  "name": "Login",
  "description": "How a user signs in, and how signing in is refused.",
  "startedAt": "2026-07-27T12:00:00Z",
  "duration": 7.42,
  "config": { "baseUrl": "http://localhost:5173", "targetAttribute": "data-constell", "evidence": ["screenshot", "console"] },
  "warnings": [],
  "summary": { "cases": 3, "assertions": 8, "passed": 3, "failed": 0, "errors": 0 },
  "cases": [
    {
      "id": "inactive-account",
      "name": "Refuses an inactive account",
      "description": "A dormant account is turned away with an explanation.",
      "status": "passed",
      "duration": 1.4,
      "steps": [
        {
          "action": "click",
          "target": "login-submit",
          "description": "Attempt to sign in",
          "status": "passed"
        }
      ],
      "assertions": [
        {
          "type": "text",
          "target": "login-error",
          "expected": "account is not active",
          "description": "The dormant-account message explains why",
          "status": "passed"
        }
      ],
      "evidence": { "screenshot": "evidence/inactive-account/screenshot.png" }
    }
  ]
}
```

- `id` is the flow's id (§3.2) — its filename, so the report names the source it came from.
- `status` at every level is `passed` | `failed` | `error`. The flow's status is the worst of its cases (`error` > `failed` > `passed`).
- `config` carries the **effective values** after resolution (§3.4) — at minimum `baseUrl` and `targetAttribute`, plus `evidence` when a default applies — so a surprising result can be traced to the setting that produced it.
- `warnings` is an array of strings for run-level notices that change no result: a target-attribute substitution (§6.2), a cleanup failure (§11), an engine-specific degradation. Empty when there are none; engines **MUST NOT** use it for failures.
- Durations are seconds.
- `evidence` maps each collected artifact to a path relative to the results directory (§14.4).
- Engines **MAY** add engine-specific fields; consumers **MUST** ignore fields they don't recognize.

### 13.1 Human-readable output

Names and descriptions exist to make this report legible, so engines **MUST** carry them through:

- The flow and every case in the report **MUST** include its `name` (falling back to `id`) and its `description` when the document declares one.
- Every reported step and assertion **MUST** include its `description` when declared.
- A failed assertion's message **SHOULD** be its `description`, falling back to a generated one (§8).

A reader who has never opened the FlowSpec document **SHOULD** be able to understand a failure from the report alone.

---

## 14. Results output

§13 defines the *shape* of a result. This section defines *where* it lands, so that CI pipelines, dashboards, and flake trackers work against any conformant engine rather than being rewritten per engine.

### 14.1 Directory layout

Engines write results to a single **results directory**, which **SHOULD** default to `flowspec-results/` and **MUST** be overridable by the user. For a run of one flow:

```
flowspec-results/
├── report.json                              # the report defined in §13
├── report.xml                               # optional JUnit XML (§14.5)
└── evidence/
    └── <case-id>/                           # one directory per case
        ├── screenshot.png
        ├── dom.html
        └── console.log
```

Setup and cleanup run per case (§11), so their evidence belongs to that case and lands in the same directory.

Rules:

- Engines **MUST NOT** write outside the results directory.
- The directory **MUST** be safe to delete and regenerate: a run **MUST NOT** depend on artifacts from a previous run.
- A run **MUST** overwrite the previous run's results rather than accumulating timestamped directories. Archiving history is CI's job, not the engine's.

### 14.2 Runs covering multiple flows

A site is normally covered by several flows — one per journey. When a single run executes more than one, results **MUST** nest under a directory per flow so they cannot overwrite each other:

```
flowspec-results/
├── report.json                 # run-level summary across all flows
├── request_quote_flow/         # mirrors .flowspec/request_quote_flow.json
│   ├── report.json
│   ├── report.xml
│   └── evidence/…
└── admin/
    └── invite_user_flow/       # mirrors .flowspec/admin/invite_user_flow.json
        ├── report.json
        ├── report.xml
        └── evidence/…
```

- The per-flow directory is the flow's **id** (§3.2) — its path under `.flowspec/` without the extension. The results tree therefore mirrors the source tree, and ids cannot collide because file paths cannot.
- For a flow run from outside `.flowspec/`, the id is its filename without extension. Engines **MUST** fail the run if two such flows collide, rather than silently overwriting.
- Each per-flow `report.json` is exactly the report of §13, with evidence paths relative to *its own* flow directory. A flow's results therefore have the same shape whether it ran alone or alongside others.
- The run-level `report.json` at the root carries the aggregate `status`, `duration`, and `summary`, plus a `flows` array of `{ id, name, status, summary }`. It **MUST NOT** duplicate per-case detail.
- Flows are independent. A failing flow **MUST NOT** prevent the others from running, and engines **MAY** execute them in parallel.

For a run covering exactly one flow, the nesting is omitted — the layout of §14.1 applies as written.

Artifact filenames need no counters or hashes: a case runs exactly once per run and its ids are unique (§10.2), so `evidence/<case-id>/` is collision-free.

### 14.3 Artifact filenames

| Evidence | Filename |
|---|---|
| `screenshot` | `screenshot.png` |
| `dom` | `dom.html` |
| `html` | `page.html` |
| `a11y-tree` | `a11y-tree.json` |
| `network` | `network.json` |
| `console` | `console.log` |
| `performance` | `performance.json` |
| `reasoning` | `reasoning.md` |

### 14.4 Path references and portability

Evidence paths in `report.json` **MUST** be relative to the results directory:

```json
{ "evidence": { "screenshot": "evidence/inactive-account/screenshot.png" } }
```

Absolute paths **MUST NOT** be used. This is what makes the results directory a self-contained bundle: it can be zipped, uploaded as a CI artifact, or attached to a pull request, and every reference still resolves.

Engines that upload evidence to remote storage **MAY** instead emit absolute `https:` URIs. A report **MUST NOT** mix the two styles.

### 14.5 Case identity and CI integration

A case's **fully-qualified id** is `<flow-id>/<case-id>` — for example `login_flow/inactive-account`. It is stable across runs and is the key that flake trackers and history dashboards **SHOULD** use to correlate a case with its previous results.

Engines **SHOULD** additionally emit JUnit XML as `report.xml`, since it is the format CI systems already understand:

| JUnit | FlowSpec |
|---|---|
| `<testsuite name>` | Flow `name`, falling back to `id` |
| `<testcase classname>` | Flow `id` |
| `<testcase name>` | Case `name`, falling back to `id` |
| `<failure message>` | The failed assertion's `description` (§13.1) |
| `<error message>` | The failing step's `description` and reason |

One flow maps to one `<testsuite>` and each case to one `<testcase>`, which is what CI systems expect from one file. Nothing maps to `<skipped>`: every case runs (§10.2).

### 14.6 Exit codes

A conformant runner **MUST** exit with:

| Code | Meaning |
|---|---|
| `0` | Every flow passed. |
| `1` | At least one flow failed — the application under test did not meet expectations. |
| `2` | At least one flow errored, or a document was invalid — the run itself did not complete. |

The distinction between `1` and `2` matters in CI: `1` is a product bug, `2` is a broken test run or environment, and pipelines usually treat them differently.

---

## 15. Versioning and extensibility

- The `spec` field uses `major.minor`. Minor versions are backward compatible; engines supporting `1.x` **MUST** accept any `1.y ≤ x` document.
- Unknown *document* fields are reserved: engines **MUST** ignore unrecognized top-level and object-level fields (forward compatibility), but **MUST** reject unknown `action` and assertion `type` values (§2).

Candidate features deliberately **out of scope** for 1.0: loops, imports/shared setup, routing or dependencies between cases, AI-generated flows, visual regression, Lighthouse audits, API testing, database assertions, native desktop support. Parallelism is not a spec concern: cases and flows are independent (§10.2, §11), so running them concurrently is an engine's choice.

---

## 16. Complete example

One feature, three paths through it. All three pass when the application behaves.

`.flowspec/login_flow.json`

```json
{
  "spec": "1.0",
  "name": "Login",
  "description": "How a user signs in, and how signing in is refused.",
  "version": "1.0.0",
  "author": "Constell",
  "tags": ["smoke"],
  "baseUrl": "https://example.com",

  "variables": {
    "email": "john@example.com",
    "password": "correct-horse-battery",
    "inactiveEmail": "dormant@example.com",
    "wrongPassword": "hunter2"
  },

  "setup": [
    { "action": "clear-storage", "description": "Start signed out" },
    { "action": "navigate", "url": "/login" }
  ],

  "cases": [
    {
      "id": "valid-credentials",
      "name": "Signs in with correct credentials",
      "description": "An active account reaches the dashboard.",
      "steps": [
        {
          "action": "fill",
          "target": "login-form",
          "description": "Enter the account's email and password",
          "values": {
            "login-email": "{{email}}",
            "login-password": "{{password}}"
          }
        },
        {
          "action": "click",
          "target": "login-submit",
          "description": "Sign in"
        }
      ],
      "assertions": [
        {
          "type": "url",
          "expected": "/dashboard",
          "match": "contains",
          "description": "The user lands on the dashboard"
        },
        {
          "type": "visible",
          "target": "account-menu",
          "description": "The account menu confirms the session"
        },
        {
          "type": "console",
          "level": "error",
          "max": 0,
          "description": "No console errors while signing in"
        }
      ],
      "evidence": ["screenshot", "dom", "console"]
    },
    {
      "id": "inactive-account",
      "name": "Refuses an inactive account",
      "description": "A dormant account is turned away with an explanation, not a generic error.",
      "steps": [
        {
          "action": "fill",
          "target": "login-form",
          "description": "Enter a dormant account's credentials",
          "values": {
            "login-email": "{{inactiveEmail}}",
            "login-password": "{{password}}"
          }
        },
        {
          "action": "click",
          "target": "login-submit",
          "description": "Attempt to sign in"
        }
      ],
      "assertions": [
        {
          "type": "text",
          "target": "login-error",
          "expected": "account is not active",
          "description": "The message explains the account is inactive"
        },
        {
          "type": "url",
          "expected": "/login",
          "match": "contains",
          "description": "The user stays on the login page"
        }
      ]
    },
    {
      "id": "invalid-credentials",
      "name": "Refuses a wrong password",
      "description": "A bad password is rejected without revealing whether the email exists.",
      "steps": [
        {
          "action": "fill",
          "target": "login-form",
          "description": "Enter a valid email with the wrong password",
          "values": {
            "login-email": "{{email}}",
            "login-password": "{{wrongPassword}}"
          }
        },
        {
          "action": "click",
          "target": "login-submit",
          "description": "Attempt to sign in"
        }
      ],
      "assertions": [
        {
          "type": "visible",
          "target": "login-error",
          "description": "An error is shown"
        },
        {
          "type": "value",
          "target": "login-password",
          "expected": "",
          "description": "The password field is cleared"
        },
        {
          "type": "hidden",
          "target": "account-menu",
          "description": "No session is created"
        }
      ]
    }
  ],

  "cleanup": [
    { "action": "clear-storage" }
  ]
}
```

Read as a report, this is three independent verdicts on one feature:

```
login_flow — Login (3 cases)
  ✓ valid-credentials     Signs in with correct credentials
  ✓ inactive-account      Refuses an inactive account
  ✓ invalid-credentials   Refuses a wrong password
```
