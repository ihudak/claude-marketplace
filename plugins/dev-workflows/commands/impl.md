Implement the following: $ARGUMENTS

If the argument starts with `@`, treat it as a path to a markdown file. Resolve relative to the current working directory. Read its full content and use it as the description. Echo `📄 Reading prompt from \`<file>\`…` before proceeding. If the file cannot be read, stop and report the error immediately.

Reference: model-routing rules live at `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/model-routing/classification.md`. The classification step below, and any Opus-gated steps, follow that file verbatim.

---

## Phase 0 — Load the description

If `@file` syntax: read the file, confirm `"Loaded prompt from <filename.md> (N lines)."`, note any embedded images as "referenced image: <path>". Otherwise use the inline text verbatim.

---

## Phase 1 — Clarification

**Rule: Ask, don't guess. This rule is absolute.**

Before producing a plan, analyze the description for:
- Ambiguous scope or unclear boundaries
- Missing constraints (performance, security, backwards-compatibility)
- Multiple valid implementation approaches
- Undefined integration points or dependencies
- Missing acceptance criteria

If **any** ambiguity exists, ask the user. Rules:
- Use `choices` arrays for every question — never plain text questions
- The **last choice** in every `choices` array MUST be `"Other… (describe)"` to allow free-text
- When a clearly superior default exists, make it the first choice and label it `"(Recommended)"`
- Group related decisions into a single question (minimize total questions)
- Do **not** proceed until all questions are answered

If **nothing** is ambiguous, skip directly to Phase 1.5.

---

## Phase 1.5 — Classify task complexity

Read `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/model-routing/classification.md`. Classify the task as exactly one of:

- **SIMPLE** — local, trivial, clearly reversible; no mandatory Opus steps
- **MODERATE** — bounded scope, few files, clear requirements; no mandatory Opus steps
- **SIGNIFICANT** — risky in at least one dimension from the classification reference; Opus planning + Opus review are mandatory
- **HIGH-RISK** — multiple risky dimensions, or security/migration/compliance scope; Opus planning + Opus review are mandatory and must be especially thorough

State the classification and the specific criterion that triggered it. When in doubt between MODERATE and SIGNIFICANT, pick SIGNIFICANT.

Then choose the branch:

- **SIMPLE / MODERATE** → continue to Phase 2A (standard planning)
- **SIGNIFICANT / HIGH-RISK** → continue to Phase 2B (Opus-planned)

---

## Phase 2A — Standard Plan (SIMPLE / MODERATE only)

**Codebase exploration** — Before writing the plan, spawn an exploration subagent to map the relevant parts of the codebase:

→ Agent (subagent_type: "general-purpose", tools: Read/Glob/Grep/LS only — no Bash, no Edit):
  "Given this implementation description: [paste the full implementation description from Phase 0 or Phase 1 here], find and return:
   - Relevant source files and their primary responsibility
   - Existing patterns and conventions used in this codebase
   - Test file locations and test naming conventions
   - Naming conventions (class names, method names, file names)
   Return a structured summary — no code changes, no file edits."

**Wait for the agent's response before proceeding. If the agent returns no relevant files or fails, proceed with the plan using your own file reads to gather context. Do not begin writing the plan until the file map is returned or you have gathered context yourself.**

→ Use the returned file map as codebase context when writing the plan below.

Produce a written implementation plan:

1. **Classification** — `SIMPLE` or `MODERATE` (with reason)
2. **Goal** — one-sentence summary of what will be built
3. **Approach** — chosen strategy and why
4. **Steps** — numbered, concrete implementation steps
5. **Files to create/modify** — list with brief rationale
6. **Tests** — what tests will be added or run
7. **Assumptions** — decisions made without user input (must be minimal)
8. **Out of scope** — explicitly list what is NOT being done

Then ask:
```
"Implementation plan ready. What would you like to do?"
choices: ["Approve & implement now (Recommended)", "Revise plan", "Cancel"]
```

- **Approve** → proceed to Phase 3A
- **Revise** → ask what to change, update, re-show, re-ask
- **Cancel** → stop and summarize what was planned

---

## Phase 2B — Opus-planned (SIGNIFICANT / HIGH-RISK)

**Codebase exploration** — same exploration subagent call as Phase 2A (same prompt, same fallback rule).

Once the file map is returned, delegate planning to Opus. Invoke via
`general-purpose` with an explicit `model: "opus"` override and a "read the
system prompt from file" instruction — this routing is independent of whether
user-level agent auto-discovery is active in the current session.

