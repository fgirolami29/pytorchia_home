#!/usr/bin/env bash
set -euo pipefail

# install-torchia-bearer.sh
# ----------------------
# Versione: 1.0.0
# Autore: fgirolami29
# Descrizione:
#   Installa gli script in TORCHIA_HOME/.bin creando symlink in ~/.local/bin
#   e assicurando che entrambe le directory siano in PATH.
#
# Uso:
#   ./install-torchia-bearer.sh [--force] [--dry-run] [--name TORCHIASSS] [--no-self]
# Opzioni:
#   --force     : sovrascrive link esistenti
#   --dry-run   : mostra le azioni senza applicarle
#   --name NAME : nome comando per auto-esporre questo installer (default: TORCHIASSS)
#   --no-self   : non crea il symlink per questo installer

FORCE=false
DRYRUN=false
SELF_LINK=true
SELF_NAME="TORCHIASSS"

for ((i = 1; i <= $#; i++)); do
    arg="${!i}"
    case "$arg" in
    --force) FORCE=true ;;
    --dry-run) DRYRUN=true ;;
    --no-self) SELF_LINK=false ;;
    --name)
        next=$((i + 1))
        if ((next <= $#)); then
            SELF_NAME="${!next}"
            i=$next
        else
            echo "Errore: --name richiede un valore" >&2
            exit 2
        fi
        ;;
    *)
        echo "Arg non riconosciuto: $arg" >&2
        exit 2
        ;;
    esac
done

: "${TORCHIA_HOME:=${HOME}/torchia}"

SRC_DIR="${TORCHIA_HOME}/.bin"
TARGET_DIR="${HOME}/.local/bin"

if [[ ! -d "$SRC_DIR" ]]; then
    echo "Errore: $SRC_DIR non esiste. Controlla \$TORCHIA_HOME (attuale: $TORCHIA_HOME)." >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

echo "Sorgente script: $SRC_DIR"
echo "Directory link:  $TARGET_DIR"
$DRYRUN && echo "(DRY-RUN attivo — non verranno applicate modifiche)"

# ---- helper per PATH ---------------------------------------------------------
append_path_snippet() {
    local file="$1"
    local dir="$2"
    local line="export PATH=\"\$PATH:$dir\""
    if [[ -f "$file" ]]; then
        if grep -Fq "$dir" "$file"; then
            : # già presente
        else
            {
                echo ""
                echo "# Aggiunto da install-torchia-bearer.sh"
                echo "$line"
            } >>"$file"
            echo "Aggiornato: $file (+ $dir)"
        fi
    else
        {
            echo "# creato da install-torchia-bearer.sh"
            echo "$line"
        } >"$file"
        echo "Creato e aggiornato: $file (+ $dir)"
    fi
}

maybe_append_path() {
    local dir="$1"
    for f in "${HOME}/.profile" "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        if $DRYRUN; then
            if [[ -f "$f" ]] && grep -Fq "$dir" "$f"; then
                echo "[DRY] $f già contiene $dir"
            else
                echo "[DRY] aggiungerei $dir a $f"
            fi
        else
            append_path_snippet "$f" "$dir"
        fi
    done
}

# Assicuriamo che entrambi siano in PATH
maybe_append_path "$SRC_DIR"
maybe_append_path "$TARGET_DIR"

# ---- link *.sh -> senza estensione -------------------------------------------
shopt -s nullglob
for src in "${SRC_DIR}"/*.sh; do
    fname="$(basename "$src")"
    base="${fname%.sh}"
    link="${TARGET_DIR}/${base}"

    if [[ -e "$link" || -L "$link" ]]; then
        if $FORCE; then
            echo "Sovrascrivo $link -> $src"
            $DRYRUN || {
                rm -f "$link"
                ln -s "$src" "$link"
            }
        else
            echo "Salto $link (esiste). Usa --force per sovrascrivere."
        fi
    else
        echo "Creo link: $link -> $src"
        $DRYRUN || ln -s "$src" "$link"
    fi

    # garantisco eseguibilità al sorgente
    if [[ ! -x "$src" ]]; then
        echo "Imposto eseguibilità su $src"
        $DRYRUN || chmod +x "$src"
    fi
done
shopt -u nullglob

# ---- auto-esponi questo installer come TORCHIASSS (o nome custom) ------------
if $SELF_LINK; then
    # risolvi percorso assoluto di questo script
    # supporta invocazioni via symlink o path relativo
    resolve_self() {
        local src="$1"
        while [[ -L "$src" ]]; do
            local target
            target="$(readlink "$src")"
            if [[ "$target" = /* ]]; then
                src="$target"
            else
                src="$(cd "$(dirname "$src")" && pwd)/$target"
            fi
        done
        echo "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
    }
    SELF_ABS="$(resolve_self "$0")"
    SELF_LINK_PATH="${TARGET_DIR}/${SELF_NAME}"

    if [[ -e "$SELF_LINK_PATH" || -L "$SELF_LINK_PATH" ]]; then
        if $FORCE; then
            echo "Sovrascrivo self-link ${SELF_LINK_PATH} -> ${SELF_ABS}"
            $DRYRUN || {
                rm -f "$SELF_LINK_PATH"
                ln -s "$SELF_ABS" "$SELF_LINK_PATH"
            }
        else
            echo "Self-link esistente: ${SELF_LINK_PATH}. Usa --force per aggiornarlo."
        fi
    else
        echo "Creo self-link: ${SELF_LINK_PATH} -> ${SELF_ABS}"
        $DRYRUN || ln -s "$SELF_ABS" "$SELF_LINK_PATH"
    fi
fi

echo ""
if $DRYRUN; then
    echo "DRY-RUN completato. Rimuovi --dry-run per applicare le modifiche."
else
    echo "Fatto!"
    echo "• Riapri la shell oppure esegui:  source ~/.profile  (e/o il tuo rc file)"
    echo "• Ora puoi eseguire gli script senza .sh, es:  mytool"
    $SELF_LINK && echo "• E puoi rilanciare l'installer da ovunque:  ${SELF_NAME} --help"
fi
