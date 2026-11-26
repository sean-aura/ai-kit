# ai-kit

One command, `ai`, for local and cloud AI models. Ask for a **role** (chat, write, code, vision, image) and ai-kit picks the right model for the job and for your machine. It runs on your Mac (or Linux box) by default, and can also use Claude, ChatGPT and Gemini when you allow it.

```bash
ai ask code "why does this regex backtrack?"      # best local coding model that fits your RAM
cat draft.md | ai ask write -p rewrite             # local writing model + a saved prompt
ai ask --cloud write "tighten this abstract"       # the cloud model for that role (hybrid mode)
ai image "isometric diagram of a small office network"
ai chat                                            # a full chat window in your browser
```

**Local by default.** A fresh install is in *local mode*: cloud providers are refused, Ollama's own cloud features are switched off, and the chat window has code execution, web search, plugins and telemetry turned off. Turning cloud use on is one deliberate command (`ai mode hybrid`).

> **Status: early.** The routing, modes, keys and installer are tested on Linux with stand-in servers. Validate on one Mac before rolling out to a team. See [Known gaps](#known-gaps).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/ai-kit/main/install.sh | bash
```

That clones the kit to `~/.ai-kit`, installs the tools with Homebrew, and links `ai` into `~/.local/bin`. Then open a new terminal:

```bash
ai sync      # download the local models that fit this machine (large: tens of GB)
ai doctor    # check everything
ai           # pick a role and start chatting
```

Variations:

```bash
curl -fsSL .../install.sh | AIKIT_REF=v0.2.0 bash   # pin a release (recommended for teams)
curl -fsSL .../install.sh | AIKIT_SYNC=1 bash       # also download models now
curl -fsSL .../install.sh | AIKIT_SKIP_DEPS=1 bash  # no Homebrew: bring your own ollama, uv, jq
```

Prefer to read before you run? `git clone` the repo, read `install.sh`, then run `./install.sh`. It's the same script.

**Requirements:** macOS on Apple Silicon (Linux works but is less tested; Windows via WSL is untested), [Homebrew](https://brew.sh), 16GB RAM minimum (32GB recommended), disk space for models, and internet for install and updates only.

## How it picks a model

`models.conf` lists models by role, best first. For a local request ai-kit takes the first row for that role that fits your RAM. For `--cloud` it takes the first cloud row.

| Role | 16GB | 24GB | 32GB+ | Cloud (hybrid) |
|---|---|---|---|---|
| chat | qwen3:8b | gemma4:26b | qwen3.8:27b | Claude Sonnet |
| write | qwen3:8b | gemma4:26b | gemma4:26b | Claude Opus |
| code | qwen2.5-coder:7b | gpt-oss:20b | qwen3-coder:30b | Claude Opus |
| vision | gemma3:4b | gemma3:4b | qwen3.8:27b | Gemini Flash |
| image | flux2-klein | z-image-turbo | z-image-turbo | gpt-image-2 |
| embed | nomic-embed-text | (same) | (same) | none |

`ai models` shows what *your* machine resolves to and what's downloaded. `ai which code` shows one role. You can always name a model directly: `ai ask qwen3:14b "..."` for any Ollama tag, or `ai ask anthropic/claude-opus-5-5 "..."` for a specific cloud model.

To change the stack, edit `models.conf` and run `ai sync`, then `ai prune` to delete models you've dropped. Personal additions go in `~/.config/ai-kit/models.conf`, which is read first, so you never have to fork the repo.

## Local and hybrid mode

| | local (default) | hybrid |
|---|---|---|
| Local models | yes | yes |
| Cloud models | **refused** | only when you ask (`--cloud`, a cloud model name, or picking one in the chat window) |
| Chat window | local models only | local models plus the approved cloud models in models.conf |

```bash
ai mode hybrid               # allow cloud use on this machine
ai key set anthropic         # stored in the macOS Keychain (mode-600 file on Linux)
ai key set openai
ai mode local                # back to local only
```

Hybrid mode never sends anything to the cloud on its own: the default for every role is still the local model. It does make it *possible* to pick a cloud model, so use local mode (or `AI_MODE=local` in the environment, which overrides the setting) for material that must not leave the machine. See [SECURITY.md](SECURITY.md).

## Memory, spaces and incognito

Local and hybrid mode each have their own **space**: chat history, uploaded documents, search indexes, prompt logs and memories. Nothing from the local space can be recalled in hybrid mode, so something remembered in a confidential local session can't end up in a prompt to a cloud model later.

ai-kit **remembers only when told**. The chat window's automatic background memory is switched off.

- **In the chat window**, ask the model to remember something (this needs a model with native tool calling), or add it yourself under Settings > Personalization. Those memories belong to that space's chat window.
- **In the terminal**, memory is explicit:

```bash
ai remember "Client reports use NZ English and the 5x5 risk matrix"
ai memory            # list what's remembered in the current space
ai forget 2          # or: ai forget all
ai ask --no-memory write "..."   # skip remembered context for one request
```

The terminal and the chat window keep separate memories, even within the same space.

**Incognito** gives you a throwaway space: no memory is read or saved, and everything (history, uploads, indexes, logs) is deleted when the command ends.

```bash
ai incognito chat                 # chat window on port 8081; open it in a private browser window
ai incognito ask write "..."      # or the short form: ai -i ask write "..."
ai -i repl chat
```

Incognito covers this machine only. If you pick a cloud model, that provider's own data-retention rules still apply. `ai code` refuses incognito, because Claude Code keeps its own session history.

| | local space | hybrid space | incognito |
|---|---|---|---|
| Chat history, uploads, logs | kept | kept (separately) | deleted on exit |
| Memory | yes, when told | yes, when told (separately) | none |
| Can reach cloud models | no | when chosen | only if the mode is hybrid |

## Commands

| Command | What it does |
|---|---|
| `ai` | Menu: pick a role, open the chat window |
| `ai chat [role\|model]` | Chat window in the browser (Open WebUI), with document upload |
| `ai ask [-c] [-p prompt] [-f file] <target> [text]` | One-shot answer in the terminal; reads stdin too |
| `ai repl [-c] <target>` | Interactive chat in the terminal |
| `ai image [-c] [-o dir] "description"` | Generate an image (local generation is macOS-only for now) |
| `ai code [-c] [target]` | Claude Code against a local model, or normally with `-c` |
| `ai prompt [name]` | List saved prompts, or copy one to the clipboard |
| `ai docx file.md [template.docx]` / `ai ocr scan.pdf` | Markdown to Word / make a scanned PDF readable |
| `ai models` / `ai which <target>` / `ai models --remote <provider>` | What each role resolves to / one target / a provider's live model list |
| `ai sync` / `ai prune [--all]` | Download the picks for this machine / delete unlisted models ai-kit downloaded |
| `ai mode` / `ai key` / `ai log` | Local or hybrid / API keys / terminal prompt history on or off |
| `ai remember` / `ai memory` / `ai forget` | Terminal memory for the current space |
| `ai incognito <command>` or `ai -i <command>` | Run chat, ask or repl with nothing saved and no memory |
| `ai status` / `ai doctor` / `ai check` | What's running / full health check / validate the config files |
| `ai stop` | Stop the chat window and the model server |
| `ai backup` / `ai wipe [local\|hybrid\|all]` | Back up both spaces / delete a space (or everything, including backups) |
| `ai update` / `ai lock` / `ai verify` | Update everything / record approved versions / check against them |
| `ai export` / `ai import` | Move models by USB to an offline machine |
| `ai receipt` / `ai uninstall [--all] [--dry-run]` | What ai-kit added / remove only that (`--all`: clean slate) |

`-c` / `--cloud` means "use the cloud model for this role". A `target` is a role, `provider/model`, or an Ollama tag.

## Prompts and packs

Saved prompts are plain Markdown. The core ones live in `prompts/` (rewrite, summarise, code-review). Domain sets live in **packs**: `packs/<name>/prompts/`. If a pack has a `_rules.md`, it is prepended to every prompt in that pack.

```bash
ai prompt                                         # list everything
ai prompt security-reports/gap-analysis           # copy to the clipboard for the chat window
cat findings.md | ai ask write -p security-reports/findings-qa
```

This repo ships the `security-reports` pack (gap analysis, risk assessment, environment review, exec summary, findings QA, open-items register). Drop your own packs into `~/.config/ai-kit/packs/`.

## Clean up

The installer writes a **receipt** (`~/.config/ai-kit/receipt`) recording everything it added, and everything it found already there. That covers Homebrew packages (including the dependencies they pull in), uv tools, the Python uv downloads, models, folders, your shell profile and Ollama's settings. Uninstall works from the receipt:

- **Removes only what ai-kit added.** Your own `llm`, models, Homebrew tools and settings stay, even if ai-kit uses them.
- **Restores what it changed.** An `ai` command you already had is set aside at install and put back. Ollama's settings file is restored exactly. Only the PATH line it added is removed from your shell profile.
- **Doesn't upgrade tools you already had.** Homebrew runs with upgrades off, and uv tools you already have aren't touched.
- **Never forces Homebrew.** If something you installed later depends on a package ai-kit added, Homebrew refuses to remove it and ai-kit leaves it.

```bash
ai receipt                      # what ai-kit added, changed, and found already here
ai uninstall --all --dry-run    # exactly what a clean-slate removal would do
ai uninstall --all              # do it
```

At the end, `--all` lists anything new in your home, `~/.cache` and `~/Library` folders since install, for you to check. ai-kit doesn't delete those: they may come from other software. `tests/clean_slate.sh` installs, uses and uninstalls on a simulated fresh machine and a lived-in one (your own `llm`, `ai` script, models and settings), and checks every file is byte-for-byte as it was. CI runs it on every change.

| To... | Run |
|---|---|
| Free RAM | `ai stop` |
| Free disk | `ai prune` (unlisted models), or remove a role's row and prune |
| Delete one space's history, uploads, memories and logs | `ai wipe local` or `ai wipe hybrid` |
| Delete both spaces and all backups | `ai wipe` |
| Leave nothing behind in the first place | `ai incognito chat` |
| Remove ai-kit but keep models, keys and tools | `ai uninstall` |
| Clean slate: everything ai-kit added, nothing else | `ai uninstall --all` |
| Free disk (models ai-kit downloaded that are no longer listed) | `ai prune` (`--all` also includes models you downloaded yourself) |

## Extending

Everything is a line in a text file: add a provider (any OpenAI-compatible endpoint: OpenRouter, Mistral, LM Studio, vLLM, a company gateway), add or swap a model, add a role, add a prompt pack, point at a shared GPU server. See [docs/extending.md](docs/extending.md).

## Known gaps

- **Not yet run on a Mac.** Logic is tested on Linux with stand-in servers. Model downloads, Open WebUI 0.13 start-up and the Keychain have not been exercised.
- **Model tags and cloud IDs are best current guesses** (Nov 2026). `ai sync` reports FAILED for a wrong tag. `ai models --remote <provider>` lists the real cloud IDs.
- **Some Open WebUI settings are unconfirmed** for 0.13.x: `ENABLE_PLUGINS`, `ENABLE_TOOL_SERVERS` and `OPENAI_API_CONFIGS` (used to limit the cloud model list). A setting Open WebUI ignores fails silently. Check the chat window's admin pages on the pilot machine.
- **Claude through Open WebUI and `ai ask` uses Anthropic's OpenAI-compatible endpoint**, which Anthropic describes as a way to test and compare models. Features such as prompt caching aren't available there. For heavier Claude use, `ai code --cloud` (Claude Code) talks to Anthropic natively.
- **Local image generation** relies on Ollama's experimental, macOS-only support.
- **"Remember this" in the chat window** needs a model with native tool calling, and it's unconfirmed whether ai-kit's `ENABLE_PLUGINS=False` also switches off Open WebUI's built-in memory tools. Adding memories by hand in Settings > Personalization works either way. Check on the pilot.
- **Clean slate is proven with stand-ins, not yet on a real Mac.** The test uses stand-ins for Homebrew, uv and Ollama. Open WebUI may write caches the stand-ins don't model (for example under `~/.cache` or `~/Library`). `ai uninstall --all` lists anything like that for you to check.
- **Terminal and chat-window memories are separate stores.** They aren't synced, even within the same space.

## Licence

MIT. See [LICENSE](LICENSE). ai-kit installs but does not include third-party software. Check their terms for your organisation: Open WebUI's licence has branding conditions, and its newer Tether and Terminals add-ons need an enterprise licence for organisational use (ai-kit doesn't use them). Model licences vary; for example, FLUX.2 klein 9B is non-commercial.