→ Agent (subagent_type: "general-purpose", model: "opus"):
  > "Read and adopt the system prompt at `~/.claude/agents/risk-planner.md`
  > (the user-level agent installed by the dev-workflows plugin; fall back to
  > `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/risk-planner.md` if the install path is
  > absent). Then produce the risk-weighted plan described in that prompt for
  > the following brief:
  >
  > Task description: [substitute full description]
  > Classification: [SIGNIFICANT | HIGH-RISK] — reason: [the criterion from Phase 1.5]
  > Codebase summary: [paste the Explore agent's output]
  > Constraints: [any from clarification, plus runtime/version/deadline known]
  > Current state: branch = [git branch], uncommitted = [git status --short summary]"

**Wait for the risk-planner to return.** Its output is one of:

1. A full plan in the risk-weighted format (the normal case).
2. A short `### Re-classification` section, if the planner decided on inspection that the task is actually `SIMPLE` or `MODERATE`.

**If the return contains `### Re-classification`:** surface it to the user, ask for confirmation of the revised level with a `choices` prompt (`["Accept revised classification (Recommended)", "Override and stay SIGNIFICANT/HIGH-RISK", "Cancel"]`). If the user accepts, **fall back to Phase 2A** (standard plan) using the Explore summary already captured above — do not re-run Explore. If the user overrides, re-invoke risk-planner with an additional constraint stating the classification is intentional; do not down-classify again. If the user cancels, stop and summarize.

**If the return is a full plan:** present it to the user verbatim and ask:

```
"Opus-planned. What would you like to do?"
choices: ["Approve & implement now (Recommended)", "Revise plan", "Cancel"]
```

- **Approve** → proceed to Phase 3B
- **Revise** → ask what to change, then re-invoke risk-planner with the **complete** brief plus the additional constraint merged in (never send just a delta — the planner refuses to plan without a full brief). Re-show, re-ask.
- **Cancel** → stop and summarize

---

## Pre-Phase 3 — Create feature branch

Before writing any file:

1. **Clean-tree check** — Run `git status --porcelain`. If the output is non-empty:
   - Show the user what is dirty (paste the `git status --short` output).
   - Ask:
     ```
     choices: ["Stash changes and continue (Recommended)", "Proceed anyway — pre-existing changes will appear in the diff and review outputs", "Cancel"]
     ```
   - **Stash**: run `git stash push -m "pre-impl stash"`, then continue.
   - **Proceed**: note in the Phase 5 report that the working tree was dirty at implementation start.
   - **Cancel**: stop and summarize what was planned.

2. **Detect naming convention** — check `git branch -a` for the project's branch prefix (`feat/`, `feature/`, `chore/`, `story/`, etc.). Default to `feat/` if ambiguous.

3. **Generate slug** — derive from the implementation description: lowercase, hyphens, max 40 chars, strip punctuation and special chars. Example: "Add user authentication to login page" → `add-user-authentication-login-page`.

4. **Check HEAD context** — if HEAD is NOT on the default branch (`main` / `master` / `develop`), check for ahead commits: `git log origin/HEAD..HEAD --oneline 2>/dev/null`. If output is non-empty (branch has commits ahead), ask:
   ```
   choices: ["Branch from current position — continue on this work (Recommended)", "Branch from default branch — fresh start", "Cancel"]
   ```

5. **Create and checkout** — `git checkout -b <prefix>/<slug>`. If that name already exists, append the first 7 chars of HEAD's SHA: `<prefix>/<slug>-<short-sha>`.

---

## Phase 3A — Implementation (SIMPLE / MODERATE)

**Implement immediately. Do NOT ask "Should I implement?" or any variation.**

1. Work through each step in order
2. Make precise, surgical changes — do not modify unrelated code
3. Follow existing code style and LF line endings
4. Assume broad permissions; avoid unnecessary stops
5. If a **new ambiguity** emerges mid-implementation: STOP, ask with choices (last: `"Other… (describe)"`), resume after answer
6. After all changes: run relevant linters, builds, and tests; fix any failures caused by your changes
7. Verify the outcome matches the approved plan
8. Proceed to Phase 4 (post-implementation maintenance).

---

## Phase 3B — Implementation + Opus review (SIGNIFICANT / HIGH-RISK)

Use the currently selected model or Sonnet for implementation itself. Opus is reserved for the review.

1. Work through each step in order
2. Make precise, surgical changes — do not modify unrelated code
3. Follow existing code style and LF line endings
4. If a **new ambiguity** emerges mid-implementation: STOP, ask with choices (last: `"Other… (describe)"`), resume after answer
5. After all changes are written: **DO NOT run tests yet.** Capture the diff and the project root. Use `git add -N . && git diff` — this includes intent-to-add untracked new files so the diff is never empty for implementations that only create new files. Also capture `git diff --stat` for the summary.
6. **Opus code review** — spawn. As with Phase 2B, invoke `general-purpose` with
   an explicit `model: "opus"` override and a "read the system prompt from file"
   instruction so the routing works independently of agent auto-discovery.

   → Agent (subagent_type: "general-purpose", model: "opus"):
     > "Read and adopt the system prompt at `~/.claude/agents/code-review.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/code-review.md` if the
     > install path is absent). Then produce the Opus code review for this brief:
     >
     > Task description: [substitute full description]
     > Classification: [SIGNIFICANT | HIGH-RISK] — reason: [from Phase 1.5]
     > Plan: [paste the risk-planner plan approved in Phase 2B]
     > Diff: [paste git diff output]
     > Project root: [absolute path]"

