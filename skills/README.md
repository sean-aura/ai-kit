# Skills

Each skill is a folder with a `SKILL.md`: YAML frontmatter (`name`, `description`)
followed by Markdown instructions. This is the Agent Skills format, the same one
Claude Code and Open WebUI use, so one folder works everywhere:

| Where | How |
|---|---|
| Terminal | `ai ask -p <skill> ...` (uses SKILL.md's text; supporting files aren't loaded) |
| Claude Code (`ai code`) | `ai skills claude` links them into `~/.claude/skills/` |
| Chat window | `ai skills export`, then Workspace > Skills > Import. Type `$` in a chat to use one |

Team skills go here, in the repo. Personal skills go in `~/.config/ai-kit/skills/`,
which wins if a name clashes.
