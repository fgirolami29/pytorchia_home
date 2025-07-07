#!/bin/bash
set -e
BR_VERSION="1.5.2"
AUTHOR="fgirolami29"
MODULE_NAME="TORCHIA_HOME"

REPO_URL="https://github.com/fgirolami29/pytorchia_home"
INSTALL_DIR="$HOME/.pytorchia"
RAW_URL="https://github.com/fgirolami29/pytorchia_home/releases/download/v$BR_VERSION"

echo -e "📦 MODULE: $MODULE_NAME - AUTHOR: $AUTHOR VERSION: V$BR_VERSION\n REPO_URL: $REPO_URL \n"
echo -e "📦 Installazione PyTorchia home da repo ufficiale..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Scarica i file essenziali
for file in embl_bash.sh emblems.zip; do
    echo "⬇️  Download $file..."
    curl -sSfL "$RAW_URL/$file" -o "$file" || {
        echo "❌ Errore nel download di $file"
        exit 1
    }

    if [[ "$file" == "embl_bash.sh" ]]; then
        chmod +x "$file"
    elif [[ "$file" == "emblems.zip" ]]; then
        unzip -o "$file" -d . || {
            echo "❌ Errore nell'estrazione di $file"
            exit 1
        }
        rm "$file"
    fi
done

# Setup in .bashrc/.zshrc
for rc in .bashrc .zshrc; do
    file="$HOME/$rc"
    [[ -f "$file" ]] || touch "$file"

    # Rimuove vecchie definizioni
    sed -i '/^[^#]*TORCHIA_HOME=/d' "$file"
    sed -i '/^[^#]*source .*embl_bash\.sh/d' "$file"

    # Inserisce sempre in fondo
    echo "export TORCHIA_HOME=\"$INSTALL_DIR\"" >> "$file"
    # shellcheck disable=SC2016
    echo '[[ $- == *i* ]] && source "$TORCHIA_HOME/embl_bash.sh"' >> "$file"
done


echo -e "\n✅ Installazione completata. Riavvia il terminale o esegui:"
echo -e "   source ~/.bashrc  oppure  source ~/.zshrc "

# shellcheck disable=SC2016
echo -e ' # ADD TO TOP OF MODULES FOR INVOKE br_flag()  > [[ $- == *i* ]] && source \"$PYTORCHIA_HOME/embl_bash.sh\" '
