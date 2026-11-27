#!/usr/bin/env bash
# ai-kit installer. Safe to re-run. Needs internet.
#
# One line:
#   curl -fsSL https://raw.githubusercontent.com/sean-aura/ai-kit/refs/heads/main/install.sh | bash
#
# Options (environment variables):
#   AIKIT_REF=v0.2.0      install a tagged release instead of main (recommended for teams)
#   AIKIT_HOME=~/ai-kit   where to put the kit (default ~/.ai-kit)
#   AIKIT_SYNC=1          also download the local models that fit this machine
#   AIKIT_SKIP_DEPS=1     don't use Homebrew; you provide ollama, uv, jq yourself
#   AIKIT_REPO=<git url>  install from a fork or internal mirror
set -euo pipefail

REPO="${AIKIT_REPO:-https://github.com/sean-aura/ai-kit.git}"
REF="${AIKIT_REF:-main}"
DEST="${AIKIT_HOME:-$HOME/.ai-kit}"

CFG_DIR="${AIKIT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ai-kit}"
RECEIPT="$CFG_DIR/receipt"

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- the receipt: what ai-kit added vs what was already here, so uninstall
# removes only what it added. Format: kind|name|added or preexisting|detail
# The FIRST record of an item wins, so re-running the installer can never
# relabel something ai-kit added as "already here".
receipt_has() { [ -f "$RECEIPT" ] && grep -q "^$1|$2|" "$RECEIPT"; }
record() {
  receipt_has "$1" "$2" && return 0
  mkdir -p "$CFG_DIR"
  printf '%s|%s|%s|%s\n' "$1" "$2" "$3" "${4:-}" >>"$RECEIPT"
}
# ai-kit just created this because it was missing, so it's ai-kit's now,
# whatever an older record says (e.g. after `ai uninstall` and a reinstall).
record_added() {
  if receipt_has "$1" "$2"; then
    grep -v "^$1|$2|" "$RECEIPT" >"$RECEIPT.tmp" || true
    mv "$RECEIPT.tmp" "$RECEIPT"
  fi
  record "$1" "$2" added "${3:-}"
}
record_path() {   # record_path kind path: added unless it already exists
  if [ -e "$2" ] || [ -L "$2" ]; then record "$1" "$2" preexisting; else record "$1" "$2" added; fi
}
init_receipt() {
  # Look at everything BEFORE creating anything (the receipt's own folder included).
  local d st lines="" snap=""
  for d in "$HOME/.config" "$CFG_DIR" "$HOME/.local" "$HOME/.local/bin" "$HOME/.local/share" \
           "$HOME/.cache" "$HOME/.cache/uv" "$HOME/.local/share/uv" "$HOME/.ollama"; do
    if [ -e "$d" ]; then st=preexisting; else st=added; fi
    lines="$lines$d|$st
"
  done
  # What's in the usual places now, so uninstall can point out anything that
  # appears later (from ai-kit's tools or from anything else).
  if [ ! -s "$CFG_DIR/home-snapshot" ]; then
    snap="$(for d in "$HOME" "$HOME/.cache" "$HOME/.config" "$HOME/.local/share" "$HOME/Library/Caches" "$HOME/Library/Application Support"; do
              if [ -d "$d" ]; then find "$d" -mindepth 1 -maxdepth 1 -print; fi
            done 2>/dev/null | sort)"
  fi
  mkdir -p "$CFG_DIR"
  printf '%s' "$lines" | while IFS='|' read -r d st; do [ -n "$d" ] && record dir "$d" "$st"; done
  [ -s "$CFG_DIR/home-snapshot" ] || printf '%s\n' "$snap" >"$CFG_DIR/home-snapshot"
}

# ---- step 1: when piped from curl, fetch the kit and re-run from the checkout.
bootstrap() {
  have git || die "git is required (macOS: xcode-select --install)"
  init_receipt
  record_path checkout "$DEST"
  if [ -d "$DEST/.git" ]; then
    say "Updating $DEST ($REF)"
    git -C "$DEST" fetch --quiet --tags origin
    git -C "$DEST" checkout --quiet "$REF"
    git -C "$DEST" pull --quiet --ff-only 2>/dev/null || true   # no-op on a tag
  elif [ -e "$DEST" ]; then
    die "$DEST exists but is not a git checkout. Move it or set AIKIT_HOME."
  else
    say "Downloading ai-kit ($REF) to $DEST"
    git clone --quiet --branch "$REF" "$REPO" "$DEST"
  fi
  # Re-run from the checkout, reading from the terminal rather than the curl pipe.
  if { exec 3</dev/tty; } 2>/dev/null; then exec bash "$DEST/install.sh" "$@" 0<&3
  else exec bash "$DEST/install.sh" "$@" </dev/null; fi
}

