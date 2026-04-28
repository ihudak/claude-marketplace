# Changelog

All notable changes to this repo are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the **repo** level.

## [Unreleased]

### Added
- **Model routing across `/impl`, `/vuln`, `/upgrade`.** Every command now classifies the task as `SIMPLE`, `MODERATE`, `SIGNIFICANT`, or `HIGH-RISK` before planning. `SIMPLE` / `MODERATE` continue on the currently selected model. `SIGNIFICANT` / `HIGH-RISK` route planning and post-implementation review through Opus and gate the test run on the review verdict.
- **`agents/risk-planner.md`** — Opus-backed risk-weighted planner system prompt. Returns a structured plan with explicit security, migration, API-stability, concurrency, dependency, rollback, and test-adequacy sections. Refuses to run without a classification. Includes a re-classification escape hatch: if the task turns out to be `SIMPLE` / `MODERATE` on inspection, the planner returns a `### Re-classification` section instead of the full plan and the caller falls back to the non-Opus path.
- **`agents/code-review.md`** — Opus-backed post-implementation reviewer system prompt. Checks eight dimensions (correctness, security, architecture, edge cases, migration risks, dependency risks, test adequacy, rollback). Returns `PASS` / `PASS WITH RECOMMENDATIONS` / `BLOCK`. `BLOCK` gates the test run. Same re-classification escape hatch.
- **`agents/test-baseline.md`** — moved from `plugins/workflow-tools/` to the repo's top-level `agents/`. Same behaviour, now installed at `~/.claude/agents/test-baseline.md` as a user-level subagent.
- **`agents/review-fixer.md`** — default-model agent that auto-fixes BLOCKER and MAJOR findings from a code-review report, deferring findings that require design judgment, migration sequencing, or cross-cutting test strategy. Returns a structured fix report with a `Stop condition flag` so callers know whether to re-review. Wired into all three commands' BLOCK and PASS-WITH-RECOMMENDATIONS branches.
- **`agents/impl-maintenance.md`** — default-model suggest-only post-session analyst. Reads the session handoff, scans existing rules/hooks/agents, returns a structured Lessons Learned report (CLAUDE.md rules, hooks, reference doc gaps, new agent suggestions, command workflow improvements). Does not write files.
- **`references/model-routing/classification.md`** — single source of truth for the four complexity levels, the triggers, the routing rules, and the eight review dimensions. All three commands link to it.
- **`tests/smoke.sh`** — install → uninstall → install smoke test in a throwaway `HOME`. 54 assertions. Covers full install, idempotent re-run, subtractive `--no-hooks`, `--no-plugin` rejection (the flag is retired), `uninstall.sh`, round-trip re-install, legacy `plugins/workflow-tools` cleanup, JSON validity, and agent-file frontmatter validation.
- **`uninstall.ps1`** — native Windows uninstaller (PowerShell). Mirrors `uninstall.sh`: removes managed symlinks/copies and strips hook entries from `settings.json` if Python is available.
- **`.gitignore`** — added `settings.local.json`, `settings-local.json`, `.claude/settings.local.json` to prevent accidental commit of Claude Code machine-specific overrides.
- **`test-baseline.md` verify mode** — second mode alongside `capture`: re-runs tests, diffs against a prior baseline, returns a structured regression report (regressions, missing-from-run, newly fixed, new failures, current snapshot for chaining). All three commands now use verify mode for post-fix comparisons.
- **Feature-branch pre-step in `/impl`, `/vuln`, `/upgrade`** — clean-tree check (stash/proceed/cancel), branch-convention detection, slug generation, HEAD context check, `git checkout -b` BEFORE any file is written. Branch naming: `feat/<slug>` for impl, `chore/upgrade-<component>-to-<ver>` for upgrade, `fix/[JIRA-]CVE-XXXX-XXXXX` for vuln.
- **Ruby/Bundler section in `references/fix-vuln/build-systems.md`** and **PHP/Composer section in `references/upgrade/ecosystems.md`** — expand ecosystem coverage to match `/vuln` Detect agent scan list.

