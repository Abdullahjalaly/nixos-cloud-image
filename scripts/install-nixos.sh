#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing NixOS on Hetzner Cloud ==="

# Partition disk (MBR for compatibility)
echo "Partitioning /dev/sda..."
parted -s /dev/sda -- mklabel msdos
parted -s /dev/sda -- mkpart primary ext4 1MiB 100%
parted -s /dev/sda -- set 1 boot on

# Format and mount root partition
echo "Formatting filesystem..."
mkfs.ext4 -L nixos /dev/sda1
mount /dev/sda1 /mnt

# Download NixOS installer
echo "Downloading NixOS 25.11 installer..."
cd /root
wget -q --show-progress https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso

# Mount ISO and setup NixOS tools
echo "Mounting NixOS ISO..."
mkdir -p /mnt-iso
mount -o loop latest-nixos-minimal-x86_64-linux.iso /mnt-iso

# Extract and prepare Nix
echo "Preparing Nix environment..."
mkdir -p /nix
mount --bind /mnt-iso/nix /nix

# Add NixOS tools to PATH
export PATH="/nix/var/nix/profiles/system/sw/bin:$PATH"

# Generate hardware configuration
echo "Generating NixOS configuration..."
nixos-generate-config --root /mnt

# Apply our custom minimal configuration
echo "Applying custom configuration..."
cp /tmp/configuration.nix /mnt/etc/nixos/configuration.nix

# Install NixOS (this takes ~10-15 minutes)
echo "Installing NixOS..."
echo "This will take 10-15 minutes. Please be patient..."
nixos-install --no-root-password

# Setup cloud-init config for first boot auto-upgrade
echo "Setting up cloud-init..."
mkdir -p /mnt/etc/cloud/cloud.cfg.d
cp /tmp/cloud-init-99-custom.yaml /mnt/etc/cloud/cloud.cfg.d/99-custom.yaml

echo "=== NixOS installation complete ==="
echo "System will boot into NixOS on next reboot"
