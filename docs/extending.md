# Extending ai-kit

Everything is a line in a text file. The kit's own files hold the team defaults. Each person can add to them in `~/.config/ai-kit/` (same file names, read first, so they win). Run `ai check` after editing.

## Add a provider

Any service with an OpenAI-compatible API works. Add one line to `providers.conf`:

```
name|kind|base_url|KEY_VARIABLE
mistral|cloud|https://api.mistral.ai/v1|MISTRAL_API_KEY
lmstudio|local|http://127.0.0.1:1234/v1|
gateway|cloud|https://llm-gateway.example.internal/v1|GATEWAY_KEY
```

`kind` decides the mode rule. `cloud` is refused in local mode; `local` is always allowed. Only mark something `local` if it runs on this machine or on a server you control.

Then `ai key set mistral`, and use it: `ai ask mistral/mistral-large-latest "..."`. `ai models --remote mistral` lists what it offers.

## Add or swap a model

Add a row to `models.conf`:

```
role|provider|model|min_RAM_GB|note
code|ollama|qwen3-coder:30b|32|MoE, 256K context
code|mistral|codestral-latest|0|cloud alternative
```

Local rows are tried best-first, and the first that fits the machine's RAM wins. Run `ai sync` to download, `ai smoke code` to test, and `ai prune` to delete models no longer listed. For Hugging Face GGUF files, Ollama tags such as `hf.co/org/model:quant` work too.

## Add a role

Roles are just names in the first column. To add a "translate" role:

```
translate|ollama|qwen3.8:27b|32|
translate|ollama|qwen3:8b|16|
translate|gemini|gemini-3.8-flash|0|
```

Then `ai ask translate "..."` and `ai chat translate` work straight away.

## Add a skill

```
~/.config/ai-kit/skills/release-notes/     # or skills/release-notes/ in the repo for the team
  SKILL.md
```

```markdown
---
name: release-notes
description: Write release notes from a list of changes. Use when asked for release notes or a changelog entry.
---

Group changes as Added, Changed and Fixed. One line each, past tense, no internal ticket numbers.
```

Then `ai ask -p release-notes ...`, `ai skills claude` for Claude Code, or `ai skills export` and import it in the chat window. See the README's Skills section.

## Change a chat-window setting

Add `KEY=value` lines to `~/.config/ai-kit/webui.env` (Open WebUI's environment variable names). Settings that decide the mode or the space are protected and ignored there. To change the team default instead, edit the settings in `cmd_chat` in `bin/ai`.

## Add a prompt pack

```
~/.config/ai-kit/packs/legal/
  prompts/_rules.md        # optional: prepended to every prompt in the pack
  prompts/contract-review.md
```

Use it with `ai prompt legal/contract-review` or `ai ask write -p legal/contract-review`. To share a pack with the team, add it under `packs/` in the repo.

## Use a shared GPU server

Run Ollama on a machine you control and point clients at it:

```bash
AI_OLLAMA_ADDR=gpu-box.internal:11434 ai ask code "..."
```

That traffic is plain HTTP, so keep it on a trusted network or behind a VPN. `ai doctor` flags a remote Ollama.

## Swap the chat window

The model layer (Ollama plus providers.conf) is separate from the chat window, so the window can be replaced. Every terminal command keeps working whichever window you use.

- **AnythingLLM** (MIT, desktop app) is organised around document workspaces. One workspace per engagement keeps client material apart. Point it at `http://127.0.0.1:11434` with `nomic-embed-text` for embeddings.
- **Any OpenAI-compatible client** can use the same providers.

To wire a different window into `ai chat`, replace `cmd_chat` in `bin/ai`. Keep the same pattern: start the model server, force settings from the script, bind to 127.0.0.1.

## Add image generation through another provider

`ai image` supports Ollama (local, macOS) and OpenAI's images API. Another provider needs a branch in `cmd_image` in `bin/ai`: post the prompt, then decode the image it returns. Pass keys with the `auth_curl` helper so they stay out of process arguments.

## Develop

```bash
shellcheck -s bash bin/ai install.sh tests/*.sh tests/stubs/*
bash tests/run.sh              # routing, modes, keys, memory, incognito
bash tests/clean_slate.sh      # install -> use -> uninstall leaves no trace
AI_RAM_GB=16 bin/ai models     # preview another machine's picks
bin/ai check
```

If you add anything that creates files or changes the machine, record it in the receipt (see `record` in install.sh and `rc_record` in bin/ai) and undo it in `cmd_uninstall`. `tests/clean_slate.sh` will fail until you do.

`bin/ai` must stay compatible with macOS's bash 3.2: no associative arrays, `mapfile` or `${var,,}`, and use `${arr[@]+"${arr[@]}"}` for arrays that may be empty.
