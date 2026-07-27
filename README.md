# FlowSpec

A declarative, engine-agnostic specification language for AI-driven acceptance testing, plus the site that documents it.

A FlowSpec document describes user journeys — flows, checkpoints, semantic interactions, expected outcomes — and leaves *how* to perform them to an execution engine: an AI browser agent, a Playwright adapter, a mobile agent. FlowSpec is to AI acceptance testing what OpenAPI is to REST APIs.

## What's here

| File | Purpose |
|---|---|
| [`public/spec-final.md`](public/spec-final.md) | **The specification.** FlowSpec 1.0 — document format, actions, assertions, evidence, graph model, execution lifecycle, results output. |
| [`public/SKILL.md`](public/SKILL.md) | A condensed authoring skill for AI agents. Drop it into an agent's skills directory to have it write valid FlowSpec documents. |
| [`public/llms.txt`](public/llms.txt) | Machine-readable overview for LLMs, following the llms.txt convention. |
| `index.html` | The documentation site — renders the spec at runtime. |
| `spec-raw.md` | The original unrefined draft, kept for provenance. |

## Using FlowSpec

FlowSpec is a specification, not a test runner — there is no reference implementation yet. To adopt it:

1. **Annotate your UI.** Add `data-constell="component-name"` to every element a test must reach. Name by role, not appearance.
2. **Author a document.** Write a `.flowspec.json` file describing the journey. See §16 of the spec for a complete example.
3. **Run it.** Give an AI coding agent `SKILL.md` plus your document, or write a thin adapter mapping FlowSpec actions onto Playwright/Selenium.
4. **Consume the results.** Conformant engines write `flowspec-results/` — `report.json`, optional JUnit `report.xml`, and evidence artifacts referenced by relative path. Exit `0` passed, `1` failed, `2` errored.

## Running the site

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # → dist/
npm run preview  # serve the production build
```

Vite with no framework: one `index.html`, Tailwind via CDN, and `marked` + `mermaid` loaded as ESM to render the spec markdown at runtime. Editing `public/spec-final.md` updates the page — there is no second copy of the spec to keep in sync.

## Status

Spec version 1.0, **draft**. The document format is stable enough to author against; expect refinement of the runner-facing sections (§13–§14) as real engines are built.

## License

An open specification by Constell.
