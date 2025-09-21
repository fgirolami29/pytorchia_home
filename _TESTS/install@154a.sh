#!/bin/bash
set -eup
BR_VERSION="1.5.4a"
AUTHOR="fgirolami29"
MODULE_NAME="TORCHIA_HOME"
PRETTY_NAME="PyTorchia Home"

INSTALL_DIR="$HOME/.pytorchia"
EXE_BIN_DIR="$HOME/.bin"
REPO_URL="https://github.com/fgirolami29/pytorchia_home"
RAW_URL="${REPO_URL}/releases/download/v${BR_VERSION}"

# File di configurazione da modificare
# (mantiene la tua logica, ma in array per facilità di gestione)
RS_ARR=(.bashrc .zshrc)
DEPS=(embl_bash.sh emblems.zip install-torchia-bearer.sh)
TORCHIA_DIRS=("$INSTALL_DIR" "$EXE_BIN_DIR")

prit_banner() {
    echo -e "\n=============================="
    echo -e "  ${PRETTY_NAME} Installer"
    echo -e "  Version: $BR_VERSION"
    echo -e "  Author: $AUTHOR"
    echo -e "==============================\n"
    echo -e "📦 MODULE: $MODULE_NAME - AUTHOR: $AUTHOR VERSION: V$BR_VERSION\n REPO_URL: $REPO_URL \n"
    echo -e "📦 Installazione ${PRETTY_NAME} da repo ufficiale..."
}
scaffold_dirs() {
    # per sicurezza, crea anche la home se non esiste
    local arr=("$@")

    for dir in "${arr[@]}"; do
        [[ -d "$dir" ]] || mkdir -p "$dir"
    done

}

# --- scarica i file essenziali (aggiunto: install-torchia-bearer.sh) ---
fetch_deps() {
    for file in ${DEPS[@]}; do
        echo "⬇️  Download $file..."
        curl -sSfL "$RAW_URL/$file" -o "$file" || {
            echo "❌ Errore nel download di $file"
            exit 1
        }

        case "$file" in
        embl_bash.sh)
            chmod +x "$file"
            ;;
        emblems.zip)
            unzip -o "$file" -d . || {
                echo "❌ Errore nell'estrazione di $file"
                exit 1
            }
            rm "$file"
            ;;
        install-torchia-bearer.sh)
            chmod +x "$file"
            ;;
        esac
    done
}
BEAR_STAY_AT_HOME=true
# Se desideri tenere il bearer dentro .bin (opzionale, comodo):
# mv -f "$INSTALL_DIR/install-torchia-bearer.sh" "$INSTALL_DIR/.bin/install-torchia-bearer.sh"
ask_move_bearer_to_bin() {
    read -r -p "Vuoi spostare 'install-torchia-bearer.sh' in '$EXE_BIN_DIR' per una gestione più pulita? (y/n) " response
    case "$response" in
    [yY][eE][sS] | [yY])
        echo "Spostamento in corso..."
        mv -f "$INSTALL_DIR/install-torchia-bearer.sh" "$EXE_BIN_DIR/install-torchia-bearer.sh"
        echo "Spostato con successo in '$EXE_BIN_DIR'."
        export BEAR_STAY_AT_HOME=false
        ;;
    [nN][oO] | [nN])
        echo "Rimarrà in '$INSTALL_DIR'."
        # IMPLICITO !
        # export BEAR_STAY_AT_HOME=true
        ;;
    *)
        echo "Risposta non valida. Rimarrà in '$INSTALL_DIR'."
        # IMPLICITO !
        #export BEAR_STAY_AT_HOME=true
        ;;
    esac
}

# --- setup in .bashrc/.zshrc (mantiene la tua logica) ---
setup_rc() {
    local rc_arr=("$@")
    for rc in rc_arr; do
        file="$HOME/$rc"
        [[ -f "$file" ]] || : >"$file"

        tmp="${file}.tmp.$$"
        awk 'BEGIN{del1=0; del2=0}
       /^[[:space:]]*[^#].*TORCHIA_HOME=/ {next}
       /embl_bash\.sh/                   {next}
       {print}' "$file" >"$tmp" && mv "$tmp" "$file"

        {
            echo
            echo '# >>> pytorchia-emblems >>>'
            echo "export TORCHIA_HOME=\"$INSTALL_DIR\""
            # shellcheck disable=SC2016
            echo '[[ $- == *i* ]] && source "$TORCHIA_HOME/embl_bash.sh"'
            # assicura che ~/.local/bin sia in PATH (per i symlink del bearer)
            # shellcheck disable=SC2016
            echo 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$PATH:$HOME/.local/bin";; esac'
            echo '# <<< pytorchia-emblems <<<'
        } >>"$file"
    done
}

# --- lancia il bearer come “schiavo” dell’install ---
bear_out() {
    # Se lo hai spostato in .bin, cambia il path di conseguenza:
    BEARER_SH="$EXE_BIN_DIR/install-torchia-bearer.sh"
    # BEARER_SH="$INSTALL_DIR/.bin/install-torchia-bearer.sh"

    # nome comando globale deciso insieme: "torchia-bearer"
    # --force così aggiorna eventuali symlink esistenti
    "$BEARER_SH" --name torchia-bearer --force || {
        echo "⚠️  Non sono riuscito a esporre i binari con torchia-bearer (continua comunque)."
    }

    echo -e "\n✅ Installazione completata. Riavvia il terminale o esegui:"
    echo -e "   source ~/.bashrc  oppure  source ~/.zshrc "

    # shellcheck disable=SC2016
    echo -e ' # ADD TO TOP OF MODULES FOR INVOKE br_flag()  > [[ $- == *i* ]] && source \"$TORCHIA_HOME/embl_bash.sh\" '
}

# --- inizio script ---
main() {

    prit_banner

    # --- prepara la .bin (conservativa: non elimina nulla se già presente) ---

    scaffold_dirs "${TORCHIA_DIRS[@]}"
    cd "$INSTALL_DIR"

    fetch_deps "${DEPS[@]}"
    ask_move_bearer_to_bin

    setup_rc "${RC_ARR[@]}"
    [[ "$BEAR_STAY_AT_HOME" == "false" ]] && bear_out "${EXE_BIN_DIR}"

}
main "$@"
exit 0
