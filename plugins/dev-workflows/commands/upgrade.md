Upgrade components: $ARGUMENTS

Each token is one of: `component:1.2.3` (exact), `component:minor` (latest patch on current minor), `component:latest` (latest stable), `component:lts` (latest LTS), or bare `component` (latest compatible with everything else).

`component` can be a library, framework, language runtime, build tool, or path like `.github/workflows`.

Reference files (read when needed):
- Ecosystem detection and update commands: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/upgrade/ecosystems.md`
- LTS lookup sources: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/upgrade/lts-sources.md`
- Compatibility constraints: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/upgrade/compatibility.md`
- Model routing: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/model-routing/classification.md`

All changes are left **uncommitted** on the current branch.

---

## Phase 1 — Compatibility Planning (no files changed)

1. **Inventory** — Detect all components and their current versions (build files, runtime version files, CI YAML). See `ecosystems.md`.

2. **Resolve** — For each token, determine the candidate target version. See "Version resolution" below.

3. **Research (parallel)** — Spawn two agents simultaneously:

   **Agent A** (general-purpose, needs WebFetch/WebSearch tools):
   > "For each component being upgraded: [list with current → target versions fetched in steps 1–2]. Fetch release notes and changelogs. Return per component:
   > - Known breaking changes
   > - Required companion upgrades (e.g. Spring Boot major → Hibernate, Mockito)
   > - Compatibility with other components in this upgrade set
   > - Any Java/Node/Python runtime version requirements"

   **Agent B** (general-purpose, needs Read/Glob/Grep tools — **read-only; do NOT apply changes**) — **only spawn if `.github/workflows/` exists in the repository**:
   > "Scan all `.yml`/`.yaml` files in `.github/workflows/`. For each `uses: owner/action@ref`, resolve the latest release tag:
   >   1. Try: `gh api repos/<owner>/<action>/releases/latest --jq .tag_name`
   >   2. If `gh` is not available or not authenticated, fall back to: `curl -s https://api.github.com/repos/<owner>/<action>/releases/latest | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get(\"tag_name\",\"\"))'`
   >   3. If both fail, use the REST response from `https://api.github.com/repos/<owner>/<action>/releases/latest`.
   > Return a **proposed change list only** — do NOT edit any files:
   >   - action ref, current version → proposed version
   >   - flag any major version bumps"

   After both agents complete, merge their reports into the upgrade plan before presenting it for user confirmation.

4. **Compatibility check** — Review the Agent A output for breaking changes and incompatibilities; if any, apply the conflict resolution logic below.

