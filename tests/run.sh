#!/usr/bin/env bash
# Offline test suite: no Ollama, no models, no network. Uses a stand-in
# OpenAI-compatible server. Needs: python3, jq, curl, llm.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
T="$(mktemp -d)"; PORT=19999
export AIKIT_CONFIG_DIR="$T/cfg" AI_DATA="$T/data" AI_RAM_GB=32 AI_OLLAMA_ADDR="127.0.0.1:$PORT"
unset AI_MODE ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY
A="bin/ai"; pass=0; fail=0

python3 tests/fake_openai.py "$PORT" "$T/req.log" >/dev/null 2>&1 &
SRV=$!; trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -fs "127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 && break; sleep 0.5; done

ok()   { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL  %s\n      got: %s\n' "$1" "$2"; }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "$2" ;; esac; }
fails(){ if "${@:2}" >/dev/null 2>&1; then bad "$1" "succeeded"; else ok "$1"; fi; }

# --- config and routing
is   "config is valid"               "$($A check)" "  ok       providers.conf and models.conf"
is   "32GB code pick"                "$($A which code)" "ollama/qwen3-coder:30b  (local)"
is   "16GB code pick"                "$(AI_RAM_GB=16 $A which code)" "ollama/qwen2.5-coder:7b  (local)"
is   "24GB chat pick"                "$(AI_RAM_GB=24 $A which chat)" "ollama/gemma4:26b  (local)"
fails "8GB chat has no local model"  env AI_RAM_GB=8 $A which chat
is   "cloud pick for write"          "$($A which --cloud write)" "anthropic/claude-opus-5-5  (cloud)"
is   "explicit provider/model"       "$($A which openai/gpt-5.5)" "openai/gpt-5.5  (cloud)"
is   "bare tag goes to ollama"       "$($A which llama3.2:3b)" "ollama/llama3.2:3b  (local)"
is   "namespaced tag goes to ollama" "$($A which x/z-image-turbo)" "ollama/x/z-image-turbo  (local)"
fails "cloud needs a role"           $A which --cloud llama3.2

# --- modes
is   "default mode is local"         "$($A mode | head -n 1)" "Mode: local"
fails "cloud refused in local mode"  $A ask --cloud write hi
fails "cloud image refused locally"  $A image --cloud cat
$A mode hybrid >/dev/null
is   "mode persists"                 "$($A mode | head -n 1)" "Mode: hybrid"
is   "env overrides saved mode"      "$(AI_MODE=local $A mode | head -n 1)" "Mode: local (from AI_MODE)"
fails "cloud needs a key"            $A ask --cloud write hi
fails "unknown mode rejected"        env AI_MODE=bogus $A mode

# --- end to end through llm against the stand-in server
mkdir -p "$T/cfg"
printf 'fakelocal|local|http://127.0.0.1:%s/v1|\nfakecloud|cloud|http://127.0.0.1:%s/v1|FAKE_API_KEY\n' "$PORT" "$PORT" >"$T/cfg/providers.conf"
printf 'write|fakelocal|model-local|8|\nwrite|fakecloud|model-cloud|0|\n' >"$T/cfg/models.conf"
is   "overlay wins"                  "$($A which write)" "fakelocal/model-local  (local)"
is   "local ask answers"             "$($A ask write hello 2>/dev/null)" "READY"
is   "cloud ask answers"             "$(FAKE_API_KEY='k"ey\x' $A ask --cloud write hello 2>/dev/null)" "READY"
echo "notes" | $A ask -p security-reports/exec-summary write >/dev/null 2>&1
is   "cloud key delivered exactly"   "$(jq -r 'select(.model=="model-cloud") | .auth' "$T/req.log" | head -n 1)" 'Bearer k"ey\x'
has  "pack rules sent as system"     "$(jq -rs 'map(select(.messages)) | last | .messages[0].content' "$T/req.log")" "Working rules"
is   "stdin sent as user message"    "$(jq -rs 'map(select(.messages)) | last | .messages[-1].content' "$T/req.log" | tr -d '\n')" "notes"
is   "no keys file left behind"      "$(ls "$T/data/spaces/hybrid/llm")" "$(printf 'extra-openai-models.yaml\nlogs.db')"
is   "remote model list"             "$(FAKE_API_KEY=x $A models --remote fakecloud | tr '\n' ' ')" "fake-model-a fake-model-b "
has  "data dir is private"           "$(ls -ld "$T/data")" "drwx------"
rm "$T/cfg/providers.conf" "$T/cfg/models.conf"


# --- spaces, memory and incognito
mkdir -p "$T/cfg"
printf 'fakelocal|local|http://127.0.0.1:%s/v1|\n' "$PORT" >"$T/cfg/providers.conf"
printf 'write|fakelocal|model-local|8|\n' >"$T/cfg/models.conf"
sysmsg() { jq -rs 'map(select(.messages)) | last | .messages | map(select(.role == "system")) | .[0].content // ""' "$T/req.log"; }
$A mode local >/dev/null
$A remember "Client name is Kowhai Ltd" >/dev/null
$A remember "Use NZ English" >/dev/null
has  "memory listed in local space"  "$($A memory)" "2. Use NZ English"
$A ask write hello >/dev/null 2>&1
has  "memory sent as context (local)" "$(sysmsg)" "Kowhai Ltd"
$A ask --no-memory write hello >/dev/null 2>&1
is   "--no-memory skips it"          "$(sysmsg)" ""
$A mode hybrid >/dev/null
has  "hybrid space can't see it"     "$($A memory)" "Nothing remembered in the hybrid space"
$A ask write hello >/dev/null 2>&1
is   "hybrid ask gets no local memory" "$(sysmsg)" ""
$A mode local >/dev/null
# llm 0.38+ records each exchange in the "turns" table
logrows() { python3 -c 'import sqlite3,sys; print(sqlite3.connect(sys.argv[1]).execute("select count(*) from turns").fetchone()[0])' "$T/data/spaces/local/llm/logs.db"; }
logs_before="$(logrows)"
$A incognito ask write hello >/dev/null 2>&1
is   "incognito ignores memory"      "$(sysmsg)" ""
is   "incognito leaves no folder"    "$(find "$T/data/incognito" -mindepth 1 | wc -l | tr -d ' ')" "0"
is   "incognito not in local logs"   "$(logrows)" "$logs_before"
if [ "$logs_before" -gt 0 ]; then ok "normal asks are logged ($logs_before turns)"; else bad "normal asks are logged" "$logs_before"; fi
printf 'hi\nexit\n' | $A -i repl write >/dev/null 2>&1
is   "incognito repl leaves nothing" "$(find "$T/data/incognito" -mindepth 1 | wc -l | tr -d ' ')" "0"
fails "incognito refuses to remember" $A -i remember "secret"
mkdir -p "$T/data/incognito/999999"
$A -i memory >/dev/null
is   "stale incognito folder cleaned" "$(ls "$T/data/incognito")" ""
$A forget 1 >/dev/null
is   "forget one"                    "$($A memory | sed -n 2p)" "  1. Use NZ English"
$A forget all >/dev/null
has  "forget all"                    "$($A memory)" "Nothing remembered"
$A mode hybrid >/dev/null; $A remember "hybrid note" >/dev/null; $A mode local >/dev/null
AIKIT_YES=1 $A wipe local >/dev/null
is   "wipe local keeps hybrid"       "$(ls "$T/data/spaces")" "hybrid"
rm "$T/cfg/providers.conf" "$T/cfg/models.conf"

# --- prompts
has  "lists core prompts"            "$($A prompt)" "rewrite"
has  "lists pack prompts"            "$($A prompt)" "security-reports/gap-analysis"
fails "unknown prompt"               $A prompt nope

# --- validation catches bad rows
printf 'write|nope|x|8|\n' >"$T/cfg/models.conf"
fails "check rejects unknown provider" $A check
rm "$T/cfg/models.conf"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
