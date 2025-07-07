#!/bin/bash

# Legge la versione da embl_bash.sh e aggiorna il README.md
REPO_BASEPATH="$HOME/Documents/GitHub/pytorchia_home"

VERSION_FILE="$REPO_BASEPATH/embl_bash.sh"
README_FILE="$REPO_BASEPATH/README.md"
INSTALL_FILE="$REPO_BASEPATH/install.sh"
REPO_REL_PREFIX="https://github.com/fgirolami29/pytorchia_home/releases/download/v"
# --------------------------------------------------------
# ANSI COLORS
# --------------------------------------------------------
BOLD="\033[1m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
ITALIC="\033[3m"
NC="\033[0m" # Reset color

# Estrai la versione da embl_bash.sh in modo portabile
BR_VERSION=$(grep 'BR_VERSION="' "$VERSION_FILE" | sed 's/.*BR_VERSION="\([^"]*\)".*/\1/')

if [[ -z "$BR_VERSION" ]]; then
    echo -e "❌ ${VERSION_FILE} non contiene una versione valida. Inseriscila come: BR_VERSION=\"1.0.0\""
    not_found=$(echo -e "${BOLD}👉 Inserisci una versione manualmente: ${NC}")
    read -rp "$not_found" BR_VERSION
fi

echo -e "${CYAN}📦 Versione trovata: ${NC}${GREEN}$BR_VERSION${NC}"
version_found=$(echo -e "${ITALIC}✅ Confermi l’aggiornamento del README.md con questa versione? [y/N] ${NC}")

read -rp "$version_found" confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "✍️  Scrittura $README_FILE..."

    # 📌 Aggiorna versioni hardcoded in README.md
    sed -i.bak -E "
s#bash <\\(curl -sSfL ${REPO_REL_PREFIX}[0-9]+\.[0-9]+\.[0-9]+/install\.sh\\)#bash <(curl -sSfL ${REPO_REL_PREFIX}${BR_VERSION}/install.sh)#g
s#wget -qO- ${REPO_REL_PREFIX}[0-9]+\.[0-9]+\.[0-9]+/install\.sh \| bash#wget -qO- ${REPO_REL_PREFIX}${BR_VERSION}/install.sh | bash#g
" "$README_FILE"

else
    echo "❌ Annullato."
fi

# Cerca e aggiorna la riga che definisce BR_VERSION in install.sh
if grep -q 'BR_VERSION=' "$INSTALL_FILE"; then
    sed -i.bak "s/^BR_VERSION=\"[^\"]*\"/BR_VERSION=\"$BR_VERSION\"/" "$INSTALL_FILE"
    echo -e "🔁 install.sh: aggiornata riga BR_VERSION a ${GREEN}$BR_VERSION${NC}"
else
    echo -e "⚠️  BR_VERSION non trovata in install.sh — nessuna modifica effettuata."
fi

# --------------------------------------------------------
# COMMIT & PUSH AUTOMATICO POST SYNC (se ci sono modifiche)
# --------------------------------------------------------
cd "$REPO_BASEPATH" || exit 1

# Facoltativo: aggiornamento branch locale
read -rp "🔄 Vuoi eseguire un 'git pull --rebase' prima del commit? [y/N] " pull_first
if [[ "$pull_first" =~ ^[Yy]$ ]]; then
    echo -e "📥 Eseguo git pull --rebase..."
    git pull --rebase || {
        echo -e "❌ ${RED}Errore durante il pull. Risolvi i conflitti prima di procedere.${NC}"
        exit 1
    }
fi

# Verifica modifiche non committate
if ! git diff --quiet; then
    echo -e "📝 ${YELLOW}Modifiche rilevate nei file. Vuoi procedere col commit?${NC}"
    read -rp "✅ Procedere con commit automatico di README.md, embl_bash.sh, install.sh? [y/N] " do_commit
    if [[ "$do_commit" =~ ^[Yy]$ ]]; then
        #git add README.md embl_bash.sh install.sh 2>/dev/null || true
        git add --all ':!*.bak' 2>/dev/null || true

        git commit -m "🔄 sync: aggiornato README e versioni per v$VERSION"
        echo -e "✅ ${GREEN}Commit effettuato con successo.${NC}"

        # Chiedi se pushare
        read -rp "📤 Vuoi fare anche il push su GitHub? [y/N] " do_push
        if [[ "$do_push" =~ ^[Yy]$ ]]; then
            git push || {
                echo -e "❌ ${RED}Errore nel push. Verifica le credenziali o conflitti remoti.${NC}"
                exit 1
            }
            echo -e "🚀 ${BOLD_GREEN}Push completato con successo!${NC}"
        else
            echo -e "📌 ${YELLOW}Push annullato su richiesta.${NC}"
        fi
    else
        echo -e "📌 ${YELLOW}Commit annullato su richiesta.${NC}"
    fi
else
    echo -e "✅ ${GREEN}Nessuna modifica da committare.${NC}"
fi
