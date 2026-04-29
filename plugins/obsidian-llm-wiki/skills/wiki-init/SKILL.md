---
name: wiki-init
description: >
  Initialize or re-initialize vault integration for the LLM wiki pattern. Creates .raw/
  inbox, bootstraps Knowledge/wiki/ with skeleton files (_index.md, _log.md,
  _manifest.json, hot.md), syncs wiki-schema to .obsidian/copilot/, and merges wiki
  blocks into CLAUDE.md and .github/copilot-instructions.md. Safe to re-run after plugin
  updates — existing wiki pages are never touched, skeleton files are never overwritten.
  Triggers on: wiki-init, initialize the wiki, set up the wiki, bootstrap the wiki,
  init wiki, wiki setup, wiki initialize, set up obsidian-llm-wiki.
allowed-tools: Read Write Edit Glob Grep Bash
---

# wiki-init

Initialize or re-initialize vault integration. Safe to re-run after plugin updates —
existing wiki pages and data files are never overwritten.

---

## Step 1 — Resolve VAULT_PATH

```bash
VAULT="${VAULT_PATH:-${HOME}/obsidian_vault}"
[ -d "${VAULT}" ] || { echo "ERROR: vault not found at ${VAULT}. Set VAULT_PATH to your vault location."; exit 1; }
echo "Vault: ${VAULT}"
```

---

## Step 2 — Create .raw/ inbox

```bash
mkdir -p "${VAULT}/.raw"
touch "${VAULT}/.raw/.gitkeep"
```

---

## Step 3 — Bootstrap Knowledge/wiki/ skeleton files

Create the wiki directory and all four skeleton files. Skip any file that already exists —
never overwrite existing data.

```bash
mkdir -p "${VAULT}/Knowledge/wiki"
```

**`Knowledge/wiki/_index.md`** — create only if absent:

```markdown
---
type: meta
title: "Wiki Index"
updated: YYYY-MM-DD
---

# Wiki Index

## Concepts
| Page | Summary | Tags | Updated |
|------|---------|------|---------|

## Entities
| Page | Summary | Tags | Updated |
|------|---------|------|---------|

## Decisions
| Page | Summary | Tags | Updated |
|------|---------|------|---------|

## Patterns
| Page | Summary | Tags | Updated |
|------|---------|------|---------|

## Sources
| Page | Summary | Tags | Updated |
|------|---------|------|---------|
```

**`Knowledge/wiki/_log.md`** — create only if absent:

```markdown
---
type: meta
title: "Ingest Log"
updated: YYYY-MM-DD
---

# Wiki Ingest Log

(Entries prepended by /wiki-ingest, /wiki-save, /wiki-scan, /wiki-lint, /wiki-tags-refresh, /wiki-hot, /wiki-init)
```

**`Knowledge/wiki/_manifest.json`** — create only if absent:

```json
{
  "ingested": [],
  "last_run": null
}
```

**`Knowledge/wiki/hot.md`** — create only if absent:

```markdown
# Recent Context

## Last Updated
(never — no wiki sessions yet)

## Current Focus
(none)

## Recent Changes
(none)
```

Use today's date (YYYY-MM-DD) in the `updated:` fields of files you create.

---

## Step 4 — Sync wiki-schema to vault

Read `skills/wiki-schema/SKILL.md` fully.

Create the target directory if needed:
```bash
mkdir -p "${VAULT}/.obsidian/copilot"
```

Write the full content of `skills/wiki-schema/SKILL.md` to
`${VAULT}/.obsidian/copilot/wiki-schema.md`. **Always overwrite** — this is the sync
mechanism that keeps the vault schema up to date after plugin updates.

---

## Step 5 — Merge wiki block into CLAUDE.md

Target: `${VAULT}/CLAUDE.md`

If this file does not exist, skip and note it in the report.

Check whether the file contains a `<!-- WIKI_BLOCK_START -->` anchor:

- **Anchor found**: replace the entire span from `<!-- WIKI_BLOCK_START -->` to
  `<!-- WIKI_BLOCK_END -->` (inclusive) with the wiki block below.
- **Anchor not found**: append the wiki block at end of file (one blank line before it).

The `<!-- WIKI_BLOCK_START -->` / `<!-- WIKI_BLOCK_END -->` HTML comments are the
idempotent merge anchors — they allow safe re-runs without duplicating content.

<!-- WIKI_BLOCK_START -->
## Wiki

Compiled knowledge base at `Knowledge/wiki/`. Plugin: `obsidian-llm-wiki`.
Full schema at `.obsidian/copilot/wiki-schema.md`.

`Knowledge/wiki/hot.md` is auto-read at session start and auto-updated at session end
by the plugin hooks. Run `/wiki-hot` to refresh manually.

### Wiki Commands

