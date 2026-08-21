---
name: journal-weekly
description: >-
  Generate a weekly summary from daily journals, grouping notes by topic
  across the week with backlinks to source journals. Creates summary in
  summaries/ and updates topic notes in topics/ for cross-week aggregation.
  Use when asked to create a weekly summary, wrap up the week, review the
  week, generate a weekly report, or summarize this week.
metadata:
  author: pshickeydev
  version: "1.1"
---

## Critical Rule — Never modify source journals

**NEVER modify any file in `journals/`.** This skill only reads daily journals to extract content. All output goes to `summaries/` and `topics/`. Modifying or editing any `journals/*.md` file during a weekly rollup is strictly prohibited.

**NEVER overwrite an existing topic note.** Topic notes accumulate content across weeks. Always edit/patch to append or insert new week sections. Writing a new topic note file is permitted ONLY when checking confirms the topic note does not exist yet.

**NEVER overwrite an existing weekly summary** without explicit user approval to regenerate.

**File ownership:** This skill owns the `summaries/` directory and shares ownership of `topics/` (topic notes are append-only stubs that accumulate cross-week sections).

## Procedure

### Step 1 — Determine week

Accept one of three input forms:

1. **No arguments**: default to the most recently completed Monday–Sunday week relative to the **system date** from your environment context (the `Today's date` field in the system prompt). If today is Sunday, default to the week before (the current week is not yet complete).
2. **A date `YYYY-MM-DD`**: resolve to the ISO 8601 week containing that date.
3. **A week identifier `YYYY-Www`**: use directly.

Compute the Monday and Sunday dates for the target week using ISO 8601 week numbering. Display the resolved range:

```
Generating summary for Week {N}: {Monday} to {Sunday}
```

Do NOT derive the date from note content, file metadata, or any other source.

### Step 2 — Find journals

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

#### 2b. Check week journals
Calculate all 7 dates from Monday to Sunday of the target week. List or check files in `{vault}/journals/` to match against the 7 expected dates (`YYYY-MM-DD.md`).

Report which journals were found and which dates are missing:

```
Found {N}/7 journals: {list of dates}
Missing: {list of missing dates}
```

If zero journals are found, inform the user and stop. If fewer than 7 are found, note the gaps but proceed.

### Step 3 — Read journals

Read the found journal files using your file reading tool.

For each journal, extract the `## Notes:` section:
1. Find the `## Notes:` header.
2. Collect all content from that header to the end of the file (the Notes section is always last).
3. Parse individual bullet points. Each top-level `- ` line is one note entry. Continuation lines (indented or not starting with `- `) belong to the preceding bullet.

Skip journals whose Notes section is empty or contains only the template placeholder (`- `).

### Step 4 — Group by topic

Analyze all extracted Notes bullets across all journals. Handle two cases:

**Already organized** (journal has `###` sub-headings under `## Notes:`): Use the existing topic headings as-is. Each `### Heading` becomes a candidate topic. Bullets under that heading are associated with both the topic and the source journal date.

**Flat bullets** (no `###` headings): Apply the same grouping heuristics as `journal-organize`:
- Project/repo names (e.g. `progress-tracker`, `ai-security-harness`)
- Jira keys (e.g. `ACM-28557`, `HCMSEC-3038`)
- Activity types (e.g. meeting notes, reading/articles, tooling)
- Related work streams (bullets about the same system or task)

For mixed weeks (some journals organized, some not), handle each journal according to its own format.

Associate each bullet with its source journal date for backlinking.

### Step 5 — Normalize topic names

Convert each topic name to a lowercase-kebab-case slug for use as a filename in `topics/`:
- Lowercase, spaces to hyphens, remove non-alphanumeric characters (except hyphens), collapse consecutive hyphens.
- Strip characters that are problematic in filenames: `/\:|?*<>"#^[]`
- Truncate to 60 characters.

**Cross-reference existing topics:** Check `{vault}/topics/` (if the directory exists). For each candidate topic slug, check if a matching or similar topic note already exists. Prefer reusing existing slugs over creating near-duplicates. For example, if `topics/security.md` already exists, do not create `topics/security-review.md` for related content — merge under `security`.

Bullets that do not fit any clear topic go under `Misc`. Misc entries are NOT linked to any topic note.

### Step 6 — Present proposed summary

Show the user the grouped topics with truncated bullet previews and source journal dates. Format:

```
## Proposed weekly summary for Week {N} ({Monday} — {Sunday}):

### [[{topic-slug}]] ({N} entries from {M} days)
- {first ~80 chars of bullet}... — [[{date}]]
- {first ~80 chars of bullet}... — [[{date}]]

### [[{topic-slug}]] ({N} entries from {M} days)
- {first ~80 chars of bullet}... — [[{date}]]

### Misc ({N} entries)
- {first ~80 chars of bullet}... — [[{date}]]

Create this summary?
```

Wait for user confirmation before proceeding. If the user requests changes (rename topics, merge groups, move bullets between groups, remove entries), adjust the plan and re-present.

### Step 7 — Check for existing summary

Check if `{vault}/summaries/{YYYY-Www}.md` exists.

