#!/usr/bin/env bash
# ==============================================================================
#  PyTorchia Home - Installer "a banda larga"
#  - Colori ANSI, logging chiaro
#  - Idempotente: non duplica blocchi in rc files
#  - Scarica dipendenze di base + torchia-bearer
#  - Chiede (interattivo) se spostare il bearer in ~/.bin e lo avvia
# ==============================================================================
set -euo pipefail

# -------------------------
# Metadati / Config
# -------------------------
BR_VERSION="1.5.7"
AUTHOR="fgirolami29"
MODULE_NAME="TORCHIA_HOME"
PRETTY_NAME="PyTorchia Home"

INSTALL_DIR="${HOME}/.pytorchia" # $TORCHIA_HOME target
EXE_BIN_DIR="${HOME}/.bin"       # dove teniamo gli eseguibili "nostri"
REPO_URL="https://github.com/fgirolami29/pytorchia_home"
RAW_URL="${REPO_URL}/releases/download/v${BR_VERSION}"

# File di configurazione shell da aggiornare (ordine conservativo)
RC_ARR=(.bashrc .zshrc .profile)

# Asset minimi da prelevare dalla release
DEPS=(embl_bash.sh emblems.zip install-torchia-bearer.sh)

# Directory da creare / garantire
TORCHIA_DIRS=("${INSTALL_DIR}" "${EXE_BIN_DIR}")

# -------------------------
# ANSI / Emoji
# -------------------------
BOLD="\033[1m"
DIM="\033[2m"
ITALIC="\033[3m"
RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"

OK="✅"
WARN="⚠️ "
ERR="❌"
DL="⬇️"
BOX="📦"
WRENCH="🛠️"
ROCKET="🚀"

# -------------------------
# Logging helpers
# -------------------------
log() { printf "%b\n" "$*"; }
info() { log "${CYAN}${WRENCH}${RESET} $*"; }
ok() { log "${GREEN}${OK}${RESET} $*"; }
warn() { log "${YELLOW}${WARN}${RESET} $*"; }
die() {
    log "${RED}${ERR}${RESET} $*"
    exit 1
}

# -------------------------
# Banner
# -------------------------
print_banner() {
    echo -e "\n${BOLD}==============================${RESET}"
    echo -e "  ${BOLD}${PRETTY_NAME}${RESET} ${DIM}Installer${RESET}"
    echo -e "  Version: ${BOLD}${BR_VERSION}${RESET}"
    echo -e "  Author : ${BOLD}${AUTHOR}${RESET}"
    echo -e "${BOLD}==============================${RESET}\n"
    echo -e "${BOX} MODULE: ${BOLD}${MODULE_NAME}${RESET}"
    echo -e "${BOX} REPO  : ${BLUE}${REPO_URL}${RESET}\n"
    echo -e "${BOX} Installazione ${PRETTY_NAME} dal repo ufficiale…"
}

# -------------------------
# Utility: garantisci directory
# -------------------------
scaffold_dirs() {
    local arr=("$@")
    for dir in "${arr[@]}"; do
        [[ -d "$dir" ]] || {
            mkdir -p "$dir"
            ok "Creata dir: ${dir}"
        }
    done
}

# -------------------------
# Utility: snippet PATH idempotente
# - assicura che <dir> sia in PATH nello specifico rc file
# -------------------------
ensure_path_in_file() {
    local file="$1" dir="$2"
    local line='case ":$PATH:" in *":'"$dir"':"*) ;; *) export PATH="$PATH:'"$dir"'" ;; esac'
    touch "$file"
    if grep -Fq "$dir" "$file"; then
        info "$file contiene già ${dir}"
    else
        {
            echo ""
            echo "# >>> pytorchia-path >>>"
            echo "$line"
            echo "# <<< pytorchia-path <<<"
        } >>"$file"
        ok "PATH aggiornato in ${file} (+ ${dir})"
    fi
}

# -------------------------
# Step 1: download/prepare deps
# -------------------------
fetch_deps() {
    for file in "${DEPS[@]}"; do
        echo "${DL} Download ${file}…"
        curl -fsSL "${RAW_URL}/${file}" -o "${file}" || die "Errore nel download di ${file}"

        case "$file" in
        embl_bash.sh)
            chmod +x "$file"
            ok "chmod +x ${file}"
            ;;
        emblems.zip)
            unzip -oq "$file" -d . || die "Errore nell’estrazione di ${file}"
            rm -f "$file"
            ok "Estratti emblemi"
            ;;
        install-torchia-bearer.sh)
            chmod +x "$file"
            ok "chmod +x ${file}"
            ;;
        esac
    done
}

