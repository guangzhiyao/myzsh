#!/usr/bin/env bash
set -euo pipefail

# Hardened installer for Zsh + Oh-My-Zsh + Starship + Atuin
# - Privilege wrapper for apt operations (works with or without sudo, requires root or sudo)
# - Safe copy of dotfiles with timestamped backups
# - clone_or_update will update existing git clones
# - Basic checks for required commands (curl, git, unzip when needed)
# - Safer handling of remote install scripts (download to temp file then execute)
#
# Usage:
#   ./setup_zsh.sh          # Run installation
#   ./setup_zsh.sh --dry-run  # Show actions without making destructive changes
#   ./setup_zsh.sh --help

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DRY_RUN=0
CLEAN_INSTALL=0
INSTALL_FONT=0

log_info()    { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✓ $*${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error()   { echo -e "${RED}✗ $*${NC}" >&2; }

usage() {
    cat <<EOF
Usage: $0 [--dry-run] [--clean] [--install-font] [--help]

Options:
  --dry-run      Show what would be done, don't perform destructive changes
  --clean        Clean install: replace existing configuration files without backups
  --install-font Attempt to download and install a Nerd Font (only useful on UI/dev machines)
  --help         Show this help
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --clean|--force) CLEAN_INSTALL=1; shift ;;
        --install-font) INSTALL_FONT=1; shift ;;
        --help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 2 ;;
    esac
done

# Wrapper to run commands (respects dry run)
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] $*"
    else
        eval "$@"
    fi
}

# Determine apt invocation (sudo if necessary)
if [ "$(id -u)" -eq 0 ]; then
    APT_CMD="apt"
elif command -v sudo >/dev/null 2>&1; then
    APT_CMD="sudo apt"
else
    APT_CMD=""
fi

run_apt() {
    if [ -z "$APT_CMD" ]; then
        log_error "Root privileges are required to install packages (run as root or install sudo)."
        return 1
    fi
    # Usage: run_apt update | run_apt install -y pkg
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] $APT_CMD $*"
        return 0
    fi
    $APT_CMD "$@"
}

# Install package via apt if missing
install_package() {
    local pkg="$1"
    local display_name="${2:-$pkg}"

    if command -v "$pkg" &>/dev/null; then
        log_success "$display_name is already installed"
        return 0
    fi

    log_info "Installing $display_name..."
    if run_apt update && run_apt install -y "$pkg"; then
        log_success "$display_name installed"
        return 0
    else
        log_error "Failed to install $display_name via apt"
        return 1
    fi
}

# Clone a repo or update it if already present (idempotent)
clone_or_update() {
    local repo_url="$1"
    local target_dir="$2"
    local repo_name
    repo_name=$(basename "$repo_url" .git)

    if [ -d "$target_dir/.git" ]; then
        log_info "Updating existing $repo_name at $target_dir..."
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY-RUN] git -C \"$target_dir\" fetch --depth=1 origin"
            echo "[DRY-RUN] git -C \"$target_dir\" pull --ff-only"
            return 0
        fi
        if git -C "$target_dir" fetch --depth=1 origin &>/dev/null; then
            if git -C "$target_dir" pull --ff-only --rebase --autostash &>/dev/null; then
                log_success "$repo_name updated"
                return 0
            else
                log_warn "Could not fast-forward $repo_name; working tree may have local changes"
                return 0
            fi
        else
            log_warn "Failed to fetch updates for $repo_name; leaving existing clone"
            return 0
        fi
    fi

    # Clone if not present
    mkdir -p "$(dirname "$target_dir")"
    log_info "Cloning $repo_name into $target_dir..."
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] git clone --depth=1 \"$repo_url\" \"$target_dir\""
        return 0
    fi
    if git clone --depth=1 "$repo_url" "$target_dir"; then
        log_success "$repo_name cloned successfully"
        return 0
    else
        log_error "Failed to clone $repo_name"
        return 1
    fi
}

# Safely copy files with backups if the destination exists
safe_copy() {
    local src="$1"
    local dst="$2"

    if [ ! -e "$src" ]; then
        log_warn "Source $src does not exist, skipping copy to $dst"
        return 0
    fi

    if [ -e "$dst" ]; then
        local ts
        ts=$(date +%Y%m%d%H%M%S)
        local backup="${dst}.backup.${ts}"
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY-RUN] cp -a \"$dst\" \"$backup\""
        else
            if cp -a "$dst" "$backup"; then
                log_info "Existing $dst backed up to $backup"
            else
                log_warn "Failed to back up existing $dst to $backup"
            fi
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] mkdir -p \"$(dirname "$dst")\" && cp -a \"$src\" \"$dst\""
    else
        mkdir -p "$(dirname "$dst")"
        if cp -a "$src" "$dst"; then
            log_success "Copied $src to $dst"
            return 0
        else
            log_error "Failed to copy $src to $dst"
            return 1
        fi
    fi
}

