#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# 1. Define the logical package list once
# ----------------------------------------
COMMON_PACKAGES=(
  btop
  micro
  zsh
  fastfetch
)

EXTRA_MAC_PACKAGES=()
EXTRA_LINUX_PACKAGES=()

ALL_MAC_PACKAGES=("${COMMON_PACKAGES[@]}" "${EXTRA_MAC_PACKAGES[@]}")
ALL_LINUX_PACKAGES=("${COMMON_PACKAGES[@]}" "${EXTRA_LINUX_PACKAGES[@]}")

# ----------------------------------------
# 2. Detect OS + Install System Packages
# ----------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Installing packages (macOS): ${ALL_MAC_PACKAGES[*]}"
  brew install "${ALL_MAC_PACKAGES[@]}"
elif [[ -f /etc/debian_version ]]; then
  echo "Installing packages (Linux/WSL): ${ALL_LINUX_PACKAGES[*]}"
  sudo apt update
  sudo apt install -y "${ALL_LINUX_PACKAGES[@]}"
fi

# ----------------------------------------
# 3. Manual Installs (idempotent)
# ----------------------------------------

# oh-my-zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "oh-my-zsh already installed"
fi

# bun
if ! command -v bun &>/dev/null; then
  echo "Installing Bun..."
  curl -fsSL https://bun.com/install | bash
else
  echo "Bun already installed"
fi

# nvm
if [[ ! -d "${HOME}/.nvm" ]]; then
  echo "Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
  echo "NVM already installed"
fi

# node install via NVM (deferred)
if command -v nvm &>/dev/null; then
  echo "Installing latest Node..."
  nvm install node
  echo "Run 'nvm use node' after restarting your shell."
else
  echo "nvm not available in current session; skip node install."
fi

# rustup
if ! command -v cargo &>/dev/null; then
  echo "Installing Rust & Cargo..."
  curl https://sh.rustup.rs -sSf | sh -s -- -y
else
  echo "Rust/Cargo already installed"
fi

# chess-tui (only if cargo exists)
if command -v cargo &>/dev/null && ! command -v chess-tui &>/dev/null; then
  echo "Installing chess-tui..."
  cargo install chess-tui || echo "Failed to install chess-tui"
fi
