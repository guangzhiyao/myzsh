## myzsh

Personalized Zsh setup with auto-complete, syntax highlighting, and modern prompt using Starship and Atuin shell history.

## Prerequisites

- Debian 13+ (or any Debian-based distro with apt)
- curl
- git

## Installation

```bash
git clone https://github.com/NeverBlink/myzsh
cd myzsh
chmod +x setup_zsh.sh
./setup_zsh.sh
```

The script will install and configure:
- **Zsh** shell with Oh-My-Zsh framework
- **Starship** modern prompt
- **Atuin** shell history management
- **Plugins**: zsh-autosuggestions, zsh-syntax-highlighting
- **Font**: CaskaydiaCove Nerd Font

After installation, restart your shell:
```bash
exec zsh
```

## Features

- 🌠 **Starship Prompt**: Fast, customizable, and cross-platform prompt
- 📜 **Atuin**: Better shell history with sync capabilities
- ✨ **Autosuggestions**: Fish-like autocompletion
- 🎨 **Syntax Highlighting**: Real-time command highlighting
- 📝 **Nerd Font**: CaskaydiaCove for better UI rendering

## Customization

### Starship Prompt
The prompt is configured with a modern, clean design that includes:
- **Fast response** (500ms timeout) - responsive even on slow connections
- **Directory truncation** - shows context without cluttering
- **Git integration** - branch and status indicators
- **Command duration** - shows how long commands take (if > 2 seconds)
- **Status indicator** - shows ✓/✗ for success/failure

Edit `~/.config/starship.toml` to customize. Popular options:
```toml
# Change timeout (in milliseconds)
command_timeout = 500

# Disable modules you don't need
[nodejs]
disabled = false

# Customize colors
[directory]
style = "bold cyan"
```

See [Starship documentation](https://starship.rs/config/) for full options.

### Atuin History
Atuin provides powerful shell history with:
- **Fuzzy search** - Ctrl+R for smart history search
- **Deduplication** - removes duplicate commands
- **Statistics** - tracks your command usage
- **Local mode** - works offline without sync

Edit `~/.config/atuin/config.toml` to customize:
```toml
# Enable remote sync
auto_sync = true
sync_interval = 60

# Change search mode
search_mode = "prefix"  # or "fuzzy"

# Show command preview
preview_height = 4
```

See [Atuin documentation](https://docs.atuin.sh/) for all options.

## Used Tools / Repos

### Core
- **Oh-My-Zsh** - https://github.com/ohmyzsh/ohmyzsh
- **Starship** - https://github.com/starship/starship
- **Atuin** - https://github.com/atuinsh/atuin

### Plugins
- **zsh-autosuggestions** - https://github.com/zsh-users/zsh-autosuggestions
- **zsh-syntax-highlighting** - https://github.com/zsh-users/zsh-syntax-highlighting

### Font
- **CaskaydiaCove Nerd Font** - https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/CascadiaCode

## License

See LICENSE file