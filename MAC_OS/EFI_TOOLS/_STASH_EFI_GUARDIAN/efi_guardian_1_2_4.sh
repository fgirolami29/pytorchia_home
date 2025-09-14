#!/usr/bin/env bash
# efi_guardian.sh — Toolkit interattivo per backup/ripristino EFI (macOS)
# Autore: fgirolami29,Nolan | Versione: 1.2.4 | Edited: 10-09-2025
set -euo pipefail

# ---------- META ----------
TOOL_NAME="EFI GUARDIAN"
TOOL_VERSION="1.2.4"
TOOL_AUTHOR="fgirolami29,Nolan"
BUILD_DATE="$(date +%F)"

# ---------- CONTEXT ----------
MODEL="$(sysctl -n hw.model 2>/dev/null || echo unknown)"
MACOS="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
EFIS=()
# ---------- IGNORED ----------
EXCLUDES=(
    # spazzatura di volume
    --exclude '/.Spotlight-V100' --exclude '/.Spotlight-V100/*'
    --exclude '/.Trashes' --exclude '/.Trashes/*'
    --exclude '/.TemporaryItems' --exclude '/.TemporaryItems/*'
    --exclude '/.fseventsd' --exclude '/.fseventsd/*'

    # file AppleDouble / Finder vari (sia root che sottocartelle)
    --exclude '/._*' --exclude '*/._*'
    --exclude '/.DS_Store' --exclude '*/.DS_Store'

    # log volatili Apple nella ESP
    --exclude 'EFI/APPLE/LOG' --exclude 'EFI/APPLE/LOG/*'
)