names_in() { [ -d "$1" ] || return 0; find "$1" -mindepth 1 -maxdepth 1 -print | sed 's|.*/||' | sort; }

find_brew() {
  have brew && return 0
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [ -x "$b" ]; then eval "$("$b" shellenv)"; return 0; fi
  done
  return 1
}

# ---- step 2: install from the checkout.
install_kit() {
  local kit="$1" before after x
  # shellcheck disable=SC1091
  . "$kit/kit.conf"
  init_receipt
  record checkout "$kit" preexisting   # a checkout you cloned yourself is never deleted

  local os arch
  os="$(uname -s)"; arch="$(uname -m)"
  case "$os" in
    Darwin) [ "$arch" = arm64 ] || warn "Intel Mac detected: this works, but local models will be slow." ;;
    Linux)  warn "Linux support is best-effort (tested less than macOS). Local image generation is macOS-only." ;;
    *)      die "unsupported system: $os (macOS or Linux; on Windows use WSL)" ;;
  esac

  if [ "${AIKIT_SKIP_DEPS:-0}" = 1 ]; then
    say "Skipping Homebrew (AIKIT_SKIP_DEPS=1)"
    for c in ollama uv jq curl; do have "$c" || die "AIKIT_SKIP_DEPS=1 but '$c' is not installed"; done
  else
    if ! find_brew; then
      say "Homebrew is required. Install it, then re-run this installer:"
      # shellcheck disable=SC2016
      say '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      exit 1
    fi
    say "Installing tools with Homebrew (tools you already have are left as they are)"
    before="$( { brew list --formula -1; brew list --cask -1 | sed 's/^/cask:/'; } 2>/dev/null | sort)"
    HOMEBREW_BUNDLE_NO_UPGRADE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 brew bundle --no-upgrade --file="$kit/Brewfile"
    after="$( { brew list --formula -1; brew list --cask -1 | sed 's/^/cask:/'; } 2>/dev/null | sort)"
    # Everything new, including dependencies Homebrew pulled in.
    for x in $(comm -13 <(echo "$before") <(echo "$after")); do
      case "$x" in cask:*) record brew_cask "${x#cask:}" added ;; *) record brew "$x" added ;; esac
    done
    awk '/^brew "/ { gsub(/"/, "", $2); print $2 }' "$kit/Brewfile" | while read -r x; do
      if echo "$before" | grep -qx "$x"; then record brew "$x" preexisting; fi
    done
  fi

  # Python versions uv downloads (it may fetch one for the tools below).
  local pydir; pydir="$(uv python dir 2>/dev/null || true)"
  before="$(names_in "$pydir")"
  local tool spec
  for tool in open-webui llm; do
    spec="$tool"; [ "$tool" = open-webui ] && spec="open-webui>=$OPEN_WEBUI_MIN"
    # Decide by what is actually installed now; the receipt only labels it.
    if uv tool list 2>/dev/null | grep -q "^$tool "; then
      if grep -q "^uv_tool|$tool|added|" "$RECEIPT" 2>/dev/null; then
        uv tool upgrade --quiet "$tool" || warn "could not upgrade $tool"   # ai-kit's copy: keep it current
      else
        record uv_tool "$tool" preexisting
        say "$tool is already installed with uv: leaving your copy as it is"
      fi
    elif have "$tool"; then
      record uv_tool "$tool" preexisting external
      say "$tool is already installed (not via uv): leaving your copy as it is"
    else
      say "Installing $tool with uv"
      uv tool install --quiet --python "$PYTHON_VERSION" "$spec" || die "uv could not install $tool (see the message above)"
      record_added uv_tool "$tool"
    fi
  done
  after="$(names_in "$pydir")"
  for x in $(comm -13 <(echo "$before") <(echo "$after")); do
    case "$x" in .*) ;; *) record uv_python "$x" added ;; esac
  done

  say "Linking the 'ai' command into ~/.local/bin"
  chmod +x "$kit/bin/ai"
  mkdir -p "$HOME/.local/bin"
  local link="$HOME/.local/bin/ai"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$kit/bin/ai" ]; then
    record link "$link" added                       # ours from an earlier run
  elif [ -e "$link" ] || [ -L "$link" ]; then
    mv "$link" "$link.pre-ai-kit"                   # set yours aside; uninstall puts it back
    record link "$link" replaced "$link.pre-ai-kit"
    say "Moved your existing $link to $link.pre-ai-kit (restored on uninstall)"
  else
    record link "$link" added
  fi
  ln -sf "$kit/bin/ai" "$link"
  # shellcheck disable=SC2016  # written literally into the rc file
  # New terminals need ~/.local/bin on PATH. Add a guarded line (it does
  # nothing if the folder is already on PATH) to the file your shell reads,
  # whether or not this session happens to have it on PATH already.
  local rc=""
  # shellcheck disable=SC2016  # written literally into the startup file
  local line='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac  # ai-kit'
  case "${SHELL:-}" in
    */zsh)  rc="$HOME/.zshrc" ;;
    */bash) if [ "$os" = Darwin ]; then rc="$HOME/.bash_profile"; else rc="$HOME/.bashrc"; fi ;;  # macOS Terminal opens login shells
    */fish) rc="" ;;
    *)      rc="$HOME/.profile" ;;
  esac
  if [ -z "$rc" ]; then
    warn "fish shell: ai-kit doesn't edit fish's config. Run once: fish_add_path ~/.local/bin"
  elif ! grep -qsF '# ai-kit' "$rc"; then
    if [ -e "$rc" ]; then record rcline "$rc" added existing-file; else record rcline "$rc" added new-file; fi
    printf '%s\n' "$line" >>"$rc"
    say "Added ~/.local/bin to PATH in $rc"
  fi

  # Don't report success unless the tools ai-kit needs actually run.
  local uvbin; uvbin="$(uv tool dir --bin 2>/dev/null || echo "$HOME/.local/bin")"
  for tool in open-webui llm; do
    if ! PATH="$uvbin:$HOME/.local/bin:$PATH" command -v "$tool" >/dev/null 2>&1; then
      die "$tool is not installed or not runnable. Try: uv tool install --python $PYTHON_VERSION $tool  (then re-run this installer)"
    fi
  done

  # Belt and braces: switch off Ollama's cloud features in its own settings
  # file too, so it also applies if the Ollama desktop app is ever started.
  local sj="$HOME/.ollama/server.json" old
  mkdir -p "$HOME/.ollama"
  if [ -f "$sj" ]; then
    old="$(jq -c '.disable_ollama_cloud' "$sj" 2>/dev/null || echo null)"
    if [ "$old" = true ]; then record server_json "$sj" preexisting
    elif ! receipt_has server_json "$sj"; then
      mkdir -p "$CFG_DIR/originals"; cp -p "$sj" "$CFG_DIR/originals/server.json"   # exact copy, restored on uninstall
      record server_json "$sj" modified "$( [ "$old" = null ] && echo absent || echo "$old")"
    fi
    jq '. + {disable_ollama_cloud: true}' "$sj" >"$sj.tmp" && mv "$sj.tmp" "$sj"
  else
    record server_json "$sj" added
    echo '{ "disable_ollama_cloud": true }' >"$sj"
  fi
  say "Ollama cloud features disabled in $sj"

  if [ "${AIKIT_SYNC:-0}" = 1 ]; then
    say "Downloading models that fit this machine (large)"
    "$kit/bin/ai" sync
  fi

  # This installer can't change the PATH of the terminal that ran it, so say
  # exactly what to do in this window.
  local ready
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ready="Ready in this terminal." ;;
    *) if [ -n "$rc" ]; then ready="To use ai in THIS terminal, run:  source ${rc/#$HOME/\~}
   (or open a new terminal window)"
       else ready="Open a new terminal window to use ai."; fi ;;
  esac

  cat <<EOF

ai-kit is installed in $kit  (mode: local, nothing leaves this machine)
What it added and what it left alone is recorded in $RECEIPT
('ai receipt' to view; 'ai uninstall --all --dry-run' to preview removal).

>> $ready

Then:
  ai sync       download the local models for this machine (large; needs internet)
  ai doctor     check everything
  ai            pick a role and start chatting

To use Claude, ChatGPT or Gemini as well:
  ai mode hybrid && ai key set anthropic
EOF
}

main() {
  local here=""
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  if [ -n "$here" ] && [ -f "$here/bin/ai" ] && [ -f "$here/kit.conf" ]; then
    install_kit "$here"
  else
    bootstrap "$@"
  fi
}

# Everything is inside functions, so a partial download can't run half a script.
main "$@"
