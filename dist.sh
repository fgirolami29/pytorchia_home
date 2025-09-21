#!/bin/bash
set -euo pipefail
# --------------------------------------------------------
# COLORI OUTPUT
# --------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
# --------------------------------------------------------
# VARIABILI
# --------------------------------------------------------
EXIT_CODE=0
REPO_BASEPATH=$(pwd)
RELEASE_DIR="$REPO_BASEPATH/release"
# --------------------------------------------------------
# PULIZIA CARTELLA RELEASE
# --------------------------------------------------------
if [ -d "$RELEASE_DIR" ]; then
    echo -e "🧹 ${YELLOW}Pulizia cartella release...${RELEASE_DIR}${NC}"
    rm -rf "$RELEASE_DIR"
fi
mkdir -p "$RELEASE_DIR"
# --------------------------------------------------------
# SINCRONIZZA README E VERSIONE
# EXAMPLE: $ ./build_tools/sync_readme.sh 1.5.5
# --------------------------------------------------------
echo -e "🔄 ${CYAN}Sincronizzazione README e versione...${NC}"
./build_tools/sync_readme.sh "$@" || EXIT_CODE=$?
if [ "${EXIT_CODE:-0}" -ne 0 ]; then
    echo "Errore durante la sincronizzazione del README. Codice di uscita: ${EXIT_CODE}"
    exit "${EXIT_CODE}"
fi
echo -e "✅ ${GREEN}README e versione sincronizzati con successo!${NC}"

# --------------------------------------------------------
# COPIA FILE CORE
# --------------------------------------------------------
#echo -e "📥 ${CYAN}Copia file:${NC} install.sh
build_tools/make_release.sh || EXIT_CODE=$?
if [ "${EXIT_CODE:-0}" -ne 0 ]; then
    echo "Errore durante la copia dei file. Codice di uscita: ${EXIT_CODE}"
    exit "${EXIT_CODE}"
fi
echo -e "✅ ${GREEN}File copiati con successo!${NC}"
# --------------------------------------------------------