# ---------- ANSI ----------
NC="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GRN="\033[32m"
YLW="\033[33m"
BLU="\033[34m"
CYA="\033[36m"
MGN='\033[0;35m'

# opzionale: stampa ASCII dal tuo .emblflag/.emblsmall se presente
_print_embl() {
    local f=""
    [[ -f ".emblsmall" ]] && f=".emblsmall"
    [[ -z "$f" && -f ".emblflag" ]] && f=".emblflag"
    [[ -z "$f" && -f "$HOME/.emblsmall" ]] && f="$HOME/.emblsmall"
    [[ -n "$f" ]] && sed -n '1,12p' "$f"
}

# ---------- BANNER ----------
banner() {
    # colori (fallback se non definiti)
    : "${NC:=$'\033[0m'}"
    : "${BOLD:=$'\033[1m'}"
    : "${CYA:=$'\033[36m'}"
    : "${GRN:=$'\033[32m'}"

    clear
    _print_embl || true

    # contenuti "raw" (senza colori) per calcolo larghezze
    local title=" ${TOOL_NAME}     •  OCLP SAFE"
    local meta=" VERSION: v${TOOL_VERSION}  •  ${TOOL_AUTHOR}  •  BUILD_DATE: ${BUILD_DATE}"
    local l1=" macOS: ${MACOS}   Model: ${MODEL}"
    local l2=" Serial: ${SERIAL:-unknown}"
    local l3=" EFI: ${EFI_ID:-auto}   Mount: ${EFI_MNT:-n/a}"
    local l4=" DEST: ${DEST}"

    local lines=("$title" "$meta" "" "$l1" "$l2" "$l3" "$l4")

    # larghezza interna: max(lunghezze), cap a larghezza terminale
    local term_cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}
    local min_w=60
    local max_w=$((term_cols > 10 ? term_cols - 2 : 78)) # spazio per i bordi
    local inner_w=$min_w
    local s
    for s in "${lines[@]}"; do
        local n=${#s}
        ((n > inner_w)) && inner_w=$n
    done
    ((inner_w > max_w)) && inner_w=$max_w

    # barra orizzontale (─ ripetuto) considerando gli spazi laterali
    local bar_w=$((inner_w + 2))
    local bar
    printf -v bar '%*s' "$bar_w" ''
    bar=${bar// /─}

    # conta byte reali (no newline)
    _bytes() { LC_ALL=C printf "%s" "$1" | wc -c | tr -d ' '; }

    # tronca al centro se eccede inner_w (resta com'è)
    _mid_trunc() {
        local str="$1" w="$2" len=${#1}
        ((len <= w)) && {
            printf "%s" "$str"
            return
        }
        local keep=$(((w - 1) / 2))
        local tail=$((w - 1 - keep))
        printf "%.*s…%.*s" "$keep" "$str" "$tail" "${str: -tail}"
    }

    # stampa riga con padding preciso
    _print_line() {
        local raw="$1"
        # prima tronco (se serve)
        local out
        out="$(_mid_trunc "$raw" "$inner_w")"

        # calcolo “colonne” (= caratteri) vs “byte” (UTF-8 multibyte)
        local bytes cols
        cols=${#out}
        bytes=$(_bytes "$out")
        local adj=$((bytes - cols)) # es. ogni '•' aggiunge 2

        # aumento la field width di adj per compensare i multibyte
        printf "${CYA}${BOLD}│${NC} %-*s ${CYA}${BOLD}│${NC}\n" $((inner_w + adj)) "$out"
    }

    # header
    echo -e "${CYA}${BOLD}┌${bar}┐${NC}"
    _print_line "$title"
    _print_line "$meta"
    echo -e "${CYA}${BOLD}├${bar}┤${NC}"
    _print_line "$l1"
    _print_line "$l2"
    _print_line "$l3"
    _print_line "$l4"
    echo -e "${CYA}${BOLD}└${bar}┘${NC}"
    echo -e "${GRN}${BOLD}Suggerimento:${NC} usa l'opzione 6 per cambiare DEST (es. USB in /Volumes)."
    echo
}

# ---------- sudo / root ----------
ensure_sudo() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${YLW}>> Permessi elevati richiesti (sudo)…${NC}"
        sudo -v || {
            echo -e "${RED}Autenticazione sudo fallita.${NC}"
            exit 1
        }
        # keep-alive sudo
        (while true; do
            sleep 60
            sudo -n true 2>/dev/null || exit
        done) &
        SUDO_KEEPALIVE_PID=$!
        trap '[[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true' EXIT
    fi
}

# ---------- global ----------
STAMP="$(date +%F_%H-%M-%S)"
SERIAL="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/ {print $2; exit}' || echo unknown)"
DEST_DEFAULT="$HOME/EFI_BACKUPS/${SERIAL}_${STAMP}"
DEST="${DEST_DEFAULT}"

EFI_ID=""
EFI_MNT=""
MOUNTED_BY_TOOL=0

# ---------- helpers ----------
pause() {
    local press_enter
    press_enter="$(echo -e "${CYA}[${NC}${YLW}INVIO per continuare${NC}${CYA}]${NC}")"
    read -rp $'\n'"$press_enter"''
}
collect_volumes() {
    VOLS=()
    shopt -s nullglob
    while IFS= read -r -d '' v; do
        [[ -d "$v" ]] && VOLS+=("$v")
    done < <(find /Volumes/* -type d -prune -print0 2>/dev/null)
    shopt -u nullglob
}

pick_destination() {
    echo -e "${BLU}Destinazione corrente:${NC} ${BOLD}${DEST}${NC}"
    echo -e "${CYA}Scegli dove salvare i backup (utile in Recovery per scrivere su USB).${NC}"
    echo "1) ${DEST_DEFAULT}"

    # elenca volumi montati
    collect_volumes
    i=2
    for v in "${VOLS[@]}"; do
        echo "${i}) $v"
        ((i++))
    done

    echo "X) Inserisci un percorso custom"
    read -rp "Selezione: " sel
    if [[ "$sel" =~ ^[0-9]+$ ]]; then
        if [[ "$sel" -eq 1 ]]; then
            DEST="$DEST_DEFAULT"
        else
            idx=$((sel - 2))
            if ((idx >= 0 && idx < ${#VOLS[@]})); then
                DEST="${VOLS[$idx]}/EFI_BACKUPS/${SERIAL}_${STAMP}"
            else
                echo -e "${RED}Selezione non valida.${NC}"
                return
            fi
        fi
    else
        if [[ "$sel" =~ ^[Xx]$ ]]; then
            read -rp "Percorso completo destinazione: " custom
            [[ -n "$custom" ]] && DEST="$custom"
        else
            echo -e "${RED}Selezione non valida.${NC}"
            return
        fi
    fi
    echo -e "${GRN}>> DEST impostata a:${NC} ${BOLD}${DEST}${NC}"
}

pick_efi_partition() {
    echo -e "${BLU}Seleziona una partizione EFI da montare:${NC}"

    # comando che elenca le partizioni EFI come diskXsY
    #local _efi_cmd='diskutil list | awk '"'"'/EFI/ && $NF ~ /disk[0-9]+s[0-9]+/ {print $NF}'"'"''

    # ripulisci l'array
    EFIS=()

    # se mapfile esiste (bash >=4) usalo, altrimenti fallback compatibile con bash 3.2
    # raccogli partizioni EFI direttamente
    if help mapfile >/dev/null 2>&1; then
        mapfile -t EFIS < <(diskutil list | awk '/EFI/ && $NF ~ /disk[0-9]+s[0-9]+/ {print $NF}')
    else
        while IFS= read -r e; do
            [[ -n "$e" ]] && EFIS+=("$e")
        done < <(diskutil list | awk '/EFI/ && $NF ~ /disk[0-9]+s[0-9]+/ {print $NF}')
    fi

    ((${#EFIS[@]})) || {
        echo -e "${RED}Nessuna partizione EFI trovata.${NC}"
        return 1
    }

    local i=1
    for e in "${EFIS[@]}"; do
        local info loc size mp status
        info="$(diskutil info "$e" 2>/dev/null)"
        loc="$(awk -F': +' '/Device Location/ {print $2}' <<<"$info")"
        size="$(awk -F': +' '/Total Size/ {print $2}' <<<"$info")"
        [[ -z "$size" ]] && size="$(awk -F': +' '/Disk Size/ {print $2}' <<<"$info")"
        mp="$(mount | awk -v d="/dev/$e" '$1==d {print $3; exit}')"
        if [[ -n "$mp" ]]; then
            status=$(printf " %b[montata:%b %b%s%b%b]" "$GRN" "$NC" "$BOLD" "$mp" "$NC" "$GRN")
        else
            status=""
        fi
        printf "  %d) %s  (%s, %s)%b\n" "$i" "$e" "${loc:-Unknown}" "${size:-n.d.}" "$status"
        ((i++))
    done

    read -rp "Scelta: " n
    ((n >= 1 && n <= ${#EFIS[@]})) || {
        printf '\n%bSelezione non valida.%b\n' "$RED" "$NC"
        return 1
    }

    EFI_ID="${EFIS[$((n - 1))]}"
    echo -e "${GRN}>> EFI selezionata:${NC} ${BOLD}${EFI_ID}${NC}"
}

mount_efi() {
    [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || return 1
    if mount | grep -q "/dev/${EFI_ID} "; then
        EFI_MNT="$(mount | awk -v d="/dev/${EFI_ID}" '$1==d {print $3; exit}')"
        echo -e "${GRN}>> EFI già montata su:${NC} ${BOLD}${EFI_MNT}${NC}"
        return 0
    fi
    ensure_sudo
    echo -e "${BLU}>> Monto /dev/${EFI_ID}…${NC}"
    sudo diskutil mount "${EFI_ID}" >/dev/null
    EFI_MNT="$(mount | awk -v d="/dev/${EFI_ID}" '$1==d {print $3; exit}')"
    [[ -d "$EFI_MNT" ]] || {
        echo -e "${RED}Mountpoint non trovato.${NC}"
        return 1
    }
    MOUNTED_BY_TOOL=1
    echo -e "${GRN}>> Montata su:${NC} ${BOLD}${EFI_MNT}${NC}"
}

# Aggiorna EFI_MNT/EFI_ID leggendo la tabella dei mount
refresh_mount_state() {
    # Se conosco l'ID, trovo il mountpoint reale
    if [[ -n "${EFI_ID:-}" ]]; then
        EFI_MNT="$(mount | awk -v d="/dev/${EFI_ID}" '$1==d {print $3; exit}')"
    fi
    # Se ancora vuoto, prova il mountpoint standard /Volumes/EFI
    if [[ -z "${EFI_MNT:-}" && -d /Volumes/EFI ]]; then
        local dev
        dev="$(mount | awk '$3=="/Volumes/EFI" {print $1; exit}')"
        if [[ -n "$dev" ]]; then
            EFI_MNT="/Volumes/EFI"
            EFI_ID="${dev#/dev/}"
        fi
    fi
}

# Conferma sì/no (rispetta ASSUME_YES=1)
ASSUME_YES=${ASSUME_YES:-0}
confirm() {
    local prompt="$1"
    ((ASSUME_YES)) && return 0
    read -rp "$prompt [y/N]: " _ans
    [[ "$_ans" =~ ^[Yy]$ ]]
}
umount_efi() {
    local force="${1:-0}" # 1 = forza senza chiedere
    refresh_mount_state

    # Non risulta montata
    if [[ -z "${EFI_MNT:-}" ]]; then
        echo -e "${GRN}>> EFI già smontata.${NC}"
        return 0
    fi

    # Se non l'abbiamo montata noi, chiedi conferma
    if ((MOUNTED_BY_TOOL == 0)); then
        echo -e "${YLW}>> EFI risulta montata su ${BOLD}${EFI_MNT}${NC} ma non l'ho montata io.${NC}"
        confirm "Procedo allo smontaggio?" || {
            echo "Annullato."
            return 1
        }
    else
        echo -e "${BLU}>> Smonto EFI (${EFI_MNT})…${NC}"
    fi

    # Primo tentativo "gentile"
    if sudo diskutil unmount "${EFI_MNT}" >/dev/null; then
        MOUNTED_BY_TOOL=0
        EFI_MNT=""
        echo -e "${GRN}✅ EFI smontata.${NC}"
        return 0
    fi

    # Fallito: offri 'force' (o applicalo se richiesto)
    echo -e "${YLW}!! Unmount fallito (volume occupato?).${NC}"
    if ((force == 1)) || confirm "Forzo lo smontaggio?"; then
        # accetta sia mountpoint che device id
        if sudo diskutil unmount force "${EFI_ID:-${EFI_MNT}}" >/dev/null; then
            MOUNTED_BY_TOOL=0
            EFI_MNT=""
            echo -e "${GRN}✅ EFI smontata (force).${NC}"
            return 0
        else
            echo -e "${RED}❌ Impossibile smontare la EFI.${NC}"
            return 2
        fi
    else
        return 1
    fi
}

copy_tree() {
    local src="$1" dst="$2"
    mkdir -p "$dst"

    # trova rsync; se manca, fallback a ditto
    local rs_bin
    rs_bin="$(command -v rsync || true)"
    if [[ -z "$rs_bin" ]]; then
        echo -e "${YLW}rsync non disponibile, uso ditto (no progress).${NC}"
        sudo ditto "$src" "$dst"
        return
    fi

    # Estrai in modo robusto la versione numerica (es. "3.3.0" oppure "2.6.9")
    # Compatibile con l'output Apple tipo: "rsync  version 2.6.9  protocol version 29"
    local rs_ver rs_major=0 rs_minor=0
    rs_ver="$("$rs_bin" --version 2>/dev/null |
        LC_ALL=C sed -n 's/^[Rr]sync[[:space:]]\+version[[:space:]]\+\([0-9][0-9.]*\).*/\1/p' |
        head -n1)"
    if [[ -n "$rs_ver" ]]; then
        IFS=. read -r rs_major rs_minor _ <<<"$rs_ver"
        rs_major="${rs_major:-0}"
        rs_minor="${rs_minor:-0}"
    fi

    # Scegli flag di progresso compatibile (macOS rsync 2.6.x non supporta --info=progress2)
    local progress_flag=()
    if ((rs_major > 3 || (rs_major == 3 && rs_minor >= 1))); then
        progress_flag=(--info=progress2)
    else
        progress_flag=(--progress)
    fi

    sudo "$rs_bin" -aEH "${EXCLUDES[@]}" "${progress_flag[@]}" "$src"/ "$dst"/
}

zip_and_sha() {
    local base="$1"
    (cd "$(dirname "$base")" && sudo zip -r "$(basename "$base").zip" "$(basename "$base")" >/dev/null)
    shasum -a 256 "${base}.zip" | tee "${base}.zip.sha256" >/dev/null
}

verify_sha() {
    local f="$1"
    [[ -f "$f" && -f "${f}.sha256" ]] || {
        echo -e "${RED}File o checksum mancante.${NC}"
        return 1
    }
    shasum -a 256 -c "${f}.sha256"
}

dd_progress_supported() {
    dd if=/dev/zero of=/dev/null bs=1m count=1 status=help 2>&1 | grep -q "status="
}
pick_external_disk() {
    echo -e "${BLU}Dischi esterni fisici:${NC}"

    # Raccogli i device /dev/diskX degli "external physical"
    local DISKS=()
    if help mapfile >/dev/null 2>&1; then
        mapfile -t DISKS < <(diskutil list external physical | awk '/^\s*\/dev\//{print $1}')
    else
        while IFS= read -r d; do
            [[ -n "$d" ]] && DISKS+=("$d")
        done < <(diskutil list external physical | awk '/^\s*\/dev\//{print $1}')
    fi

    ((${#DISKS[@]})) || {
        echo -e "${RED}Nessun disco esterno trovato.${NC}"
        return 1
    }

    local i=1
    for d in "${DISKS[@]}"; do
        # Arricchiamo con qualche info utile
        local info size name proto
        info="$(diskutil info "$d" 2>/dev/null)"
        size="$(awk -F': +' '/Total Size:/ {print $2}' <<<"$info")"
        [[ -z "$size" ]] && size="$(awk -F': +' '/Disk Size:/ {print $2}' <<<"$info")"
        name="$(awk -F': +' '/Device \/ Media Name:/ {print $2}' <<<"$info")"
        [[ -z "$name" ]] && name="$(awk -F': +' '/Media Name:/ {print $2}' <<<"$info")"
        proto="$(awk -F': +' '/Protocol:/ {print $2}' <<<"$info")"

        printf "  %d) %s  (%s, %s, %s)\n" \
            "$i" "$d" "${name:-n.d.}" "${size:-n.d.}" "${proto:-n.d.}"
        ((i++))
    done

    read -rp "Seleziona disco (numero): " n
    [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#DISKS[@]})) || {
        echo -e "${RED}Selezione non valida.${NC}"
        return 1
    }

    local sel="${DISKS[$((n - 1))]}"
    echo -e "${GRN}>> Disco selezionato:${NC} ${BOLD}${sel}${NC}"
    printf '%s\n' "${sel#/dev/}" # stampa "diskX"
}

# ---------- tasks ----------
task_backup_zip() {
    [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || return 1
    mount_efi || return 1
    local out="${DEST}/EFI"
    echo -e "${BLU}>> Backup file-level da ${EFI_MNT} → ${out}${NC}"
    copy_tree "$EFI_MNT" "$out"
    echo -e "${BLU}>> Creo ZIP + SHA256…${NC}"
    zip_and_sha "$out"
    echo -e "${GRN}✅ Backup completato.${NC}"
    echo " Cartella: ${out}"
    echo " Archivio: ${out}.zip"
    echo " SHA256  : ${out}.zip.sha256"
}

task_raw_image() {
    [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || return 1
    # ensure_sudo  # opzionale
    local raw="${DEST}/efi_fat32_${SERIAL}_${STAMP}.img"
    local dev="rdisk${EFI_ID#disk}" # da disk0s1 → rdisk0s1
    mkdir -p "${DEST}"
    echo -e "${BLU}>> Creo immagine RAW da /dev/${dev} → ${raw}${NC}"
    if dd_progress_supported; then
        sudo dd if="/dev/${dev}" of="${raw}" bs=1m status=progress
    else
        echo -e "${YLW}(Suggerimento: premi ${BOLD}Ctrl+T${NC}${YLW} per vedere il progresso di dd)${NC}"
        sudo dd if="/dev/${dev}" of="${raw}" bs=1m
    fi
    shasum -a 256 "${raw}" | tee "${raw}.sha256" >/dev/null
    echo -e "${GRN}✅ RAW creato.${NC}"
    echo " Immagine: ${raw}"
    echo " SHA256  : ${raw}.sha256"
}

# task_restore_zip [ZIPFILE]
task_restore_zip() {
    # ensure_sudo  # opzionale
    local zipf="${1:-}"
    if [[ -z "$zipf" ]]; then
        read -rp "Percorso ZIP (…/EFI_*.zip): " zipf
    fi
    [[ -f "$zipf" ]] || {
        echo -e "${RED}File non trovato.${NC}"
        return 1
    }

    local sha="${zipf}.sha256"
    [[ -f "$sha" ]] && {
        echo -e "${BLU}>> Verifico checksum…${NC}"
        verify_sha "$zipf" || {
            echo -e "${RED}Checksum fallita!${NC}"
            return 1
        }
    }

    [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || return 1
    mount_efi || return 1

    echo -e "${YLW}${BOLD}ATTENZIONE:${NC} sovrascriverò i file nella EFI ${BOLD}${EFI_MNT}${NC}."
    confirm "Confermi?" || {
        echo "Annullato."
        return 1
    }

    local tmp="/tmp/efi_restore_${RANDOM}"
    mkdir -p "$tmp"
    unzip -q "$zipf" -d "$tmp"
    local src="${tmp}/EFI"
    [[ -d "$src" ]] || src="$(find "$tmp" -maxdepth 2 -type d -name EFI | head -n1)"
    [[ -d "$src" ]] || {
        echo -e "${RED}Cartella EFI non trovata nello ZIP.${NC}"
        return 1
    }

    echo -e "${BLU}>> Copio su ${EFI_MNT}…${NC}"
    sudo rsync -aEH "$src"/ "${EFI_MNT}"/
    echo -e "${GRN}✅ Ripristino da ZIP completato.${NC}"
}

# task_restore_raw IMG TARGET_DISKXs1 [--force]
task_restore_raw() {
    local img="${1:-}" target="${2:-}" force="${3:-}"
    [[ -n "$img" ]] || read -rp "Percorso immagine RAW (.img): " img
    [[ -f "$img" ]] || {
        echo -e "${RED}File non trovato.${NC}"
        return 1
    }
    [[ -n "$target" ]] || read -rp "EFI di destinazione (es. disk0s1): " target
    [[ -n "$target" ]] || {
        echo -e "${RED}Destinazione mancante.${NC}"
        return 1
    }

    echo -e "${YLW}${BOLD}ATTENZIONE:${NC} scriverò byte-per-byte su /dev/r${target}. Operazione distruttiva."
    diskutil info "$target" || true
    if ! confirm "Digita y per continuare"; then
        echo "Annullato."
        return 1
    fi

    sudo diskutil unmount "disk${target#disk}" >/dev/null || true
    if dd_progress_supported; then
        sudo dd if="$img" of="/dev/r${target}" bs=1m status=progress
    else
        echo -e "${YLW}(Ctrl+T per progresso)${NC}"
        sudo dd if="$img" of="/dev/r${target}" bs=1m
    fi
    sudo diskutil mount "$target" >/dev/null || true
    echo -e "${GRN}✅ Ripristino RAW completato.${NC}"
}

task_verify() {
    read -rp "File da verificare (.zip o .img): " f
    verify_sha "$f"
}

task_unmount() {
    refresh_mount_state
    if [[ -z "${EFI_MNT:-}" ]]; then
        echo -e "${GRN}>> EFI già smontata.${NC}"
        return 0
    fi
    echo -e "${BLU}>> Trovata EFI montata su ${BOLD}${EFI_MNT}${NC}"
    umount_efi
}

task_dry_run() {
    [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || return 1
    mount_efi || return 1
    local out="${DEST}/EFI"
    echo -e "${BLU}>> DRY-RUN: elenco dei file che verrebbero copiati (exclude attive)…${NC}"
    rsync -aEHn "${EXCLUDES[@]}" "$EFI_MNT"/ "$out"/
}
task_prepare_usb() {
    local d
    d="$(pick_external_disk)" || return 1
    echo -e "${YLW}ATTENZIONE: verrà ripartizionato ${BOLD}${d}${NC} (tutti i dati andranno persi).${NC}"
    read -rp "Scrivi YES in maiuscolo per confermare: " ok
    [[ "$ok" == "YES" ]] || {
        echo "Annullato."
        return 1
    }
    sudo diskutil partitionDisk "$d" GPT FAT32 EFI 300MB ExFAT DATA R
    echo -e "${GRN}✅ USB pronta. Montaggio EFI…${NC}"
    sudo diskutil mount "${d}s1" >/dev/null || true
    EFI_ID="${d}s1"
    EFI_MNT="$(mount | awk -v dev="/dev/${EFI_ID}" '$1==dev {print $3; exit}')"
    echo "EFI montata su: ${EFI_MNT:-/Volumes/EFI}"
}
task_promote_usb() {
    #____________ UNTESTED !! #####____________ UNTESTED !! ####

    local src_id="${1:-}" dst_id="${2:-disk0s1}"
    [[ -n "$src_id" ]] || {
        echo "Uso: --promote-usb <srcEFI> [dstEFI]"
        return 2
    }

    # sanity check: sorgente esterna, destinazione interna
    diskutil info "$src_id" | grep -q "Device Location: External" ||
        {
            echo -e "${RED}Sorgente non è esterna:${NC} $src_id"
            return 1
        }
    diskutil info "$dst_id" | grep -q "Device Location: Internal" ||
        {
            echo -e "${RED}Destinazione non è interna:${NC} $dst_id"
            return 1
        }

    sudo diskutil mount "$src_id" >/dev/null
    sudo diskutil mount "$dst_id" >/dev/null
    local src_mnt dst_mnt
    src_mnt="$(mount | awk -v d="/dev/${src_id}" '$1==d{print $3;exit}')"
    dst_mnt="$(mount | awk -v d="/dev/${dst_id}" '$1==d{print $3;exit}')"

    echo -e "${BLU}>> Copio ${BOLD}${src_mnt}/EFI${NC} → ${BOLD}${dst_mnt}/EFI${NC}"
    confirm "Procedo con sync (usa --delete per allineare 1:1)?" || {
        echo "Annullato."
        return 1
    }

    # sync puntuale della sola cartella EFI (mantiene OC/BOOT e compagnia)
    sudo rsync -aEH --delete "${src_mnt}/EFI/" "${dst_mnt}/EFI/"

    sudo diskutil unmount "$src_mnt" >/dev/null || true
    sudo diskutil unmount "$dst_mnt" >/dev/null || true
    echo -e "${GRN}✅ Promozione completata.${NC}"
}

# ---------- menu ----------
menu() {
    clear
    banner
    ensure_sudo
    echo -e "${BOLD}MBP Serial:${NC} ${SERIAL}"
    echo -e "${BOLD}DEST:${NC} ${DEST}"
    echo
    echo -e "${BLU}Seleziona un'operazione:${NC}"
    echo -e " ${GRN}1${NC}) Backup EFI → ZIP (+SHA256)"
    echo -e " ${GRN}2${NC}) Crea immagine RAW della EFI"
    echo -e " ${GRN}3${NC}) Ripristina da ZIP → EFI"
    echo -e " ${GRN}4${NC}) Ripristina da RAW → EFI target"
    echo -e " ${GRN}5${NC}) Verifica checksum (.zip/.img)"
    echo -e " ${GRN}6${NC}) Scegli DEST (es. USB in /Volumes)"
    echo -e " ${GRN}7${NC}) Prepara USB (GPT + EFI 300MB)"
    echo -e " ${GRN}8${NC}) Monta/Seleziona EFI"
    echo -e " ${GRN}9${NC}) Smonta EFI"
    echo -e " ${MGN}10${NC}) DRY-RUN: testa exclude"
    echo
    echo -e " ${RED}0${NC}) Esci"
    echo
    read -rp "Scelta: " s
    case "$s" in
    1)
        task_backup_zip
        pause
        ;;
    2)
        task_raw_image
        pause
        ;;
    3)
        task_restore_zip
        pause
        ;;
    4)
        task_restore_raw
        pause
        ;;
    5)
        task_verify
        pause
        ;;
    6)
        pick_destination
        pause
        ;;
    7)
        task_prepare_usb
        pause
        ;;
    8)
        # se non hai già scelto una EFI in CLI, proponi la scelta interattiva
        if [[ -z "${EFI_ID:-}" ]]; then
            pick_efi_partition || {
                pause
                return
            }
        fi
        mount_efi
        pause
        ;;
    9)
        task_unmount
        pause
        ;;
    10)
        task_dry_run
        pause
        ;;
    0) exit 0 ;;
    *)
        printf '\n%bScelta non valida!%b\n' "$RED" "$NC"
        pause
        ;;
    esac
}

