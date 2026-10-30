#!/usr/bin/env bash
# Installer for my Caelestia setup (Arch Linux / CachyOS).
#
# Usage:
#   ./install.sh                 run the default steps
#   ./install.sh configs         run only the listed steps
#   MUSIC_SRC=/path/to/Music ./install.sh music
#   MUSIC_URL=https://... ./install.sh music
#
# Default steps: packages shell configs services cleanup
# Optional step: music (never runs unless requested)

set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_REPO="https://github.com/FavnyWasTaken/my-caelestia-shell.git"
SHELL_BRANCH="custom"
SHELL_DIR="$HOME/.config/quickshell/caelestia"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.dots-backup/$(date +%Y%m%d-%H%M%S)"
OLD_HOME="/home/favny"   # home path used inside the repo files
WALLPAPER_URL="https://github.com/FavnyWasTaken/my-dots/releases/download/assets-v1/live.mp4"
DEFAULT_STEPS=(packages shell configs services cleanup)

remove_unneeded() {
  log "Removing unneeded packages"
  local pkg found=()
  for pkg in vim micro nano alacritty firefox; do
    pacman -Qq "$pkg" &>/dev/null && found+=("$pkg")
  done
  if [[ ${#found[@]} -eq 0 ]]; then
    echo "Nothing to remove."
    return 0
  fi
  sudo pacman -Rnsdd "${found[@]}" || warn "Could not remove: ${found[*]}"
}

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31merror: %s\033[0m\n' "$*" >&2; exit 1; }

preflight() {
  [[ $EUID -ne 0 ]] || die "Do not run this script as root."
  command -v pacman >/dev/null || die "pacman not found: only Arch-based systems are supported."
  command -v sudo >/dev/null || die "sudo is required."
  curl -fsI https://archlinux.org >/dev/null || die "No internet connection."
}

ensure_paru() {
  command -v paru >/dev/null && return 0
  log "Installing paru"
  sudo pacman -S --needed --noconfirm git base-devel
  local tmp
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
  (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

read_list() { grep -vE '^\s*(#|$)' "$1"; }

install_packages() {
  ensure_paru
  log "Updating system"
  sudo pacman -Syu
  local list pkgs
  for list in system apps; do
    log "Installing $list packages"
    mapfile -t pkgs < <(read_list "$DOTS_DIR/packages/$list.txt")
    paru -S --needed --skipreview "${pkgs[@]}"
  done
}

install_shell() {
  log "Getting the Caelestia shell fork"
  mkdir -p "$(dirname "$SHELL_DIR")"
  if [[ -d "$SHELL_DIR/.git" ]]; then
    git -C "$SHELL_DIR" fetch origin
    git -C "$SHELL_DIR" checkout "$SHELL_BRANCH"
    git -C "$SHELL_DIR" pull --ff-only origin "$SHELL_BRANCH" \
      || warn "Could not fast-forward, keeping the local state"
  else
    if [[ -e "$SHELL_DIR" ]]; then
      mkdir -p "$BACKUP_DIR"
      mv "$SHELL_DIR" "$BACKUP_DIR/caelestia-shell"
    fi
    git clone --branch "$SHELL_BRANCH" "$SHELL_REPO" "$SHELL_DIR"
  fi
  log "Building the shell"
  cmake -B "$SHELL_DIR/build" -S "$SHELL_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build "$SHELL_DIR/build"
}

install_configs() {
  log "Installing configs"
  local stage item name
  stage="$(mktemp -d)"
  cp -a "$DOTS_DIR/config/." "$stage/"

  # Replace the original author's home path with the current user's home
  grep -rlI --null -- "$OLD_HOME" "$stage" \
    | xargs -0 -r sed -i "s|$OLD_HOME|$HOME|g" || true

  for item in "$stage"/*; do
    [[ -d "$item" ]] || continue
    name="$(basename "$item")"
    if [[ -e "$CONFIG_DIR/$name" ]]; then
      mkdir -p "$BACKUP_DIR"
      cp -a "$CONFIG_DIR/$name" "$BACKUP_DIR/"
    fi
    mkdir -p "$CONFIG_DIR/$name"
    cp -a "$item/." "$CONFIG_DIR/$name/"
  done
  rm -rf "$stage"

  # Top-level files from config/ (for example starship.toml)
  local f
  for f in "$DOTS_DIR"/config/*; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    if [[ -e "$CONFIG_DIR/$name" ]]; then
      mkdir -p "$BACKUP_DIR"
      cp -a "$CONFIG_DIR/$name" "$BACKUP_DIR/"
    fi
    sed "s|$OLD_HOME|$HOME|g" "$f" > "$CONFIG_DIR/$name"
  done

  log "Installing pictures"
  mkdir -p "$HOME/Pictures"
  cp -a "$DOTS_DIR/Pictures/." "$HOME/Pictures/"

  # The animated wallpaper is too big for git, so it is a release asset
  if [[ ! -f "$HOME/Pictures/Wallpapers/live.mp4" ]]; then
    log "Downloading live.mp4"
    if curl -fL "$WALLPAPER_URL" -o "$HOME/Pictures/Wallpapers/live.mp4.part"; then
      mv "$HOME/Pictures/Wallpapers/live.mp4.part" "$HOME/Pictures/Wallpapers/live.mp4"
    else
      rm -f "$HOME/Pictures/Wallpapers/live.mp4.part"
      warn "Could not download live.mp4; the animated wallpaper will be skipped"
    fi
  fi
  mkdir -p "$HOME/Music" "$HOME/Videos/Replays"
}

install_services() {
  log "Installing user services"
  mkdir -p "$CONFIG_DIR/systemd/user"
  cp -a "$DOTS_DIR"/systemd/*.service "$CONFIG_DIR/systemd/user/"
  systemctl --user daemon-reload \
    || warn "systemctl --user is unavailable here; enable the services after the first login"

  local unit
  for unit in quickshell-caelestia.service mpd.service linux-soundboard-engine.target; do
    systemctl --user enable "$unit" || warn "Could not enable $unit"
  done

  if [[ -f "$HOME/Pictures/Wallpapers/live.mp4" ]]; then
    systemctl --user enable wallpaper.service || warn "Could not enable wallpaper.service"
  else
    warn "live.mp4 not found in ~/Pictures/Wallpapers: wallpaper.service was not enabled"
  fi

  if ! systemctl is-enabled display-manager.service &>/dev/null; then
    sudo systemctl enable sddm.service || warn "Could not enable sddm"
  fi
}

install_music() {
  log "Music"
  mkdir -p "$HOME/Music"
  if [[ -n "${MUSIC_SRC:-}" && -d "$MUSIC_SRC" ]]; then
    rsync -a --info=progress2 "$MUSIC_SRC"/ "$HOME/Music"/
  elif [[ -n "${MUSIC_URL:-}" ]]; then
    local archive
    archive="$(mktemp)"
    curl -fL "$MUSIC_URL" -o "$archive"
    tar -xf "$archive" -C "$HOME/Music"
    rm -f "$archive"
  else
    die "Set MUSIC_SRC=/path/to/Music or MUSIC_URL=https://... for this step."
  fi
}

main() {
  preflight
  local steps=("$@") step
  [[ ${#steps[@]} -gt 0 ]] || steps=("${DEFAULT_STEPS[@]}")
  for step in "${steps[@]}"; do
    case "$step" in
      packages) install_packages ;;
      shell)    install_shell ;;
      configs)  install_configs ;;
      services) install_services ;;
      music)    install_music ;;
      cleanup)  remove_unneeded ;;
      *) die "Unknown step: $step (available: ${DEFAULT_STEPS[*]} music)" ;;
    esac
  done
  log "Done. Log out and back in (or reboot) to start the desktop."
  if [[ -d "$BACKUP_DIR" ]]; then
    echo "Backups of replaced files: $BACKUP_DIR"
  fi
}

main "$@"
