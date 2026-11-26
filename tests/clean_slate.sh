#!/usr/bin/env bash
# Clean-slate test: install, use, uninstall, and check the home folder (and the
# stand-in Homebrew/uv state) is exactly as it was. Two machines:
#   fresh   - nothing installed beforehand; one-step `ai uninstall --all`
#   lived-in - your own llm, `ai` script, models, settings and shell profile;
#             `ai uninstall` then `ai uninstall --all`
# No network, Homebrew, uv or Ollama needed: tests/stubs stand in for them.
# shellcheck disable=SC2015  # 'check && ok || bad' is the intended reporting style
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
KIT_SRC="$PWD"; PORT=19996
W="$(mktemp -d)"; pass=0; fail=0
python3 tests/fake_openai.py "$PORT" "$W/server.log" >/dev/null 2>&1 &
SRV=$!; trap 'kill $SRV 2>/dev/null; rm -rf "$W"' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -fs "127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 && break; sleep 0.5; done

# The kit as a git repo, as the one-line installer would clone it.
cp -R "$KIT_SRC" "$W/repo"; rm -rf "$W/repo/.git"
git -C "$W/repo" init -q -b main && git -C "$W/repo" add -A && git -C "$W/repo" -c user.email=t@t -c user.name=t commit -qm test

ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n%s\n' "$1" "$2" | sed '3,$s/^/      /'; }

# Every path under the machine root, with type, link target and checksum.
snapshot() {
  (cd "$1" && find . -mindepth 1 | sort | while read -r p; do
     if [ -L "$p" ]; then echo "L $p -> $(readlink "$p")"
     elif [ -d "$p" ]; then echo "D $p"
     else echo "F $p $(cksum <"$p" | cut -d' ' -f1)"; fi
   done)
}
same() {   # same "label" before after
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$(diff <(echo "$2") <(echo "$3") | grep '^[<>]')"; fi
}

run_machine() {   # run_machine NAME SETUP_FUNCTION
  local R="$W/$1"; L="$W/logs-$1"; mkdir -p "$R/home" "$R/state" "$L"
  export HOME="$R/home" STUB_STATE="$R/state" SHELL=/bin/bash \
         PATH="$KIT_SRC/tests/stubs:/usr/local/bin:/usr/bin:/bin" \
         AI_OLLAMA_ADDR="127.0.0.1:$PORT" AI_RAM_GB=16 AIKIT_YES=1
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME AIKIT_CONFIG_DIR AI_DATA AI_MODE
  "$2"
  local before; before="$(snapshot "$R")"
  local A="$HOME/.local/bin/ai"

  # install exactly as the one-liner does, then use the tool
  AIKIT_REPO="file://$W/repo" bash <"$W/repo/install.sh" >"$L/install.log" 2>&1 || { bad "$1: install" "$(tail -5 "$L/install.log")"; return; }
  ok "$1: one-line install"
  # Re-running must never relabel what ai-kit added as "already here".
  AIKIT_REPO="file://$W/repo" bash <"$W/repo/install.sh" >"$L/install2.log" 2>&1 || { bad "$1: re-install" "$(tail -5 "$L/install2.log")"; return; }
  if [ "$(grep -c '' "$HOME/.config/ai-kit/receipt")" = "$(sort -u -t'|' -k1,2 "$HOME/.config/ai-kit/receipt" | grep -c '')" ]; then
    ok "$1: re-install keeps one record per item"; else bad "$1: receipt duplicates" "$(cat "$HOME/.config/ai-kit/receipt")"; fi
  "$A" help >/dev/null
  [ -d "$HOME/.local/share/ai-kit" ] && bad "$1: ai help creates no data folder" "it did" || ok "$1: ai help creates no data folder"
  "$A" sync >/dev/null 2>&1; "$A" remember "test memory" >/dev/null; "$A" mode hybrid >/dev/null
  "$A" incognito memory >/dev/null
  [ -n "$(find "$HOME/.ollama/models/manifests" -type f 2>/dev/null)" ] && ok "$1: models downloaded"

  "$3" "$A" "$R" "$before"
}