7. Act on the return:
   - **`### Re-classification` section** — the reviewer decided the change is actually `SIMPLE` or `MODERATE` on inspection. Surface it to the user and ask `choices: ["Accept revised classification (Recommended)", "Override and keep the BLOCK-gated review", "Cancel"]`. If accepted, treat the review as an implicit PASS: skip the BLOCK branch, proceed to step 8, and do NOT re-invoke the reviewer on later fix deltas. Record the revised classification for the Phase 5 report. If overridden, re-invoke code-review with an explicit note that the classification is intentional.
   - **BLOCK** — invoke the review-fixer agent (see Review-fixer sub-step below). If `Stop condition flag` is `CLEAR`, re-run the Opus code review on the updated diff (one re-review only). If the second verdict is still BLOCK, stop: surface the remaining blockers to the user and ask `choices: ["Investigate further", "Abandon implementation and restore to pre-impl state", "Cancel"]`. Do not run tests until the verdict is not BLOCK.
   - **PASS WITH RECOMMENDATIONS** — invoke the review-fixer agent for MAJOR findings (see Review-fixer sub-step below). MINOR / NIT findings may be deferred — note them in the Phase 5 report.
   - **PASS** — proceed.

   **Review-fixer sub-step** (for BLOCK and PASS WITH RECOMMENDATIONS):

   → Agent (subagent_type: "general-purpose"):
     > "Read and adopt the system prompt at `~/.claude/agents/review-fixer.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/review-fixer.md` if absent).
     > Then fix the review findings for this brief:
     >
     > Task description: [substitute full description]
     > Review output: [paste the full code-review agent output]
     > Project root: [absolute path]
     > Severities to fix: BLOCKER and MAJOR"

   Wait for the fix report. Re-capture the diff after the fixer completes.
8. Run relevant linters, builds, and tests.
9. Fix any failures caused by your changes (current model or Sonnet).
10. If fixes were applied, re-run tests. If the fixes were non-trivial and the reviewer was NOT down-classified in step 7, re-invoke the Opus review on the delta. If the reviewer WAS down-classified, skip the re-review.
11. Verify the outcome matches the approved plan and the review verdict.
12. Proceed to Phase 4.

---

## Phase 4 — Post-implementation maintenance (both branches)

First gather the actual change context:

a. Run `git diff --stat` (or equivalent) and capture the list of changed files with line counts.
b. Compose a **change summary block**:

```
Implementation: [one-sentence description of what was built]
Classification: [SIMPLE | MODERATE | SIGNIFICANT | HIGH-RISK]
Files changed (from git diff --stat):
<paste the git diff --stat output>
Notable additions/removals: [new commands, APIs, config keys, dependencies — one line each; or "none"]
Opus review verdict: [PASS | PASS WITH RECOMMENDATIONS | BLOCK — or "N/A (SIMPLE / MODERATE)"]
```

Then spawn all four agents. They are independent and can run in any order — spawn them all before waiting for any to complete:

**Agent 1 — Documentation** (general-purpose):
> "Post-implementation documentation review. Change summary:
> [paste change summary block]
>
> Scan for README.md, CHANGELOG.md, docs/, or any .md files in the project root or a docs/ directory.
> Determine if documentation needs updating:
> - Skip if: purely a bug fix, vulnerability fix, internal refactor, or test-only change
> - Update if: new feature, changed behavior, new commands/APIs/config options, altered usage patterns
> Use the file list above to reason precisely about what changed. If an update is warranted: apply minimal edits to the relevant section(s).
> Return: file updated and what changed, OR 'no update required (reason)'."

