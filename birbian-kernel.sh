#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root (use: sudo -i bash birbian-kernel.sh)" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

KERNEL_META="${KERNEL_META:-kernel-pika}"

if [[ ! -f /etc/apt/sources.list.d/pikaos.sources ]]; then
    echo "The PikaOS repository is not configured yet." >&2
    echo "Run part 1 (birbian.sh) first to convert to Sid and add the repo." >&2
    exit 1
fi

echo ""
echo "This script will:"
echo "  1. Install the PikaOS kernel metapackage: ${KERNEL_META}"
echo "  2. Refresh grub"
echo ""
confirm=""
while [[ "${confirm}" != "y" && "${confirm}" != "yes" ]]; do
    read -r -p "Type 'y' to continue, anything else to abort: " confirm
done

echo ""
echo "== Refreshing apt =="
apt-get update -y

echo ""
echo "== Installing PikaOS kernel (${KERNEL_META}) =="
apt-get install -y "${KERNEL_META}"

if command -v update-grub >/dev/null 2>&1; then
    echo ""
    echo "== Refreshing grub =="
    update-grub
fi

echo ""
echo "== Installed PikaOS kernels =="
ls -1 /boot/vmlinuz-*pikaos* 2>/dev/null || echo "(no -pikaos vmlinuz found in /boot)"

echo ""
echo "Done. Reboot to boot the PikaOS kernel:"
echo "  sudo reboot"
echo ""
echo "To verify after reboot:"
echo "  uname -r        # should show a *-pikaos kernel"
echo "  apt list --installed | grep pikaos"
echo ""
echo "Tip: set KERNEL_META=kernel-pika-nvidia to also install NVIDIA dkms modules."
echo "Example: KERNEL_META=kernel-pika-nvidia sudo -i bash birbian-kernel.sh"