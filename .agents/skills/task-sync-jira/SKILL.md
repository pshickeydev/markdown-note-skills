---
name: task-sync-jira
description: >-
  Batch import tasks from a Jira JQL query into the Obsidian vault. Creates
  task notes for issues that don't already exist, using the standard task
  template. Adds new tasks to today's journal. Use when asked to sync from
  Jira, import Jira issues, pull backlog from Jira, or open tasks from Jira.
compatibility: Requires Obsidian MCP server and the official Atlassian Rovo MCP server (Jira)
metadata:
  author: pshickeydev
  version: "1.4"
---

## Procedure

### Step 1 — Build the JQL query

Examine the input arguments:

- If it contains JQL operators (`=`, `AND`, `OR`, `ORDER BY`, `IN`, `!=`), use it as-is.
- If it matches a bare project key pattern (`^[A-Z]+$`), expand to:
  `project = {KEY} AND assignee = currentUser() AND status != Done AND status != Closed ORDER BY priority DESC, created ASC`
- If empty, use:
  `assignee = currentUser() AND status != Done AND status != Closed ORDER BY priority DESC, created ASC`

### Step 2 — Resolve cloudId and fetch issues

Resolve the Jira `cloudId` the same way as `task-create`:
1. Use the configured Jira domain (see `AGENTS.md`) as the `cloudId` parameter directly.
2. If that fails, call the Jira `getAccessibleAtlassianResources` tool to list accessible sites and use the matching `id` as `cloudId` instead. Ask the user if more than one site is returned and none obviously matches.

Use the Jira `searchJiraIssuesUsingJql` tool with `cloudId`, the JQL query, `fields: ["summary", "priority", "status", "labels"]`, `maxResults: 100`, and `searchResultMode: "issues"`.

If the response includes a `nextPageToken`, continue paginating by passing it back in as `nextPageToken` on the next call until no token is returned. Safety cap: 200 issues. If more than 200, warn the user and suggest narrowing the JQL.

### Step 3 — Identify existing tasks

1. List all files in `tasks/` using the Obsidian `list_directory` tool.
2. For each Jira issue returned, check if an existing task file starts with the Jira key prefix lowercased (e.g. `proj-123-`). If found, mark as **EXISTS**. Otherwise mark as **NEW**.

### Step 4 — Present plan and confirm

Show a table of all found issues:

```
| Jira Key | Summary | Priority | Vault Status |
|----------|---------|----------|--------------|
| PROJ-123 | Fix the thing | Major | NEW |
| PROJ-456 | Review config | Medium | EXISTS |
```

State: "{N} new, {M} already in vault."

Ask the user to confirm:
- Options: `Create all new tasks`, `Cancel`

### Step 5 — Create new task notes

Read `templates/task.md` using the Obsidian `read_note` tool. If the template does not exist, inform the user and stop. Reuse the template for all issues below.

For each confirmed new issue:

1. **Map priority:**

   | Jira priority | Obsidian priority |
   |---------------|-------------------|
   | Critical, Blocker | highest |
   | Major | high |
   | Medium, Normal | medium |
   | Minor, Low, Trivial | low |
   | (missing) | medium |

2. **Build jira_link:** Default `https://yourcompany.atlassian.net/browse/{JIRA_KEY}`. If the API response `self` URL contains a different domain, use that domain instead.

3. **Derive filename slug:**
   - Take the Jira key (lowercased) + `-` + summary (lowercased)
   - Replace spaces and underscores with hyphens
   - Remove characters that are not lowercase letters, digits, or hyphens
   - Collapse consecutive hyphens into one
   - Truncate to 60 characters
   - Strip trailing hyphens

4. **Write the note** using the Obsidian `write_note` tool at `tasks/{slug}.md`. Populate the template frontmatter fields:
   - `title`: Jira summary
   - `status`: `"open"`
   - `priority`: mapped priority
   - `created_date`: today's date `YYYY-MM-DD`
   - `jira_link`: URL from sub-step 2
   - `tags`: from Jira labels (lowercased) or empty array
   - Leave `due_date`, `completed_date`, `cancelled_date` as empty strings

   Body: one-line description matching the summary.

### Step 6 — Update today's journal

**Critical: NEVER use `write_note` on an existing journal.** Journals accumulate user content throughout the day — overwriting would destroy it.

Read today's journal at `journals/{today}.md` using the Obsidian `read_note` tool.

**If journal does not exist** (read_note returns a not-found error), create it from the vault template:

1. Read `templates/daily.md` using the Obsidian `read_note` tool.
2. Replace the `{{date:YYYY-MM-DD}}` placeholder with today's date.
3. Include the batch import section (shown below) under the tasks section header.
4. Write the result to `journals/{today}.md` using the Obsidian `write_note` tool. This is the ONLY case where `write_note` is permitted on a journal file.

**If journal exists**, use the Obsidian `patch_note` tool to add each imported task as a checkbox in the Tasks section:

For each imported task, add `- [ ] [[{slug}]]` after the last existing checkbox line (`- [ ]` or `- [x]`) in the Tasks section. Do NOT write to the Notes section — that is owned by the `journal-note` skill.

### Step 7 — Report

Print a summary table of all created tasks:

```
| Slug | Jira Key | Priority |
|------|----------|----------|
| proj-123-fix-the-thing | PROJ-123 | high |
```

State total created and journal updated.

## Gotchas

- **NEVER use `write_note` on an existing journal.** Journals accumulate user content throughout the day. Always use `patch_note` for modifications. `write_note` is only for initial creation when no journal exists yet.
- Build the `jira_link` URL from the API response `self` URL domain. Default to `yourcompany.atlassian.net` if not detectable.
- Duplicate detection uses Jira key prefix matching, not exact slug — slugs may vary slightly between runs due to summary wording.
- Almost every Jira Rovo MCP tool requires `cloudId`. Try the configured site hostname first; only call `getAccessibleAtlassianResources` if that fails.
- The Rovo MCP authenticates via OAuth, not an API token. If a Jira tool call fails with an authentication/authorization error, tell the user to complete sign-in in their MCP client — do not ask for an API token or URL, since token-based auth isn't supported.
- `searchJiraIssuesUsingJql` paginates via `nextPageToken`, not `startAt`/`limit`. `maxResults` tops out at 100 per call.
- If Jira returns more than 200 new tasks, warn the user and suggest narrowing the JQL before creating.
- `patch_note` cannot use empty `newString` — use a space character if needed.
- Do NOT use `search_notes` for frontmatter filtering — always batch-read and filter in-memory.