# ---------- USAGE ----------
usage() {
    # usa la palette già definita: NC, BOLD, RED, GRN, YLW, BLU, CYA, MGN
    cat <<EOF
${BOLD}${CYA}${TOOL_NAME} CLI${NC}  ${MGN}v${TOOL_VERSION}${NC}
${BLU}USO:${NC} ${BOLD}$(basename "$0")${NC} ${YLW}[OPZIONI]${NC}

${CYA}Comandi:${NC}
  ${GRN}--backup-zip${NC} ${YLW}[DEST]${NC}        Esegue backup EFI in DEST (default: ~/EFI_BACKUPS/…)
  ${GRN}--raw-image${NC}                  Crea immagine RAW della EFI selezionata
  ${GRN}--restore-zip${NC} ${YLW}[ZIP]${NC}        Ripristina da ZIP (se manca, chiede il file)
    ${MGN}--efi${NC} ${YLW}diskXs1${NC}            Seleziona EFI target per mount/restore
  ${GRN}--restore-raw${NC} ${YLW}IMG diskXs1${NC}  Ripristino RAW diretto
  ${GRN}--prepare-usb${NC} ${YLW}[diskX]${NC}      Partiziona USB GPT (EFI 300MB + DATA)
  ${GRN}--unmount${NC}                   Smonta la EFI (usa ${MGN}--force${NC} per forzare)

${CYA}Opzioni:${NC}
  ${GRN}--dest${NC} ${YLW}PATH${NC}                Imposta DEST
  ${GRN}--efi${NC} ${YLW}diskXs1${NC}              Imposta EFI_ID
  ${GRN}--yes${NC}, ${GRN}-y${NC}                  Auto-conferma
  ${GRN}--force${NC}                    Forza unmount senza chiedere
  ${GRN}--help${NC}, ${GRN}-h${NC}                 Mostra questo aiuto

${BLU}Esempi:${NC}
  ${BOLD}$(basename "$0")${NC} ${GRN}--prepare-usb${NC} ${YLW}disk2${NC}
  ${BOLD}$(basename "$0")${NC} ${GRN}--efi${NC} ${YLW}disk2s1${NC} ${GRN}--backup-zip${NC} ${YLW}/Volumes/DATA/EFI_BACKUPS${NC}
  ${BOLD}$(basename "$0")${NC} ${GRN}--yes --restore-zip${NC} ${YLW}/path/EFI.zip${NC}
EOF
}

