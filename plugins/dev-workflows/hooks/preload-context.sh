#!/usr/bin/env bash
# Fires on every message submission. Injects git context for /impl, /vuln, /upgrade commands.
# Exits immediately (near-zero overhead) if the message doesn't match.
# Always exits 0 — must never block Claude.

# Guard: if python3 is not available, skip silently
command -v python3 &>/dev/null || exit 0

# Read prompt from stdin JSON. Claude Code's UserPromptSubmit payload uses the
# key "prompt"; hookify's rule engine also accepts "user_prompt". Try all three
# known names for robustness across versions.
prompt=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt') or d.get('user_prompt') or d.get('message') or '')
except Exception:
    print('')
" 2>/dev/null) || true

# Require at least one non-whitespace argument so bare `/impl` (or `/impl --help`
# parsed before a real description) doesn't inject noise every misfire.
if ! echo "$prompt" | grep -qE '^/(impl|vuln|upgrade)[[:space:]]+[^[:space:]-]'; then
    exit 0
fi

echo "=== Auto-injected project context ==="
echo "Model routing: classify task as SIMPLE / MODERATE / SIGNIFICANT / HIGH-RISK before planning."
echo "  SIGNIFICANT / HIGH-RISK -> plan with risk-planner (Opus), code-review (Opus)"
echo "  BEFORE running tests. Invoke via Agent(subagent_type: general-purpose,"
echo "  model: opus) + prompt to read ~/.claude/agents/<name>.md."
echo "  Full rules: ~/.claude/plugins/data/dev-workflows@claude-marketplace/references/model-routing/classification.md"
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Status:"
    git status --short 2>/dev/null | head -20
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null
else
    echo "(not a git repository)"
fi
# Only inject a short directory listing for small repos (<= 30 entries)
entry_count=$(ls -1 2>/dev/null | wc -l | tr -d ' ')
if [[ "$entry_count" -le 30 ]]; then
    echo "Directory:"
    ls -1 2>/dev/null | head -20
fi

exit 0
