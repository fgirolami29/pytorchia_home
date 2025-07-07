#!/bin/bash
set -euo pipefail

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

# --------------------------------------------------------
# CONFIG
# --------------------------------------------------------
REPO_BASEPATH="$HOME/Documents/GitHub/pytorchia_home"
VERSION_FILE="$REPO_BASEPATH/embl_bash.sh"
README_SYNC_SCRIPT="$REPO_BASEPATH/build_tools/sync_readme.sh"
ZIP_NAME="emblems.zip"
RELEASE_TITLE="PyTorchia™ Tools"

# Estrai versione corrente
VERSION=$(grep 'BR_VERSION="' "$VERSION_FILE" | sed -E 's/.*BR_VERSION="([^"]*)".*/\1/')
RELEASE_DIR="$REPO_BASEPATH/release/v$VERSION"

# --------------------------------------------------------
# SYNC README
# --------------------------------------------------------
if [[ -x "$README_SYNC_SCRIPT" ]]; then
    echo -e "🔄 ${CYAN}Sync README.md...${NC}"
    "$README_SYNC_SCRIPT"
else
    echo -e "⚠️  ${YELLOW}ATTENZIONE:${NC} script ${BOLD}$README_SYNC_SCRIPT${NC} non trovato o non eseguibile"
    read -rp "👉 Procedere comunque? [y/N] " cont
    [[ "$cont" =~ ^[Yy]$ ]] || exit 1
fi

# --------------------------------------------------------
# CONFERMA
# --------------------------------------------------------
echo -e "\n📦 Versione da rilasciare: ${GREEN}$VERSION${NC}"
read -rp "✅ Procedere con la creazione della release locale? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

# --------------------------------------------------------
# PREPARA CARTELLA RELEASE
# --------------------------------------------------------
echo -e "🧹 ${CYAN}Pulizia e setup cartella:${NC} $RELEASE_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# --------------------------------------------------------
# CREA ZIP DEI BANNER
# --------------------------------------------------------
if compgen -G "$REPO_BASEPATH/.embl*" >/dev/null; then
    echo -e "📦 ${CYAN}Creazione archivio${NC} $ZIP_NAME"
    zip -q -j "$RELEASE_DIR/$ZIP_NAME" "$REPO_BASEPATH"/.embl*
else
    echo -e "❌ ${RED}Nessun file .embl* trovato per lo zip${NC}"
    exit 1
fi

# --------------------------------------------------------
# COPIA FILE CORE
# --------------------------------------------------------
echo -e "📥 ${CYAN}Copia file:${NC} install.sh, embl_bash.sh"
cp "$REPO_BASEPATH/install.sh" "$REPO_BASEPATH/embl_bash.sh" "$RELEASE_DIR/"

# --------------------------------------------------------
# INFO COMPLETAMENTO LOCALE
# --------------------------------------------------------
echo -e "\n✅ ${CYAN}Release folder pronta:${NC} ${BOLD}$RELEASE_DIR${NC}"

# --------------------------------------------------------
# CHIEDI PUBBLICAZIONE GITHUB
# --------------------------------------------------------
read -rp "📤 Pubblicare la release su GitHub? [y/N] " confirm_gh
if [[ ! "$confirm_gh" =~ ^[Yy]$ ]]; then
    echo -e "\n📤 ${ITALIC}Per pubblicare manualmente su GitHub:${NC}\n"
    echo -e "   ${ITALIC}gh release create v$VERSION $RELEASE_DIR/* -t \"v$VERSION\" -n \"$RELEASE_TITLE v$VERSION\"${NC}"
    exit 0
fi

# --------------------------------------------------------
# VERIFICA gh CLI
# --------------------------------------------------------
# --------------------------------------------------------
# VERIFICA gh CLI E LOGIN
# --------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
    echo -e "⚠️  ${YELLOW}GitHub CLI (gh) non trovato. Procedo all'installazione...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install gh -y
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gh || {
            echo -e "❌ ${RED}brew non disponibile. Installa gh manualmente da https://cli.github.com${NC}"
            exit 1
        }
    else
        echo -e "❌ ${RED}Sistema operativo non supportato per installazione automatica.${NC}"
        exit 1
    fi
fi

# Verifica autenticazione GitHub
if ! gh auth status >/dev/null 2>&1; then
    echo -e "🔐 ${YELLOW}Non risulti autenticato su GitHub.${NC}"
    read -rp "👉 Vuoi autenticarti ora con \`gh auth login\`? [Y/n] " login_confirm
    if [[ ! "$login_confirm" =~ ^[Nn]$ ]]; then
        gh auth login || {
            echo -e "❌ ${RED}Login fallito. Verifica le credenziali o usa GH_TOKEN.${NC}"
            exit 1
        }
    else
        echo -e "❌ ${RED}Login GitHub necessario per pubblicare la release.${NC}"
        exit 1
    fi
fi


# --------------------------------------------------------
# PUBBLICAZIONE GITHUB
# --------------------------------------------------------
echo -e "\n🚀 ${GREEN}Pubblicazione release su GitHub...${NC}"
gh release create "v$VERSION" "$RELEASE_DIR"/* \
    -t "v$VERSION" \
    -n "$RELEASE_TITLE v$VERSION"

echo -e "\n✅ ${GREEN}Release v$VERSION pubblicata con successo!${NC}"
