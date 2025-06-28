#!/usr/bin/env bash

# ===============================================================
# Broadcom BCM43142 Wi-Fi & Bluetooth Installer for Arch Linux
# Updated with proper kernel header handling and DKMS check
# ===============================================================

set -e
C_BLUE="\e[1;34m"; C_GREEN="\e[1;32m"; C_RED="\e[1;31m"; C_YELLOW="\e[1;33m"; C_RESET="\e[0m"

info()     { echo -e "${C_BLUE}INFO:${C_RESET} $1"; }
success()  { echo -e "${C_GREEN}SUCCESS:${C_RESET} $1"; }
warn()     { echo -e "${C_YELLOW}WARNING:${C_RESET} $1"; }
error()    { echo -e "${C_RED}ERROR:${C_RESET} $1" >&2; exit 1; }

info "Checking for root privileges..."
[[ $EUID -ne 0 || -z "$SUDO_USER" ]] && error "Run as: sudo bash ${0##*/}"
success "Running with root privileges."

info "Verifying package manager..."
command -v pacman &> /dev/null || error "This script is for Arch Linux only."
success "Pacman found."

# --- Step 1: Install kernel headers and broadcom-wl-dkms ---
info "Installing kernel headers and Broadcom Wi-Fi driver..."

# Always install both headers
pacman -Syu --needed --noconfirm linux-headers linux-lts-headers broadcom-wl-dkms

# Confirm DKMS status
if ! dkms status | grep -q 'broadcom-wl.*installed'; then
    error "DKMS did not successfully build the 'wl' driver."
fi
success "DKMS built the Broadcom wl module."

# --- Step 2: Install Bluetooth firmware via yay ---
info "Installing Broadcom Bluetooth firmware..."

if ! command -v yay &> /dev/null; then
    warn "'yay' not found. Installing it..."
    pacman -S --needed --noconfirm git base-devel
    sudo -u "$SUDO_USER" bash <<'EOF'
cd /tmp
rm -rf yay
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOF
    success "yay installed successfully."
fi

sudo -u "$SUDO_USER" yay -S --needed --noconfirm broadcom-bt-firmware
success "Bluetooth firmware installed."

# --- Step 3: Blacklist conflicting modules ---
info "Blacklisting conflicting Broadcom modules..."

cat > /etc/modprobe.d/broadcom-blacklist.conf <<EOF
# Prevent native Broadcom modules from loading
blacklist b43
blacklist b43legacy
blacklist ssb
blacklist bcma
EOF
success "Conflicting modules blacklisted."

# --- Step 4: Load wl module ---
info "Loading 'wl' kernel module..."
if modprobe wl; then
    success "'wl' module loaded successfully."
else
    error "Failed to load 'wl' module. Reboot and try again."
fi

# --- Final Reminder ---
echo
warn "A REBOOT IS STRONGLY RECOMMENDED to ensure everything works."
info "After reboot, run: lspci -k | grep -A 3 -i network"
success "Broadcom Wi-Fi and Bluetooth setup complete!"