# ---------- CLI ----------
FORCE_UNMOUNT=${FORCE_UNMOUNT:-0} # usato da umount_efi()
if (($#)); then
    # default: non-interattivo (salta menu)
    while (($#)); do
        case "$1" in
        --yes | -y) ASSUME_YES=1 ;;
        --force) FORCE_UNMOUNT=1 ;;
        --dest)
            DEST="$2"
            shift
            ;;
        --efi)
            EFI_ID="$2"
            shift
            ;;
        --prepare-usb)
            shift
            if [[ -n "${1:-}" && "$1" =~ ^disk[0-9]+$ ]]; then
                d="$1"
                shift
            else d="$(pick_external_disk)" || exit 1; fi
            echo -e "${YLW}ATTENZIONE: ripartiziono ${BOLD}${d}${NC}.${NC}"
            ((ASSUME_YES)) || confirm "Confermi?" || exit 1
            sudo diskutil partitionDisk "$d" GPT FAT32 EFI 300MB ExFAT DATA R
            sudo diskutil mount "${d}s1" >/dev/null || true
            EFI_ID="${d}s1"
            refresh_mount_state
            echo "EFI montata su: ${EFI_MNT:-/Volumes/EFI}"
            exit 0
            ;;
        --backup-zip)
            [[ -n "${2:-}" && "${2:0:1}" != "-" ]] && {
                DEST="$2"
                shift
            }
            [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || exit 1
            mount_efi && task_backup_zip
            exit $?
            ;;
        --raw-image)
            [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || exit 1
            task_raw_image
            exit $?
            ;;
        --restore-zip)
            ZIPF="${2:-}"
            [[ -n "$ZIPF" ]] && shift
            [[ -n "${EFI_ID:-}" ]] || pick_efi_partition || exit 1
            mount_efi && task_restore_zip "${ZIPF:-}"
            exit $?
            ;;
        --restore-raw)
            IMG="$2"
            TARGET="$3"
            shift 2
            [[ -n "$IMG" && -n "$TARGET" ]] || {
                echo "Uso: --restore-raw <img> <diskXs1>"
                exit 2
            }
            task_restore_raw "$IMG" "$TARGET"
            exit $?
            ;;
        --pick-efi)
            pick_efi_partition && mount_efi
            exit $?
            ;;
        --unmount)
            refresh_mount_state
            umount_efi "$FORCE_UNMOUNT"
            exit $?
            ;;
        --promote-usb)
            # $2 obbligatorio (src EFI), $3 opzionale (dst EFI)
            SRC="${2-}"
            DST="${3-}"

            # valida SRC
            if [[ -z "${SRC:-}" || "${SRC:0:1}" = "-" ]]; then
                printf '%s\n' "Uso: --promote-usb <srcEFI> [dstEFI]" >&2
                exit 2
            fi

            # default per DST se mancante o è un'altra opzione
            if [[ -z "${DST:-}" || "${DST:0:1}" = "-" ]]; then
                DST="disk0s1"
            fi

            task_promote_usb "$SRC" "$DST"
            exit $?
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "Argomento sconosciuto: $1"
            exit 2
            ;;
        esac
        shift
    done
fi

# ---------- main ----------
while true; do menu; done
