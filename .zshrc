# ~/.zshrc - repo-managed safe default
# This file is intended as a sensible default for most users.
# It ensures Atuin's install dir ($HOME/.atuin/bin) is available on PATH
# before attempting to initialize Atuin, so users don't need to manually
# add it to their shell configuration.

# Path to Oh-My-Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Allow overriding custom directory
export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Plugins (zsh-syntax-highlighting is sourced last below)
plugins=(git zsh-autosuggestions)

# ---- Ensure Atuin bin is on PATH (idempotent) ----
# If Atuin was installed into $HOME/.atuin/bin, it's common that this
# directory is not on PATH for non-login shells. Add it here if needed.
if [ -d "$HOME/.atuin/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.atuin/bin:"*)
      # already present
      ;;
    *)
      export PATH="$HOME/.atuin/bin:$PATH"
      ;;
  esac
fi

# If installer created an env helper script, source it (safe & idempotent)
if [ -f "$HOME/.atuin/bin/env" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.atuin/bin/env"
fi

# ---- Load Oh-My-Zsh safely ----
if [ -n "${ZSH:-}" ] && [ -f "${ZSH}/oh-my-zsh.sh" ]; then
  export plugins
  # shellcheck disable=SC1090
  source "${ZSH}/oh-my-zsh.sh"
else
  echo "⚠️  Oh-My-Zsh not found at ${ZSH}; continuing without it" >&2
fi

# ---- Starship prompt (modern & fast) ----
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ---- Atuin init: only run if command is available ----
# The PATH tweak above makes this work even if Atuin was installed to ~/.atuin/bin
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
else
  # If the binary isn't yet available, but an env helper exists (installer artifact),
  # source it and try again. This helps shells that source this file in non-login mode.
  if [ -f "$HOME/.atuin/bin/env" ]; then
    # shellcheck disable=SC1090
    source "$HOME/.atuin/bin/env"
    if command -v atuin >/dev/null 2>&1; then
      eval "$(atuin init zsh)"
    fi
  fi
fi

# ---- Completion setup ----
if type compinit >/dev/null 2>&1; then
  autoload -Uz compinit
  # -u avoids insecure directory checks failing for some setups
  compinit -u
fi

# ---- Useful zsh options ----
setopt auto_cd             # cd by just typing directory name
setopt pushd_ignore_dups   # don't store duplicates in directory stack
setopt correct_all         # suggest corrections for commands/arguments
setopt hist_ignore_dups    # avoid duplicate history entries
setopt share_history       # try to share history across sessions

# History sizing
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="${HOME}/.zsh_history"

# ---- Source zsh-syntax-highlighting last to avoid initialization ordering issues ----
_zsh_syntax_highlighting_path="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

if [ -f "${_zsh_syntax_highlighting_path}" ]; then
  # shellcheck disable=SC1090
  source "${_zsh_syntax_highlighting_path}"
else
  # check common system locations
  if [ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    # shellcheck disable=SC1090
    source "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  elif [ -f "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    # shellcheck disable=SC1090
    source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
fi

# ---- User overrides ----
# Create ~/.zshrc.local for per-machine or personal overrides instead of editing this file.
if [ -f "${HOME}/.zshrc.local" ]; then
  # shellcheck disable=SC1090
  source "${HOME}/.zshrc.local"
fi
