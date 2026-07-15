# Obsidian Task Skills

AI agent skills for managing tasks and daily journals in an [Obsidian](https://obsidian.md/) vault via MCP (Model Context Protocol).

These skills give any compatible AI coding agent a lightweight personal task board — create tasks (optionally linked to Jira), track status, maintain daily journals, generate weekly summaries with topic-based backlinking, and sync backlogs — all stored as plain Markdown files in your Obsidian vault.

## Skills

| Skill | Description |
|-------|-------------|
| **task-create** | Create a new task note from a Jira issue key or freeform title |
| **task-list** | Dashboard view of tasks, filterable by status, priority, or tag |
| **task-status** | Transition a task between `open`, `doing`, `done`, and `cancelled` |
| **task-daily** | Create or refresh today's daily journal with active tasks |
| **task-sync-jira** | Batch import tasks from a Jira JQL query |
| **journal-note** | Append freeform notes to today's journal |
| **journal-organize** | Group flat journal notes into themed topic sub-sections |
| **journal-weekly** | Generate a weekly summary grouped by topic with backlinks to journals and topic notes |

## Prerequisites

- **Obsidian MCP server** — all skills require read/write access to your vault via [MCP Vault](https://github.com/bitbonsai/mcpvault)
- **Atlassian Rovo MCP server** (official, remote) — required by `task-create` and `task-sync-jira` for fetching Jira issue data

## Installation

### 1. Clone this repo

```sh
git clone https://github.com/<your-org>/obsidian-task-skills.git
```

### 2. Wire skills into your agent

Skills live in `.agents/skills/` with symlinks for agent-specific discovery:

```
.agents/skills/          ← canonical skill definitions
.crush/skills -> ../.agents/skills   ← Crush symlink
.claude/skills -> ../.agents/skills  ← Claude Code symlink
```

**Crush** — Copy or symlink `.crush/skills/*` into your project's `.crush/skills/` directory, or add this repo's `.crush/` path to your Crush config.

**Claude Code** — Copy or symlink `.claude/skills/*` into your project's `.claude/skills/` directory.

**Other agents** — Point your agent at `.agents/skills/`. Each skill is a self-contained `SKILL.md` with YAML frontmatter (name, description, compatibility) and a step-by-step procedure the agent follows.

### 3. Configure project context

Copy `AGENTS.md.example` to `AGENTS.md` and fill in your vault path and Jira domain. This file contains vault conventions, the task frontmatter schema, filename patterns, journal format rules, and critical safety rules (e.g., never overwriting existing journals). `AGENTS.md` is gitignored so your personal config stays local.

### 4. Set up MCP servers

Ensure your agent has access to:

- An **Obsidian MCP server** connected to your vault
- The official **Atlassian Rovo MCP server** if you want Jira integration (remote, OAuth-authenticated — no API token needed)

**Jira authentication:** the Rovo MCP server uses OAuth 2.1, not API tokens. The first time a skill calls a Jira tool in a given client, that client prompts you to sign in via your browser — there's no `JIRA_URL`/`JIRA_API_TOKEN`/`JIRA_USERNAME` to configure. Because sign-in is interactive, `task-create` and `task-sync-jira` need a client environment where that browser prompt can be completed; fully headless/non-interactive setups may not be able to authenticate.

### 5. Vault structure

The skills expect this directory layout inside your Obsidian vault:

```
vault/
├── tasks/              ← task notes (one file per task)
├── journals/           ← daily journals (YYYY-MM-DD.md)
├── summaries/          ← weekly summaries (YYYY-Www.md)
├── topics/             ← topic notes for cross-week aggregation
└── templates/
    ├── daily.md        ← journal template with {{date:YYYY-MM-DD}} placeholder
    ├── task.md         ← task note frontmatter schema
    ├── weekly.md       ← weekly summary template
    └── topic.md        ← topic note template
```

## Templates

Skills read templates from the vault's `templates/` directory at runtime to create new files. Templates are never hardcoded in skill procedures — customize them to change the output format without modifying skill definitions.

| Template | Used by | Purpose |
|----------|---------|---------|
| `templates/daily.md` | `task-daily`, `task-create`, `task-sync-jira`, `journal-note` | Daily journal scaffold |
| `templates/task.md` | `task-create`, `task-sync-jira` | Task note frontmatter schema |
| `templates/weekly.md` | `journal-weekly` | Weekly summary scaffold |
| `templates/topic.md` | `journal-weekly` | Topic note template |

If a required template is missing when a skill runs, the skill will inform you and stop.

## Task Schema

Every task note uses this frontmatter (all 9 fields required):

```yaml
title: "Analyze push protection config"
status: "open"            # open | doing | done | cancelled
priority: "high"          # highest | high | medium | low
created_date: "2025-06-17"
due_date: ""
completed_date: ""
cancelled_date: ""
jira_link: "https://yourcompany.atlassian.net/browse/PROJ-123"
tags: [backend, urgent]
```

### Filename conventions

- Jira-linked: `{jira-key-lower}-{title-slug}.md` (e.g., `proj-123-fix-login-timeout.md`)
- Standalone: `{descriptive-slug}.md`

## Journal Format

Journals live at `journals/YYYY-MM-DD.md`:

```markdown
# 2025-06-17

## Tasks:
- [ ] [[proj-123-fix-login-timeout]]
- [x] [[fix-vault-sync-issue]]

## Notes:
- Discussed rollout timeline with team
- Need to follow up on CI pipeline changes
```

- The **Tasks** section is managed by task skills (`task-create`, `task-daily`, `task-status`, `task-sync-jira`).
- The **Notes** section is managed by `journal-note` (appending) and `journal-organize` (grouping into topic sub-sections). Read by `journal-weekly` to generate weekly summaries.
- Older journals may use `Targets:` instead of `Tasks:` — skills detect and preserve the existing header.

## Usage Examples

These are natural-language prompts you'd give your agent:

```
Create a task for PROJ-123
List my tasks
Start working on proj-123
Mark proj-123 done
Start my day
Sync tasks from Jira project PROJ
Note: discussed rollout timeline with the team
Wrap up the week
Generate a weekly summary for 2026-W26
Review last week's notes
```

## Customization

### Jira domain

By default, Jira links use `https://yourcompany.atlassian.net`. To use a different instance, update the `jira_link` URL construction in the relevant `SKILL.md` files and in `AGENTS.md`.

The same domain (as a bare hostname, e.g. `yourcompany.atlassian.net`) is also passed as the `cloudId` parameter the Rovo MCP's Jira tools require — the server resolves it to the underlying cloud ID automatically. If that lookup ever fails, the skills fall back to the Rovo MCP's `getAccessibleAtlassianResources` tool to list accessible sites.

### Priority mapping

| Jira priority | Obsidian priority |
|---------------|-------------------|
| Critical, Blocker | highest |
| Major | high |
| Medium, Normal | medium |
| Minor, Low, Trivial | low |
| (missing) | medium |

### Vault path

The vault path is configured in your Obsidian MCP server, not in these skills. Update your MCP server config to point to a different vault.

## Adding a New Agent

To support a new AI agent:

1. Create a dotfile directory for the agent (e.g., `.myagent/`)
2. Symlink skills: `ln -s ../.agents/skills .myagent/skills`
3. Configure the agent to discover skills from that directory
4. Copy `AGENTS.md.example` to `AGENTS.md` and fill in your vault path and Jira domain

The skill definitions in `.agents/skills/` are agent-agnostic — each `SKILL.md` uses a standard structure:

```yaml
---
name: skill-name
description: When to activate this skill
compatibility: Required MCP servers
metadata:
  author: author
  version: "1.0"
---

## Procedure
### Step 1 — ...
```

## License

MIT