# -------------------------
# Step 2: opzionale spostamento bearer in ~/.bin
# - se non TTY → default NO, rimane in $INSTALL_DIR
# -------------------------
BEAR_STAY_AT_HOME=true
ask_move_bearer_to_bin() {
    if [[ -t 0 ]]; then
        read -r -p "Vuoi spostare 'install-torchia-bearer.sh' in '${EXE_BIN_DIR}'? (y/N) " response
    else
        response="n"
    fi

    case "${response:-n}" in
    [yY][eE][sS] | [yY])
        info "Spostamento in corso…"
        mv -f "${INSTALL_DIR}/install-torchia-bearer.sh" "${EXE_BIN_DIR}/install-torchia-bearer.sh"
        ok "Spostato in ${EXE_BIN_DIR}"
        BEAR_STAY_AT_HOME=false
        ;;
    *)
        info "Rimane in ${INSTALL_DIR}"
        BEAR_STAY_AT_HOME=true
        ;;
    esac
}

# -------------------------
# Step 3: setup RC files
# - pulisce vecchie righe di TORCHIA_HOME/embl_bash.sh
# - setta TORCHIA_HOME, source embl_bash.sh
# - assicura PATH a ~/.bin e ~/.local/bin
# -------------------------
setup_rc() {
    local arr=("$@")
    for rc in "${arr[@]}"; do
        local file="${HOME}/${rc}"
        touch "$file"

        # rimuovi righe duplicate/vecchie relative a TORCHIA
        local tmp="${file}.tmp.$$"
        awk '
      /^[[:space:]]*[^#].*TORCHIA_HOME=/ { next }
      /embl_bash\.sh/                    { next }
      /pytorchia-path/                   { next }
      { print }
    ' "$file" >"$tmp" && mv "$tmp" "$file"

        {
            echo ""
            echo "# >>> pytorchia-emblems >>>"
            echo "export TORCHIA_HOME=\"${INSTALL_DIR}\""
            # shellcheck disable=SC2016
            echo '[[ $- == *i* ]] && source "$TORCHIA_HOME/embl_bash.sh"'
            echo "# <<< pytorchia-emblems <<<"
        } >>"$file"
        ok "Aggiornato blocco TORCHIA in ${file}"

        # PATH a ~/.bin e ~/.local/bin
        ensure_path_in_file "$file" "${EXE_BIN_DIR}"
        ensure_path_in_file "$file" "${HOME}/.local/bin"
    done
}

# -------------------------
# Step 4: esponi ed esegui bearer
# - se l’hai spostato in ~/.bin lo prendo da lì
# - altrimenti lo lancio da $INSTALL_DIR
# -------------------------
run_bearer() {
    local bearer_sh
    if [[ "${BEAR_STAY_AT_HOME}" == "false" ]]; then
        bearer_sh="${EXE_BIN_DIR}/install-torchia-bearer.sh"
    else
        bearer_sh="${INSTALL_DIR}/install-torchia-bearer.sh"
    fi

    if [[ ! -x "$bearer_sh" ]]; then
        warn "Bearer non trovato/eseguibile: ${bearer_sh} (continuo comunque)"
        return 0
    fi

    info "Eseguo bearer: ${bearer_sh} --name torchia-bearer --force"
    if ! "$bearer_sh" --name torchia-bearer --force; then
        warn "Non sono riuscito a esporre i binari con torchia-bearer (continua comunque)."
    else
        ok "torchia-bearer completato."
    fi

    echo
    ok "Installazione completata."
    echo -e "Riapri il terminale o esegui:\n  ${BOLD}source ~/.bashrc${RESET}  oppure  ${BOLD}source ~/.zshrc${RESET}"
    echo -e "${DIM}Tip:${RESET} puoi rilanciare in futuro ${BOLD}torchia-bearer --force${RESET} per riallineare i symlink."
}

# -------------------------
# MAIN
# -------------------------
main() {
    print_banner

    # 0) scaffold
    scaffold_dirs "${TORCHIA_DIRS[@]}"

    # 1) muoviamoci nell’install dir (TORCHIA_HOME target)
    cd "${INSTALL_DIR}"

    # 2) prendi dipendenze
    fetch_deps

    # 3) chiedi se spostare bearer in ~/.bin
    ask_move_bearer_to_bin

    # 4) setup rc files (PATH + TORCHIA_HOME)
    setup_rc "${RC_ARR[@]}"

    # 5) lancia bearer
    run_bearer
}

main "$@"
exit 0
