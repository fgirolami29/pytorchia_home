#!/usr/bin/env bash
# ==============================================================================
#  install-torchia-bearer.sh
# ------------------------------------------------------------------------------
#  Autore: Federico Girolami <fgirolami29>
#  Data:   2025-09-22
#  Versione: 1.0.2
#  Descrizione:
#  - "Portatore" degli script TORCHIA:
#    * vive (o viene ancorato) in $TORCHIA_HOME/.bin
#    * espone TUTTI i *.sh di .bin come comandi senza .sh in ~/.local/bin
#    * pubblica se stesso come 'torchia-bearer' (target dentro .bin)
#    * può installare nuovi "TORCHIETTI" (add/fetch)
# ------------------------------------------------------------------------------
#  Uso:
#    ./install-torchia-bearer.sh [opzioni] [azioni]
#
#  Opzioni:
#    --force            Sovrascrive link/esistenti
#    --dry-run          Mostra cosa farebbe senza modifiche
#    --name NAME        Nome comando globale per il bearer (default: torchia-bearer)
#    --no-self          Non pubblicare il bearer (nessun symlink torchia-bearer)
#
#  Azioni (ripetibili):
#    --add   PATH[:NOME]    Copia un file locale in $TORCHIA_HOME/.bin (chmod +x) e lo pubblica
#    --fetch URL[:NOME]     Scarica da URL in $TORCHIA_HOME/.bin (chmod +x) e lo pubblica
#    --list                 Elenca i comandi esposti e i target
#
#  Note:
#    - Il symlink globale (~/.local/bin/<NAME>) punta SEMPRE a $TORCHIA_HOME/.bin/<file>
#    - Il bearer viene escluso dalla pubblicazione automatica dei *.sh (niente alias "install-torchia-bearer")
# ==============================================================================

set -euo pipefail

# -------------------------
# ANSI
# -------------------------
BOLD="\033[1m"
DIM="\033[2m"
ITALIC="\033[3m"
RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
OK="✅"
WARN="⚠️"
ERR="❌"
WRENCH="🛠️"

log() { printf "%b\n" "$*"; }
ok() { log "${GREEN}${OK}${RESET} $*"; }
warn() { log "${YELLOW}${WARN}${RESET} $*"; }
die() {
    log "${RED}${ERR}${RESET} $*"
    exit 1
}
info() { log "${CYAN}${WRENCH}${RESET} $*"; }

# -------------------------
# Parametri / Default
# -------------------------
FORCE=false
DRYRUN=false
SELF_LINK=true
SELF_NAME="torchia-bearer"

# Evita unbound con set -u
declare -a ADD_ITEMS=()   # elementi tipo PATH[:NAME]
declare -a FETCH_ITEMS=() # elementi tipo URL[:NAME]
DO_LIST=false

# -------------------------
# Parse args (opzioni + azioni)
# -------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
    --force) FORCE=true ;;
    --dry-run) DRYRUN=true ;;
    --no-self) SELF_LINK=false ;;
    --name)
        shift || die "Errore: --name richiede un valore"
        SELF_NAME="$1"
        ;;
    --add)
        shift || die "Errore: --add richiede PATH[:NOME]"
        ADD_ITEMS+=("$1")
        ;;
    --fetch)
        shift || die "Errore: --fetch richiede URL[:NOME]"
        FETCH_ITEMS+=("$1")
        ;;
    --list) DO_LIST=true ;;
    -h | --help)
        grep -E '^# ' "$0" | sed 's/^# //'
        exit 0
        ;;
    *)
        die "Argomento non riconosciuto: $1"
        ;;
    esac
    shift
done

# -------------------------
# Layout cartelle
# -------------------------
: "${TORCHIA_HOME:=${HOME}/torchia}"
SRC_DIR="${TORCHIA_HOME}/.bin"  # dove vivono gli script "sorgenti"
TARGET_DIR="${HOME}/.local/bin" # dove creiamo i comandi (symlink senza .sh)

