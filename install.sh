#!/usr/bin/env bash
# usage: ./install.sh [step ...]
# default steps: packages shell configs services theme sddm limine cleanup soundboard
# optional step: music (MUSIC_SRC=/path/to/Music or MUSIC_URL=https://...)

set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_REPO="https://github.com/FavnyWasTaken/my-caelestia-shell.git"
SHELL_BRANCH="custom"
SHELL_DIR="$HOME/.config/quickshell/caelestia"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.dots-backup/$(date +%Y%m%d-%H%M%S)"
OLD_HOME="/home/favny"
LIVE_WALLPAPER="$HOME/Pictures/Wallpapers/live.mp4"
WALLPAPER_URL="https://github.com/FavnyWasTaken/my-dots/releases/download/assets-v1/live.mp4"
SOUNDBOARD_THEME_URL="https://raw.githubusercontent.com/FavnyWasTaken/Soundboard-mono/main/soundboard-mono.sh"
DEFAULT_STEPS=(packages shell configs services theme sddm limine cleanup soundboard)

log()  { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }
die()  { echo "error: $*" >&2; exit 1; }

# backup <path> [name inside the backup dir]
backup() {
  [[ -e "$1" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp -a "$1" "$BACKUP_DIR/${2:-$(basename "$1")}"
}

preflight() {
  [[ $EUID -ne 0 ]] || die "don't run this as root"
  command -v pacman >/dev/null || die "only Arch-based systems are supported"
  command -v sudo >/dev/null || die "sudo is required"
  curl -fsI https://archlinux.org >/dev/null || die "no internet connection"
}

install_packages() {
  if ! command -v paru >/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
  fi
  sudo pacman -Syu
  local list pkgs
  for list in system apps; do
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$DOTS_DIR/packages/$list.txt")
    paru -S --needed --skipreview "${pkgs[@]}"
  done
}

install_shell() {
  mkdir -p "$(dirname "$SHELL_DIR")"
  if [[ -d "$SHELL_DIR/.git" ]]; then
    git -C "$SHELL_DIR" fetch origin
    git -C "$SHELL_DIR" checkout "$SHELL_BRANCH"
    git -C "$SHELL_DIR" pull --ff-only origin "$SHELL_BRANCH" || warn "could not fast-forward, keeping the local state"
  else
    if [[ -e "$SHELL_DIR" ]]; then
      mkdir -p "$BACKUP_DIR"
      mv "$SHELL_DIR" "$BACKUP_DIR/caelestia-shell"
    fi
    git clone --branch "$SHELL_BRANCH" "$SHELL_REPO" "$SHELL_DIR"
  fi
  cmake -B "$SHELL_DIR/build" -S "$SHELL_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build "$SHELL_DIR/build"
}

install_configs() {
  local stage item name
  stage="$(mktemp -d)"
  cp -a "$DOTS_DIR/config/." "$stage/"
  grep -rlI --null -- "$OLD_HOME" "$stage" | xargs -0 -r sed -i "s|$OLD_HOME|$HOME|g" || true
  for item in "$stage"/*; do
    name="$(basename "$item")"
    backup "$CONFIG_DIR/$name"
    if [[ -d "$item" ]]; then
      mkdir -p "$CONFIG_DIR/$name"
      cp -a "$item/." "$CONFIG_DIR/$name/"
    else
      cp -a "$item" "$CONFIG_DIR/$name"
    fi
  done
  rm -rf "$stage"

  mkdir -p "$HOME/Pictures"
  cp -a "$DOTS_DIR/Pictures/." "$HOME/Pictures/"
  [[ -f "$DOTS_DIR/home/.gtkrc-2.0" ]] && sed "s|$OLD_HOME|$HOME|g" "$DOTS_DIR/home/.gtkrc-2.0" > "$HOME/.gtkrc-2.0"
  [[ -f "$DOTS_DIR/home/.face" ]] && cp -a "$DOTS_DIR/home/.face" "$HOME/.face"

  # too big for git, it's a release asset
  if [[ ! -f "$LIVE_WALLPAPER" ]]; then
    if curl -fL "$WALLPAPER_URL" -o "$LIVE_WALLPAPER.part"; then
      mv "$LIVE_WALLPAPER.part" "$LIVE_WALLPAPER"
    else
      rm -f "$LIVE_WALLPAPER.part"
      warn "could not download live.mp4, the animated wallpaper will be skipped"
    fi
  fi

  mkdir -p "$HOME/Music" "$HOME/Videos/Replays" "$CONFIG_DIR/mpd/playlists" "$HOME/.local/share/mpd"

  backup "$HOME/.icons" icons
  mkdir -p "$HOME/.icons"
  cp -a "$DOTS_DIR/icons/." "$HOME/.icons/"
}

install_services() {
  mkdir -p "$CONFIG_DIR/systemd/user"
  cp -a "$DOTS_DIR"/systemd/*.service "$CONFIG_DIR/systemd/user/"
  systemctl --user daemon-reload || warn "systemctl --user is unavailable, enable the services after the first login"

  local unit
  for unit in quickshell-caelestia.service mpd.service linux-soundboard-engine.target; do
    systemctl --user enable "$unit" || warn "could not enable $unit"
  done

  if [[ -f "$LIVE_WALLPAPER" ]]; then
    systemctl --user enable wallpaper.service || warn "could not enable wallpaper.service"
  else
    warn "live.mp4 not found, wallpaper.service was not enabled"
  fi

  systemctl is-enabled display-manager.service &>/dev/null || sudo systemctl enable sddm.service || warn "could not enable sddm"
}

set_dark_theme() {
  command -v gsettings >/dev/null || { warn "gsettings not found, skipping the theme"; return 0; }
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || { warn "no desktop session, log in and run ./install.sh theme"; return 0; }
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark || warn "could not set color-scheme"
  gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || warn "could not set gtk-theme"
  gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark || warn "could not set icon-theme"
  command -v dconf >/dev/null && dconf load /org/gnome/desktop/interface/ < "$DOTS_DIR/dconf/interface.ini" || warn "could not load the dconf settings"
}

install_sddm() {
  local dest=/usr/share/sddm/themes/pixel-cyberpunk
  [[ -d "$DOTS_DIR/sddm/pixel-cyberpunk" ]] || die "sddm/pixel-cyberpunk is missing in the repo, run git pull"
  sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
  sudo rm -rf "$dest"
  sudo cp -a "$DOTS_DIR/sddm/pixel-cyberpunk" "$dest"
  if [[ -f "$LIVE_WALLPAPER" ]]; then
    sudo cp "$LIVE_WALLPAPER" "$dest/bg.mp4"
  else
    warn "live.mp4 not found, the sddm theme will have no background video"
  fi
  sudo cp "$DOTS_DIR/sddm/99-theme.conf" /etc/sddm.conf.d/99-theme.conf
}

install_limine() {
  local conf=/boot/limine.conf src="$DOTS_DIR/limine"
  if ! sudo test -f "$conf"; then
    warn "$conf not found, skipping limine"
    return 0
  fi
  [[ -f "$src/header.conf" && -f "$src/limine-splash.png" && -f "$src/monocraft.bin" ]] || die "limine/ files are missing in the repo, run git pull"

  local keys="remember_last_entry|term_font|term_font_size|term_font_scale|term_palette|term_palette_bright|term_foreground|term_foreground_bright|term_margin|interface_branding|wallpaper"
  local tmp bak before after
  tmp="$(mktemp)"
  bak="$conf.bak-$(date +%Y%m%d-%H%M%S)"
  sudo cp -a "$conf" "$bak"
  echo "limine.conf backup: $bak"

  # my header on top, then the old file without the old customization keys
  { cat "$src/header.conf"; sudo grep -vE "^($keys):" "$conf" || true; } > "$tmp"

  before="$(sudo grep -c '^/' "$conf" || true)"
  after="$(grep -c '^/' "$tmp" || true)"
  if [[ "$before" != "$after" ]]; then
    rm -f "$tmp"
    die "boot entry count changed ($before -> $after), limine.conf was not modified"
  fi

  sudo install -m 644 "$src/limine-splash.png" /boot/limine-splash.png
  sudo install -m 644 "$src/monocraft.bin" /boot/monocraft.bin
  sudo diff -u "$conf" "$tmp" || true
  sudo install -m 644 "$tmp" "$conf"
  rm -f "$tmp"
}

remove_unneeded() {
  local pkg found=()
  for pkg in vim micro nano meld alacritty firefox; do
    pacman -Qq "$pkg" &>/dev/null && found+=("$pkg")
  done
  [[ ${#found[@]} -gt 0 ]] || return 0
  sudo pacman -Rnsdd "${found[@]}" || warn "could not remove: ${found[*]}"
}

install_soundboard() {
  if ! pacman -Qq linux-soundboard &>/dev/null; then
    warn "linux-soundboard is not installed, skipping the theme (install it and run ./install.sh soundboard)"
    return 0
  fi
  curl -fsSL "$SOUNDBOARD_THEME_URL" | bash || warn "soundboard theme failed, run ./install.sh soundboard to retry"
}

install_music() {
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
    die "set MUSIC_SRC=/path/to/Music or MUSIC_URL=https://... for this step"
  fi
}

main() {
  preflight
  local steps=("$@") step
  [[ ${#steps[@]} -gt 0 ]] || steps=("${DEFAULT_STEPS[@]}")
  for step in "${steps[@]}"; do
    log "$step"
    case "$step" in
      packages)   install_packages ;;
      shell)      install_shell ;;
      configs)    install_configs ;;
      services)   install_services ;;
      theme)      set_dark_theme ;;
      sddm)       install_sddm ;;
      limine)     install_limine ;;
      cleanup)    remove_unneeded ;;
      soundboard) install_soundboard ;;
      music)      install_music ;;
      *) die "unknown step: $step" ;;
    esac
  done
  log "done, log out and back in (or reboot) to start the desktop"
  [[ ! -d "$BACKUP_DIR" ]] || echo "backups: $BACKUP_DIR"
}

main "$@"
