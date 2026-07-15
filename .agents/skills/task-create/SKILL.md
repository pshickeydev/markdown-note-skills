---
name: task-create
description: >-
  Create a new task note in the Obsidian vault. Accepts a Jira issue key
  (e.g. PROJ-123, DEV-456) to auto-populate title, priority, and link
  from Jira, or a freeform title for standalone tasks. Writes the note to
  tasks/, adds it to today's journal, and reports confirmation. Use when
  asked to create a task, open a task, track an issue, or add to the task
  list.
compatibility: Requires Obsidian MCP server and the official Atlassian Rovo MCP server (Jira)
metadata:
  author: pshickeydev
  version: "1.3"
---

## Procedure

### Step 1 — Parse input

Examine the input arguments:

- If it matches the pattern `^[A-Z]+-\d+$` (e.g. `PROJ-123`, `DEV-456`), treat it as a **Jira key** and go to Step 2.
- Otherwise, treat it as a **freeform title** and go to Step 3.

### Step 2 — Jira-linked task

Resolve the Jira `cloudId`:
1. Use the configured Jira domain (see `AGENTS.md`) as the `cloudId` parameter directly — the Rovo MCP accepts a site hostname (e.g. `yourcompany.atlassian.net`) and resolves it to the cloud ID automatically.
2. If a call using the hostname fails, call the Jira `getAccessibleAtlassianResources` tool to list the sites the current session can access, and use the matching `id` as `cloudId` instead. If more than one site is returned and none obviously matches, ask the user which to use.

Fetch the issue using the Jira `getJiraIssue` tool with `cloudId`, `issueIdOrKey` set to the Jira key, and `fields: ["summary", "priority", "labels"]`.

Extract and map:

| Jira priority | Obsidian priority |
|---------------|-------------------|
| Critical, Blocker | highest |
| Major | high |
| Medium, Normal | medium |
| Minor, Low, Trivial | low |
| (missing) | medium |

Build the `jira_link` URL:
- Default: `https://yourcompany.atlassian.net/browse/{JIRA_KEY}`
- If the issue response `self` URL contains a different domain, use that domain instead

Derive the filename slug:
1. Take the Jira key (lowercased) + `-` + summary (lowercased)
2. Replace spaces and underscores with hyphens
3. Remove characters that are not lowercase letters, digits, or hyphens
4. Collapse consecutive hyphens into one
5. Truncate to 60 characters
6. Strip trailing hyphens

Result: `tasks/{slug}.md`

Skip to Step 4.

### Step 3 — Freeform task

Ask the user to choose a priority:
- Options: `highest`, `high`, `medium` (recommended default), `low`

Derive the filename slug from the title using the same rules as Step 2 (without a Jira key prefix).

Result: `tasks/{slug}.md`

### Step 4 — Check for duplicates

Use the Obsidian `list_directory` tool on `tasks/`.

- If a file with the exact slug already exists, inform the user and ask: open the existing note, or create with a `-2` suffix?
- For Jira-linked tasks, also check if any file starts with the Jira key prefix (e.g. `proj-123-`). If found, treat as duplicate.

### Step 5 — Write the task note

1. Read `templates/task.md` using the Obsidian `read_note` tool. If the template does not exist, inform the user and stop.
2. Populate the frontmatter fields from the template:
   - `title`: from Jira summary or freeform input
   - `status`: `"open"`
   - `priority`: mapped priority from Step 2 or Step 3
   - `created_date`: today's date `YYYY-MM-DD`
   - `jira_link`: URL from Step 2 or empty string for freeform
   - `tags`: from Jira labels (lowercased) or empty array
   - Leave `due_date`, `completed_date`, `cancelled_date` as empty strings
3. Set the body to a one-line description matching the title, ending with a period.
4. Write to `tasks/{slug}.md` using the Obsidian `write_note` tool.

### Step 6 — Update today's journal

**Critical: NEVER use `write_note` on an existing journal.** Journals accumulate user content throughout the day — overwriting would destroy it.

Read `journals/{today YYYY-MM-DD}.md` using the Obsidian `read_note` tool.

**If the journal does not exist** (read_note returns a not-found error), create it from the vault template:

1. Read `templates/daily.md` using the Obsidian `read_note` tool.
2. Replace the `{{date:YYYY-MM-DD}}` placeholder with today's date.
3. Insert `- [ ] [[{slug-without-extension}]]` under the tasks section header.
4. Write the result to `journals/{today YYYY-MM-DD}.md` using the Obsidian `write_note` tool. This is the ONLY case where `write_note` is permitted on a journal file.

**If the journal exists**, use only `patch_note` to add the task reference:
1. Check if `[[{slug-without-extension}]]` already appears — if so, skip.
2. Find the task section header. Look for `## Tasks:`, `## Targets:`, `Tasks:`, or `Targets:` (with or without the `##` prefix). Preserve whichever exists.
3. Use the Obsidian `patch_note` tool to insert `- [ ] [[{slug-without-extension}]]` as a new line after the last `- [ ]` or `- [x]` line in that section.
4. If no task section header exists, prepend one using the `Tasks:` format.

### Step 7 — Report

Print a confirmation including:
- Task file path
- Title
- Priority
- Jira link (if applicable)
- Journal updated confirmation

## Gotchas

- **NEVER use `write_note` on an existing journal.** Journals accumulate user content throughout the day. Always use `patch_note` for modifications. `write_note` is only for initial creation when no journal exists yet.
- Build the `jira_link` URL from the API response `self` URL domain. Default to `yourcompany.atlassian.net` if not detectable.
- Some older journals use `Targets:` instead of `Tasks:` as the section header. Detect and preserve the existing header; only use `Tasks:` for newly created journals.
- Almost every Jira Rovo MCP tool requires `cloudId`. Try the configured site hostname first; only call `getAccessibleAtlassianResources` if that fails.
- The Rovo MCP authenticates via OAuth, not an API token. If a Jira tool call fails with an authentication/authorization error, tell the user to complete sign-in in their MCP client — do not ask for an API token or URL, since token-based auth isn't supported.
- If the Jira tool call fails for any other reason, inform the user and offer to create the task manually with the Jira key pre-filled in the `jira_link` field.
