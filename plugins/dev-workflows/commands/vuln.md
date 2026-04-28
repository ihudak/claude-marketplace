Fix security vulnerabilities: $ARGUMENTS

Each argument token is either `JIRA-ID:CVE-ID` (e.g. `MGD-2423:CVE-2023-46604`) or a bare `CVE-ID` (e.g. `CVE-2023-46604`). Parse and filter each token (steps 1–2), then research all CVEs in two parallel rounds (step 3) before applying fixes sequentially (steps 5 onward).

Reference files (read when needed):
- Build system detection: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/fix-vuln/build-systems.md`
- NVD API usage: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/fix-vuln/nvd-api.md`
- Model routing: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/model-routing/classification.md`

---

## Workflow

For each vulnerability token:

1. **Parse** — Extract JIRA-ID (optional) and CVE-ID.
   - `JIRA-ID:CVE-ID` format when the part before `:` matches `[A-Z]+-\d+`
   - Bare CVE-ID otherwise
   - Determine NOJIRA placeholder once: scan `git log --oneline -50` and `git branch -a` for patterns like `NOJIRA`. Use it in branch names where applicable; omit entirely if history is ambiguous.

2. **Filter** — Skip non-CVE IDs (CWE-*, OWASP `\d{4}:A\d{2}`). Warn and continue.

3. **Research — two sequential rounds:**

   **Round A (parallel — no package name needed):**

   Spawn all of the following simultaneously in a single message:

   - **NVD agent per CVE-ID** (general-purpose, needs WebFetch/WebSearch):
     > "Fetch CVE details for [CVE-ID] using the NVD API. Reference: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/fix-vuln/nvd-api.md`.
     > Return: affected package name, vulnerable version range, minimum safe version, one-line CVE description."

   - **Baseline agent** (once per batch, not per CVE) — invoke via `general-purpose` with
     the test-baseline system prompt loaded from file:
     > "Read and adopt the system prompt at `~/.claude/agents/test-baseline.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/test-baseline.md` if absent).
     > Then run in **capture** mode and return the structured baseline result."
     >
     > If neither path exists, warn the user to run `install.sh` and skip the baseline step.

   **Wait for all Round A agents to complete before proceeding.**

   **Round B (parallel — package names now known):**

   For each CVE where the NVD agent returned a package name, spawn a Detect agent. Skip any CVE where NVD failed, flag it individually, and do not block the rest of the batch.

   - **Detect agent per CVE** (general-purpose, needs Read/Glob/Grep/LS tools):
     > "Scan this repository for the dependency [package name returned by NVD for CVE-ID].
     > Check all build and manifest files: pom.xml, build.gradle, build.gradle.kts, package.json, requirements.txt, go.mod, Cargo.toml, *.csproj, Gemfile, composer.json.
     > Reference: `~/.claude/plugins/data/dev-workflows@claude-marketplace/references/fix-vuln/build-systems.md`.
     > Return: current version in use, file paths where the dependency appears."

   **Wait for all Round B agents to complete before proceeding.**

4. **Merge research results** — Combine the agent outputs: CVE details, current library version, safe target version. For each CVE, confirm a fix is needed (current version falls within the vulnerable range). Skip with a warning if the library is not found in the repo. Log NVD-failed CVEs as unresolved.

5. **Classify each CVE fix** — For every CVE that requires a fix, apply the routing rules from `references/model-routing/classification.md`. Decide based on the ACTUAL change required, not the CVE's CVSS score.

   | Condition on the fix | Classification |
   |---|---|
   | Same-major version bump (e.g. `2.14.1 → 2.14.3`, `2.14.x → 2.15.0`), library used as a drop-in, no consumer-code change expected | `MODERATE` |
   | Major version bump (e.g. `2.x → 3.x`), OR the new version has documented API changes that will require code edits, OR the library is used in security-sensitive code paths (auth, crypto, session, payment) | `SIGNIFICANT` / `HIGH-RISK` |

   If unsure, err toward `SIGNIFICANT`. Print the classification and the reason before touching files.

6. **Version** — Safe target version is the minimum safe version returned by the NVD agent. If ambiguous, use the lowest fixed version in the CVE's affected range.

7. **Baseline** — Already captured by the Baseline agent in step 3. Do not re-run the test suite.

---

## Sequential fix — MODERATE path

For CVEs classified `MODERATE`, fix one at a time:

1. **Create branch** — Before touching any file:
   - Run `git status --porcelain`. If dirty, ask:
     ```
     choices: ["Stash changes and continue (Recommended)", "Proceed anyway — pre-existing changes will appear in the diff and PR", "Cancel"]
     ```
     If Stash: `git stash push -m "pre-fix stash"`. If Cancel: skip this CVE.
   - Determine branch name (see **Git Workflow** section below for naming rules).
   - Run `git checkout -b <branch-name>`. If the branch already exists, append `-<7-char-sha>`.

