# Changelog

## 0.2.0 (unreleased)

Reworked from the offline-only "local-ai-kit" into a local-first kit that can also use cloud models.

**Added**
- Roles (chat, write, code, vision, image, embed) chosen per machine by RAM, replacing light/standard/heavy tiers.
- `providers.conf`: any OpenAI-compatible endpoint, local or cloud (Anthropic, OpenAI, Gemini, OpenRouter included).
- Local and hybrid modes. Local is the default and refuses cloud providers.
- `ai ask` and `ai repl` for the terminal (via llm), `ai image`, `ai which`, `ai key`, `ai mode`, `ai log`.
- Lifecycle commands: `ai status`, `ai prune`, `ai backup`, `ai check`, `ai uninstall [--all]`.
- One-line installer (`curl ... | bash`) with release pinning, `AIKIT_SYNC` and `AIKIT_SKIP_DEPS`.
- Prompt packs; the security-report prompts moved to `packs/security-reports`. Generic core prompts added.
- Per-user overrides in `~/.config/ai-kit/` for models, providers, prompts and packs.
- Separate spaces for local and hybrid mode (chat history, uploads, indexes, logs, memories), so local-session memories can't reach cloud models.
- Explicit memory: `ai remember`, `ai memory`, `ai forget`. The chat window's background memory review is forced off.
- Incognito mode (`ai incognito <command>` / `ai -i`): a throwaway space deleted on exit, with no memory.
- `ai wipe [local|hybrid|all]`.
- Install receipt (`ai receipt`). `ai uninstall [--all] [--dry-run]` removes only what ai-kit added, including Homebrew dependencies, the uv Python download, models and folders, and restores what it changed (an existing `ai` command, Ollama's settings file). `ai prune` only removes models ai-kit downloaded unless given `--all`.
- Install no longer upgrades tools you already had.
- Folders are created only when something is written, so `ai help` and dry runs leave no trace.
- Linux support (best-effort, via Homebrew on Linux). `AI_OLLAMA_ADDR` for a shared GPU server.
- MIT licence, SECURITY.md, CI (shellcheck and offline tests).

**Changed**
- Open WebUI minimum raised from 0.10.0 to 0.13.1 (security fixes); Python 3.12.
- Data moved from `~/.local-ai` to `~/.local/share/ai-kit` (mode 700).
- `ai stop` only stops an Ollama server that ai-kit started.
- Chat window: also disables video generation, tool servers and plugins, and turns on tool permissions. Removed `ENABLE_DIRECT_CONNECTIONS`, which Open WebUI 0.13.4 dropped.
- Open WebUI's secret key is kept in the data folder, not written to the current directory.

**Fixed**
- `ai sync` no longer lets `ollama pull` read from the loop's input.
- Cloud API keys never appear in process arguments.
- The installer stopped silently on machines missing a standard folder (e.g. a fresh machine with no uv Python folder).

**Breaking**
- `ai chat light|standard|heavy` is now `ai chat <role>`. Add rows named light, standard or heavy to `~/.config/ai-kit/models.conf` if you want the old names back.
