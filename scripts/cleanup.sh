#!/usr/bin/env bash
set -euo pipefail

echo "=== Cleaning up for minimal snapshot ==="

# Change to mounted NixOS system
cd /mnt

# Remove nixpkgs channel tarball (will download on first boot)
echo "Removing nixpkgs channel..."
chroot /mnt /nix/var/nix/profiles/per-user/root/channels/bin/nix-channel --remove nixos || true

# Aggressive garbage collection
echo "Running garbage collection..."
chroot /mnt nix-collect-garbage -d

# Optimize Nix store (hard-link duplicates)
echo "Optimizing Nix store..."
chroot /mnt nix-store --optimize

# Clean all logs
echo "Cleaning logs..."
chroot /mnt journalctl --vacuum-time=1s
rm -rf /mnt/var/log/journal/* || true

# Remove SSH host keys (regenerated on first boot)
echo "Removing SSH host keys..."
rm -f /mnt/etc/ssh/ssh_host_*

# Clean shell history
echo "Cleaning shell history..."
rm -f /mnt/root/.bash_history
rm -f /mnt/root/.lesshst

# Clean temp files
echo "Cleaning temp files..."
rm -rf /mnt/tmp/* /mnt/var/tmp/* 2>/dev/null || true
rm -rf /mnt/root/.cache/* 2>/dev/null || true

# Show final sizes
echo ""
echo "=== Final Image Stats ==="
echo "Nix store size:"
du -sh /mnt/nix/store
echo ""
echo "Total disk usage:"
df -h /mnt | grep -v Filesystem
echo ""

echo "=== Cleanup complete ==="
echo "Image ready for snapshot!"
