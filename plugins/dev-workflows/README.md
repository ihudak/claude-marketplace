# dev-workflows

Three Claude Code slash commands for structured implementation, vulnerability remediation, and dependency upgrades — with Opus-backed risk planning, post-implementation code review, and test regression detection.

## Commands

| Command | Description |
|---------|-------------|
| `/impl <description>` | Structured implementation: classify → plan → branch → implement → Opus review → test → document |
| `/vuln CVE-XXXX-XXXXX` | Fix CVEs: research (NVD + baseline in parallel) → classify → branch → fix → Opus review → compare → PR |
| `/upgrade component:version` | Upgrade dependencies: compat check → Opus plan → branch → apply → Opus review → compare |

All three commands:
- Classify tasks as SIMPLE / MODERATE / SIGNIFICANT / HIGH-RISK before acting
- Create a feature branch before touching any file
- Route SIGNIFICANT / HIGH-RISK work through Opus for planning and post-implementation review
- Gate the test run on the review verdict (no tests until BLOCK is cleared)
- Capture a pre-change test baseline and diff after changes

## Agents

Five reusable subagents (invoked internally by the commands):

| Agent | Description |
|-------|-------------|
| `risk-planner` | Opus-backed risk-weighted planner — returns structured plan with security, migration, rollback sections |
| `code-review` | Opus-backed 8-dimension reviewer — PASS / PASS WITH RECOMMENDATIONS / BLOCK |
| `test-baseline` | Runs the test suite in capture or verify mode; diffs for regressions |
| `review-fixer` | Applies BLOCKER/MAJOR findings from a code-review report; returns a fix report |
| `impl-maintenance` | Post-session lessons-learned analyst — suggest-only, does not write files |

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `notify-done` | Stop | Desktop notification when Claude Code finishes a turn |
| `preload-context` | UserPromptSubmit | Injects git context and model-routing reminder for `/impl`, `/vuln`, `/upgrade` |
| `test-notify` | PostToolUse:Bash | Parses test output and sends a desktop notification with pass/fail counts |

## Reference docs

`references/` contains the vendored reference docs the commands consult:

- `references/model-routing/classification.md` — four-level complexity taxonomy and routing rules
- `references/fix-vuln/nvd-api.md` — NVD API shape, safe-version derivation
- `references/fix-vuln/build-systems.md` — build system detection rules
- `references/upgrade/ecosystems.md` — ecosystem detection and update commands
- `references/upgrade/compatibility.md` — compatibility constraints and known migrations
- `references/upgrade/lts-sources.md` — LTS lookup sources

## License

MIT — see [LICENSE](LICENSE).