### Changed in commands
- **`/impl`** — new Phase 1.5 classification step; for `SIGNIFICANT` / `HIGH-RISK`, planning is delegated to `risk-planner` (Opus) and the post-implementation `code-review` (Opus) gates the test run. Implementation itself stays on the currently selected model or Sonnet — Opus is reserved for planning and review. Phases 4 and 5 include the classification and the review verdict. Phase 2B "Revise" re-sends the full risk-planner brief (the planner refuses partial briefs).
- **`/vuln`** — step 5 classifies each CVE on the actual change required (same-major patch/minor bump → `MODERATE`; major bump or API-break or security-sensitive code path → `SIGNIFICANT` / `HIGH-RISK`). `MODERATE` keeps the existing flow; `SIGNIFICANT` / `HIGH-RISK` delegate planning to Opus, review the fix with Opus, and gate tests on the verdict. Classification is included in the commit message and PR body. The risk-planner brief no longer overstates the inputs — it passes declaration paths from the Detect agent and lets the planner do its own usage-site grep.
- **`/upgrade`** — Phase 1 step 5 classifies each component. `MODERATE` components follow the existing apply → build → test path. `SIGNIFICANT` / `HIGH-RISK` components plan with Opus (Phase 1 step 8) and get an Opus review before build/test (Phase 2 step 6). Summary table gains `Class` and `Review` columns. Same brief-correctness fix as `/vuln` — the brief passes inventory paths + Agent A's compat output and delegates usage-site scanning to the planner.

### Changed in hooks
- **`preload-context.sh`** — injects a one-line model-routing reminder before the existing git context for `/impl`, `/vuln`, `/upgrade`. Points at `references/model-routing/classification.md` so the rules are one read away. Regex tightened to require at least one non-whitespace, non-hyphen argument so bare `/impl` or `/impl --help` no longer triggers a context injection. Directory listing now gated to repos with ≤30 root entries — large repos no longer leak the listing into context.

### Changed in installers / docs
- **`install.sh --no-hooks` is subtractive**, not just a skip-flag. It actively removes previously-installed hook symlinks and strips matching entries from `settings.json` so the post-flag state matches what users expect.
- **`uninstall.sh` and `uninstall.ps1` symlink matching tightened** — require a path-segment boundary (`/claude-config/` rather than a loose substring) so unrelated paths like `claude-config-backup` can't be matched.
- **`install.sh` / `install.ps1` legacy-plugin cleanup** — on upgrade from a pre-restructure install, both installers remove any leftover `~/.claude/plugins/workflow-tools` symlink and drop the empty `~/.claude/plugins/` parent if nothing else lives there.
- **`README.md`** — surfaces the Windows installation path from the main Install section; adds the native Windows uninstall command and update workflow; documents the new `Class` / `Review` columns in the `/upgrade` example table; new "Subagents" section explaining the `general-purpose` + `model: "opus"` invocation pattern; replaces "commands + plugin" framing with "commands + agents".

