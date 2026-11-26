#!/usr/bin/env bash
# ai-kit installer. Safe to re-run. Needs internet.
#
# One line:
#   curl -fsSL https://raw.githubusercontent.com/OWNER/ai-kit/main/install.sh | bash
#
# Options (environment variables):
#   AIKIT_REF=v0.2.0      install a tagged release instead of main (recommended for teams)
#   AIKIT_HOME=~/ai-kit   where to put the kit (default ~/.ai-kit)
#   AIKIT_SYNC=1          also download the local models that fit this machine
#   AIKIT_SKIP_DEPS=1     don't use Homebrew; you provide ollama, uv, jq yourself
#   AIKIT_REPO=<git url>  install from a fork or internal mirror
set -euo pipefail

REPO="${AIKIT_REPO:-https://github.com/OWNER/ai-kit.git}"
REF="${AIKIT_REF:-main}"
DEST="${AIKIT_HOME:-$HOME/.ai-kit}"

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- step 1: when piped from curl, fetch the kit and re-run from the checkout.
bootstrap() {
  have git || die "git is required (macOS: xcode-select --install)"
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
  local kit="$1"
  # shellcheck disable=SC1091
  . "$kit/kit.conf"

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
    say "Installing tools with Homebrew"
    brew bundle --file="$kit/Brewfile"
  fi

  say "Installing Open WebUI (minimum $OPEN_WEBUI_MIN) and llm with uv"
  uv tool install --quiet --python "$PYTHON_VERSION" "open-webui>=$OPEN_WEBUI_MIN" \
    || uv tool upgrade --quiet open-webui
  uv tool install --quiet --python "$PYTHON_VERSION" llm || uv tool upgrade --quiet llm

  say "Linking the 'ai' command into ~/.local/bin"
  chmod +x "$kit/bin/ai"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$kit/bin/ai" "$HOME/.local/bin/ai"
  # shellcheck disable=SC2016  # written literally into the rc file
  local rc line='export PATH="$HOME/.local/bin:$PATH"  # ai-kit'
  case "${SHELL:-}" in */zsh) rc="$HOME/.zshrc" ;; */bash) rc="$HOME/.bashrc" ;; *) rc="$HOME/.profile" ;; esac
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) grep -qsF '# ai-kit' "$rc" || { echo "$line" >>"$rc"; say "Added ~/.local/bin to PATH in $rc"; } ;;
  esac

  # Belt and braces: switch off Ollama's cloud features in its own settings
  # file too, so it also applies if the Ollama desktop app is ever started.
  local sj="$HOME/.ollama/server.json"
  mkdir -p "$HOME/.ollama"
  if [ -f "$sj" ]; then
    jq '. + {disable_ollama_cloud: true}' "$sj" >"$sj.tmp" && mv "$sj.tmp" "$sj"
  else
    echo '{ "disable_ollama_cloud": true }' >"$sj"
  fi
  say "Ollama cloud features disabled in $sj"

  if [ "${AIKIT_SYNC:-0}" = 1 ]; then
    say "Downloading models that fit this machine (large)"
    "$kit/bin/ai" sync
  fi

  cat <<EOF

ai-kit is installed in $kit  (mode: local, nothing leaves this machine)

Open a NEW terminal, then:
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
