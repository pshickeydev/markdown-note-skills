---
name: journal-note
description: >-
  Add freeform notes to today's daily journal in the Obsidian vault. Appends
  the input as bullet points under the Notes section. Use when asked to add
  a note, jot something down, journal this, or record something in today's
  journal.
compatibility: Requires Obsidian MCP server
metadata:
  author: pshickeydev
  version: "1.1"
---

## Critical Rule — Never overwrite existing journals

**NEVER use `write_note` on a journal file that already exists.** User-written notes, meeting records, and freeform content accumulate in journals throughout the day. Using `write_note` (mode `overwrite`) would destroy that content. Only use `patch_note` to modify existing journals. `write_note` is permitted ONLY when `read_note` confirms the journal does not exist yet.

**Section ownership:** This skill owns the `## Notes:` section only. Do NOT modify any other sections that may exist in the journal.

## Procedure

### Step 1 — Determine date

If the input arguments contain a date in `YYYY-MM-DD` format, use that date. Otherwise use the **system date** from your environment context (the `Today's date` field in the system prompt). Do NOT derive the date from Obsidian note content, vault metadata, or any other source.

### Step 2 — Read the journal

Read `journals/{date}.md` using the Obsidian `read_note` tool.

**If the journal does not exist** (read_note returns a not-found error), create it from the vault template:

1. Read `templates/daily.md` using the Obsidian `read_note` tool.
2. Replace the `{{date:YYYY-MM-DD}}` placeholder with the target date.
3. Write the result to `journals/{date}.md` using the Obsidian `write_note` tool. This is the ONLY case where `write_note` is permitted on a journal file.
4. Re-read the journal so you have the current content for Step 3.

**If the journal exists**, proceed to Step 3.

### Step 3 — Append the note

Use the Obsidian `patch_note` tool to insert the note under the `## Notes:` section.

**Formatting rules:**
- Pass through the user's input as-is. Do NOT restructure, summarize, reword, or editorialize.
- Prefix each line with `- ` to make it a bullet point (unless the user's input is already bulleted).
- If the input is multi-line, each line becomes its own bullet.

**Insertion point:**
1. Find the `## Notes:` section header.
2. If there are existing bullets (`- ` lines) under that header, insert after the last one.
3. If the section is empty (only the header, or header followed by `- ` with no content), replace the empty placeholder line with the new bullet(s).
4. If no `## Notes:` header exists, append `\n## Notes:\n- {note}` at the end of the file.

### Step 4 — Confirm

Print a short confirmation:
```
Added to {date} journal:
- {first line of note}
```

If multi-line, show the first line followed by `(+N more lines)`.

## Gotchas

- **NEVER use `write_note` on an existing journal.** Always use `patch_note`. `write_note` is only for initial creation when no journal exists yet.
- This skill only adds plain bullets under `## Notes:`.
- Do NOT modify sections outside of `## Notes:`. This skill owns the Notes section only.
- `patch_note` cannot replace with empty string — use a single space if removing content.
- Preserve existing Notes section content exactly. The new note is appended, never prepended or inserted in the middle of existing notes.
- Do NOT use `get_notes_info` for checking journal content — it returns file metadata only, not note content or frontmatter values.
- Do NOT use `search_notes` with `searchFrontmatter: true` to find journals — it does fuzzy text matching and returns false positives. Use `read_note` with the exact path.