2. **Fix** — Apply the minimal version change (patch/minor).
3. **Verify** — Build the project. (Tests come after — see step 5 below.)
4. **Run tests** — Re-run the test suite.
5. **Compare** — Invoke `general-purpose` with the test-baseline system prompt in **verify** mode, passing the baseline captured in Research step 3:
   > "Read and adopt the system prompt at `~/.claude/agents/test-baseline.md`
   > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/test-baseline.md` if absent).
   > Run in **verify** mode. Baseline: [paste the captured baseline block]."

   If `Regressions` or `Missing from run` lists any tests: present them clearly and ask the user to choose — proceed anyway, revert, or investigate further.
6. **Commit & PR** — See the Git Workflow section.

---

## Sequential fix — SIGNIFICANT / HIGH-RISK path

For CVEs classified `SIGNIFICANT` or `HIGH-RISK`, fix one at a time:

1. **Create branch** — Same rules as the MODERATE path step 1: clean-tree check → stash/proceed/cancel → `git checkout -b <branch-name>`.

2. **Plan with Opus** — Invoke `general-purpose` with `model: "opus"` override and the risk-planner system prompt loaded from file. The planner will do its own usage-site scan — the Detect agent only returned declaration paths, not import sites.

   → Agent (subagent_type: "general-purpose", model: "opus"):
     > "Read and adopt the system prompt at `~/.claude/agents/risk-planner.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/risk-planner.md` if absent).
     > Then produce the risk-weighted plan for:
     >
     > Task description: Remediate [CVE-ID] in [repo name]. Upgrade [library] from [current version] to [target version]. [One-line CVE description.]
     > Classification: [SIGNIFICANT | HIGH-RISK] — reason: [from step 5]
     > Codebase summary: Detect agent found the dependency declared in: [list of declaration file paths from step 3]. Current version: [current]. Target version: [target].
     > Constraints: keep breaking changes out of consumer code if avoidable; if unavoidable, enumerate them.
     > Current state: branch = [git branch], uncommitted = [git status --short summary]
     >
     > Before writing the plan, grep the repo for import sites and usage patterns of this library to understand the blast radius of a version bump / API change."

   **If the risk-planner returns a `### Re-classification` section** instead of a full plan (it decided the CVE fix is actually `MODERATE` on inspection — e.g. a drop-in patch bump with no consumer-code change), surface it and ask `choices: ["Accept revised classification (Recommended)", "Override and keep HIGH-RISK path", "Cancel"]`. If accepted, fall back to the MODERATE path for this CVE. If overridden, re-invoke with the complete brief plus a note that the classification is intentional. Do not send a delta-only re-invocation.

   Otherwise, present the plan to the user and ask for approval before touching files.

3. **Apply the fix** — With current model or Sonnet. Version bump + any code changes per the plan. No tests yet.

4. **Opus code review** — Capture the full diff for this CVE fix. Use `git add -N . && git diff` (this includes intent-to-add untracked new files; unlike bare `git diff`, it won't produce an empty diff for implementations that only create new files). Then invoke `general-purpose` with `model: "opus"` override and the code-review system prompt loaded from file:

   → Agent (subagent_type: "general-purpose", model: "opus"):
     > "Read and adopt the system prompt at `~/.claude/agents/code-review.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/code-review.md` if absent).
     > Then produce the Opus code review for this brief, focusing especially on security, dependency risk, migration (library API changes), and rollback:
     >
     > Task description: Remediate [CVE-ID] — upgrade [library] from [current] to [target].
     > Classification: [SIGNIFICANT | HIGH-RISK]
     > Plan: [paste risk-planner plan]
     > Diff: [paste git diff]
     > Project root: [absolute path]"

5. **Act on the return:**
   - **`### Re-classification` section** — the reviewer decided the change is actually `MODERATE`. Surface it and ask `choices: ["Accept revised classification (Recommended)", "Override and keep BLOCK-gated review", "Cancel"]`. If accepted, treat as an implicit PASS and proceed to step 6; do NOT re-invoke code-review on fix deltas. Record the revised classification for the PR body.
   - **BLOCK** — invoke the review-fixer agent (see Review-fixer sub-step below). If `Stop condition flag` is `CLEAR`, re-run the Opus review on the updated diff (one re-review only). If the second verdict is still BLOCK, stop: surface the remaining blockers to the user and ask `choices: ["Investigate further", "Revert this CVE fix and skip it", "Cancel"]`. Do not run tests until the verdict is not BLOCK.
   - **PASS WITH RECOMMENDATIONS** — invoke the review-fixer agent for MAJOR findings (see Review-fixer sub-step below). MINOR / NIT may be deferred; note them in the PR description.
   - **PASS** — proceed.

   **Review-fixer sub-step** (for BLOCK and PASS WITH RECOMMENDATIONS):

   → Agent (subagent_type: "general-purpose"):
     > "Read and adopt the system prompt at `~/.claude/agents/review-fixer.md`
     > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/review-fixer.md` if absent).
     > Then fix the review findings for this brief:
     >
     > Task description: Remediate [CVE-ID] — upgrade [library] from [current] to [target].
     > Review output: [paste the full code-review agent output]
     > Project root: [absolute path]
     > Severities to fix: BLOCKER and MAJOR"

   Wait for the fix report. Re-capture the diff after the fixer completes.

6. **Build & run tests** — Build the project; re-run the test suite.

7. **Compare** — Invoke `general-purpose` with the test-baseline system prompt in **verify** mode, passing the baseline captured in Round A of research step 3:
   > "Read and adopt the system prompt at `~/.claude/agents/test-baseline.md`
   > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/test-baseline.md` if absent).
   > Run in **verify** mode. Baseline: [paste the captured baseline block]."

   Act on the verify report:
   - If `Regressions` or `Missing from run` lists any tests: present them clearly and ask the user to choose — proceed anyway, revert, or investigate further
   - If `Comparison status: invalid`: warn the user and ask for manual review before continuing
   - If fixes were applied in response to failures, re-run tests; if the fixes were non-trivial AND the reviewer was NOT down-classified in step 5, re-invoke the Opus review on the delta. If it was down-classified, skip the re-review.

