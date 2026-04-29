---
name: wiki-tags-refresh
description: >
  Scan Knowledge/wiki/ for tags used in wiki page frontmatter, diff against the vault's
  tag-index.md, prompt the user to approve new tags and clean stale ones, then update
  tag-index.md in place. Mirrors the vault's /tags-refresh workflow but scoped to wiki
  pages. Run after heavy ingest sessions when new concepts may have introduced new tags.
  Triggers on: wiki-tags-refresh, refresh wiki tags, update tag index for wiki,
  wiki tags, sync wiki tags.
allowed-tools: Read Write Edit Glob Grep Bash
---

# wiki-tags-refresh

Read `skills/wiki-schema/SKILL.md` fully before proceeding.

Both forms invoke this skill identically:
- Claude Code: `/wiki-tags-refresh`
- Copilot: `wiki-tags-refresh:`

---

## Step 1 — Resolve VAULT_PATH

Vault path: `~/obsidian_vault` by default; set `VAULT_PATH` to override. WSL users with a Windows-side vault must set `VAULT_PATH` explicitly (e.g. `/mnt/c/Users/<name>/obsidian_vault`).

---

## Step 2 — Read the current tag index

Read `.obsidian/copilot/tag-index.md` fully. Extract every documented tag (lines matching
`` `#tagname` ``).

---

## Step 3 — Collect tags from wiki pages

Scan every `.md` file under `Knowledge/wiki/` for frontmatter `tags:` entries only.
The previous broad grep also matched `related:` wikilinks — use the awk approach below
to stay strictly within the `tags:` block:

```bash
find "Knowledge/wiki" -name "*.md" | xargs awk '
  FNR==1{front=0; intags=0}
  /^---/{if(front==0) front=1; else front=0; next}
  !front{next}
  /^tags:/{intags=1; next}
  /^[a-zA-Z]/{intags=0; next}
  intags && /^  - /{gsub(/^  - /, ""); print}
' | sort -u
```

> Note: tags must use the YAML multi-line block form (`tags:` followed by `  - tagname` lines); inline arrays (`tags: [a, b]`) are silently skipped by this script.

Also collect inline tags from page bodies:
```bash
grep -roh "#[a-zA-Z][a-zA-Z0-9/_-]*" "Knowledge/wiki/" | grep -v "^#" | sort -u
```

Exclude false positives: markdown headings at line start (`^#`), code blocks, URLs.

Deduplicate the full collected set.

---

## Step 4 — Diff against tag-index.md

- **New tags**: found in `Knowledge/wiki/` pages but NOT documented in `tag-index.md`
- **Stale candidates**: documented in `tag-index.md` but found in ZERO wiki pages
  (flag only — never auto-remove; they may be used in other vault files)

---

## Step 5 — Report findings

```
wiki-tags-refresh results
─────────────────────────
New (undocumented in tag-index.md):   #newtag  #anothertag
Stale (0 uses in wiki pages):         #oldtag  #unusedtag
Already in sync:                      N tags
```

---

## Step 6 — Process new tags

For each new tag, ask the user:

1. "What does `#newtag` mean?"
2. "Which section of tag-index.md should it go in?"
   Present the existing section list as choices + "Other / new section…"
3. If the user skips a tag, leave it undocumented.

---

## Step 7 — Process stale candidates

Present the stale list and ask:
- `"Remove all stale tags from index"` — removes only confirmed zero-use tags
- `"Review one by one"` — step through each with keep/remove choice
- `"Keep all (ignore)"` — leave index unchanged for these

Note: stale means zero uses in `Knowledge/wiki/` only. The tag may be used elsewhere
in the vault (tasks, project files). Confirm zero vault-wide use before suggesting removal:
```bash
grep -r "#tagname" "${VAULT}" --include="*.md" | grep -v "Knowledge/wiki/" | wc -l
```
If vault-wide count > 0, flag as "used outside wiki — keep?" rather than suggesting removal.

---

## Step 8 — Update tag-index.md

For approved new tags:
- Insert into the chosen section in alphabetical order within the section.
- Format: `` `#tagname` - <description> ``
- Before appending to `## Recently Approved Tags`, ensure the section exists:
  ```bash
  grep -q "^## Recently Approved Tags" ".obsidian/copilot/tag-index.md" || \
    printf "\n## Recently Approved Tags\n" >> ".obsidian/copilot/tag-index.md"
  ```
- Append to `## Recently Approved Tags`:
  `` `#tagname` (YYYY-MM-DD) - <description> ``

For confirmed removals:
- Remove the entry from its section.
- Do NOT remove from `## Recently Approved Tags` (history record).

Do not touch any section not affected by the diff.

---

## Step 9 — Append to _log.md

```markdown
## [YYYY-MM-DD] tags-refresh | N new tags proposed, M approved, L removed
- New: #tag1, #tag2 (if any approved)
- Removed: #oldtag (if any removed)
```

---

## Finish

```
wiki-tags-refresh complete.
Tags added: N   Tags removed: M   Unchanged: K
tag-index.md updated.
```
