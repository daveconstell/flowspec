<p align="center">
  <img src="public/logo.png" alt="FlowSpec" width="160" />
</p>

# FlowSpec

A declarative, engine-agnostic specification language for AI-driven acceptance testing, plus the site that documents it.

One FlowSpec file describes one feature a user moves through — signing in, checking out — and leaves *how* to drive it to an execution engine: an AI browser agent, a Playwright adapter, a mobile agent. FlowSpec is to AI acceptance testing what OpenAPI is to REST APIs.

```
login_flow.json                       ← the flow: one feature, one file
├── valid-credentials                 ← a case: one path through it
│   ├── steps: fill the form, submit  ← how to reproduce the path
│   └── assertions: lands on /dashboard
├── inactive-account                  ← cases are siblings, not a chain
└── invalid-credentials
```

Every case is expected to **pass**, sad paths included: `inactive-account` passes when the refusal appears, and fails only when the app lets a dormant user in.

## What's here

| File | Purpose |
|---|---|
| [`public/spec-final.md`](public/spec-final.md) | **The specification.** FlowSpec 1.0 — flow file format, cases, actions, assertions, evidence, setup/cleanup, execution lifecycle, results output. |
| [`public/SKILL.md`](public/SKILL.md) | A condensed skill for AI agents. Drop it into an agent's skills directory — or run `./install-skill.sh` — to author, review, and run FlowSpec flows via `/flowspec` commands. |
| [`public/llms.txt`](public/llms.txt) | Machine-readable overview for LLMs, following the llms.txt convention. |
| `index.html` | The documentation site — renders the spec at runtime. |

## Installing the skill

One file, no dependencies. Drop it anywhere your agent reads skills from — `~/.claude/skills/` and `~/.agents/skills/` for a global install, `<project>/.claude/skills/` for one project.

```bash
# direct download
mkdir -p ~/.claude/skills/flowspec
curl -fsSL https://raw.githubusercontent.com/daveconstell/flowspec/main/public/SKILL.md \
  -o ~/.claude/skills/flowspec/SKILL.md
```

```bash
# or clone and use the installer — writes to both skill directories
git clone https://github.com/daveconstell/flowspec.git
./flowspec/install-skill.sh              # global (~)
./flowspec/install-skill.sh /path/to/app # project-local
```

Restart the agent session, then `/flowspec` to confirm it loaded.

## Using FlowSpec

FlowSpec is a specification, not a test runner — there is no reference implementation yet. To adopt it:

1. **Annotate your UI.** Add `data-constell="component-name"` to every element a test must reach. Name by role, not appearance. Already using `data-testid` or another convention? Set `targetAttribute` instead of migrating markup. If the configured attribute turns out to be absent from the page entirely, engines detect the convention the page actually uses (`data-constell`, `data-testid`, `data-qa`, `data-test`), run with it, and flag the config mismatch — instead of failing every step.
2. **Author your flows.** One feature per file in `.flowspec/`, with project settings in `.flowspec.json`:

   ```
   .flowspec.json                  # baseUrl, targetAttribute, output
   .flowspec/
   ├── login_flow.json
   ├── request_quote_flow.json
   ├── admin/invite_user_flow.json
   └── fixtures/                   # files referenced by upload steps
   ```

   The file *is* the flow — `spec`, `name`, `variables`, `setup`, `cases`, `cleanup` at the top level, no wrapper — and its filename is its id. Inside it, one case per path; `setup` runs before each of them, so no case inherits a sibling's state. See §3.2 of the spec for the layout and §16 for a complete flow.
3. **Run it.** Give an AI coding agent `SKILL.md` plus your flow, or write a thin adapter mapping FlowSpec actions onto Playwright/Selenium.

   With the skill installed (`./install-skill.sh`, or pass a project path for a local install), the agent answers to slash commands:

   | Command | Does |
   |---|---|
   | `/flowspec help` | The command list plus setup state — config, flows, whether testing tooling is connected |
   | `/flowspec init` | Detect `baseUrl`/`targetAttribute`, write `.flowspec.json`, create `.flowspec/` |
   | `/flowspec run [file] [case]` | Run every flow, one flow, or one case. `--url X` overrides the origin, `--headed` shows the browser |
   | `/flowspec flow:new` | Create a flow: ask which paths to cover, then walk each one in the browser or derive it from the source |
   | `/flowspec flow:set` | Update a flow's name, description, variables, setup, or cleanup |
   | `/flowspec case:new` | Add a path to a flow — asks which flow first, always |
   | `/flowspec case:set` | Update a case — asks which flow, then which case |
   | `/flowspec mermaid [file]` | Render a flow as a diagram: one setup, one branch per case |

   Two guards apply throughout: nothing claims to run without browser tooling actually connected, and any precondition, credential, or seeded record a flow needs is **asked for**, never invented.

   **Authoring can be interactive.** With a browser MCP connected and the app up, `flow:new` and `case:new` walk the path with you: the agent drives, reports where it landed and which components are reachable by name, and asks what the user does next. Each answer becomes one step. At the end it asks for the acceptance criteria, which become the assertions. Nothing is recorded that can't be replayed — if a control you just used has no target attribute, it stops and annotates it first, so a walked case is still a portable FlowSpec and not a pile of selectors.
4. **Consume the results.** Conformant engines write `flowspec-results/` — `report.json` (flow → cases → steps + assertions), optional JUnit `report.xml`, and evidence artifacts referenced by relative path. Multi-flow runs nest per flow id, mirroring the `.flowspec/` tree. Exit `0` passed, `1` failed, `2` errored.

## Running the site

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # → dist/
npm run preview  # serve the production build
```

Vite with no framework: one `index.html`, Tailwind via CDN, and `marked` + `mermaid` loaded as ESM to render the spec markdown at runtime. Editing `public/spec-final.md` updates the page — there is no second copy of the spec to keep in sync.

## Status

Spec version 1.0, **draft**. The flow file format is stable enough to author against; expect refinement of the runner-facing sections (§13–§14) as real engines are built.

## License

[MIT](LICENSE) — an open specification by Constell.