8. **Commit & PR** — See the Git Workflow section. Include the review verdict in the PR body.

---

## Git Workflow

**Branch naming** (match project convention from `git log --oneline -50`):

- With Jira ID: `fix/JIRA-ID-CVE-XXXX-XXXXX`
- Without Jira ID: `fix/NOJIRA-CVE-XXXX-XXXXX` (or `fix/CVE-XXXX-XXXXX` if project omits placeholders)

**Commit message** (match project style):

```
fix(deps): upgrade <library> to <version> to remediate <CVE-ID>

[Resolves <JIRA-ID>]
Fixes <CVE-ID> - <one-line CVE description>

Vulnerable range: <range>
Safe version: <version>
Classification: <MODERATE | SIGNIFICANT | HIGH-RISK>
```

Omit the `Resolves` line when there is no Jira ID.

**PR:**
- Base branch: `main` (fallback: `master`)
- Title: `fix(deps): <library> upgrade to remediate <CVE-ID>` (append ` [<JIRA-ID>]` when present)
- Body: CVE summary, vulnerable range, version change made, classification, test results (pass count before vs. after). For SIGNIFICANT / HIGH-RISK: paste the Opus review verdict and any deferred MINOR / NIT findings.

---

## Handling Test Failures After Fix

If the fix causes previously-green tests to fail and a quick investigation reveals no obvious fix:

Present the failing tests and ask:
```
"These tests were passing before. Would you like me to:
(1) Apply the fix anyway and flag the failures in the PR description
(2) Revert the fix
(3) Investigate further"
```

Honor the user's choice.

---

## Post-batch maintenance

After all CVEs in the batch have been processed (fixed, committed, and PRed — or explicitly skipped), invoke the session-maintenance agent:

→ Agent (subagent_type: "general-purpose"):
  > "Read and adopt the system prompt at `~/.claude/agents/impl-maintenance.md`
  > (fall back to `~/.claude/plugins/data/dev-workflows@claude-marketplace/agents/impl-maintenance.md` if absent).
  > Then analyse this session and return a Lessons Learned report.
  >
  > Session handoff:
  > - What was done: [summary: N CVEs processed — list each CVE-ID, library, classification, outcome (fixed/skipped/blocked)]
  > - Key events: [BLOCK reviews and their reason, test regressions, workarounds needed, NVD lookup failures, Detect failures, missing reference docs — or 'none']
  > - Workarounds used: [manual steps not automated — or 'none']
  > - Overall result: [N fixed, N skipped, N blocked]
  > - Project root: [absolute path]"

Include the Lessons Learned report in the final batch summary.

---

## Invariants (always enforced)

- NEVER skip classification (step 5 of the research phase) — every CVE fix must be labelled
- NEVER use Opus for a MODERATE fix unless the user explicitly requests it
- NEVER run the test suite on a SIGNIFICANT / HIGH-RISK fix before the Opus code review returns a non-BLOCK verdict
- NEVER touch any file before creating and checking out the per-CVE branch
- ALWAYS check for a clean working tree before branching; stash or get explicit user consent if dirty
- ALWAYS include the classification in the commit message and PR body
- ALWAYS compare against the Baseline agent's results — a regression is only real vs. the pre-change baseline
- AFTER one review-fixer pass + one re-review, if verdict is still BLOCK: stop and surface to user — do NOT loop
