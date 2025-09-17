#!/usr/bin/env bash
set -euo pipefail

TOOL_NAME="mount_and_dump_efi.sh"
TOOL_VERSION="0.1.0"
TOOL_AUTHOR="fgirolami29"

export \
    TOOL_NAME \
    TOOL_VERSION \
    TOOL_AUTHOR

# --- parametri ---
STAMP="$(date +%F_%H-%M-%S)"
SERIAL="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/ {print $2; exit}' || echo unknown)"
DEST="$HOME/EFI_BACKUPS/${SERIAL}_${STAMP}"
mkdir -p "$DEST"

echo ">> Cerco la EFI interna…"
EFI_ID="$(diskutil list internal | awk '/EFI/ && $NF ~ /disk[0-9]+s[0-9]+/ {print $NF; exit}')"
[ -n "${EFI_ID:-}" ] || {
    echo "ERR: EFI non trovata"
    exit 1
}

echo ">> Monto /dev/${EFI_ID}…"
sudo diskutil mount "${EFI_ID}" >/dev/null

MNT="$(mount | awk -v d="/dev/${EFI_ID}" '$1==d {print $3; exit}')"
[ -d "$MNT" ] || {
    echo "ERR: mountpoint non trovato"
    exit 1
}

echo ">> Copio il contenuto della EFI in ${DEST}/EFI/ …"
sudo rsync -aEH --progress "$MNT"/ "$DEST/EFI/"

echo ">> Creo archivio ZIP…"
(cd "$DEST" && sudo zip -r "EFI_${SERIAL}_${STAMP}.zip" EFI >/dev/null)

echo ">> Creo checksum SHA256…"
shasum -a 256 "$DEST/EFI_${SERIAL}_${STAMP}.zip" | tee "$DEST/EFI_${SERIAL}_${STAMP}.zip.sha256" >/dev/null

echo ">> Smonto EFI…"
sudo diskutil unmount "$MNT" >/dev/null || true

echo "✅ Backup completato:"
echo "   Cartella: $DEST/EFI"
echo "   Archivio: $DEST/EFI_${SERIAL}_${STAMP}.zip"
echo "   SHA256  : $DEST/EFI_${SERIAL}_${STAMP}.zip.sha256"
