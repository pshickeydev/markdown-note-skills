---
name: journal-organize
description: >-
  Organize a daily journal's Notes section by grouping flat bullet points
  into themed sub-sections with ### topic headings. Preserves all original
  content — only adds structure. Use when asked to organize a journal,
  clean up today's notes, group my notes, or tidy the daily.
compatibility: Requires Obsidian MCP server
metadata:
  author: pshickeydev
  version: "1.1"
---

## Critical Rule — Never overwrite existing journals

**NEVER use `write_note` on a journal file that already exists.** User-written notes, meeting records, and freeform content accumulate in journals throughout the day. Using `write_note` (mode `overwrite`) would destroy that content. Only use `patch_note` to modify existing journals.

**Section ownership:** This skill owns the `## Notes:` section only. Do NOT modify any other sections that may exist in the journal.

## Procedure

### Step 1 — Determine date

If the input arguments contain a date in `YYYY-MM-DD` format, use that date. Otherwise use the **system date** from your environment context (the `Today's date` field in the system prompt). Do NOT derive the date from Obsidian note content, vault metadata, or any other source.

### Step 2 — Read the journal

Read `journals/{date}.md` using the Obsidian `read_note` tool.

**If the journal does not exist**, inform the user and stop. This skill does not create journals — use `journal-note` to create one first.

**If the journal exists**, proceed to Step 3.

### Step 3 — Check if already organized

Examine the `## Notes:` section. If it already contains `###` sub-headings, inform the user:

```
Journal {date} is already organized ({N} topic sections found).
```

Ask whether the user wants to re-organize (which will replace existing topic groupings) or cancel. If cancel, stop.

### Step 4 — Parse the notes into entries

Read the content under the `## Notes:` section and break it into individual note entries — you need this list to group by topic in Step 5. You are parsing for understanding, **not** assembling a replacement block (Step 7 edits the journal in place with small patches, so you never rebuild the whole section).

1. Find the `## Notes:` header (the Notes section is always last, so it runs to the end of the file).
2. Parse individual bullet points. Each top-level `- ` line is one note entry. Continuation lines (indented, or lines not starting with `- `) belong to the preceding bullet — keep them attached to that entry.
3. Record the exact text of the first and last bullet of the file, and of each bullet you expect to sit at a topic boundary — Step 7 uses these verbatim as patch anchors.

If the Notes section is empty or contains only the template placeholder (`- `), inform the user there is nothing to organize and stop.

### Step 5 — Group by topic

Analyze each bullet point and assign it to a topic group. Grouping rules:

1. **Identify themes** from the content of each bullet. Look for:
   - Project/repo names (e.g. `progress-tracker`, `ai-security-harness`)
   - Jira keys (e.g. `ACM-28557`, `HCMSEC-3038`)
   - Activity types (e.g. meeting notes, reading/articles, tooling)
   - Related work streams (bullets about the same system or task)

2. **Choose concise heading names.** Follow patterns from existing organized journals:
   - Project-scoped: `### progress-tracker MR !22`
   - Activity-scoped: `### Meeting: chickenwing sync`
   - Tool/project: `### container-sha2tag`
   - Reading: `### Reading: {article title}`
   - Catch-all: `### Misc` (only for genuinely unrelated single bullets)

3. **Preserve bullet order.** Do not reorder bullets. Grouping is expressed by *inserting headings* between existing bullets (Step 7), so the bullets stay exactly where they are — a group is simply the run of consecutive bullets that falls under one heading.

4. **Single-bullet groups are fine.** Not every topic needs multiple bullets. A single bullet about a distinct topic gets its own heading.