### Fixed
- **Subagent invocation pattern: `general-purpose` + `model` override.** Earlier iterations of this release tried two layouts that did not actually register the subagents — `plugins/workflow-tools/` (which requires marketplace registration + `installed_plugins.json` + `enabledPlugins`, not satisfied by a local symlink) and a user-level `agents/*.md` install (which requires a session restart to be discovered). Both produced static-correctness wins but a no-op routing in the installing session. The three commands now invoke the agents via `Agent(subagent_type: "general-purpose", model: "opus", prompt: "Read and adopt ~/.claude/agents/<name>.md, then [brief]")`. The `model` argument on the `Agent` tool itself forces Opus for `risk-planner` / `code-review` regardless of discovery; `test-baseline` omits the override and inherits the session's model. Agent files are still installed at `~/.claude/agents/` so a future Claude Code release with reliable user-agent discovery can invoke them directly with no further changes. Verified empirically in-session. Removes the `--no-plugin` installer flag (the agents are required by `/vuln`, `/upgrade`, and the Opus-gated `/impl` flow — there is no opt-out).
- **`agents/risk-planner.md` and `agents/code-review.md` cite classification rules by absolute path** (`~/.claude/claude-config/references/model-routing/classification.md`). The agents' working directory is the caller's project, not this repo, so relative paths wouldn't resolve.
- **Classification file-count threshold made exclusive** — was `more than 3-5` on SIGNIFICANT and `fewer than 3-5` on MODERATE, which both matched at exactly 4. Pinned to `4 or more` for SIGNIFICANT and `3 or fewer` for MODERATE.
- **`agents/test-baseline.md` Makefile parse row** — previously detected `make test` but had no parse pattern; a Make-driven project would silently get `Total: 0 | Passing: 0 | Failing: 0`. The parse table now has a Make row with best-effort pattern matching and a note explaining the limitation.
- **`install.ps1` / `uninstall.ps1`** — removed PowerShell 7+ only operators (`||`, `??`) that broke on Windows PowerShell 5.1 (the default on Windows 10/11). Replaced with PS5.1-compatible forms.
- **`install.ps1` / `uninstall.ps1`** — replaced em-dashes and box-drawing characters with ASCII. Windows PowerShell 5.1 reads BOM-less script files using the ANSI code page, which mangled UTF-8 multi-byte sequences and caused parser errors at every line with fancy characters.
- **`uninstall.ps1`** — probe Python with a real `--version` call before using it, so the Windows Store `python3.exe` stub (a placeholder that errors at runtime) is correctly identified as "not Python" and the script prints a helpful skip-message instead of a red error.
- **NVD/Detect circular dependency in `/vuln`** — split research into Round A (NVD + Baseline in parallel, no package name needed) then Round B (Detect agents per CVE, package names now known). Per-CVE failure handling explicit.
- **`subagent_type: "Explore"`** replaced with `general-purpose` + explicit Read/Glob/Grep/LS tool restrictions in `/impl` and `/vuln` (Explore is not a valid Claude Code Agent type).
- **`git diff` for new-file-only implementations** — all three commands now use `git add -N . && git diff` so the code-review agent never receives an empty diff.
- **`/upgrade` Agent B is now read-only** in Phase 1; changes are applied in Phase 2 prep step 3, AFTER baseline capture, so the baseline is pristine.
- **`/upgrade` Opus planning** moved before user confirmation; user now sees the full Opus-generated plan before approving.
- **`code-review.md` `Bash` removed from tools list** — reviewer must be read-only; the "NEVER modify files" prompt rule is now enforced by the toolset.
- **Stop condition enforcement** — all three commands enforce: after one review-fixer pass + one re-review, if verdict is still BLOCK, stop and surface to user. No infinite loops.
- **OWASP filter regex** in `/vuln` — `A\d` → `A\d{2}` (OWASP IDs use two digits).
- **`/vuln` Detect agent scan list** expanded to include `*.csproj`, `Gemfile`, `composer.json` (aligning with `build-systems.md` coverage).
- **`hooks/test-notify.sh` ARG_MAX** — switched from passing test output as argv to stdin pipe; large test outputs (>128KB on Linux, >256KB on macOS) no longer crash the hook.
- **`commands/vuln.md` SIGNIFICANT/HIGH-RISK path numbering** — fixed duplicated step 4, missing step 5; downstream references updated.
- **`commands/upgrade.md` Phase 2 structure** — split into "Phase 2 prep (once)" + per-component loop with unambiguous numbering (prep: 1–3, loop: 1–8).
- **`commands/impl.md` Phase 4 agent count** — corrected "three agents" → "four agents".
- **`commands/impl.md` Phase 5 report** — now surfaces feature-branch name under `### Branch`.
- **`references/model-routing/classification.md`** — "4+ non-test files" threshold qualified to require non-trivial logic changes (excludes pure renames, import updates, mechanical refactors, generated-code changes).
- **`references/fix-vuln/nvd-api.md` safe-version derivation** — added worked examples for `.Final`/`-RELEASE` suffixes; clarified range-matching against project's current version line to avoid wrong-range selection.
- **`references/upgrade/compatibility.md`** — new "Known major migrations" section documenting Spring Boot `javax`→`jakarta` migration with detection command, fix approach, and companion changes.
- **`/upgrade` companion-upgrade chain** — now hard-capped at 3 levels with cycle detection; chains exceeding the limit are surfaced as `BLOCKED — companion-cycle` in the summary table (matters for unattended ai-container runs).
- **`hooks/preload-context.sh`** — directory listing gated to repos with ≤30 root entries; large repos no longer leak the listing into context.
- **`/vuln` commit template** — removed hardcoded `Co-authored-by: Claude Code <noreply@anthropic.com>` (some corp Bitbucket instances reject the email).
- **All PowerShell code fences in `references/fix-vuln/build-systems.md`** corrected to `bash` fences.