# Set zsh as default shell if not already
set_zsh_default() {
    local zsh_path
    zsh_path=$(command -v zsh || true)
    if [ -z "$zsh_path" ]; then
        log_warn "zsh not found in PATH; cannot set as default shell"
        return 1
    fi

    if [ "$SHELL" = "$zsh_path" ]; then
        log_success "Zsh is already the default shell ($SHELL)"
        return 0
    fi

    log_info "Setting Zsh ($zsh_path) as default shell..."
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] chsh -s \"$zsh_path\""
        return 0
    fi

    if chsh -s "$zsh_path"; then
        log_success "Zsh set as default shell"
        return 0
    else
        log_warn "chsh failed. You may need to run: chsh -s \"$zsh_path\""
        return 1
    fi
}

# Install CaskaydiaCove Nerd Font (best-effort, non-fatal)
install_font() {
    log_info "Attempting to install CaskaydiaCove Nerd Font (best-effort)..."

    local fonts_dir="$HOME/.local/share/fonts"
    local font_file="$fonts_dir/CaskaydiaCoveNerdFont-Regular.ttf"

    if [ -f "$font_file" ]; then
        log_success "CaskaydiaCove Nerd Font already installed"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] create $fonts_dir and attempt to download font archive"
        return 0
    fi

    install_package unzip "unzip (required to install font)" || log_warn "unzip not available; font installation may fail"

    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip"
    local zip_file="$tmpdir/cascadiacode.zip"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSLo "$zip_file" "$zip_url"; then
            if unzip -q "$zip_file" -d "$tmpdir"; then
                mkdir -p "$fonts_dir"
                # Copy any NerdFont ttf files (best-effort)
                shopt -s nullglob 2>/dev/null || true
                local copied=0
                for f in "$tmpdir"/*NerdFont*.ttf "$tmpdir"/*NerdFont*.otf; do
                    if [ -f "$f" ]; then
                        cp -a "$f" "$fonts_dir/" && copied=$((copied+1)) || true
                    fi
                done
                if [ "$copied" -gt 0 ]; then
                    if command -v fc-cache >/dev/null 2>&1; then
                        fc-cache -fv "$fonts_dir" &>/dev/null || true
                    fi
                    log_success "CaskaydiaCove Nerd Font installed (copied $copied files)"
                    return 0
                fi
            fi
        fi
    fi

    log_warn "Could not download/install font automatically. Please install a compatible Nerd Font manually."
    return 0
}

# Execute remote script safely by downloading first and then running
# Usage: run_remote_script "<url>" ["shell"] [args...]
# Example: run_remote_script "https://starship.rs/install.sh" sh -s -- -y
run_remote_script() {
    local url="$1"
    shift || true
    local shell="${1:-bash}"
    shift || true
    # capture all remaining arguments as an array to forward them exactly
    local args=("$@")
    local tmpfile
    # Ensure tmpfile is always defined even if mktemp fails; using parameter expansion
    # in the trap avoids unbound variable errors under `set -u`.
    tmpfile=$(mktemp) || tmpfile=''
    trap 'rm -f "${tmpfile:-}"' RETURN

    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$url" -o "$tmpfile"; then
            log_error "Failed to download remote script: $url"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -qO "$tmpfile" "$url"; then
            log_error "Failed to download remote script: $url"
            return 1
        fi
    else
        log_error "Neither curl nor wget is available to fetch remote scripts."
        return 1
    fi

    # Optionally show first few lines for auditing
    log_info "Downloaded remote installer to $tmpfile (first 5 lines shown for audit):"
    head -n 5 "$tmpfile" || true

    if [ "$DRY_RUN" -eq 1 ]; then
        # Print a safely quoted preview of the command we would run
        printf '[DRY-RUN] %s %s' "$shell" "$tmpfile"
        for a in "${args[@]}"; do
            printf ' %q' "$a"
        done
        echo
        return 0
    fi

    if "$shell" "$tmpfile" "${args[@]}"; then
        log_success "Remote script executed successfully"
        return 0
    else
        log_error "Remote script failed: $url"
        return 1
    fi
}

# Basic pre-checks
preflight_checks() {
    log_info "Running preflight checks..."

    # We need at least: curl or wget, git, and a working POSIX shell.
    if ! command -v git >/dev/null 2>&1; then
        log_info "git not found; attempting to install git"
        install_package git "Git" || { log_error "git is required"; return 1; }
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        log_info "curl/wget not found; attempting to install curl"
        install_package curl "curl" || { log_warn "Neither curl nor wget present; remote installs may fail"; }
    fi

    return 0
}

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Zsh Setup with Starship & Atuin (Hardened)${NC}"
    echo -e "${BLUE}========================================${NC}\n"

    preflight_checks || { log_error "Preflight checks failed"; exit 1; }

    # Install core packages (best-effort; will stop on fatal errors)
    log_info "Ensuring core dependencies are present..."
    install_package zsh "Zsh" || { log_error "zsh is required"; exit 1; }
    install_package git "Git" || { log_error "git is required"; exit 1; }
    install_package curl "curl" || true

    # Set zsh default (best-effort)
    set_zsh_default || log_warn "Could not set zsh as default automatically"

    # Install font (non-fatal) — only if explicitly requested via --install-font
    if [ "$INSTALL_FONT" -eq 1 ]; then
        install_font || true
    else
        log_info "Skipping font installation (use --install-font to enable)"
    fi

    # Install Oh-My-Zsh (if not present)
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh-My-Zsh..."
        # Use unattended installer but download first to inspect
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY-RUN] curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/ohmyzsh_install.sh"
            echo "[DRY-RUN] sh /tmp/ohmyzsh_install.sh --unattended"
        else
            if run_remote_script "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" sh "--unattended"; then
                    log_success "Oh-My-Zsh installed"
                else
                    log_error "Oh-My-Zsh installation failed"
                    exit 1
                fi
        fi
    else
        log_success "Oh-My-Zsh is already installed"
    fi

    # Install plugins (zsh-autosuggestions, zsh-syntax-highlighting)
    log_info "Installing Zsh plugins..."
    clone_or_update "https://github.com/zsh-users/zsh-autosuggestions" \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

    # Install Starship
    if command -v starship >/dev/null 2>&1; then
        log_success "Starship is already installed"
    else
        log_info "Installing Starship..."
        # Prefer official installer with -y; download first
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY-RUN] curl -sS https://starship.rs/install.sh -o /tmp/starship_install.sh"
            echo "[DRY-RUN] sh /tmp/starship_install.sh -y"
        else
            # Forward arguments correctly: -s (read from stdin), "--" to end options, "-y" to auto-confirm
            if run_remote_script "https://starship.rs/install.sh" sh -s -- -y; then
            log_success "Starship installed"
        else
            log_error "Failed to install Starship"
            exit 1
        fi
        fi
    fi

    # Install Atuin
    if command -v atuin >/dev/null 2>&1; then
        log_success "Atuin is already installed"
    else
        log_info "Installing Atuin..."
        # Atuin provides a setup script; download first
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY-RUN] curl -sS https://setup.atuin.sh -o /tmp/atuin_install.sh"
            echo "[DRY-RUN] bash /tmp/atuin_install.sh"
        else
            if run_remote_script "https://setup.atuin.sh" bash; then
                log_success "Atuin installed"
            else
                log_warn "Atuin installer failed; attempting to install via apt if available"
                install_package atuin "Atuin" || log_warn "Atuin installation could not be completed"
            fi
        fi
    fi

    # Copy configurations
    if [ "$CLEAN_INSTALL" -eq 1 ]; then
        log_info "Clean install requested: existing configuration files will be replaced (no backups)"
    else
        log_info "Copying configuration files (backups will be created if target exists)..."
    fi

    # If clean install requested, remove existing targets so safe_copy will not create backups
    if [ "$CLEAN_INSTALL" -eq 1 ]; then
        rm -f "$HOME/.zshrc" "$HOME/.config/starship.toml" "$HOME/.config/atuin/config.toml" 2>/dev/null || true
    fi

    safe_copy ".zshrc" "$HOME/.zshrc"
    safe_copy "starship.toml" "$HOME/.config/starship.toml"

    # Ensure atuin config directory exists, then copy (respect clean install flag)
    mkdir -p "$HOME/.config/atuin"
    if [ "$CLEAN_INSTALL" -eq 1 ]; then
        safe_copy "atuin.toml" "$HOME/.config/atuin/config.toml"
    else
        # Preserve existing user Atuin config to avoid creating duplicate TOML keys
        if [ -f "$HOME/.config/atuin/config.toml" ]; then
            log_warn "Atuin config already exists at $HOME/.config/atuin/config.toml - skipping to avoid duplicate keys"
        else
            safe_copy "atuin.toml" "$HOME/.config/atuin/config.toml"
        fi
    fi

    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Installation complete (or dry-run finished).${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "\nℹ️  Please restart your shell or run: ${YELLOW}exec zsh${NC}\n"
}

main "$@"