5. **Prefer contiguous groups; flag interleaving.** The apply step (Step 7) works by *inserting headings* between bullets — it does not physically move bullets. This means a group can only be formed cleanly when its bullets are already **contiguous** in the original order. Journals written chronologically are usually already topic-contiguous, so this is the normal case. If your grouping would require **interleaving** (a topic's bullets are split by bullets from another topic, e.g. order A, B, A), you cannot achieve it with heading insertion alone. When that happens:
   - Prefer a grouping that keeps the original order and splits the interleaved topic into two adjacent groups (e.g. `### Topic A (part 1)` … `### Topic B` … `### Topic A (part 2)`), **or**
   - Call it out in the Step 6 plan and ask the user whether they want bullets physically reordered (which requires moving bullet text, not just inserting headings) or left in place with split headings.

### Step 6 — Present the plan

Show the user the proposed organization **without modifying the journal yet**:

```
## Proposed organization for {date}:

### {Topic 1} ({N} bullets)
- {first few words of bullet 1}...
- {first few words of bullet 2}...

### {Topic 2} ({N} bullets)
- {first few words of bullet 1}...

Apply this organization?
```

Truncate each bullet preview to ~80 characters for readability.

Wait for user confirmation before proceeding. If the user requests changes to the grouping (e.g. merge two topics, rename a heading, move a bullet), adjust the plan and re-present.

### Step 7 — Apply the organization (incremental heading insertion)

**Do NOT attempt a single `patch_note` that replaces the entire Notes section** (from `## Notes:` to end of file). That approach is unreliable: a large multi-bullet `oldString` frequently fails to match because of whitespace/newline normalization between what `read_note` returns and what is stored on disk. Matching one giant block is all-or-nothing and repeatedly fails in practice.

Instead, apply the organization as a series of **small, targeted `patch_note` calls** — one per heading you need to insert. Each patch inserts a `### {Topic Heading}` at a topic boundary while leaving all bullets in place.

**Procedure:**

1. **First heading** — insert it directly after the `## Notes:` header. Use a small, unique `oldString` that anchors on the header plus the first bullet:
   - `oldString`:
     ```
     ## Notes:
     - {exact text of first bullet}
     ```
   - `newString`:
     ```
     ## Notes:

     ### {First Topic Heading}
     - {exact text of first bullet}
     ```

2. **Each subsequent heading** — insert it at the boundary between the last bullet of the previous group and the first bullet of the new group. Anchor on both bullets so the match is unique:
   - `oldString`:
     ```
     - {exact text of last bullet in previous group}
     - {exact text of first bullet in new group}
     ```
   - `newString`:
     ```
     - {exact text of last bullet in previous group}

     ### {New Topic Heading}
     - {exact text of first bullet in new group}
     ```

**Rules for reliable matching:**
- Keep each `oldString` as small as possible — typically just the two adjacent bullets at the boundary (or the header + first bullet). Two-line anchors match reliably where a full-section block does not.
- Copy bullet text **verbatim** from the `read_note` output, including inline links, punctuation, and em-dashes. Do not retype or paraphrase.
- If a boundary bullet is very long, you may truncate the `oldString` to a unique **prefix** of that bullet (enough to be unambiguous) rather than including the whole line — but the `newString` must reproduce that same prefix exactly.
- Apply the patches **in document order** (top to bottom). Each patch adds a blank line + heading; it never removes or reorders bullets.
- If a patch reports `matchCount: 0`, re-read the affected lines with `read_note_lines` and retry with a corrected anchor. Do not fall back to `write_note` or to a full-section replace.

**Note on blank-line separators:** because each heading is inserted with a leading blank line only when it follows the `## Notes:` header or a preceding bullet, verify in Step 8 that every `###` heading has a blank line before it. If any two topic groups ended up adjacent without a separator (e.g. the last bullet of one group and the next heading are on consecutive lines with no blank line), add the blank line with one more small `patch_note`.

### Step 8 — Confirm

Read the journal back using the Obsidian `read_note` tool to verify the patch applied correctly.

Print:
```
Organized {date} journal: {N} notes grouped into {M} topics.
Topics: {comma-separated list of heading names}
```

## Gotchas

- **NEVER use `write_note` on an existing journal.** Always use `patch_note`. This is critical — journals accumulate content throughout the day.
- **Preserve bullet content exactly.** This skill only adds `###` headings and regroups — it does NOT rewrite, summarize, expand, or editorialize bullet text. The user's words are preserved verbatim.
- **Do NOT touch sections outside Notes.** Only modify content under `## Notes:`.
- **Handle multi-line bullets carefully.** A note entry may span multiple lines (e.g. a bullet followed by indented sub-bullets or continuation text). Never insert a heading in the middle of a multi-line entry — place boundary headings only before a top-level `- ` line, and when a multi-line bullet is a patch anchor, keep its full text together.
- **The Notes section is always last** in the current journal format. There is no content after it.
- **Insert headings incrementally — never replace the whole Notes section in one patch.** A single `patch_note` whose `oldString` spans the entire Notes section (many bullets) is unreliable and repeatedly fails to match due to whitespace/newline normalization. Use one small `patch_note` per heading, anchored on the two adjacent bullets at each topic boundary (see Step 7). This has proven reliable across sessions where the monolithic-replace approach failed.
- **Keep each `oldString` to ~2 lines.** Small anchors (header + first bullet, or two adjacent bullets) match reliably; large blocks do not. Copy bullet text verbatim from `read_note` output.
- **On `matchCount: 0`, re-read and retry — do not escalate to `write_note`.** Use `read_note_lines` to get the exact on-disk text for the failing anchor, then retry the small patch. Never fall back to `write_note` (it would destroy accumulated journal content) or to a full-section replace.
- `patch_note` cannot replace with empty string — use a single space if needed.
- Do NOT use `search_notes` for finding journals — use `read_note` with the exact path `journals/{date}.md`.
- If the user has `###` headings already but wants to re-organize, still work incrementally, one small patch at a time — never a large replace:
  - **Rename** a heading: `oldString` = the `### old text` line, `newString` = the `### new text` line.
  - **Remove** a heading (to merge two groups): `oldString` = the blank line + `### heading` + the following bullet; `newString` = just that following bullet (drops the heading and its separator).
  - **Add** a new heading: same boundary-insertion patch as Step 7.
  Because heading insertion/removal never moves bullets, re-grouping that requires reordering interleaved bullets still needs the interleaving handling from Step 5.