### Verified
- End-to-end install and uninstall on Windows with both Windows PowerShell 5.1 and PowerShell 7.6.1. PS 5.1 falls back to file copies (no Dev Mode / admin); PS 7.6.1 successfully creates symlinks. Round-trip install → uninstall → install works cleanly on both. Smoke test (`tests/smoke.sh`) is 54/54 green on Linux.

## [1.1.0] — 2026-04-24

### Added
- **`uninstall.sh`** — idempotent reverse of `install.sh`; removes managed symlinks and strips our hook entries from `~/.claude/settings.json`.
- **`install.sh --no-hooks` / `--no-plugin` / `--help`** flags for granular installs.
- **`install.ps1`** — native Windows installer (PowerShell). Creates symlinks with auto-fallback to file copy when Developer Mode / admin isn't available. Skips hooks (bash-only).
- **`references/fix-vuln/`** and **`references/upgrade/`** — reference docs for `/vuln` and `/upgrade` are now vendored into the repo (previously external at `~/.copilot/skills/`).
- **`CHANGELOG.md`** — this file.

### Changed
- **Hook field names corrected**: `preload-context.sh` now reads the `prompt` field (with `user_prompt`/`message` fallbacks) from the UserPromptSubmit payload; `test-notify.sh` now reads `tool_input.command` and `tool_response.output` (with top-level fallbacks) from the PostToolUse payload. Both hooks were previously silently exiting early due to reading the wrong fields.
- **`preload-context.sh` hardening** — removed `set -euo pipefail`, added `python3` availability guard, error-tolerant command substitution. Matches the robustness of `test-notify.sh`.
- **`/impl` step 8 agents** now receive a structured change summary block (including `git diff --stat` output and notable additions/removals) instead of a one-sentence description. Documentation, knowledge, and instructions agents can now reason precisely about what changed.
- **`install.sh` location guard** — refuses to run unless located at `$HOME/.claude/claude-config/`. Prevents silent misconfiguration when the repo is cloned elsewhere.
- **`install.sh` plugin symlink** — now unconditionally `rm -rf`s the target before `ln -sf`, preventing the "stray nested symlink" bug that occurred on repeated runs.
- **`install.sh` settings.json guard** — creates an empty `{}` skeleton if `~/.claude/settings.json` doesn't exist, rather than crashing.
- **`test-notify.sh` output parsing** — uses `python3` for framework output parsing (portable) instead of `grep -oP` (GNU-only, fails on macOS).
- **`/vuln` intro** — clarified the sequential-then-parallel execution model.
- **`/upgrade` Phase 2 step 3** — excludes `.github/workflows/` to prevent GitHub Actions from being processed twice.
- **README** — added detailed per-command phase explanations, Windows section, uninstall instructions, install-flag table.

## [1.0.0] — 2026-04-24

Initial shareable repo.

### Added
- **`commands/impl.md`** — `/impl` command with Explore subagent before planning and three parallel post-implementation agents (Documentation / Knowledge / Instructions).
- **`commands/vuln.md`** — `/vuln` command with parallel NVD / Detect / Baseline research before fix.
- **`commands/upgrade.md`** — `/upgrade` command with parallel compatibility research and GitHub Actions agents in Phase 1; uses `workflow-tools:test-baseline` for the test baseline.
- **`plugins/workflow-tools/`** — plugin with the reusable `test-baseline` agent (Maven / Gradle / npm / pytest / Makefile detection).
- **`hooks/notify-done.sh`** — Stop hook; cross-platform desktop notification (macOS / Linux / WSL2 fallback chain).
- **`hooks/preload-context.sh`** — UserPromptSubmit hook; injects git branch/status/log for `/impl` / `/vuln` / `/upgrade`.
- **`hooks/test-notify.sh`** — PostToolUse:Bash hook; parses test output and notifies.
- **`install.sh`** — idempotent installer; `ln -sf` symlinks + Python JSON merge.
- **`settings-additions.json`** — hook entries merged into `~/.claude/settings.json`.
- **`README.md`** — setup, usage, and platform notes.
- **`docs/specs/2026-04-24-command-subagents-hooks-design.md`** — design document.
