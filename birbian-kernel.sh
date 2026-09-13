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
if ! apt-get install -y "${KERNEL_META}"; then
    if apt-cache policy libssl4 2>/dev/null | grep -q 'Candidate: (none)'; then
        echo ""
        echo "Install failed because PikaOS 'scx' requires libssl4," >&2
        echo "which is not available on Debian. Retrying with a pinned 'scx'" >&2
        echo "version that links against Debian's libssl3t64 instead." >&2
        SCX_PIN=""
        while read -r ver; do
            if ! apt-cache depends "scx=${ver}" 2>/dev/null | grep -qE '[^[:alnum:]]libssl4([^[:alnum:]]|$)'; then
                SCX_PIN="${ver}"
                break
            fi
        done < <(apt-cache policy scx 2>/dev/null | sed -n '/Version table:/,$p' | sed 's/^ *//' | cut -d' ' -f1 | grep -E '^[0-9]+\.[0-9]')
        if [[ -z "${SCX_PIN}" ]]; then
            echo "No usable 'scx' version found; giving up." >&2
            exit 1
        fi
        echo ""
        echo "== Installing PikaOS kernel with scx=${SCX_PIN} =="
        apt-get install -y "scx=${SCX_PIN}" "${KERNEL_META}"
        echo ""
        echo "Tip: to keep scx pinned after future upgrades, run:"
        echo "  printf 'Package: scx\\nPin: version ${SCX_PIN}\\nPin-Priority: 1001\\n' | sudo tee /etc/apt/preferences.d/scx-pin"
    else
        exit 1
    fi
fi

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