5. **Classify each component** — Apply `references/model-routing/classification.md` to each component in this upgrade set. Use the actual change required, not the component's popularity or size.

   | Condition on the upgrade | Classification |
   |---|---|
   | Same-major version bump, no documented breaking changes, no companion upgrades required | `MODERATE` |
   | GitHub Actions `uses:` bumps (Agent B's output) | `MODERATE` (en bloc) |
   | Major version bump, OR breaking changes flagged by Agent A, OR companion upgrades required, OR runtime (Java/Node/Python) upgrade, OR build-tool (Maven/Gradle/npm) upgrade | `SIGNIFICANT` / `HIGH-RISK` |
   | Any upgrade that touches security-sensitive code paths (auth, crypto, session, payment), migration logic, or framework-level components (Spring Boot, Rails, Next.js) | `HIGH-RISK` |

   If unsure, err toward `SIGNIFICANT`.

   Print a classification line per component:
   ```
   springboot 3.1.4 → 3.3.11: HIGH-RISK (framework major-minor bump, companion upgrades required)
   java 17 → 21: SIGNIFICANT (runtime major bump)
   commons-text 1.10.0 → 1.11.0: MODERATE (same-major, no breaking changes)
   ```

6. **Detect conflicts** — If any incompatibility is found, do NOT proceed. Instead:
   - Explain the conflict clearly (e.g. "Gradle 9 requires Java 17+, but the repo uses Java 11")
   - Offer concrete, ranked alternatives:
     - **Option A** — Lower the conflicting component to the highest compatible version
     - **Option B** — Upgrade the blocking dependency too (suggest version)
     - **Option C** — Skip this component
   - Ask the user to choose before continuing

7. **Opus planning for SIGNIFICANT / HIGH-RISK components** — For every component flagged `SIGNIFICANT` or `HIGH-RISK`, invoke `general-purpose` with `model: "opus"` override and the risk-planner system prompt loaded from file. The planner will do its own usage-site scan; the caller does not pre-compute that. Run all Opus planning agents in parallel.

   → Agent (subagent_type: "general-purpose", model: "opus"):
     > "Read and adopt the system prompt at `~/.claude/agents/risk-planner.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/risk-planner.md` if absent).
     > Then produce the risk-weighted plan for:
     >
     > Task description: Upgrade [component] from [current version] to [target version] in this repo.
     > Classification: [SIGNIFICANT | HIGH-RISK] — reason: [the criterion from step 5]
     > Codebase summary: inventory found the component in: [list of file paths from the Phase 1 step 1 inventory]. Release-notes and compat findings from Agent A: [paste Agent A's output for this component — breaking changes, companion upgrades, runtime requirements].
     > Constraints: [companion upgrades required; runtime version; any compatibility notes from Agent A]
     > Current state: branch = [git branch], uncommitted = [git status --short summary]
     >
     > Before writing the plan, grep the repo for import sites and usage patterns of this component to understand the blast radius. Pay particular attention to: breaking API changes, migration order, test coverage of usage sites, rollback."

   **If the risk-planner returns a `### Re-classification` section** for any component (planner decided on inspection the upgrade is actually `MODERATE`), surface it and ask `choices: ["Accept revised classification (Recommended)", "Override and keep SIGNIFICANT/HIGH-RISK path", "Cancel component"]`. If accepted, drop that component to the MODERATE path for Phase 2 (standard apply → build → test with no Opus review gate). If overridden, re-invoke with the complete brief plus a note that the classification is intentional. Do not send a delta-only re-invocation.

   Otherwise, present the full upgrade plan (including all Opus component plans) to the user.

8. **Confirm plan** — Present the complete plan (per-component classification + Opus plans for SIGNIFICANT/HIGH-RISK) and ask for confirmation:
   ```
   "Ready to apply. What would you like to do?"
   choices: ["Approve & apply now (Recommended)", "Revise plan", "Cancel"]
   ```
   Do not touch any files until the user approves.

### Version Resolution

| Token | Resolution |
|---|---|
| `component:1.2.3` | Use exact version; verify it exists; run compatibility check; surface conflicts (never silently downgrade) |
| `component:minor` | Latest stable patch within current `MAJOR.MINOR.*` |
| `component:latest` | Highest stable release; run compatibility check |
| `component:lts` | Consult official LTS source (see `lts-sources.md`); if lookup fails, ask the user |
| bare `component` | Highest version compatible with all other repo components; report conflict if none found |

---

## Phase 2 — Execution (after user confirms)

### Phase 2 prep (once)

1. **Create feature branch**
   - Run `git status --porcelain`. If the output is non-empty:
     - Show the user what is dirty.
     - Ask:
       ```
       choices: ["Stash changes and continue (Recommended)", "Proceed anyway — pre-existing changes will appear in the diff and review outputs", "Cancel"]
       ```
     - **Stash**: `git stash push -m "pre-upgrade stash"`, then continue. **Cancel**: stop.
   - Generate the branch name:
     - Single component: `chore/upgrade-<component>-to-<version>` (e.g. `chore/upgrade-springboot-to-3.3.11`)
     - Multiple components: `chore/upgrade-<first>-and-<N>-more` (e.g. `chore/upgrade-springboot-and-2-more`)
     - Check `git branch -a` for the project's prefix convention; default to `chore/`.
   - Check HEAD context: if HEAD is NOT on the default branch and has ahead commits (`git log origin/HEAD..HEAD --oneline 2>/dev/null` is non-empty), ask:
     ```
     choices: ["Branch from current position (Recommended)", "Branch from default branch", "Cancel"]
     ```
   - Run `git checkout -b <branch-name>`. If it already exists, append `-<7-char-sha>`.

2. **Capture baseline tests** — Invoke `general-purpose` with the test-baseline system prompt loaded from file:

   → Agent (subagent_type: "general-purpose"):
     > "Read and adopt the system prompt at `~/.claude/agents/test-baseline.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/test-baseline.md` if absent).
     > Then run in **capture** mode in [project root] and return the structured baseline result."
     >
     > If neither path exists, warn the user to run `install.sh` and skip the baseline step.

   Store the returned baseline; reuse for ALL component comparisons in this Phase 2 run. Do not re-run the baseline per component — this snapshot is captured on the pristine branch, before Agent B changes and component upgrades.

3. **Apply Agent B changes** (if Agent B ran in Phase 1 step 3) — Apply the proposed `.github/workflows/` changes from Agent B's report. These are MODERATE changes and do not require a code review gate. Note the files changed in the summary.

### Per-component loop (for each component, in order)

1. **Detect** — Find the component. See `ecosystems.md`. If not found, warn and skip.

2. **Plan changes** — Identify all files that must change (build files, lock files, wrapper scripts, config, Docker base images, CI YAML — excluding `.github/workflows/` action refs applied in Phase 2 prep step 3).

3. **Apply** — Make the changes per `ecosystems.md` update commands.

4. **Companion upgrades** — Apply automatically and note in summary (e.g. Spring Boot major bump may require Hibernate, Mockito).

   > **Max depth**: 3 levels of transitive companion upgrades. Track visited components; if a companion upgrade would re-introduce a component already in the visited set at a different version, stop and report the cycle in the summary table (Status = `BLOCKED — companion-cycle`). Do not loop.

5. **Branch on classification:**

   **MODERATE components** → go to step 6 directly (build, then test).

   **SIGNIFICANT / HIGH-RISK components** → perform an Opus code review BEFORE building/testing:

   a. Capture the diff for this component (and the companion-upgrade diffs applied in step 4). Use `git add -N . && git diff` to include any newly-created untracked files.
   b. Spawn the reviewer — `general-purpose` with `model: "opus"` override and the code-review system prompt loaded from file:
      → Agent (subagent_type: "general-purpose", model: "opus"):
        > "Read and adopt the system prompt at `~/.claude/agents/code-review.md`
        > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/code-review.md` if absent).
        > Then produce the Opus code review for this brief, focusing on migration order, breaking API changes, missed usage sites, dependency risk, rollback:
        >
        > Task description: Upgrade [component] from [current] to [target] and any companion upgrades applied alongside it.
        > Classification: [SIGNIFICANT | HIGH-RISK]
        > Plan: [paste the Opus plan from Phase 1 step 7]
        > Diff: [paste git diff output]
        > Project root: [absolute path]"
   c. Act on the return:
      - **`### Re-classification` section** — reviewer decided this component is actually `MODERATE`. Surface it, ask `choices: ["Accept revised classification (Recommended)", "Override and keep BLOCK-gated review", "Cancel component"]`. If accepted, drop this component to the MODERATE path — treat as implicit PASS, proceed to step 6, skip the re-review on later fix deltas. Record the revised classification for the summary table.
      - **BLOCK** — invoke the review-fixer agent (see Review-fixer sub-step below). If `Stop condition flag` is `CLEAR`, re-run the Opus code review on the updated diff (one re-review only). If the second verdict is still BLOCK, stop: surface the remaining blockers to the user and ask `choices: ["Investigate further", "Revert this component and skip it", "Cancel"]`. Do NOT proceed to step 6 until verdict is not BLOCK.
      - **PASS WITH RECOMMENDATIONS** — invoke the review-fixer agent for MAJOR findings (see Review-fixer sub-step below). MINOR / NIT may be deferred.
      - **PASS** — proceed.

      **Review-fixer sub-step** (for BLOCK and PASS WITH RECOMMENDATIONS):

      → Agent (subagent_type: "general-purpose"):
        > "Read and adopt the system prompt at `~/.claude/agents/review-fixer.md`
        > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/review-fixer.md` if absent).
        > Then fix the review findings for this brief:
        >
        > Task description: Upgrade [component] from [current] to [target].
        > Review output: [paste the full code-review agent output]
        > Project root: [absolute path]
        > Severities to fix: BLOCKER and MAJOR"

      Wait for the fix report. Re-capture the diff after the fixer completes.

6. **Build** — Run the build command (no tests yet). If build fails, see "Handling build failures".

7. **Test** — Run full test suite.

8. **Compare** — Invoke `general-purpose` with the test-baseline system prompt in **verify** mode, passing the baseline captured in Phase 2 prep step 2:
   > "Read and adopt the system prompt at `~/.claude/agents/test-baseline.md`
   > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/test-baseline.md` if absent).
   > Run in **verify** mode. Baseline: [paste the captured baseline block]."

   Act on the verify report:
   - If `Regressions` or `Missing from run` lists any tests: see "Handling test failures"
   - If `Comparison status: invalid`: warn the user and ask for manual review before continuing
   - If fixes were applied and the component was STILL classified SIGNIFICANT / HIGH-RISK after step 5 (i.e. was NOT down-classified by the reviewer), re-invoke the Opus code review on the delta before re-running tests. If it was down-classified, skip the re-review.

After all components: print the summary table (Output section). Then invoke the session-maintenance agent.

### Post-batch maintenance

→ Agent (subagent_type: "general-purpose"):
  > "Read and adopt the system prompt at `~/.claude/agents/impl-maintenance.md`
  > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/impl-maintenance.md` if absent).
  > Then analyse this session and return a Lessons Learned report.
  >
  > Session handoff:
  > - What was done: [summary: N components upgraded — list each component, from→to, classification, outcome (OK/SKIPPED/BLOCKED)]
  > - Key events: [BLOCK reviews and their reasons, test regressions, build failures, workarounds, compatibility surprises, missing reference docs — or 'none']
  > - Workarounds used: [manual steps not automated — or 'none']
  > - Overall result: [N upgraded, N skipped, N blocked]
  > - Project root: [absolute path]"

Include the Lessons Learned report after the summary table.

### Handling Test Failures

1. Inspect — determine if caused by breaking API change in the upgraded component
2. Auto-fix test code if straightforward (rename import, update assertion syntax, adjust config); explain every test change in the summary
3. If not auto-fixable, ask:
   > "These tests were passing before. Would you like me to: (1) Keep the upgrade and leave the failing tests for you to fix, (2) Revert this upgrade and skip it, (3) Investigate further?"

### Handling Build Failures

1. Read the full error output
2. Attempt auto-fix (wrong API, missing plugin version, incompatible config)
3. If unfixable: revert this component, warn the user, continue with the next

---

## Output

```
## Upgrade Summary

| Component  | Before | After  | Class       | Review | Status  | Notes                       |
|------------|--------|--------|-------------|--------|---------|-----------------------------|
| springboot | 3.1.4  | 3.3.11 | HIGH-RISK   | PASS   | OK      | Also upgraded hibernate 6.4 |
| java       | 17     | 21     | SIGNIFICANT | PASS W/RECS | OK | Updated 2 test files        |
| commons-text | 1.10 | 1.11   | MODERATE    | N/A    | OK      |                             |
| redis      | -      | -      | -           | -      | SKIPPED | Not found in project        |

Tests: 142 passed, 0 regressions (baseline: 142 passing)
```

---

## Invariants (always enforced)

- NEVER skip per-component classification in Phase 1 step 5
- NEVER use Opus for a MODERATE component upgrade unless the user explicitly requests it
- NEVER run tests on a SIGNIFICANT / HIGH-RISK component before the Opus code review returns a non-BLOCK verdict
- NEVER modify any files during Phase 1 (Agent B must return a proposed change list, not apply changes)
- NEVER touch any file before creating and checking out the upgrade branch (Phase 2 pre-steps)
- ALWAYS check for a clean working tree before branching; stash or get explicit user consent if dirty
- ALWAYS capture the baseline in Phase 2 prep step 2 (before Agent B and component changes)
- ALWAYS include the classification column in the final summary table
- ALWAYS compare against the Baseline captured once at the start of Phase 2 — use verify mode from test-baseline agent
- NEVER follow a companion-upgrade chain deeper than 3 levels; treat as a cycle and surface to the summary table
- AFTER one review-fixer pass + one re-review, if verdict is still BLOCK: stop and surface to user — do NOT loop
