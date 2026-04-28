# Task complexity classification

Shared criteria for `/impl`, `/vuln`, and `/upgrade`. Classifies every task into one
of four buckets and decides whether to invoke Opus for planning and for the
post-implementation code review.

The goal: reserve Opus for heavy-reasoning work (planning risky change, deep
review of completed code) on genuinely risky tasks. Routine implementation
stays on the currently selected model.

## Levels

| Level | Route |
|-------|-------|
| SIMPLE | Proceed with currently selected model. No mandatory Opus steps. |
| MODERATE | Proceed with currently selected model. No mandatory Opus steps. |
| SIGNIFICANT | Plan with Opus. Implement with current model or Sonnet. Opus code review gates the tests. Fixes with current model or Sonnet. |
| HIGH-RISK | Same as SIGNIFICANT. Review must be especially thorough on security, migration, and rollback. |

## Classify as SIGNIFICANT / HIGH-RISK if ANY of these holds

- major framework or library upgrade
- vulnerability fix that requires a major version change, OR application-code
  changes (for example, because a new library version breaks API)
- authentication, authorization, sessions, tokens, or permissions
- database schema, migrations, or data integrity
- public API or contract changes
- broad refactoring across multiple modules
- concurrency, caching, transactions, async processing
- payment, billing, audit, compliance, or security-sensitive logic
- changes touching 4 or more non-test files AND involving non-trivial logic modifications (not just renames, import updates, mechanical refactors, or generated-code changes)
- unclear requirements or high blast radius

## Classify as SIMPLE / MODERATE if

- local change, single module, clear requirements
- small, reversible edits
- a dependency bump contained within the current major version with no
  consumer-code changes required
- a refactor kept to a single file or closely related cluster
- 3 or fewer non-test files changed

When in doubt between MODERATE and SIGNIFICANT, pick SIGNIFICANT and use Opus.

## Workflow for SIGNIFICANT / HIGH-RISK tasks

1. Classify task complexity (output the level explicitly).
2. **Plan with Opus** via the `risk-planner` system prompt at `~/.claude/agents/risk-planner.md`, invoked via `Agent(subagent_type: "general-purpose", model: "opus")`.
3. Implement with the current model or Sonnet.
4. **Opus code review** via the `code-review` system prompt at `~/.claude/agents/code-review.md`, invoked the same way. Tests have NOT been run
   yet at this point - the review gates the test run.
5. Run tests.
6. Fix issues raised by the review or by failing tests (current model or Sonnet).
7. Re-run tests if fixes were applied.
8. Produce final summary including: classification, reviewer verdict, test
   deltas, any outstanding items.

For SIMPLE / MODERATE tasks: skip steps 2 and 4. Plan, implement, and test as
normal with the currently selected model.

## Opus code review must check

- **Correctness** - does the implementation match the plan and handle
  documented inputs/outputs?
- **Security impact** - does it introduce or miss a security concern
  (auth, injection, crypto, secrets, dependency vulnerabilities)?
- **Architectural consistency** - does it match existing patterns, module
  boundaries, and abstractions in the codebase?
- **Missed edge cases** - nulls, empty collections, concurrent access,
  failure paths, retries, partial failures, boundary conditions.
- **Migration risks** - forward/backward compatibility, data migration
  safety, deploy order, feature flags.
- **Dependency risks** - new or upgraded dependencies: known CVEs,
  transitive impact, license, maintenance status.
- **Test adequacy** - are there tests? Do they cover the real risk? Are
  they deterministic? Any mocks that hide real behaviour?
- **Rollback considerations** - how do we revert? Is the change
  reversible? Any irreversible side effects (schema, external calls)?

The reviewer returns a verdict (`PASS`, `PASS WITH RECOMMENDATIONS`, or
`BLOCK`) plus the findings per dimension. `BLOCK` means do not run tests
until the blocking issue is addressed.

## Hard rules

- NEVER use Opus for routine implementation unless the user explicitly requests
  it.
- NEVER skip the Opus code review on SIGNIFICANT / HIGH-RISK work.
- NEVER run the test suite on SIGNIFICANT / HIGH-RISK work before the Opus
  code review has returned.
- ALWAYS state the classification and the reason for it at the top of the
  plan and of the final report.
