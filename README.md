# Obsidian Journal Skills

AI agent skills for managing daily journals, note organization, weekly summaries, and topic aggregations in an [Obsidian](https://obsidian.md/) vault via MCP (Model Context Protocol).

These skills give any compatible AI coding agent structured workflows for personal knowledge management — appending daily notes, organizing bullet points into topic headings, compiling weekly rollups with bidirectional links, and maintaining cross-week topic notes — all stored as plain Markdown files in your Obsidian vault.

## Skills

| Skill | Description |
|-------|-------------|
| **journal-note** | Append freeform notes to today's daily journal |
| **journal-organize** | Group flat journal notes into themed topic sub-sections with `###` headings |
| **journal-weekly** | Generate a weekly summary grouped by topic with backlinks to journals and topic notes |

## Prerequisites

- **Obsidian MCP server** — all skills require read/write access to your vault via [MCP Vault](https://github.com/bitbonsai/mcpvault) or a compatible Obsidian MCP server

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

Copy `AGENTS.md.example` to `AGENTS.md` and fill in your vault path. This file contains vault conventions, journal format rules, and critical safety rules (e.g., never overwriting existing journals). `AGENTS.md` is gitignored so your personal config stays local.

### 4. Set up MCP servers

Ensure your agent has access to an **Obsidian MCP server** connected to your vault.

### 5. Vault structure

The skills expect this directory layout inside your Obsidian vault:

```
vault/
├── journals/           ← daily journals (YYYY-MM-DD.md)
├── summaries/          ← weekly summaries (YYYY-Www.md)
├── topics/             ← topic notes for cross-week aggregation
└── templates/
    ├── daily.md        ← journal template with {{date:YYYY-MM-DD}} placeholder
    ├── weekly.md       ← weekly summary template
    └── topic.md        ← topic note template
```

## Templates

Skills read templates from the vault's `templates/` directory at runtime to create new files. Templates are never hardcoded in skill procedures — customize them to change the output format without modifying skill definitions.

| Template | Used by | Purpose |
|----------|---------|---------|
| `templates/daily.md` | `journal-note` | Daily journal scaffold |
| `templates/weekly.md` | `journal-weekly` | Weekly summary scaffold |
| `templates/topic.md` | `journal-weekly` | Topic note template |

If a required template is missing when a skill runs, the skill will inform you and stop.

## Journal Format

Journals live at `journals/YYYY-MM-DD.md`:

```markdown
# 2026-08-21

## Notes:
- Discussed rollout timeline with team
- Need to follow up on CI pipeline changes
```

- The **Notes** section is managed by `journal-note` (appending) and `journal-organize` (grouping into topic sub-sections). Read by `journal-weekly` to generate weekly summaries.
- Existing or older journals may contain legacy sections (such as `Tasks:` or `Targets:`) above `Notes:`. Skills ignore everything before `## Notes:` and only modify the Notes section.

## Usage Examples

These are natural-language prompts you'd give your agent:

```
Note: discussed rollout timeline with the team
Add to today's notes: fixed CI pipeline failure on MR !85
Organize today's notes
Wrap up the week
Generate a weekly summary for 2026-W34
Review last week's notes
```

## Customization

### Vault path

The vault path is configured in your Obsidian MCP server, not in these skills. Update your MCP server config to point to your vault.

## Adding a New Agent

To support a new AI agent:

1. Create a dotfile directory for the agent (e.g., `.myagent/`)
2. Symlink skills: `ln -s ../.agents/skills .myagent/skills`
3. Configure the agent to discover skills from that directory
4. Copy `AGENTS.md.example` to `AGENTS.md` and fill in your vault path

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
