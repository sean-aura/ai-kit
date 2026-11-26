# Security

ai-kit puts several fast-moving tools behind one command. This page says what it locks down, what it can't, and how to check.

## Reporting a vulnerability

Please use GitHub's **private vulnerability reporting** (Security tab, then "Report a vulnerability") rather than a public issue. Problems in Ollama, Open WebUI or llm themselves should go to those projects.

## Design

| Control | Why |
|---|---|
| **Local mode is the default.** Cloud providers are refused before any request is built. | Nothing leaves the machine unless someone deliberately runs `ai mode hybrid`. `AI_MODE=local` in the environment overrides the saved setting, for scripts and locked-down profiles. |
| Ollama's cloud models and web search are always off (`OLLAMA_NO_CLOUD=1`, plus `disable_ollama_cloud` in `~/.ollama/server.json`) | Cloud use goes only through `providers.conf`, where the mode gates it. The settings file also covers the Ollama desktop app if it is ever started. |
| Ollama and the chat window listen on `127.0.0.1` only | Other machines can't reach them. |
| Chat window: code execution, code interpreter, web search, image and video generation, tool servers, plugins, community sharing, update checks and telemetry are off; tool permissions are on | Smaller attack surface. Code-execution features in Open WebUI have had security bugs. |
| Chat window settings forced from the script (`ENABLE_PERSISTENT_CONFIG=False`) | Settings saved in the UI can't quietly override the safe defaults. Side effect: changes made in the UI's settings pages don't persist. |
| Cloud models in the chat window limited to those listed in `models.conf` | The picker shows approved models only (unconfirmed for Open WebUI 0.13, see README). |
| Minimum Open WebUI version (`OPEN_WEBUI_MIN` in kit.conf, currently 0.13.1) | `ai chat` refuses to start on older versions with known vulnerabilities. |
| API keys in the macOS Keychain, or a mode-600 file on Linux; never in the repo | Environment variables of the same name override them, for CI or managed machines. |
| Keys never appear in process arguments | curl reads headers from stdin. llm gets the key from a user-only file that exists only while the command runs. |
| Data folder (`~/.local/share/ai-kit`) is mode 700 | Chats, uploads, logs and backups are readable by your user only. |
| Models pinned by fingerprint (`ai lock` / `ai verify`) | Detects a model that was swapped or corrupted. |
| Nothing updates automatically | A change never lands unreviewed. `ai update` backs up chat data first. |

## Verifying it is offline

- `ai doctor` lists non-local network connections from the AI processes. In local mode it should say `none`. It only sees connections open at that moment.
- `ai doctor` confirms Ollama's cloud features are disabled and warns if an Ollama server was already running (for example the desktop app), because then ai-kit's settings may not apply to it.
- Open WebUI's offline mode prevents errors when there's no internet; it does not isolate the network. For real assurance, run a network monitor (Little Snitch or LuLu on macOS) through a test session, or do client work with the network off.

## Risks not fully managed

| Risk | Current position |
|---|---|
| Models give wrong or invented content | Prompts in the security-reports pack require citations and NOT EVIDENCED. Human review is the only real control. |
| Someone picks a cloud model for sensitive material in hybrid mode | Warnings, and the defaults stay local. Policy: use local mode for that work. No content-based blocking. |
| Cloud keys are available to the chat window process | They're passed as environment variables, readable by your own user. Use keys with spending limits. |
| Open WebUI is large and changing fast (agents, terminals and Tether arrived in 0.13) | Version floor, locked settings, `ai update` cadence. Watch its security advisories. An exposure window remains between disclosure and patching. |
| Settings Open WebUI ignores fail silently | `ai doctor` can't detect an ignored setting. Check the admin pages after raising the version floor. |
| Chat login is off | Single-user design. Don't use it on a shared OS account. |
| Retrieval misses part of an uploaded document | Documented in the security-reports pack. No technical control. |
| Models come from public registries | `models.lock` detects change but doesn't vet the source. |
| Python dependencies of Open WebUI and llm aren't hash-pinned by ai-kit | Version floor only. `tools.lock` records what was approved. |
| `ai wipe` is not a secure erase on SSDs | Relies on disk encryption (FileVault). `ai doctor` reports it. |
| `ai ask` keeps a prompt history (llm's logs.db) | Stored in the user-only data folder. `ai log off` stops it, `ai wipe` deletes it. |
| A remote Ollama (`AI_OLLAMA_ADDR`) still counts as "local" | Prompts cross the network to that machine. Use only a server you control. `ai doctor` flags it. |
| `ai code` with a local model | Not verified to make no outside connections. Don't use it for sensitive work. |
| The one-line installer runs code from the network | Pin a release with `AIKIT_REF`, or clone and read `install.sh` first. |
