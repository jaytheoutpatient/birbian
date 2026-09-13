#!/usr/bin/env bash
set -euo pipefail

REPO="jaytheoutpatient/birbian"
BRANCH="main"
SCRIPT="birbian.sh"
URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${SCRIPT}"

echo ""
if [[ ${EUID} -eq 0 ]]; then
    SUDO=""
else
    if ! command -v sudo >/dev/null 2>&1; then
        echo "sudo is required to run birbian." >&2
        exit 1
    fi
    SUDO="sudo"
fi

echo "== Downloading birbian.sh from ${URL} =="
TMP_SCRIPT=$(mktemp /tmp/birbian.XXXXXX.sh)
trap 'rm -f "${TMP_SCRIPT}"' EXIT

wget -q -O "${TMP_SCRIPT}" "${URL}" || {
    echo "Download failed. Push birbian.sh to ${BRANCH} of ${REPO} first." >&2
    exit 1
}

echo "== Running birbian (${SCRIPT}) =="
# shellcheck disable=SC2086
${SUDO} bash "${TMP_SCRIPT}"