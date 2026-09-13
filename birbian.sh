#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root (use: sudo -i bash birbian.sh)" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

COCKATIEL_COMPONENT="${COCKATIEL_COMPONENT:-cockatiel}"
KERNEL_META="${KERNEL_META:-kernel-pika}"
BACKUP_DIR="/root/apt-sources-backup-$(date +%Y%m%d-%H%M%S)"

if [[ ! -f /etc/os-release ]]; then
    echo "/etc/os-release not found; this does not look like a Debian system." >&2
    exit 1
fi
source /etc/os-release
echo "Detected OS: ${PRETTY_NAME:-unknown} on $(dpkg --print-architecture 2>/dev/null || echo unknown-arch)"

if [[ "${ID}" != "debian" ]]; then
    echo "Warning: this does not look like Debian (ID=${ID}). Proceeding anyway." >&2
fi
if [[ "${VERSION_CODENAME:-}" != "trixie" && "${VERSION_CODENAME:-}" != "trixie/sid" ]]; then
    echo "Warning: expected Debian 13 (trixie), found codename '${VERSION_CODENAME:-unknown}'." >&2
    echo "This script is intended for a fresh Debian 13 Trixie install." >&2
fi

echo ""
echo "This script will:"
echo "  1. Switch this Debian Trixie system to Debian Sid (unstable)"
echo "  2. Apt sources will be backed up to ${BACKUP_DIR}"
echo "  3. Add the PikaOS 'pika/${COCKATIEL_COMPONENT}' (Cockatiel) repository"
echo "  4. Install the PikaOS kernel metapackage: ${KERNEL_META}"
echo ""
confirm=""
while [[ "${confirm}" != "y" && "${confirm}" != "yes" ]]; do
    read -r -p "Type 'y' to continue, anything else to abort: " confirm
done

required=(wget ca-certificates)
echo ""
echo "== Refreshing apt and installing prerequisites =="
apt-get update -y
apt-get install -y "${required[@]}"

echo ""
echo "== Backing up existing apt sources to ${BACKUP_DIR} =="
mkdir -p "${BACKUP_DIR}"
cp -v /etc/apt/sources.list "${BACKUP_DIR}/sources.list.orig" 2>/dev/null || true
if [[ -d /etc/apt/sources.list.d ]]; then
    cp -v /etc/apt/sources.list.d/* "${BACKUP_DIR}/" 2>/dev/null || true
fi

echo ""
echo "== Removing old Trixie sources and writing Debian Sid sources =="
rm -f /etc/apt/sources.list
rm -rf /etc/apt/sources.list.d
mkdir -p /etc/apt/sources.list.d

cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: sid
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

echo ""
echo "== Upgrading Trixie to Debian Sid (this may take a while) =="
apt-get update -y
apt-get -y full-upgrade
apt-get -y autoremove

echo ""
echo "== Adding PikaOS Cockatiel repository and keyring =="
mkdir -p /etc/apt/keyrings
wget -q -O /etc/apt/keyrings/pika-keyring.gpg.key \
    https://github.com/PikaOS-Linux/pika-base-debian-container/raw/main/pika-keyring.gpg.key

cat > /etc/apt/sources.list.d/pikaos.sources <<EOF
Types: deb
URIs: https://ppa.pika-os.com/
Suites: pika
Components: ${COCKATIEL_COMPONENT}
Signed-By: /etc/apt/keyrings/pika-keyring.gpg.key
EOF

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