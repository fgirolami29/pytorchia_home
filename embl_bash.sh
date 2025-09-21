#!/bin/bash
: "${TORCHIA_INTER:=true}"

DEBUG=false
ASCII_ART_LOADED=false
BR_VERSION="1.5.6"
BASE_PATH="$HOME/.pytorchia"
TORCHIA_TY_AUTHOR="⚡ F.GIROLAMI29  ⚡"
MODE="*"
# ANSI Colors
RED="\033[91m"
YELLOW="\033[93m"
BLUE="\033[94m"
GREEN="\033[92m"
MAGENTA="\033[95m"
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

# sever a garantire il calcolo vero delle spaziature
REPLACERS=(
    "ART_COLORS[0]"
    "ART_COLORS[1]"
    "RED"
    "YELLOW"
    "BLUE"
    "GREEN"
    "MAGENTA"
    "RESET"
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

! declare -f br_ln >/dev/null 2>&1 && br_ln() {
    local repeat i=1
    repeat=${1:-1}
    while ((i <= repeat)); do
        echo
        ((i++))
    done

}

! declare -f br_spacer >/dev/null 2>&1 && br_spacer() {
    echo -e "${RESET}"
    local ln=${1:-2}
    printf '\n%.0s' $(seq 1 "$ln")
}
# Definisci solo se non è già definita
! declare -f bbr_truer_trues >/dev/null 2>&1 && br_true() {
    local val
    val="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    ##echo "val $val"
    [[ "$val" == "true" || "$val" == "1" ]]
}

! declare -f read_ansi_ascii >/dev/null 2>&1 && read_ansi_ascii() {
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
        line="${line//"MAGENTA"/${MAGENTA}}"
        line="${line//"RESET"/${RESET}}"
        result+=("$line")
    done <"$filename"

    # Print the lines joined by a special delimiter
    printf "%s${IFS}" "${result[@]}"
}

! declare -f load_ascii_art >/dev/null 2>&1 && load_ascii_art() {
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
#! declare -f br_calculate_spaces >/dev/null 2>&1 &&
br_calculate_spaces() {
    # Funzione per calcolare gli spazi di riempimento centrati
    local line="$1"
    local max_length="$2"
    local current_length
    current_length="$(br_strip_ansi_codes ${#line})"
    br_true "$DEBUG" && echo "[DEBUG] current_length $current_length"
    if ((current_length < max_length)); then
        local padding=$(((max_length - current_length) / 2))
        printf "%*s" "$padding" ""
    fi
}

! declare -f br_specific_loader >/dev/null 2>&1 && br_specific_loader() {
    local specific_embl=${1:-}
    local specific_embl_path="$BASE_PATH/.embl_$specific_embl"

    if [[ -z "$specific_embl" ]]; then
        echo -e "${RED}❌ br_specific_loader: Specific emblem name not provided.${RESET}"
        return 1
    fi

    if [[ ! -f "$specific_embl_path" ]]; then
        echo -e "${RED}❌ br_specific_loader: File not found: $specific_embl_path${RESET}"
        return 1
    fi

    load_ascii_art "$specific_embl_path" ASCII_ART_EMBL_SPEC
}

# Stampa le modalità disponibili per br_flag
! declare -f br_cases_usage >/dev/null 2>&1 && br_cases_usage() {
    echo -e "${COLORS[10]}🎨 MODALITÀ SUPPORTATE:${RESET}"
    echo -e "  ${COLORS[4]}specific${RESET}   ➤ Stampa il file \".embl_<specific_val>\" (es: .embl_docker)"
    echo -e "  ${COLORS[4]}dual${RESET}       ➤ Stampa affiancati .emblflag e .emblsmall (default)"
    echo -e "  ${COLORS[4]}left${RESET}       ➤ Stampa solo l’ASCII Art grande (.emblflag)"
    echo -e "  ${COLORS[4]}right${RESET}      ➤ Stampa solo l’ASCII Art piccolo (.emblsmall)"
    echo -e "  ${COLORS[4]}centered${RESET}   ➤ (🧪 Work in progress) Centra .emblflag nel terminale"
    br_ln
    echo -e "${COLORS[2]} [INFO]  N.B.${RESET} Se usi la modalità \"specific\", il quinto parametro è obbligatorio!"
    br_ln 2
}

# Mostra uso con spiegazione modalità supportate
! declare -f br_usage_new >/dev/null 2>&1 && br_usage_new() {
    echo -e "${COLORS[4]}🔧 br_flag() - Versione: $BR_VERSION${RESET}"
    br_ln

    echo -e "${COLORS[10]}📦 USO:${RESET}"
    echo -e "  br_flag \"<modulo>\" \"<versione>\" \"<autore>\" \"<ritardo>\" \"<modalità>\" \"<specific_val>\"\n"

    echo -e "${COLORS[10]}📘 ESEMPI:${RESET}"
    echo -e "  br_flag \"SEO Engine\" \"1.2.0\" \"F.Girolami\" 0.5 specific docker"
    echo -e "  br_flag \"Docker Booster\" \"2.0\" \"\" 0.3 dual"
    echo -e "  br_flag \"Tiny Mode\" \"\" \"\" 0.2 right"
    echo -e "  br_flag \"\" \"\" \"\" 0.7 left"

    br_ln
    br_cases_usage
}

# unused
br_strip_ansi_placeholders() {
    local line="$1"
    local pattern keywords=()

    for rep in "${REPLACERS[@]}"; do
        local escaped
        escaped="$(printf '%s' "$rep" | sed 's/[][\/.^$*]/\\&/g')"
        keywords+=("$escaped")

        br_true "$DEBUG" && echo -e "${COLORS[2]}[DEBUG] Placeholder rilevato: ${rep} → ${escaped}${RESET}"

    done

    # Costruisce pattern tipo: \b(RED|YELLOW|ART_COLORS\[0\]|...)\b
    pattern="\\b($(
        IFS='|'
        echo "${keywords[*]}"
    ))\\b"

    br_true "$DEBUG" && echo -e "${COLORS[2]}[DEBUG] Pattern regex usato: ${pattern}${RESET}"
    br_true "$DEBUG" && echo -e "${COLORS[2]}[DEBUG] Input originale: ${line}${RESET}"

    local stripped
    stripped=$(echo "$line" | sed -E "s/${pattern}//g")

    br_true "$DEBUG" && echo -e "${COLORS[2]}[DEBUG] Output ripulito: ${stripped}${RESET}"

    echo "$stripped"
}

