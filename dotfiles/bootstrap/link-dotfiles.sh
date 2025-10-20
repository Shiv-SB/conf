#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dev/dotfiles"

link_file() {
  src="$DOTFILES_DIR/$1"
  dest="$2"

  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "Skipping existing: $dest"
  else
    ln -s "$src" "$dest"
    echo "Linked $src -> $dest"
  fi
}

link_file "zsh/zshrc" "$HOME/.zshrc"
