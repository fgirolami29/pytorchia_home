#!/bin/bash
ASCII_ART_LOADED=false
BR_VERSION="1.0.1"
BASE_PATH="$HOME/.pytorchia/"
export DOCKER_USER

# ANSI Colors
RED="\033[91m"
YELLOW="\033[93m"
BLUE="\033[94m"
GREEN="\033[92m"
RESET="\033[0m"

# ANSI Colors
COLORS=(
    $'\033[91m' # RED
    $'\033[93m' # YELLOW
    $'\033[94m' # BLUE
    $'\033[92m' # GREEN
    $'\033[92m' # BRIGHT_GREEN
    $'\033[94m' # BRIGHT_BLUE
    $'\033[90m' # BRIGHT_BLACK
    $'\033[91m' # BRIGHT_RED
    $'\033[93m' # BRIGHT_YELLOW
    $'\033[95m' # BRIGHT_MAGENTA
    $'\033[96m' # BRIGHT_CYAN
)
ART_COLORS=(
    $'\033[36m' # CYAN
    $'\033[94m' # BRIGHT_BLUE
)

### Helper centralizzato: `define_function_once()`
###** define_function_once say_hello 'echo "Ciao mondo"'
define_function_once() {
    local fun_name="$1"
    shift
    if ! declare -f "$fun_name" >/dev/null 2>&1; then
        eval "$fun_name() { $*; }"
    fi
}

# *1* DECLARE define_br_flag() { ex_fun() { } }
# *2* USAGE define_if_not_exists br_flag define_br_flag
define_if_not_exists() {
    local name="$1"
    if ! declare -f "$name" >/dev/null 2>&1; then
        shift
        "$@"
    fi
}

read_ansi_ascii() {
    local filename="$1"
    local result=()

    while IFS= read -r line; do
        # Replace placeholders with ANSI color values
        line="${line//"ART_COLORS[0]"/${ART_COLORS[0]}}"
        line="${line//"ART_COLORS[1]"/${ART_COLORS[1]}}"
        line="${line//"RED"/${RED}}"
        line="${line//"YELLOW"/${YELLOW}}"
        line="${line//"BLUE"/${BLUE}}"
        line="${line//"GREEN"/${GREEN}}"
        line="${line//"RESET"/${RESET}}"
        result+=("$line")
    done <"$filename"

    # Print the lines joined by a special delimiter
    printf "%s${IFS}" "${result[@]}"
}

br_spacer() {
    echo -e "${RESET}"
    local ln=${1:-2}
    printf '\n%.0s' $(seq 1 "$ln")
}

load_ascii_art() {
    local filename="$1"
    local target_array="$2"

    if [[ ! -f "$filename" ]]; then
        echo "⚠️  File not found: $filename"
        return 1
    fi

    eval "$target_array=()"
    while IFS= read -r line; do
        eval "$target_array+=(\"\$line\")"
    done < <(read_ansi_ascii "$filename")
}

# Definisci solo se non è già definita
if ! declare -f br_calculate_spaces >/dev/null 2>&1; then
    # Funzione per calcolare gli spazi di riempimento centrati
    br_calculate_spaces() {
        local line="$1"
        local max_length="$2"
        local current_length="${#line}"

        if ((current_length < max_length)); then
            local padding=$(((max_length - current_length) / 2))
            printf "%*s" "$padding" ""
        fi
    }

fi
# Definisci solo se non è già definita
if ! declare -f br_usage >/dev/null 2>&1; then
    br_usage() {
        echo -e "${COLORS[4]} Version: $BR_VERSION ${RESET}"
        echo ""
        echo "${COLORS[2]} Version: USAGE br_flag 0.7 as SECOND ${RESET}"
        echo "${COLORS[7]} Version: USAGE br_flag \"\$@\" ${RESET}"
        echo ""
    }
fi

define_br_test_new() {
    eval 'br_test_new() { br_flag "$@"; }'
}

# Questa è la corretta chiamata:
define_if_not_exists br_test_new define_br_test_new

br_flag() {
    local i=0 MODULE_NAME=${1:-""} MODULE_VERSION=${2:+ ${2}} delay=${3:-0.65}

    local SPACES="" SPACES_AUTHOR="" FULL_MODULE="" AUTHOR="" LONGEST_COMMAND=74 # Lunghezza massima delle righe di comando

    AUTHOR=" ⚡ FGIROLAMI29  ⚡  "
    [[ -n "$MODULE_NAME" ]] && FULL_MODULE="MODULO: ${MODULE_NAME}${MODULE_VERSION:+ VERSION: ${MODULE_VERSION}}"

    # Calcola la lunghezza attuale della riga di comando
    SPACES=$(br_calculate_spaces "${FULL_MODULE}" "$LONGEST_COMMAND")
    SPACES_AUTHOR=$(br_calculate_spaces "${AUTHOR}" "$LONGEST_COMMAND")

    # Scegli un colore ciclico color=${COLORS[$color_index]}
    # Stampa la riga di comando con gli spazi aggiuntivi e l'ASCII Art    echo -e "${color}${COMMANDS[$index]:-}${RESET}${SPACES}${ASCII_ART_EMBL[$art_emb_index]:-}"
    br_spacer 1

    while [ $i -lt ${#ASCII_ART[@]} ]; do
        # Aggiunge un'interruzione di riga alla riga corrente
        printf "%b\n" "${ASCII_ART[$i]}"
        ((i++))
    done

   # echo -e "${RESET}${BLUE}                                 LEGION 🐋                                ${RESET}"

    echo -e "${COLORS[10]}${SPACES_AUTHOR}${AUTHOR}${RESET}"

    # Stampa la riga di comando con gli spazi aggiuntivi e l'ASCII Art
    echo -e "${COLORS[4]}${SPACES}${FULL_MODULE}${SPACES}${RESET}"

    br_spacer 2

    sleep "$delay"

}

# Definisci solo se non è già definita
if ! declare -f br_true >/dev/null 2>&1; then
    br_true() {
        local val
        val="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
        [[ "$val" == "true" || "$val" == "1" ]]
    }
fi

#load_ascii_art "$BASE_PATH/.emblflag" ASCII_ART
#load_ascii_art "$BASE_PATH/.emblsmall" ASCII_ART_EMBL

if ! br_true "$ASCII_ART_LOADED"; then
    # carica solo se le variabili sono *non definite* o vuote
    if ! declare -p ASCII_ART &>/dev/null || [[ -z "${ASCII_ART[*]:-}" ]]; then
        declare -a ASCII_ART
        load_ascii_art "$BASE_PATH/.emblflag" ASCII_ART
    fi

    if ! declare -p ASCII_ART_EMBL &>/dev/null || [[ -z "${ASCII_ART_EMBL[*]:-}" ]]; then
        declare -a ASCII_ART_EMBL
        load_ascii_art "$BASE_PATH/.emblsmall" ASCII_ART_EMBL
    fi

    ASCII_ART_LOADED=true
fi
