---
name: wiki-ingest
description: >
  Ingest a single source file into the vault wiki. Reads the source, extracts knowledge
  by file type, creates or updates wiki pages, updates _index.md and _log.md, and records
  the operation in _manifest.json. Use when the user wants to add a specific file to the
  wiki. Triggers on: wiki-ingest, ingest this file, add this to the wiki, process this
  source, wiki ingest.
allowed-tools: Read Write Edit Glob Grep Bash
---

# wiki-ingest

Read `skills/wiki-schema/SKILL.md` fully before proceeding.

Both forms invoke this skill identically:
- Claude Code: `/wiki-ingest @filepath`
- Copilot: `wiki-ingest: @filepath`

---

## Step 1 — Resolve VAULT_PATH

Vault path: `~/obsidian_vault` by default; set `VAULT_PATH` to override. WSL users with a Windows-side vault must set `VAULT_PATH` explicitly (e.g. `/mnt/c/Users/<name>/obsidian_vault`).
All file paths in this skill are relative to the vault root.

---

## Step 2 — Delta check

Read `Knowledge/wiki/_manifest.json` (create it from the schema template if it does not
exist yet).

Compute the source file hash:
```bash
md5sum "<filepath>" | cut -d' ' -f1
```

If the path exists in `_manifest.json` with the same hash: stop and report
`Already ingested (unchanged). Use 'force' keyword to re-ingest.`

Proceed if: path is absent, hash differs, or user said `force`.

---

## Step 3 — Read the source file completely

Do not skim. Read every section.

---

## Step 4 — Identify file type and extract accordingly

| Path prefix | Type | What to extract |
|---|---|---|
| `Meetings/` | Meeting note | Decisions made, technologies discussed, action items (flag them — do NOT create tasks directly), people present, open questions |
| `Daily/` | Daily note | `## Notes` and `## Worklog` sections only. Skip all Dataview/Obsidian Tasks query blocks — those are not content |
| `Projects/` | Project file | Tech stack, decisions, key links, patterns discovered, status |
| `Customers/` | Customer note | Use cases, pain points, customer context, integrations mentioned |
| `People/` | Person note | Role, team, expertise areas, relationships |
| `Clippings/` or `Research/` | Research/clip | Key concepts, takeaways, relevant decisions |
| `.raw/` | Inbox source | Full extraction — this is a deliberate ingest target; extract everything |

> Note: Daily notes must use level-2 `## Notes` and `## Worklog` headings; other heading levels are skipped.

**For `.raw/` HTML files**: check if defuddle is available first:
```bash
npx defuddle --version 2>/dev/null && echo "available" || echo "not available"
```
If available: `npx defuddle parse "<filepath>" --md` and use that output.
If not: read the file directly.

**Action items from meeting notes**: flag them in the log entry as
`action-item: <description>` but do NOT create tasks. The user creates tasks via `/task`.

---

## Step 5 — Resolve against existing wiki

Before creating any new page:
1. Read `Knowledge/wiki/_index.md` to see what already exists.
2. Search for an existing page with a matching or near-matching title:
   ```bash
   find "Knowledge/wiki" -name "*.md" | grep -i "${CONCEPT}"  # substitute the actual concept name
   ```
3. If an existing page covers this concept/entity/decision: **update it**, do not create
   a duplicate.
4. Create a new page only if genuinely new content with no existing home.

When updating an existing page:
- Add new information; do not overwrite existing content unless it is factually wrong.
- If new info contradicts existing content, add a `> [!warning] Potential contradiction`
  callout on both pages noting the conflict. Do not silently overwrite.
- Update the `updated:` frontmatter date.

---

## Step 6 — Write wiki pages

Apply the frontmatter schema from `wiki-schema` for the correct page type.

File naming: Title Case with spaces. `MCP Server.md`, not `mcp-server.md`.

Place files in the correct subdirectory:
- `Knowledge/wiki/concepts/`
- `Knowledge/wiki/entities/`
- `Knowledge/wiki/decisions/`
- `Knowledge/wiki/patterns/`
- `Knowledge/wiki/sources/` (.raw/ files only)

For the page body:
- Write in declarative present tense. "X does Y", not "X basically does Y".
- Cross-link on first mention of any concept, entity, or decision.
- Keep pages 100–300 lines. If content would exceed 300 lines, split into related pages.
- Do NOT add Dataview queries to wiki pages.

---

## Step 7 — Update _index.md

Add a row for every new page to the correct section table. Update the `Summary` and
`Updated` columns for any existing page that was significantly changed. Sort alphabetically
within each section. Update the `updated:` frontmatter date on `_index.md`.

---

## Step 8 — Append to _log.md

New entry at the TOP of the file (newest first):

```markdown
## [YYYY-MM-DD] ingest | <source file path>
- Pages created: [[concept/Name]], [[entity/Name]]
- Pages updated: [[entity/Existing]]
- Key insight: One sentence on what is genuinely new.
- Action items flagged: <description> (if any from meeting notes)
- tag-needed: <proposed-tag> (if any tag was missing from tag-index.md)
```

---

## Step 9 — Update _manifest.json

Write or update the entry for the ingested file:
```json
"<filepath>": {
  "hash": "<md5>",
  "ingested_at": "YYYY-MM-DD",
  "wiki_pages": ["Knowledge/wiki/concepts/Name.md", ...]
}
```

---

## Step 10 — Update hot.md

Update `Knowledge/wiki/hot.md` following the format in `wiki-schema`:
- Set `## Last Updated` to today and one sentence describing this ingest.
- Add key facts learned to `## Key Recent Facts`.
- List created/updated pages in `## Recent Changes`.
- Keep the file ≤300 words total.

---

## Finish

Report:
```
Ingested: <source file>
Pages created: N  (<list>)
Pages updated: M  (<list>)
Tags flagged: <list or "none">
Action items flagged: <list or "none">
```