| Command | Description |
|---------|-------------|
| `/wiki-ingest @filepath` | Ingest one source file into the wiki |
| `/wiki-scan [directory]` | Scan directory for unprocessed files; batch-ingest new/changed |
| `/wiki-query <question>` | Answer from the compiled wiki with citations |
| `/wiki-save` | Save current conversation as a wiki page |
| `/wiki-lint` | Run wiki health check, produce lint report |
| `/wiki-hot` | Manually refresh the hot cache |
| `/wiki-tags-refresh` | Sync wiki tags with tag-index.md |
| `/wiki-init` | Re-initialize vault integration after plugin install/update |

### Wiki Boundary Rules

Wiki operations MUST NEVER write to: `Meetings/`, `Daily/`, `Projects/`, `Customers/`,
`People/`, `Clippings/`, `Research/`. Read these directories; never modify them.
Write only to `Knowledge/wiki/`.

Only use tags from `.obsidian/copilot/tag-index.md`. Never invent new tags.
<!-- WIKI_BLOCK_END -->

---

## Step 6 — Merge wiki section into .github/copilot-instructions.md

Target: `${VAULT}/.github/copilot-instructions.md`

If this file does not exist, skip and note it in the report.

Check whether the file contains a `<!-- WIKI_BLOCK_START -->` anchor:

- **Anchor found**: replace the entire span from `<!-- WIKI_BLOCK_START -->` to
  `<!-- WIKI_BLOCK_END -->` (inclusive) with the wiki block below.
- **Anchor not found**: append the wiki block at end of file (one blank line before it).

The `<!-- WIKI_BLOCK_START -->` / `<!-- WIKI_BLOCK_END -->` HTML comments are the
idempotent merge anchors — they allow safe re-runs without duplicating content.

<!-- WIKI_BLOCK_START -->
## Wiki

The vault has a compiled knowledge base at `Knowledge/wiki/` managed by the
`obsidian-llm-wiki` Copilot plugin.

### CRITICAL — Hot Cache Rule (Copilot has no hooks)

**START of any wiki operation**: read `Knowledge/wiki/hot.md` first if it exists.
Silently absorb it as session context — do not announce it.

**END of every wiki session**: run `wiki-hot:` before finishing. This saves session
context so the next session starts warm. There are no automatic hooks in Copilot;
skipping this means the next session starts cold.

### Copilot Wiki Prefixes

| Prefix | Description |
|--------|-------------|
| `wiki-ingest: @filepath` | Ingest one source file into the wiki |
| `wiki-scan: [directory]` | Scan directory for unprocessed files |
| `wiki-query: <question>` | Answer from the compiled wiki with citations |
| `wiki-save:` | Save current conversation as a wiki page |
| `wiki-lint:` | Run wiki health check |
| `wiki-hot:` | Refresh the hot cache (run at END of every wiki session) |
| `wiki-tags-refresh:` | Sync wiki tags with tag-index.md |
| `wiki-init:` | Re-initialize vault integration after plugin update |

### Wiki Schema

Full vault conventions (page types, frontmatter, tags, cross-linking) at:
`.obsidian/copilot/wiki-schema.md`

Read the schema fully before any operation that creates or modifies wiki pages.

### Wiki Boundary Rules

Wiki operations MUST NEVER write to: `Meetings/`, `Daily/`, `Projects/`, `Customers/`,
`People/`, `Clippings/`, `Research/`. Read these directories; never modify them.
Write only to `Knowledge/wiki/`.

Only use tags from `.obsidian/copilot/tag-index.md`. Never invent new tags.
If a concept needs a new tag, flag it with `tag-needed: <proposed>` and let the user
approve it via `wiki-tags-refresh:`.
<!-- WIKI_BLOCK_END -->

---

## Step 7 — Report

Print a structured summary of what happened:

```
wiki-init complete
──────────────────────────────────────────────────
Vault: ${VAULT}

Infrastructure
  .raw/                              ✓ ready
  Knowledge/wiki/                    ✓ ready

Skeleton files (skip = already existed)
  _index.md          [created | skipped]
  _log.md            [created | skipped]
  _manifest.json     [created | skipped]
  hot.md             [created | skipped]

Schema sync
  .obsidian/copilot/wiki-schema.md   [synced | skipped — .obsidian/copilot/ not found]

Instruction file merges
  CLAUDE.md                          [section added | section updated | skipped — not found]
  .github/copilot-instructions.md    [section added | section updated | skipped — not found]
──────────────────────────────────────────────────
```

If `.github/copilot-instructions.md` was touched, append:

```
Copilot session workflow:
  SESSION START  — hot cache loads automatically via AGENTS.md standing instruction
  SESSION END    — run `wiki-hot:` to save context before closing Copilot
  AFTER UPDATE   — run `wiki-init:` to sync wiki-schema.md with the new plugin version
```

---

## Step 8 — Suggest vault commit

Do not run git commands. Just suggest:

```
Next step: commit these changes to your vault repo so other machines get the
integration on git pull:

  git add .raw/.gitkeep Knowledge/wiki/ .obsidian/copilot/wiki-schema.md \
          CLAUDE.md .github/copilot-instructions.md
  git commit -m "chore: initialize obsidian-llm-wiki integration"
```
