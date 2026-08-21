---
name: journal-organize
description: >-
  Organize a daily journal's Notes section by grouping flat bullet points
  into themed sub-sections with ### topic headings. Preserves all original
  content — only adds structure. Use when asked to organize a journal,
  clean up today's notes, group my notes, or tidy the daily.
metadata:
  author: pshickeydev
  version: "1.1"
---

## Critical Rule — Never overwrite existing journals

**NEVER overwrite an existing journal file with a complete rewrite.** User-written notes, meeting records, and freeform content accumulate in journals throughout the day. Overwriting a journal file destroys that content. Only use targeted file edits/patches to modify existing journals.

**Section ownership:** This skill owns the `## Notes:` section only. Do NOT modify any other sections that may exist in the journal.

## Procedure

### Step 1 — Determine date

If the input arguments contain a date in `YYYY-MM-DD` format, use that date. Otherwise use the **system date** from your environment context (the `Today's date` field in the system prompt). Do NOT derive the date from note content, file metadata, or any other source.

### Step 2 — Read the journal

Read `{vault}/journals/{date}.md` using your file reading tool (resolving `{vault}` from the vault location in `AGENTS.md`).

**If the journal does not exist**, inform the user and stop. This skill does not create journals — use `journal-note` to create one first.

**If the journal exists**, proceed to Step 3.

### Step 3 — Check if already organized

Examine the `## Notes:` section. If it already contains `###` sub-headings, inform the user:

```
Journal {date} is already organized ({N} topic sections found).
```

Ask whether the user wants to re-organize (which will replace existing topic groupings) or cancel. If cancel, stop.

### Step 4 — Parse the notes into entries

Read the content under the `## Notes:` section and break it into individual note entries — you need this list to group by topic in Step 5. You are parsing for understanding, **not** assembling a replacement block for the whole file (Step 7 edits the journal in place with targeted heading insertions, leaving bullets intact).

1. Find the `## Notes:` header (the Notes section is always last, so it runs to the end of the file).
2. Parse individual bullet points. Each top-level `- ` line is one note entry. Continuation lines (indented, or lines not starting with `- `) belong to the preceding bullet — keep them attached to that entry.
3. Record the exact text of the first and last bullet of the file, and of each bullet you expect to sit at a topic boundary — Step 7 uses these verbatim as edit anchors.

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

**Do NOT rewrite or overwrite the entire journal or the entire Notes section in one broad replacement.** That risks clobbering text, whitespace mismatches, or destroying content outside Notes.

Instead, apply the organization as **targeted edits/patches** — inserting each `### {Topic Heading}` at its respective topic boundary while leaving all bullets in place.

**Procedure:**

1. **First heading** — insert it directly after the `## Notes:` header:
   - Target the anchor:
     ```
     ## Notes:
     - {exact text of first bullet}
     ```
   - Replace with:
     ```
     ## Notes:

     ### {First Topic Heading}
     - {exact text of first bullet}
     ```

2. **Each subsequent heading** — insert it at the boundary between the last bullet of the previous group and the first bullet of the new group:
   - Target the anchor:
     ```
     - {exact text of last bullet in previous group}
     - {exact text of first bullet in new group}
     ```
   - Replace with:
     ```
     - {exact text of last bullet in previous group}

     ### {New Topic Heading}
     - {exact text of first bullet in new group}
     ```

**Rules for reliable matching:**
- Keep each edit anchor small — typically just the two adjacent bullets at the boundary (or the header + first bullet).
- Copy bullet text **verbatim** from the file, including inline links, punctuation, and em-dashes. Do not retype or paraphrase.
- If a boundary bullet is very long, anchor on a unique prefix of that bullet.
- Apply the edits in document order (top to bottom).
- If an edit fails to match, re-read the affected lines to verify exact on-disk text and retry with a corrected anchor.

**Note on blank-line separators:** Ensure every `###` heading has a blank line before it.

### Step 8 — Confirm

Read the journal back using your file reading tool to verify the edits applied correctly.

Print:
```
Organized {date} journal: {N} notes grouped into {M} topics.
Topics: {comma-separated list of heading names}
```

## Gotchas

- **NEVER overwrite an existing journal file.** Always use targeted in-place edits. This is critical — journals accumulate content throughout the day.
- **Preserve bullet content exactly.** This skill only adds `###` headings and regroups — it does NOT rewrite, summarize, expand, or editorialize bullet text. The user's words are preserved verbatim.
- **Do NOT touch sections outside Notes.** Only modify content under `## Notes:`.
- **Handle multi-line bullets carefully.** A note entry may span multiple lines (e.g. a bullet followed by indented sub-bullets or continuation text). Never insert a heading in the middle of a multi-line entry — place boundary headings only before a top-level `- ` line, and keep full multi-line entries intact.
- **The Notes section is always last** in the current journal format. There is no content after it.
- **Insert headings incrementally.** Targeted boundary edits prevent whitespace/newline mismatch bugs and protect unedited content.
- If the user has `###` headings already but wants to re-organize, work incrementally:
  - **Rename** a heading: replace `### old text` with `### new text`.
  - **Remove** a heading (to merge two groups): remove the `### heading` line and any extra blank lines.
  - **Add** a new heading: same boundary-insertion edit as Step 7.