**If it already exists**, inform the user and ask: regenerate (overwrite) or cancel? If regenerating, warn that topic note entries from the previous generation will not be automatically cleaned up — the user may need to manually edit topic notes if they were modified since the last run. If the user confirms, proceed to Step 8.

**If it does not exist**, proceed to Step 8.

### Step 8 — Create weekly summary

1. Read `{vault}/templates/weekly.md`. If the template does not exist, inform the user and stop — they need to create the template first.

2. Replace template placeholders:
   - `{{week}}` → `YYYY-Www` (e.g. `2026-W26`)
   - `{{week_number}}` → week number (e.g. `26`)
   - `{{start_date}}` → Monday's date `YYYY-MM-DD`
   - `{{end_date}}` → Sunday's date `YYYY-MM-DD`

3. Populate the `journals` frontmatter list with the dates of found journals.

4. Write a 2–3 sentence AI-generated summary under `## Highlights` capturing the week's key themes and accomplishments.

5. Append the grouped topic sections under `## Topics`. For each topic:
   - Emit a blank line before the heading.
   - Use `### [[{topic-slug}]]` as the heading (wikilink creates a graph edge to the topic note in Obsidian).
   - List each bullet verbatim from the source journal, with ` — [[{date}]]` appended to link back to the source daily journal.
   - If the original bullet already ends with a journal reference, do not duplicate it.

6. Append a `### Misc` section (if any ungrouped bullets exist) with the same bullet format but no wikilink in the heading.

7. Write the result to `{vault}/summaries/{YYYY-Www}.md`.

### Step 9 — Update topic notes

For each topic referenced in the summary (excluding Misc):

1. Check if `{vault}/topics/{topic-slug}.md` exists.

2. **If it does not exist**, read `{vault}/templates/topic.md` (once, before the loop — reuse for all topics). If the template does not exist, inform the user and stop. Replace `{{created_date}}` with today's date and `{{slug}}` with the topic slug. Append the first week section:

   ```markdown
   ## [[YYYY-Www]]
   - {bullet 1}
   - {bullet 2}
   ```

   Write to `{vault}/topics/{topic-slug}.md`.

3. **If it already exists**, first check whether a `## [[YYYY-Www]]` section for this week already appears in the content. If so, ask the user whether to replace it or skip. If replacing, edit the file to replace the existing week section (from `## [[YYYY-Www]]` through to the next `## [[` heading or end of file).

   To insert a new week section, edit the file:
   - Target the `# {topic-slug}` title line exactly as it appears in the file.
   - Replace with that same title line followed by a blank line, then `## [[YYYY-Www]]`, then each bullet. This places the new week immediately after the title (newest first, reverse chronological).

4. Bullet text in topic notes does NOT include the ` — [[date]]` journal backlink suffix. The topic note gets clean bullet text only. The journal backlinks live in the weekly summary.

### Step 10 — Confirm

Read back `{vault}/summaries/{YYYY-Www}.md` to verify the write succeeded.

Print:

```
Created weekly summary for Week {N} ({Monday} — {Sunday}).
{X} topics across {Y} entries from {Z} journals.
Topics: {comma-separated list of topic names}
Summary: summaries/{YYYY-Www}.md
Topic notes updated: {list of topics/{slug}.md paths}
```

## Gotchas

- **NEVER modify any file in `journals/`.** This skill is read-only for journal content. All writes go to `summaries/` and `topics/`.
- **NEVER overwrite an existing topic note.** Topic notes accumulate content across weeks. Always edit/patch to add new sections. Writing a new file is only for initial creation of a topic note that does not yet exist.
- **Preserve bullet content exactly.** When copying bullets from journals into the summary and topic notes, do not rewrite, summarize, expand, or editorialize. The `## Highlights` section is the only place for AI-generated text.
- **Topic note section ordering:** Newest week at the top (immediately after the `# {slug}` title). This gives a reverse-chronological view.
- **Section insertion for topic notes:** Match the `# {slug}` title line and insert the new `## [[YYYY-Www]]` section immediately below it. This places the new week between the title and any existing week sections.
- **Duplicate week sections:** Before editing a topic note, check whether `## [[YYYY-Www]]` already appears in the content. If it does, either skip or ask the user about replacement.
- **Misc entries are NOT added to topic notes.** They exist only in the weekly summary.
- **Resolving vault path:** Always resolve `{vault}` by finding the main `AGENTS.md` (checking `../../../AGENTS.md` relative to this skill file or git root) and extracting `## Vault Location` (expanding `~` to home directory). Do not hardcode or assume vault locations.
- **Em dash in backlinks:** Use ` — ` (space-em-dash-space) before the `[[date]]` backlink in weekly summaries.
- Some journals may have `Targets:` instead of `Tasks:` as their first section header. The skill should look for `## Notes:` specifically and ignore everything before it.
- **ISO 8601 week numbering** has edge cases around year boundaries (e.g. Dec 29–31 may belong to Week 1 of the following year). Compute week numbers correctly using ISO 8601 rules.
- **Topic slug sanitization:** Strip characters problematic in filenames: `/\:|?*<>"#^[]`. Collapse consecutive hyphens. Truncate to 60 characters.
