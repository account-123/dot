#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# --- Enable Multilib Repository ---
read -p "Should I enable the multilib repository? (Needed for Steam, 32-bit drivers, etc.) [Y/n]: " choice
# Default to Yes if the user just presses Enter
if [[ -z "$choice" || "$choice" == [yY] ]]; then
    echo "Enabling multilib repository..."
    # Uncomment the [multilib] section in /etc/pacman.conf
    sed -i "/^#\\[multilib\\]/,/^#Include/"'s/^#//' /etc/pacman.conf
else
    echo "Skipping multilib repository."
fi

# --- Synchronize Package Databases ---
echo "Synchronizing package databases..."
pacman -Syu --noconfirm

# --- Graphics Driver Installation ---
echo "Select the graphics driver to install:"
options=("NVIDIA" "AMD" "Intel" "Skip")
select opt in "${options[@]}"; do
    case $opt in
        "NVIDIA")
            echo "Installing NVIDIA drivers..."
            pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings libxnvctrl
            break
            ;;
        "AMD")
            echo "Installing AMD drivers..."
            pacman -S --noconfirm --needed lib32-mesa vulkan-radeon lib32-vulkan-radeon
            break
            ;;
        "Intel")
            echo "Installing Intel drivers..."
            pacman -S --noconfirm --needed lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver xf86-video-intel
            break
            ;;
        "Skip")
            echo "Skipping graphics driver installation."
            break
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done

# --- YAY (AUR Helper) Installation ---
echo "Installing yay AUR helper..."
pacman -S --noconfirm --needed git base-devel
# Switch to a non-root user to build yay
if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" bash -c '
        cd /tmp
        if [ ! -d "yay" ]; then
            git clone https://aur.archlinux.org/yay.git
        fi
        cd yay
        makepkg -si --noconfirm
    '
else
    echo "Cannot determine non-root user. Please install yay manually." >&2
    exit 1
fi

# --- Hyprland and SDDM Installation ---
echo "Installing Hyprland, SDDM, and essential packages..."
pacman -S --noconfirm --needed hyprland waybar kitty sddm xdg-desktop-portal-hyprland ttf-jetbrains-mono noto-fonts noto-fonts-cjk noto-fonts-emoji

# --- Enable SDDM ---
echo "Enabling SDDM service..."
systemctl enable sddm.service

echo "Installation complete! Please reboot your system for the changes to take effect."

# Ask the user if they want to reboot
read -p "Do you want to reboot now? (y/N): " reboot_choice
case "$reboot_choice" in
  y|Y )
    echo "Rebooting..."
    reboot
    ;;
  * )
    echo "Please reboot your system manually later."
    ;;
esac

exit 0
