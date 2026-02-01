# myzsh

A small, opinionated Zsh setup that installs:
- Zsh + Oh-My-Zsh
- Starship prompt
- Atuin shell history
- Useful Zsh plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`)

This repository provides a hardened, idempotent installer script: `./setup_zsh.sh`.

Prerequisites
- Debian-based system (apt) is the primary target
- `git` and either `curl` or `wget` available

Quick install
```bash
git clone https://github.com/guangzhiyao/myzsh
cd myzsh
chmod +x setup_zsh.sh
./setup_zsh.sh
```

Important installer behaviour
- `--dry-run` shows actions without making changes.
- `--clean` / `--force` performs a clean install (replaces configs).
- `--install-font` enables an optional best-effort Nerd Font download (disabled by default; useful only on UI/dev machines).
- Existing user files are backed up with timestamps by default; `--clean` removes targets before copying.
- The installer downloads remote installers to temporary files for audit before execution.
- If an `Atuin` configuration already exists at `~/.config/atuin/config.toml`, the shipped config will be skipped unless `--clean` is used (to avoid duplicate TOML keys).

Post-install
- Restart your shell or run: `exec zsh`
- User configuration files written/modified:
  - `~/.zshrc`
  - `~/.config/starship.toml`
  - `~/.config/atuin/config.toml` (only when not present or when using `--clean`)

Notes & recommendations
- The installer assumes a Debian/apt environment. On other distros, run steps manually or adapt the script.
- If you want the provided configs but prefer to merge manually, consider copying `atuin.toml` to `~/.config/atuin/config.toml.example` and merging by hand.
- Verify `starship` and `atuin` behavior after install (e.g., `starship explain`, `atuin --version`).

License
See the `LICENSE` file in this repository.