# Funzione per rimuovere i codici ANSI
br_strip_ansi_codes() {
    echo -e "$1" | sed -E 's/\x1B\[[0-9;]*[mK]//g'
}

br_case_printer() {
    local mode="${1}" specific_val="${2}" i=0 max_lines
    local current_len=0 total_len max_len=0     # for all cases
    local left_cleaned right_cleaned left right # only for dual cases
    case "$mode" in

    dual)

        load_ascii_art "$BASE_PATH/.emblflag" ASCII_ART
        load_ascii_art "$BASE_PATH/.emblsmall" ASCII_ART_EMBL

        max_lines=${#ASCII_ART[@]}
        br_true "$TORCHIA_INTER" && max_lines=$((max_lines + 1))

        ((${#ASCII_ART_EMBL[@]} > max_lines)) && max_lines=${#ASCII_ART_EMBL[@]}

        LONGEST_COMMAND=$((${#ASCII_ART[1]} + ${#ASCII_ART_EMBL[1]})) # lo esportiamo per il br_computed_spaces
        while [ $i -lt "$max_lines" ]; do
            left="${ASCII_ART[$i]}"
            right="${ASCII_ART_EMBL[$i]}"
            printf "%-60b  %b\n" "$left" "$right"

            # Strip dei placeholder ANSI per calcolo effettivo della larghezza

            left_cleaned=$(br_strip_ansi_codes "$left")
            right_cleaned=$(br_strip_ansi_codes "$right")

            current_len=${#left_cleaned}
            total_len=$((current_len + ${#right_cleaned}))

            ((total_len > max_len)) && max_len=$total_len

            ((i++))
        done
        LONGEST_COMMAND=$max_len
        ;;
    left)
        load_ascii_art "$BASE_PATH/.emblflag" ASCII_ART
        max_lines=${#ASCII_ART[@]}
        br_true "$TORCHIA_INTER" && max_lines=$((max_lines + 1))
        while [ $i -lt "$max_lines" ]; do
            local line="${ASCII_ART[$i]}"
            printf "%b\n" "$line"
            cleaned=$(br_strip_ansi_codes "$line")
            current_len=${#cleaned}
            ((current_len > max_len)) && max_len=$current_len
            ((i++))
        done
        LONGEST_COMMAND=$max_len
        ;;
    right)
        load_ascii_art "$BASE_PATH/.emblsmall" ASCII_ART_EMBL
        max_lines=${#ASCII_ART_EMBL[@]}
        br_true "$TORCHIA_INTER" && max_lines=$((max_lines + 1))
        while [ $i -lt "$max_lines" ]; do
            local line="${ASCII_ART_EMBL[$i]}"
            cleaned=$(br_strip_ansi_codes "$line")
            current_len=${#cleaned}
            printf "%b\n" "${ASCII_ART_EMBL[$i]}"
            ((current_len > max_len)) && max_len=$current_len
            ((i++))
        done
        LONGEST_COMMAND=$max_len
        ;;
    centered)
        echo -e "${RED}❌ Modalità br_flag IN ARRIVO: '$mode'${RESET}\n"
        echo -e "${RED}❌ FALLBACK in Modalità : 'left' \n"

        load_ascii_art "$BASE_PATH/.emblflag" ASCII_ART

        max_lines=${#ASCII_ART[@]}

        br_true "$TORCHIA_INTER" && max_lines=$((max_lines + 1))
        while [ $i -lt "$max_lines" ]; do
            local line="${ASCII_ART[$i]}"
            printf "%b\n" "$line"
            cleaned=$(br_strip_ansi_codes "$line")
            current_len=${#cleaned}
            ((current_len > max_len)) && max_len=$current_len
            ((i++))
        done

        LONGEST_COMMAND=$max_len
        ;;
    specific)
        br_specific_loader "$specific_val" ASCII_ART_EMBL_SPEC
        max_lines=${#ASCII_ART_EMBL_SPEC[@]}
        br_true "$TORCHIA_INTER" && max_lines=$((max_lines + 1))
        while [ $i -lt "$max_lines" ]; do
            line="${ASCII_ART_EMBL_SPEC[$i]}"
            printf "%b\n" "$line"
            cleaned=$(br_strip_ansi_codes "$line")
            current_len=${#cleaned}
            ((current_len > max_len)) && max_len=$current_len
            ((i++))
        done
        LONGEST_COMMAND=$max_len
        br_ln 2
        ;;
    *)
        LONGEST_COMMAND=74
        echo -e "${RED}❌ Modalità br_flag sconosciuta: '$mode'${RESET}\n" >&2
        br_usage_new
        return 1
        ;;
    esac
    export MODE=$mode
    export LONGEST_COMMAND=$max_len

}

lazy_load_ascii_art() {
    if ! br_true "$ASCII_ART_LOADED"; then
        br_true "$DEBUG" && echo -e "${COLORS[6]}[DEBUG] ⬇️ Caricamento emblem ASCII...${RESET}"

        # Caricamento .emblflag
        if [[ -f "$BASE_PATH/.emblflag" ]]; then
            declare -f -a ASCII_ART
            load_ascii_art "$BASE_PATH/.emblflag" ASCII_ART
            br_true "$DEBUG" && echo -e "${COLORS[5]}[LOAD] .emblflag${RESET}"
        else
            br_true "$DEBUG" && echo -e "${RED}[DEBUG] ❌ File non trovato: $BASE_PATH/.emblflag${RESET}"
        fi

        # Caricamento .emblsmall
        if [[ -f "$BASE_PATH/.emblsmall" ]]; then
            declare -f -a ASCII_ART_EMBL
            load_ascii_art "$BASE_PATH/.emblsmall" ASCII_ART_EMBL
            br_true "$DEBUG" && echo -e "${COLORS[5]}[LOAD] .emblsmall${RESET}"
        else
            br_true "$DEBUG" && echo -e "${RED}[DEBUG] ❌ File non trovato: $BASE_PATH/.emblsmall${RESET}"
        fi

        # Inizializza sempre, anche se vuota (verrà usata da specific)
        # declare -f -a ASCII_ART_EMBL_SPEC

        ASCII_ART_LOADED=true
    fi
}

br_computed_spaces() {
    local mode=${1} longest_cmd=${2:-$LONGEST_COMMAND}

    local offset longest_cmd_offset

    # Imposta offset base a 4, ma lo azzera se modalità right
    offset=4
    [ "$mode" = "right" ] && offset=3

    # Calcola il numero di spazi da inserire per allineamento
    longest_cmd_offset=$((longest_cmd - offset))

    # Calcola la lunghezza attuale della riga di comando
    SPACES=$(br_calculate_spaces "${FULL_MODULE}" "$longest_cmd_offset")
    SPACES_TY_AUTHOR=$(br_calculate_spaces "${TY_AUTHOR}" "$longest_cmd_offset")
    SPACES_TORCHIA_TY_AUTHOR=$(br_calculate_spaces "${TORCHIA_TY_AUTHOR}" "$longest_cmd_offset")

    echo -e "${COLORS[10]}${SPACES_TORCHIA_TY_AUTHOR}${TORCHIA_TY_AUTHOR}${RESET}"

    printf "${MAGENTA}%*s${RESET}\n\n" "$longest_cmd_offset" '' | tr ' ' '_'

    # Stampa la riga di comando con gli spazi aggiuntivi e l'ASCII Art
    echo -e "${COLORS[4]}${SPACES}${FULL_MODULE}${SPACES}${RESET}"

    echo -e "${COLORS[0]}${SPACES_TY_AUTHOR}${TY_AUTHOR}${RESET}"

    if br_true "$DEBUG"; then
        br_spacer 1
        echo -e "${COLORS[4]}longest_cmd: ($longest_cmd) longest_cmd_author: ($longest_cmd_offset)  offset:  ($offset) ${RESET}"
        br_spacer 1
        echo -e "${COLORS[4]}SPACES: (${#SPACES})  SPACES_TY_AUTHOR:  (${#SPACES_TY_AUTHOR}) ${RESET}"
    fi
}

br_flag() {

    local TY_MODULE_NAME=${1:-""} TY_MODULE_VERSION=${2:+ ${2}} TY_AUTHOR=${3:+AUTHOR: ${3}} delay=${4:-0.65} mode="${5:-left}" specific_val="${6}"

    local SPACES="" SPACES_TY_AUTHOR="" FULL_MODULE="" LONGEST_COMMAND=74 # Lunghezza massima delle righe di comando

    [[ -n "$TY_MODULE_NAME" ]] && FULL_MODULE="MODULO: ${TY_MODULE_NAME}${TY_MODULE_VERSION:+ VERSION:${TY_MODULE_VERSION}}"

    [[ -z "$3" ]] && TY_AUTHOR="$TORCHIA_TY_AUTHOR"

    br_spacer 1

    br_case_printer "$mode" "$specific_val"

    br_computed_spaces "$mode" $LONGEST_COMMAND

    br_spacer 2

    sleep "$delay"

}
# RUN LAZY ASCII CACHING !DONT USE IT# lazy_load_ascii_art

# Se viene passato almeno un argomento, esegui br_flag con tutti gli argomenti
#[[ -n "$1" ]] && br_flag "$@"
