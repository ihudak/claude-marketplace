# planning

Two pre-implementation planning skills for turning vague ideas into solid, risk-aware plans.

## Skills

### discovery-interview

Transforms a vague idea into a detailed, implementable specification through a structured 6-phase interview: orientation, category-by-category deep dive (problem, UX, data, technical landscape, scale, integrations, security, deployment), research loops for knowledge gaps, conflict resolution, completeness check, and spec generation. Writes the spec to `specs/YYYY-MM-DD-<name>.md` in the project root, or `/specs/` if that directory is externally mounted. Use when starting a new project or feature with unclear requirements. Runs on Opus for maximum reasoning depth.

### premortem

Identifies failure modes before implementation using Gary Klein's pre-mortem technique with Shreyas Doshi's Tiger/Paper Tiger/Elephant risk framework. Supports quick mode (plans, PRs) and deep mode (full implementation review). Requires evidence before flagging any risk — a two-pass process that filters false positives. Use before starting implementation on any non-trivial task.
