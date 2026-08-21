---
name: journal-note
description: >-
  Add freeform notes to today's daily journal in the Obsidian vault. Appends
  the input as bullet points under the Notes section. Use when asked to add
  a note, jot something down, journal this, or record something in today's
  journal.
metadata:
  author: pshickeydev
  version: "1.1"
---

## Critical Rule — Never overwrite existing journals

**NEVER overwrite an existing journal file.** User-written notes, meeting records, and freeform content accumulate in journals throughout the day. Overwriting a journal file destroys that content. Only use targeted file edits/patches to modify existing journals. Creating/writing a new file is permitted ONLY when checking confirms the journal does not exist yet.

**Section ownership:** This skill owns the `## Notes:` section only. Do NOT modify any other sections that may exist in the journal.

## Procedure

### Step 1 — Determine date

If the input arguments contain a date in `YYYY-MM-DD` format, use that date. Otherwise use the **system date** from your environment context (the `Today's date` field in the system prompt). Do NOT derive the date from note content, file metadata, or any other source.

### Step 2 — Read the journal

#### 2a. Resolve vault location (`{vault}`)
Locate the main `AGENTS.md` file from the skills repository to determine `{vault}` (the base directory of your Obsidian vault), ensuring this works regardless of the current working directory:

1. **Locate `AGENTS.md`**: Find the repository's `AGENTS.md` by checking in order:
   - **Relative to this skill file**: Resolve `../../../AGENTS.md` relative to this `SKILL.md` file's directory (follow symlinks to the canonical path if needed).
   - **Git repository root**: Query the git root enclosing this skill (`git -C <skill_dir> rev-parse --show-toplevel`/AGENTS.md).
   - **Current working directory**: Check `./AGENTS.md`.
   - **Environment / project context**: Check if `AGENTS.md` or `## Vault Location` is provided in system prompt / project instructions.
2. **Extract vault path**: Read `AGENTS.md` and extract the path under the `## Vault Location` section.
3. **Normalize path**:
   - Strip any surrounding backticks, quotes, or trailing slashes.
   - Expand `~` or `$HOME` to the user's absolute home directory (e.g. `/home/username/Documents/MkdwnNotes`).
   - If the path is relative, resolve it relative to the directory containing `AGENTS.md`.
4. **Validate**: If `AGENTS.md` cannot be located or `## Vault Location` is unconfigured/missing (or contains placeholder text), inform the user that `AGENTS.md` needs a valid `## Vault Location` configured, and stop.

#### 2b. Read or create journal
Check if `{vault}/journals/{date}.md` exists and read it using your file reading tool.

**If the journal does not exist**, create it from the vault template:

1. Read `{vault}/templates/daily.md`.
2. Replace the `{{date:YYYY-MM-DD}}` placeholder with the target date.
3. Write the result to `{vault}/journals/{date}.md`. This is the ONLY case where writing a new journal file is permitted.
4. Re-read the journal so you have the current content for Step 3.

**If the journal exists**, proceed to Step 3.

### Step 3 — Append the note

Use targeted file editing to insert the note under the `## Notes:` section.

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

- **NEVER overwrite an existing journal.** Always use targeted edits/patches. Writing a whole file is only for initial creation when no journal exists yet.
- This skill only adds plain bullets under `## Notes:`.
- Do NOT modify sections outside of `## Notes:`. This skill owns the Notes section only.
- Preserve existing Notes section content exactly. The new note is appended, never prepended or inserted in the middle of existing notes.
- **Resolving vault path:** Always resolve `{vault}` by finding the main `AGENTS.md` (checking `../../../AGENTS.md` relative to this skill file or git root) and extracting `## Vault Location` (expanding `~` to home directory). Do not hardcode or assume vault locations.
- Verify the exact path `{vault}/journals/{date}.md` rather than guessing or searching broadly.
