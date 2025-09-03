#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="$HOME/dotfiles-install.log"
DRY_RUN=false
ZSHRC_PATH="$HOME/.zshrc"

log() {
  echo "$*" | tee -a "$LOG_FILE"
}

run() {
  if $DRY_RUN; then
    log "[dry-run] $*"
  else
    log "Running: $*"
    eval "$@" 2>&1 | tee -a "$LOG_FILE"
  fi
}

# --- Parse Args ---
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
    log "Dry-run mode enabled"
  fi
done

# --- Shell Detection ---
CURRENT_SHELL="$(ps -p $$ -o comm=)"
log "Detected shell: $CURRENT_SHELL"

if [[ "$CURRENT_SHELL" == *zsh* ]]; then
  log "Warning: This script is running in Zsh. Some logic assumes Bash and may behave differently."
fi

# --- Bash Version Check ---
if [[ -n "${BASH_VERSION:-}" ]]; then
  BASH_MAJOR="${BASH_VERSINFO[0]}"
  if (( BASH_MAJOR < 4 )); then
    log "Warning: Bash < 4 detected. Some features may be limited. Recommend installing Bash 5."
  fi
else
  log "Bash not detected. You're likely running under another shell."
fi

# --- OS/Arch Detection ---
OS="$(uname -s)"
ARCH="$(uname -m)"
log "Detected OS: $OS"
log "Architecture: $ARCH"

if [[ $EUID -eq 0 ]]; then
  log "This script should not be run as root"
  exit 1
fi

# --- Package Manager Setup ---
if [[ "$OS" == "Darwin" ]]; then
  if ! command -v brew &>/dev/null; then
    log "Installing Homebrew"
    run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  PKG_INSTALL="brew install"
  CASK_INSTALL="brew install --cask"
else
  run "apt update -y"
  run "apt install -y curl git zsh tmux unzip wget build-essential"
  PKG_INSTALL="apt install -y"
  CASK_INSTALL=":"
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  log "Homebrew not found. Installing Homebrew..."
  run 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  # For Linux, add Brew to PATH if needed
  if [[ "$OS" != "Darwin" ]]; then
    if ! grep -q '/home/linuxbrew/.linuxbrew/bin' "$HOME/.profile"; then
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.profile"
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  else
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
  fi
else
  log "Homebrew is already installed"
fi

# --- Oh My Zsh ---
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing Oh My Zsh"
  run 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
else
  log "Oh My Zsh already installed"
fi

# --- Powerlevel10k ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
  log "Installing Powerlevel10k theme"
  run "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $P10K_DIR"
else
  log "Powerlevel10k already installed"
fi

# --- Zsh Plugins (no associative arrays) ---
ZSH_PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
plugins=(
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting"
  #"alias-finder|https://github.com/zdharma-continuum/alias-finder"
)

for plugin in "${plugins[@]}"; do
  name="${plugin%%|*}"
  url="${plugin##*|}"
  target="$ZSH_PLUGIN_DIR/$name"
  if [[ ! -d "$target" ]]; then
    log "Installing plugin: $name"
    run "git clone --depth=1 $url $target"
  else
    log "Plugin already installed: $name"
  fi
done

# --- NVM & Node ---
if [[ ! -d "$HOME/.nvm" ]]; then
  log "Installing NVM"
  run 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
else
  log "NVM already installed"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

log "Installing latest Node.js with NVM"
run "nvm install node"
run "nvm use node"

# --- Bun ---
if ! command -v bun &>/dev/null; then
  log "Installing Bun"
  run 'curl -fsSL https://bun.sh/install | bash'
else
  log "Bun already installed"
fi

# --- Go ---
if ! command -v go &>/dev/null; then
  log "Installing Go"
  if [[ "$OS" == "Darwin" ]]; then
    run "$PKG_INSTALL go"
  else
    # Set Go version and correct architecture string
    GO_VER="1.22.3"
    GO_ARCH="$ARCH"
    if [[ "$ARCH" == "x86_64" ]]; then
      GO_ARCH="amd64"
    elif [[ "$ARCH" == "aarch64" ]]; then
      GO_ARCH="arm64"
    fi

    # Download and extract Go
    GO_TGZ_URL="https://go.dev/dl/go${GO_VER}.linux-${GO_ARCH}.tar.gz"
    run "wget $GO_TGZ_URL -O /tmp/go${GO_VER}.linux-${GO_ARCH}.tar.gz"
    run "rm -rf /usr/local/go"
    run "tar -C /usr/local -xzf /tmp/go${GO_VER}.linux-${GO_ARCH}.tar.gz"
    # Ensure /usr/local/go/bin is in PATH for both current and future shells
    if ! grep -q '/usr/local/go/bin' "$HOME/.profile"; then
      echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.profile"
      log "Added /usr/local/go/bin to PATH via .profile"
    fi
    export PATH="$PATH:/usr/local/go/bin"
  fi
else
  log "Go already installed"
fi


# --- Docker ---
if ! command -v docker &>/dev/null; then
  log "Installing Docker"
  if [[ "$OS" == "Darwin" ]]; then
    run "$CASK_INSTALL docker"
  else
    run "apt install -y docker.io"
    run "usermod -aG docker $USER"
  fi
else
  log "Docker already installed"
fi

# --- CLI tools ---
log "Installing extra CLI tools"
run "$PKG_INSTALL tmux fzf ripgrep bat"
run "brew install fastfetch"


# --- Zsh config ---
if [[ -f "$ZSHRC_PATH" ]]; then
  log "Skipping .zshrc creation: already exists"
else
  log "Creating .zshrc"
  cat > "$ZSHRC_PATH" <<'EOF'
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
 git
 z
 docker
 history-substring-search
 alias-finder
 zsh-autosuggestions
 zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

HIST_STAMPS="yyyy-mm-dd"

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme 2>/dev/null || true

zstyle ':omz:plugins:alias-finder' autoload yes # disabled by default
zstyle ':omz:plugins:alias-finder' longer yes # disabled by default
zstyle ':omz:plugins:alias-finder' exact yes # disabled by default
zstyle ':omz:plugins:alias-finder' cheaper yes # disabled by default

alias ..='cd ..'
alias ll='ls -lah'
alias ports='lsof -i -P -n | grep LISTEN'
alias cls='clear'
alias ff='fastfetch'
alias zshconfig='nano ~/.zshrc'
alias reload='source ~/.zshrc'

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF
fi

# --- Change default shell ---
if [[ "$SHELL" != *zsh ]]; then
  log "Changing default shell to zsh"
  run "chsh -s $(which zsh)"
else
  log "Zsh is already the default shell"
fi

log "Install complete. Review ~/.zshrc (zshconfig) and restart your shell (reload) if needed."
log "Full log: $LOG_FILE"
