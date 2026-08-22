---
name: journal-organize
description: >-
  Organize a daily journal's Notes section by grouping flat bullet points
  into themed sub-sections with ### topic headings, grouping related bullets
  under one heading (reordering bullets when needed). Preserves every bullet
  verbatim. Use when asked to organize a journal,
  clean up today's notes, group my notes, or tidy the daily.
metadata:
  author: pshickeydev
  version: "1.2"
---

## Critical Rule — Never overwrite existing journals

**NEVER overwrite an existing journal file with a complete rewrite.** User-written notes, meeting records, and freeform content accumulate in journals throughout the day. Overwriting a journal file destroys that content. Only use targeted file edits/patches to modify existing journals.

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

#### 2b. Read journal
Read `{vault}/journals/{date}.md` using your file reading tool.

**If the journal does not exist**, inform the user and stop. This skill does not create journals — use `journal-note` to create one first.

**If the journal exists**, proceed to Step 3.

### Step 3 — Check if already organized

Examine the `## Notes:` section. If it already contains `###` sub-headings, inform the user:

```
Journal {date} is already organized ({N} topic sections found).
```

Ask whether the user wants to re-organize (which will replace existing topic groupings) or cancel. If cancel, stop.

### Step 4 — Parse the notes into entries

Read the content under the `## Notes:` section and break it into individual note entries — you need this list to group by topic in Step 5.

1. Find the `## Notes:` header (the Notes section is always last, so it runs to the end of the file).
2. Parse individual bullet points. Each top-level `- ` line is one note entry. Continuation lines (indented, or lines not starting with `- `) belong to the preceding bullet — keep them attached to that entry (multi-line entries move as one unit).
3. Capture each entry's **verbatim** text (including any continuation lines). Step 7 reuses these exact strings — either as edit anchors (contiguous case) or as the material for the rebuilt Notes body (reorder case).

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

   **Avoid redundant headings.** The heading names the *theme*; it should not simply restate a bullet verbatim. When the bullets already carry a shared prefix (a project name, Jira key, or `Reading:`/`Meeting:` label), use that prefix as the concise heading and let the bullets supply the detail — do not pad the heading with words copied wholesale from a single bullet. Aim for the shortest heading that unambiguously names the group.

3. **Group related bullets together — reorder when needed.** The goal is **one heading per topic**. Bullets belonging to the same topic must end up contiguous under a single heading. If they are already contiguous, leave them in place. If they are interleaved with other topics, **physically move the bullets** so the topic's bullets sit together (see Step 7). Never split one topic across multiple headings with `(part 2)`/`(cont.)` suffixes when reordering can unite it.

4. **Preserve bullet text and intra-group order.** Reordering moves whole bullets between groups; it never edits, summarizes, splits, or drops bullet text — every bullet stays **verbatim**. Within a single group, keep the bullets in their original relative order.

5. **Single-bullet groups are fine.** Not every topic needs multiple bullets. A single bullet about a distinct topic gets its own heading.

6. **When in doubt about reordering, confirm in the plan.** Reordering is expected and preferred for interleaved journals. If reordering would separate bullets whose adjacency seems intentional (e.g. a chronological narrative), call it out in the Step 6 plan so the user can veto before you apply.

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

### Step 7 — Apply the organization

**Never overwrite the entire journal file, and never touch anything above `## Notes:`.** Choose the apply method based on whether your grouping requires reordering:

- **Method A — incremental heading insertion** (use when NO bullet needs to move, i.e. every group is already contiguous in the original order).
- **Method B — rebuild the Notes body** (use when grouping requires reordering interleaved bullets).

#### Method A — incremental heading insertion (no reordering needed)

Apply the organization as **targeted edits/patches** — inserting each `### {Topic Heading}` at its respective topic boundary while leaving all bullets in place.

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

#### Method B — rebuild the Notes body (reordering needed)

When bullets must move to make topic groups contiguous, heading insertion alone cannot do it. Instead, replace **only the body of the `## Notes:` section** with the reorganized version, in a single targeted edit. Everything above `## Notes:` stays byte-for-byte identical, and every bullet is copied **verbatim** — you are re-ordering and adding headings, never rewriting bullet text.

**Procedure:**

1. **Anchor on the Notes section only.** Set the edit's `oldText` to start at the `## Notes:` header and run to the end of the file (the Notes section is always last). Do not include any line above `## Notes:` in the anchor.
2. **Build the replacement** by emitting, in group order:
   ```
   ## Notes:

   ### {Topic 1 Heading}
   - {verbatim bullet}
   - {verbatim bullet}

   ### {Topic 2 Heading}
   - {verbatim bullet}
   ```
   - Each `### heading` has a blank line before it.
   - Copy every bullet (and its continuation lines) **exactly** as captured in Step 4 — same text, links, punctuation, and em-dashes.
3. **Account for every bullet.** Before applying, confirm the replacement contains the same number of `- ` top-level bullets as the original, each verbatim. No bullet may be dropped, merged, or altered.
4. If the anchor fails to match, re-read the Notes section and retry with the exact on-disk text.

**Safety:** Method B replaces the Notes section body, never the whole file. If you cannot construct an anchor that leaves content above `## Notes:` untouched, stop and report rather than risk a full rewrite.

### Step 8 — Confirm

Read the journal back using your file reading tool to verify the edits applied correctly.

Print:
```
Organized {date} journal: {N} notes grouped into {M} topics.
Topics: {comma-separated list of heading names}
```

## Gotchas

- **NEVER overwrite an existing journal file.** Always use targeted edits scoped to the `## Notes:` section (Method A inserts headings; Method B replaces only the Notes body). Content above `## Notes:` must stay byte-for-byte identical. This is critical — journals accumulate content throughout the day.
- **Preserve bullet content exactly.** This skill adds `###` headings and may **reorder** whole bullets to group related topics — it does NOT rewrite, summarize, expand, split, or editorialize bullet text. The user's words are preserved verbatim; only a bullet's position may change.
- **Reorder to group; don't split a topic.** For interleaved journals, move bullets so each topic gets a single heading. Do not fall back to `(part 2)`/`(cont.)` suffixes when reordering can unite a topic.
- **Keep headings concise, not redundant.** Name the theme; don't copy a whole bullet verbatim into its heading.
- **Do NOT touch sections outside Notes.** Only modify content under `## Notes:`.
- **Handle multi-line bullets carefully.** A note entry may span multiple lines (e.g. a bullet followed by indented sub-bullets or continuation text). Never insert a heading in the middle of a multi-line entry — place boundary headings only before a top-level `- ` line, and keep full multi-line entries intact.
- **The Notes section is always last** in the current journal format. There is no content after it.
- **Insert headings incrementally.** Targeted boundary edits prevent whitespace/newline mismatch bugs and protect unedited content.
- **Resolving vault path:** Always resolve `{vault}` by finding the main `AGENTS.md` (checking `../../../AGENTS.md` relative to this skill file or git root) and extracting `## Vault Location` (expanding `~` to home directory). Do not hardcode or assume vault locations.
- If the user has `###` headings already but wants to re-organize, work incrementally:
  - **Rename** a heading: replace `### old text` with `### new text`.
  - **Remove** a heading (to merge two groups): remove the `### heading` line and any extra blank lines.
  - **Add** a new heading: same boundary-insertion edit as Step 7.
