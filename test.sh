#!/bin/bash

# ANSI COLORS
RED="\033[91m"
YELLOW="\033[93m"
BLUE="\033[94m"
GREEN="\033[92m"
MAGENTA="\033[95m"
RESET="\033[0m"

ART_COLORS=(
    $'\033[36m'  # CYAN
    $'\033[94m'  # BRIGHT_BLUE
)

# Funzione per rimuovere i codici ANSI
br_strip_ansi_codes() {
    echo -e "$1" | sed -E 's/\x1B\[[0-9;]*[mK]//g'
}

# Funzione per leggere e sostituire placeholder colori
read_ansi_ascii() {
    local filename="$1"
    COLORED_LINES=()  # Usata come globale

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//"ART_COLORS[0]"/${ART_COLORS[0]}}"
        line="${line//"ART_COLORS[1]"/${ART_COLORS[1]}}"
        line="${line//"RED"/${RED}}"
        line="${line//"YELLOW"/${YELLOW}}"
        line="${line//"BLUE"/${BLUE}}"
        line="${line//"GREEN"/${GREEN}}"
        line="${line//"MAGENTA"/${MAGENTA}}"
        line="${line//"RESET"/${RESET}}"
        COLORED_LINES+=("$line")
    done < "$filename"
}

# MAIN
FILE="$1"
[[ -z "$FILE" ]] && echo "❌ Nessun file fornito." && exit 1
[[ ! -f "$FILE" ]] && echo "❌ File non trovato: $FILE" && exit 1

echo -e "\n📄 Lettura file: $FILE"
echo "──────────────────────────────────────────────────────"

read_ansi_ascii "$FILE"

# Itera sulle righe e calcola lunghezze
for ((i = 0; i < ${#COLORED_LINES[@]}; i++)); do
    line="${COLORED_LINES[$i]}"
    clean=$(br_strip_ansi_codes "$line")
    len=${#clean}
    echo -e "🎨 ${line}"
    echo -e "   🔹 ${clean}"
    echo -e "   ↳ Lunghezza visiva: ${YELLOW}${len}${RESET}"
done