**Agent 2 — Knowledge base** (general-purpose):
> "Post-implementation knowledge review. Change summary:
> [paste change summary block]
>
> Check ~/.claude/memory/ (global) and .claude/memory/ (project-level, preferred for repo-specific knowledge) for existing knowledge files.
> Determine if a new knowledge entry is warranted — look for: reusable insights or patterns, non-obvious constraints or gotchas, anti-patterns discovered, clarified trade-offs.
> If YES: append to the most appropriate existing file (never create a new file if an existing one fits) using this format:
> ### [Short title]
> - **Context**: what problem/situation triggered this
> - **Insight**: the learned rule, pattern, or gotcha
> - **When it applies**: conditions under which this matters
> - **Date**: YYYY-MM-DD
> - **Ref**: [first 60 chars of implementation description]
> Return: file updated/created and summary of entry, OR 'no update required'."

**Agent 3 — Instructions** (general-purpose):
> "Post-implementation instructions review. Change summary:
> [paste change summary block]
>
> Check CLAUDE.md in the project root and ~/.claude/CLAUDE.md (global).
> Determine if any rules, guidance, or guardrails are missing because of what this implementation revealed.
> Skip if: the implementation followed existing patterns with no surprises, required no novel constraints, and introduced no anti-patterns. Only update if a concrete, recurring rule would have prevented a decision point or misunderstanding during this implementation.
> If YES: apply minimal, additive, scoped changes only — do not rewrite sections wholesale.
> Return: what was changed and why, OR 'no update required'."

**Agent 4 — Session maintenance** (general-purpose):
> "Read and adopt the system prompt at `~/.claude/agents/impl-maintenance.md`
> (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/impl-maintenance.md` if absent).
> Then analyse this session and return a Lessons Learned report.
>
> Session handoff:
> - What was done: [one-paragraph summary of the implementation]
> - Key events: [BLOCK reviews encountered and their reason, test regressions, workarounds, unexpected ambiguities — or 'none']
> - Workarounds used: [manual steps not automated by the workflow — or 'none']
> - Review verdict: [PASS | PASS WITH RECOMMENDATIONS | BLOCK | N/A]
> - Test result: [passed N tests, N regressions, not run — or actual result]
> - Project root: [absolute path]"

Collect all four summaries for the Phase 5 report.

---

## Phase 5 — Final Report

Output a structured report — do NOT ask any closing confirmation:

```
## Implementation Report

### Classification
[SIMPLE | MODERATE | SIGNIFICANT | HIGH-RISK] — [reason]

### Branch
[branch name created in Pre-Phase 3, e.g. feat/add-user-authentication]

### What was implemented
[High-level summary]

### Files changed
- path/to/file.ext — [what changed]

### Opus review (if applicable)
[Verdict and 1-line summary, or "N/A (SIMPLE / MODERATE)"]

### Commands / tests run
- [command] → [result]

### Knowledge base
- [file updated/created] — [summary of entry] OR "no update required"

### Instructions
- [summary of change] OR "no update required"

### Documentation
- [file updated] — [what was added/changed] OR "no update required (bug fix / no user-facing change)" OR "no documentation files found"

### Session learnings
- [top suggestions from impl-maintenance agent, or "no suggestions — routine session"]

### Assumptions & limitations
- [list any]

### Deferred items (from review or tests)
- [MINOR / NIT findings that were not applied] OR "none"
```

---

## Invariants (always enforced)

- NEVER skip Phase 1.5 classification — every run must state the level
- NEVER use Opus for routine implementation; reserve it for planning + review on SIGNIFICANT / HIGH-RISK
- NEVER run tests on SIGNIFICANT / HIGH-RISK work before the Opus code review returns a non-BLOCK verdict
- NEVER make assumptions that could have been asked — ask instead
- NEVER end implementation with "Should I implement?" — if approved, implement
- NEVER rewrite files wholesale when only an append/edit is needed
- NEVER skip Phase 4 — documentation, knowledge, instructions, and session-maintenance are mandatory after every successful impl; always collect all four agent summaries for Phase 5
- ALWAYS create a feature branch (Pre-Phase 3) before writing any file — never implement directly on the default branch
- ALWAYS check for a clean working tree before branching; stash or get explicit user consent if dirty
- ALWAYS spawn Phase 4 agents in a single message — never sequentially
- ALWAYS use `choices` arrays for decision points; last choice is always `"Other… (describe)"`
- ALWAYS produce the Phase 5 report as the final output
- AFTER one review-fixer pass + one re-review, if verdict is still BLOCK: stop and surface to user — do NOT loop