# ---- machine 1: fresh
setup_fresh() { :; }
check_fresh() {
  local A="$1" R="$2" before="$3" mid
  mid="$(snapshot "$R")"
  "$A" uninstall --all --dry-run >"$L/dry.log" 2>&1
  same "fresh: dry run changes nothing" "$mid" "$(snapshot "$R")"
  grep -q "would: brew uninstall.*tesseract" "$L/dry.log" && ok "fresh: dry run lists the dependency Homebrew pulled in" || bad "fresh: dependency listed" "$(cat "$L/dry.log")"
  "$A" uninstall --all >"$L/uninstall.log" 2>&1
  same "fresh: clean slate after uninstall --all" "$before" "$(snapshot "$R")"
}

# ---- machine 2: lived-in
setup_lived_in() {
  mkdir -p "$HOME/.local/bin" "$HOME/.config/other-app" "$HOME/.ollama/models/manifests" \
           "$HOME/.local/share/uv/python/cpython-3.11.4-user" "$HOME/.local/share/uv/tools/llm" "$STUB_STATE/uv/tools" "$STUB_STATE/brew/formula"
  printf "alias ll='ls -l'\n" >"$HOME/.bashrc"
  printf '#!/bin/sh\necho my own ai script\n' >"$HOME/.local/bin/ai"; chmod +x "$HOME/.local/bin/ai"
  printf '#!/bin/sh\necho my llm\n' >"$HOME/.local/bin/llm"; chmod +x "$HOME/.local/bin/llm"
  touch "$STUB_STATE/uv/tools/llm" "$STUB_STATE/brew/formula/jq" "$STUB_STATE/brew/formula/uv" "$STUB_STATE/brew/formula/git"
  echo manifest >"$HOME/.ollama/models/manifests/llama3.2:3b"
  echo manifest >"$HOME/.ollama/models/manifests/qwen3:8b"      # also in models.conf
  echo '{"other_setting": 1, "disable_ollama_cloud": false}' >"$HOME/.ollama/server.json"
  echo 'theme=dark' >"$HOME/.config/other-app/settings"
}
check_lived_in() {
  local A="$1" R="$2" before="$3"
  grep -q '^uv_tool|llm|preexisting' "$HOME/.config/ai-kit/receipt" && ok "lived-in: your llm recorded as already here" || bad "lived-in: llm recorded" "$(cat "$HOME/.config/ai-kit/receipt")"
  [ "$(cat "$HOME/.local/bin/ai.pre-ai-kit" 2>/dev/null)" = "$(printf '#!/bin/sh\necho my own ai script')" ] && ok "lived-in: your ai script set aside, not overwritten" || bad "lived-in: ai script kept" "$(ls -la "$HOME/.local/bin")"
  "$A" prune >"$L/prune.log" 2>&1
  [ -f "$HOME/.ollama/models/manifests/llama3.2:3b" ] && ok "lived-in: prune leaves your own model alone" || bad "lived-in: prune kept model" "$(cat "$L/prune.log")"

  "$A" uninstall >"$L/uninstall1.log" 2>&1
  [ "$("$HOME/.local/bin/ai")" = "my own ai script" ] && ok "lived-in: uninstall puts your ai script back" || bad "lived-in: ai restored" "$(ls -la "$HOME/.local/bin")"
  [ -x "$HOME/.local/bin/llm" ] && ok "lived-in: uninstall keeps your llm" || bad "lived-in: llm kept" "$(cat "$L/uninstall1.log")"
  [ -f "$HOME/.ollama/models/manifests/qwen3:8b" ] && ok "lived-in: plain uninstall keeps models" || bad "lived-in: models kept" ""

  "$HOME/.ai-kit/bin/ai" uninstall --all >"$L/uninstall2.log" 2>&1
  same "lived-in: clean slate after uninstall --all" "$before" "$(snapshot "$R")"
}

run_machine fresh setup_fresh check_fresh
run_machine lived-in setup_lived_in check_lived_in

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
