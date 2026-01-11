#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Arch Linux Post-Install Script
# Hyprland + AUR (yay) + Zsh + Fonts + Theming
# =========================================================
#
# Run this script as a regular user with sudo privileges.
# Do NOT run as root.
#
# =========================================================

# -----------------------
# Package definitions
# -----------------------

PACMAN_PKGS_STAGE1=(
  hyprland
  hyprlock
  kitty
  nano
  git
  base-devel
)

PACMAN_PKGS_MISC=(
  hyprpaper
  zsh
  rofi
  waybar
  swaync
  sddm
  qt5
  qt5-quickcontrols2
  qt5-svg
  xdg-user-dirs
  pavucontrol
  vlc
  blueman
  networkmanager
  nm-connection-editor
  brightnessctl
  ristretto
  papirus-icon-theme
  papirus-folders
  thunar
  gvfs
  gvfs-smb
)

AUR_PKGS=(
  brave-bin
  visual-studio-code-bin
  nwg-look
  ttf-jetbrains-mono-nerd
  noto-fonts
  noto-fonts-emoji
  gruvbox-dark-gtk
)

# -----------------------
# Helper functions
# -----------------------

log() {
  printf "\n[%s] %s\n" "$(date +'%F %T')" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command '$1' not found." >&2
    exit 1
  }
}

check_arch() {
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *"arch"* ]]
}

pacman_install() {
  sudo pacman --noconfirm --needed "$@"
}

# -----------------------
# Pre-flight checks
# -----------------------

if ! check_arch; then
  echo "This script is intended for Arch Linux (or Arch-based systems)." >&2
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  echo "Do not run this script as root. Run it as a regular user with sudo access." >&2
  exit 1
fi

require_cmd sudo
require_cmd pacman
require_cmd git
require_cmd curl

# -----------------------
# System update
# -----------------------

log "Updating system (pacman -Syu)..."
sudo pacman -Syu --noconfirm

# -----------------------
# Base packages
# -----------------------

log "Installing base packages..."
pacman_install -S "${PACMAN_PKGS_STAGE1[@]}"

log "Installing additional packages..."
pacman_install -S "${PACMAN_PKGS_MISC[@]}"

# -----------------------
# Enable common services
# -----------------------

log "Enabling NetworkManager and SDDM..."
sudo systemctl enable --now NetworkManager.service || true
sudo systemctl enable --now sddm.service || true

# -----------------------
# yay (AUR helper)
# -----------------------

if ! command -v yay >/dev/null 2>&1; then
  log "yay not found. Installing yay..."

  pacman_install -S base-devel git

  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT

  git clone https://aur.archlinux.org/yay.git "$TMPDIR/yay"
  pushd "$TMPDIR/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
else
  log "yay already installed. Skipping."
fi

# -----------------------
# AUR packages
# -----------------------

log "Updating repositories and AUR packages via yay..."
yay -Syu --noconfirm

log "Installing AUR packages..."
yay -S --noconfirm --needed "${AUR_PKGS[@]}"

# -----------------------
# Post-install steps
# -----------------------

log "Updating XDG user directories..."
xdg-user-dirs-update || true

log "Changing default shell to zsh..."
if [[ "${SHELL:-}" != "/bin/zsh" ]]; then
  chsh -s /bin/zsh || true
fi

# -----------------------
# Oh My Zsh
# -----------------------

log "Installing Oh My Zsh (non-interactive)..."
export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true

# -----------------------
# Powerlevel10k
# -----------------------

log "Installing powerlevel10k..."
if [[ ! -d "$HOME/powerlevel10k" ]]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
fi

P10K_LINE='source ~/powerlevel10k/powerlevel10k.zsh-theme'
if [[ -f "$HOME/.zshrc" ]]; then
  grep -qxF "$P10K_LINE" "$HOME/.zshrc" || echo "$P10K_LINE" >> "$HOME/.zshrc"
else
  echo "$P10K_LINE" > "$HOME/.zshrc"
fi

# -----------------------
# Theming
# -----------------------

log "Applying Papirus folders (black variant)..."
papirus-folders -C black || true

# -----------------------
# Done
# -----------------------

log "Setup completed successfully."

echo
echo "Notes:"
echo "- You may need to install GPU drivers and audio (PipeWire/PulseAudio) manually depending on your system."
echo "- Log out and log back in (or reboot) to ensure all changes take effect."