mkdir -p "$SRC_DIR" "$TARGET_DIR"

# -------------------------
# Helpers
# -------------------------
resolve_abs() {
    local src="$1"
    while [[ -L "$src" ]]; do
        local t
        t="$(readlink "$src")"
        if [[ "$t" = /* ]]; then src="$t"; else src="$(cd "$(dirname "$src")" && pwd)/$t"; fi
    done
    echo "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
}

append_path_snippet() {
    local file="$1" dir="$2"
    local line='case ":$PATH:" in *":'"$dir"':"*) ;; *) export PATH="$PATH:'"$dir"'" ;; esac'
    if [[ -f "$file" ]] && grep -Fq "$dir" "$file"; then
        return 0
    fi
    $DRYRUN && {
        info "[DRY] aggiungerei $dir a $file"
        return 0
    }
    {
        echo ""
        echo "# >>> torchia-bearer path >>>"
        echo "$line"
        echo "# <<< torchia-bearer path <<<"
    } >>"$file"
    ok "PATH aggiornato in $file (+ $dir)"
}

ensure_paths_in_shells() {
    for rc in "${HOME}/.profile" "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        [[ -f "$rc" ]] || : >"$rc"
        append_path_snippet "$rc" "$SRC_DIR"
        append_path_snippet "$rc" "$TARGET_DIR"
    done
}

# copia/muove file nella .bin con nome definito
install_into_bin() {
    local src="$1" name="$2"
    local dest="$SRC_DIR/$name"
    if $DRYRUN; then
        info "[DRY] Copierei $src -> $dest e chmod +x"
    else
        cp -f "$src" "$dest"
        chmod +x "$dest"
        ok "Installato in .bin: $dest"
    fi
}

# scarica URL in .bin
fetch_into_bin() {
    local url="$1" name="$2"
    local dest="$SRC_DIR/$name"
    if $DRYRUN; then
        info "[DRY] Scaricherei $url -> $dest e chmod +x"
    else
        curl -fsSL "$url" -o "$dest" || die "Download fallito: $url"
        chmod +x "$dest"
        ok "Scaricato in .bin: $dest"
    fi
}

# pubblica tutti i *.sh (tranne il bearer) come comandi senza .sh
publish_all_bins() {
    shopt -s nullglob
    for src in "$SRC_DIR"/*.sh; do
        local fname base link
        fname="$(basename "$src")"
        base="${fname%.sh}"
        # escludi il bearer (non vogliamo anche "install-torchia-bearer")
        [[ "$base" == "install-torchia-bearer" ]] && continue
        link="${TARGET_DIR}/${base}"
        if [[ -e "$link" || -L "$link" ]]; then
            if $FORCE; then
                $DRYRUN && info "[DRY] Sovrascriverei $link -> $src" || {
                    rm -f "$link"
                    ln -s "$src" "$link"
                    ok "Sovrascritto $link -> $src"
                }
            else
                info "Presente: $link (usa --force per aggiornare)"
            fi
        else
            $DRYRUN && info "[DRY] Creerei $link -> $src" || {
                ln -s "$src" "$link"
                ok "Creato $link -> $src"
            }
        fi
        # assicura eseguibilità del sorgente
        [[ -x "$src" ]] || { $DRYRUN && info "[DRY] chmod +x $src" || {
            chmod +x "$src"
            ok "chmod +x $src"
        }; }
    done
    shopt -u nullglob
}

# pubblica il symlink "canonico" del bearer: ~/.local/bin/<SELF_NAME> -> $SRC_DIR/install-torchia-bearer.sh
publish_self_link() {
    local link="${TARGET_DIR}/${SELF_NAME}"
    local target="${SRC_DIR}/install-torchia-bearer.sh"
    if [[ -e "$link" || -L "$link" ]]; then
        if $FORCE; then
            $DRYRUN && info "[DRY] Sovrascriverei $link -> $target" || {
                rm -f "$link"
                ln -s "$target" "$link"
                ok "Sovrascritto $link -> $target"
            }
        else
            info "Self-link già presente: $link (usa --force per aggiornare)"
        fi
    else
        $DRYRUN && info "[DRY] Creerei $link -> $target" || {
            ln -s "$target" "$link"
            ok "Creato $link -> $target"
        }
    fi
}

list_exposed() {
    echo -e "${BOLD}Comandi esposti in ${TARGET_DIR}:${RESET}"
    if compgen -G "${TARGET_DIR}/*" >/dev/null; then
        ls -l "${TARGET_DIR}"
    else
        echo " (vuoto)"
    fi
}

# -------------------------
# 1) Ancorare il bearer in $TORCHIA_HOME/.bin
#    - se lo stai lanciando altrove, lo copiamo in .bin come install-torchia-bearer.sh
#    - poi pubblicheremo ~/.local/bin/${SELF_NAME} -> $SRC_DIR/install-torchia-bearer.sh
# -------------------------
SELF_ABS="$(resolve_abs "$0")"
CANONICAL="${SRC_DIR}/install-torchia-bearer.sh"

if [[ "$SELF_ABS" != "$CANONICAL" ]]; then
    if $DRYRUN; then
        info "[DRY] Copierei il bearer in ${CANONICAL}"
    else
        cp -f "$SELF_ABS" "$CANONICAL"
        chmod +x "$CANONICAL"
        ok "Bearer ancorato in ${CANONICAL}"
    fi
else
    info "Bearer già ancorato in ${CANONICAL}"
fi

# -------------------------
# 2) Aggiorna PATH nei rc files
# -------------------------
ensure_paths_in_shells

# -------------------------
# 3) Esegui azioni richieste (installare TORCHIETTI)
#    --add PATH[:NOME]    | --fetch URL[:NOME]
#    Nota: se :NOME non specificato, si usa il basename; se non ha estensione, aggiungiamo .sh
# -------------------------
add_one() {
    local spec="$1"
    local path="${spec%%:*}"
    local name="${spec#*:}"
    [[ "$name" == "$spec" ]] && name="$(basename "$path")"
    # se name non ha estensione, metti .sh per coerenza con publishing
    [[ "$name" == *.* ]] || name="${name}.sh"
    [[ -f "$path" ]] || die "--add: file non trovato: $path"
    install_into_bin "$path" "$name"
}

fetch_one() {
    local spec="$1"
    local url="${spec%%:*}"
    local name="${spec#*:}"
    if [[ "$name" == "$spec" ]]; then
        name="$(basename "${url%%\?*}")"
        [[ "$name" == *.* ]] || name="${name}.sh"
    fi
    fetch_into_bin "$url" "$name"
}

# for it in "${ADD_ITEMS[@]}"; do add_one "$it"; done
# for it in "${FETCH_ITEMS[@]}"; do fetch_one "$it"; done
for spec in "${ADD_ITEMS[@]+"${ADD_ITEMS[@]}"}";   do add_one   "$spec"; done
for spec in "${FETCH_ITEMS[@]+"${FETCH_ITEMS[@]}"}"; do fetch_one "$spec"; done

# -------------------------
# 4) Pubblica tutti i *.sh (senza il bearer) + pubblica il bearer come nome desiderato
# -------------------------
publish_all_bins
$SELF_LINK && publish_self_link

# -------------------------
# 5) Lista (se richiesto)
# -------------------------
$DO_LIST && list_exposed

ok "Fatto."
echo -e "• Riapri la shell oppure: ${BOLD}source ~/.profile${RESET} (o il tuo rc file)"
echo -e "• Installa un nuovo TORCHIETTO: ${BOLD}${SELF_NAME} --add ./mio_tool.sh:mytool${RESET}"
echo -e "• Oppure da URL:            ${BOLD}${SELF_NAME} --fetch https://example/script.sh:myscript${RESET}"
echo -e "• Vedi tutti i comandi:     ${BOLD}ls -l ${TARGET_DIR}${RESET}"
