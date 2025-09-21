#!/usr/bin/env bash
set -euo pipefail
SYNC_VERSION="2.0.1"
# --------------------------------------------------------
# Script: sync_readme.sh
# Descrizione: Aggiorna il README.md con la versione corrente
# Legge la versione da embl_bash.sh e aggiorna il README.md e install.sh
# --------------------------------------------------------
# CONFIG
# --------------------------------------------------------
# -------------------------------------------------------------------
# sync_readme.sh (enhanced)
# - Legge .env -> BR_VERSION
# - Se passi una nuova versione come 1° arg ed è maggiore, aggiorna:
#   .env, embl_bash.sh, install.sh, README.md (link release)
# - ANSI, semver-compare, commit/push opzionale
# -------------------------------------------------------------------

# Config repo
REPO_BASEPATH="${REPO_BASEPATH:-$HOME/Documents/GitHub/pytorchia_home}"
VERSION_FILE="$REPO_BASEPATH/embl_bash.sh"
README_FILE="$REPO_BASEPATH/README.md"
INSTALL_FILE="$REPO_BASEPATH/install.sh"
ENV_FILE="$REPO_BASEPATH/.env"

REPO_REL_PREFIX="https://github.com/fgirolami29/pytorchia_home/releases/download/v"

# --------------------------------------------------------
# ANSI COLORS
# --------------------------------------------------------
BOLD="\033[1m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BRED="\033[1;31m"
ITALIC="\033[3m"
NC="\033[0m" # Reset color
OK="✅"
WARN="⚠️"
ERR="❌"
SYNC="🔄"
DL="⬇️"
PEN="✍️"
ROCKET="🚀"

# --------------------------------------------------------
# Helpers
# --------------------------------------------------------
die() {
    echo -e "${BRED}${ERR} $*${NC}"
    exit 1
}
info() { echo -e "${CYAN}${SYNC} ${ITALIC}$*${NC}"; }
ok() { echo -e "${GREEN}${OK} $*${NC}"; }
warn() { echo -e "${YELLOW}${WARN} $*${NC}"; }

# semver_compare a b -> echo -1/0/1
semver_compare() {
    local A="$1" B="$2"
    # normalizza (x.y.z)
    IFS=. read -r a1 a2 a3 <<<"${A//[!0-9.]/}"
    IFS=. read -r b1 b2 b3 <<<"${B//[!0-9.]/}"
    a1=${a1:-0}
    a2=${a2:-0}
    a3=${a3:-0}
    b1=${b1:-0}
    b2=${b2:-0}
    b3=${b3:-0}
    ((a1 < b1)) && {
        echo -1
        return
    }
    ((a1 > b1)) && {
        echo 1
        return
    }
    ((a2 < b2)) && {
        echo -1
        return
    }
    ((a2 > b2)) && {
        echo 1
        return
    }
    ((a3 < b3)) && {
        echo -1
        return
    }
    ((a3 > b3)) && {
        echo 1
        return
    }
    echo 0
}

get_version_from_env() {
    [[ -f "$ENV_FILE" ]] || {
        echo ""
        return
    }
    grep -E '^\s*BR_VERSION=' "$ENV_FILE" | tail -1 | sed -E 's/^\s*BR_VERSION\s*=\s*"?([^"#]+)"?.*/\1/'
}

set_version_in_env() {
    local ver="$1"
    if [[ -f "$ENV_FILE" ]]; then
        if grep -qE '^\s*BR_VERSION=' "$ENV_FILE"; then
            sed -i.bak -E "s|^\s*BR_VERSION\s*=.*|BR_VERSION=\"$ver\"|" "$ENV_FILE"
        else
            echo "BR_VERSION=\"$ver\"" >>"$ENV_FILE"
        fi
    else
        echo "BR_VERSION=\"$ver\"" >"$ENV_FILE"
    fi
    ok ".env: BR_VERSION=$ver"
}

get_version_from_embl() {
    grep 'BR_VERSION="' "$VERSION_FILE" | sed -E 's/.*BR_VERSION="([^"]*)".*/\1/'
}

set_version_in_embl() {
    local ver="$1"
    if grep -q 'BR_VERSION="' "$VERSION_FILE"; then
        sed -i.bak -E "s|^BR_VERSION=\"[^\"]*\"|BR_VERSION=\"$ver\"|" "$VERSION_FILE"
        ok "embl_bash.sh: BR_VERSION=$ver"
    else
        warn "embl_bash.sh: BR_VERSION non trovato (nessuna modifica)"
    fi
}

set_version_in_install() {
    local ver="$1"
    if grep -q 'BR_VERSION=' "$INSTALL_FILE"; then
        sed -i.bak -E "s|^BR_VERSION=\"[^\"]*\"|BR_VERSION=\"$ver\"|" "$INSTALL_FILE"
        ok "install.sh: BR_VERSION=$ver"
    else
        warn "install.sh: BR_VERSION non trovata (nessuna modifica)"
    fi
}

update_readme_links() {
    local ver="$1"
    sed -i.bak -E "
s#bash <\\(curl -sSfL ${REPO_REL_PREFIX}[0-9]+\.[0-9]+\.[0-9]+/install\.sh\\)#bash <(curl -sSfL ${REPO_REL_PREFIX}${ver}/install.sh)#g
s#wget -qO- ${REPO_REL_PREFIX}[0-9]+\.[0-9]+\.[0-9]+/install\.sh \| bash#wget -qO- ${REPO_REL_PREFIX}${ver}/install.sh | bash#g
" "$README_FILE"
    ok "README.md: link aggiornati a v${ver}"
}

# --------------------------------------------------------
# Flow
# --------------------------------------------------------
# Versioni “sorgente”
ENV_VER="$(get_version_from_env || true)"
EMBL_VER="$(get_version_from_embl || true)"

if [[ -z "${EMBL_VER:-}" ]]; then
    die "$VERSION_FILE non contiene una versione valida (BR_VERSION=\"x.y.z\")."
fi

echo -e "📦 Versione corrente da ${BOLD}embl_bash.sh${NC}: ${GREEN}${EMBL_VER}${NC}"
[[ -n "${ENV_VER:-}" ]] && echo -e "🧩 Versione da ${BOLD}.env${NC}: ${GREEN}${ENV_VER}${NC}"

# Versione target (CLI > .env > embl)
TARGET_VER="${1:-}"
if [[ -z "$TARGET_VER" ]]; then
    # se non viene passata, prova da .env; altrimenti chiedi conferma su EMBL
    if [[ -n "${ENV_VER:-}" ]]; then
        TARGET_VER="$ENV_VER"
        info "Uso versione da .env: ${TARGET_VER}"
    else
        echo -en "${ITALIC}✅ Confermi sync README/install con versione ${BOLD}${EMBL_VER}${NC}${ITALIC}? [y/N] ${NC}"
        read -r confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || {
            echo -e "${ERR} Annullato."
            exit 0
        }
        TARGET_VER="$EMBL_VER"
    fi
else
    # è stata passata una nuova versione: deve essere > EMBL_VER
    cmp="$(semver_compare "$EMBL_VER" "$TARGET_VER")"
    if [[ "$cmp" -ge 0 ]]; then
        die "La nuova versione (${TARGET_VER}) non è maggiore della corrente (${EMBL_VER})."
    fi
    ok "Nuova versione accettata: ${TARGET_VER} (>${EMBL_VER})"
fi


# Aggiorna file a TARGET_VER
update_readme_links "$TARGET_VER"
set_version_in_install "$TARGET_VER"
set_version_in_embl "$TARGET_VER"
set_version_in_env "$TARGET_VER"

# --------------------------------------------------------
# COMMIT & PUSH (opzionale)
# --------------------------------------------------------
cd "$REPO_BASEPATH" || exit 1

# Helpers per stato working tree
git_has_unstaged() { ! git diff --quiet; }
git_has_staged() { ! git diff --cached --quiet; }

echo -en "🔄 Vuoi eseguire un 'git pull --rebase' prima del commit? [y/N] "
read -r pull_first
if [[ "$pull_first" =~ ^[Yy]$ ]]; then
    info "Controllo stato working tree…"
    if git_has_unstaged || git_has_staged; then
        warn "Hai modifiche locali non pulite."
        echo -en "➤ Uso ${BOLD}--autostash${NC} per procedere in sicurezza? [Y/n] "
        read -r use_autostash
        if [[ ! "$use_autostash" =~ ^[Nn]$ ]]; then
            info "git pull --rebase --autostash…"
            if ! git pull --rebase --autostash; then
                die "Errore durante il pull --autostash: risolvi i conflitti e riprova."
            fi
        else
            echo -e "Scegli un'azione:
  1) Stash automatico (git stash -u; pull --rebase; stash pop)
  2) Commit adesso (add + commit 'wip'; pull --rebase)
  3) Annulla"
            read -rp "Selezione [1/2/3]: " choice
            case "$choice" in
            1)
                info "git stash -u; pull --rebase; stash pop…"
                git stash -u || die "stash fallito"
                if git pull --rebase; then
                    git stash pop || warn "Niente da poppare o conflitti durante pop."
                else
                    warn "Pull fallito. Lo stash è rimasto salvato (usa 'git stash list')."
                    exit 1
                fi
                ;;
            2)
                info "Eseguo add+commit (wip) e poi pull --rebase…"
                git add -A
                git commit -m "wip: prima del rebase" || true
                git pull --rebase || die "Errore durante il pull --rebase."
                ;;
            *)
                die "Pull annullato su richiesta."
                ;;
            esac
        fi
    else
        info "Working tree pulito. Eseguo pull --rebase…"
        git pull --rebase || die "Errore durante il pull: risolvi i conflitti e riprova."
    fi
fi

# Ora verifica modifiche e proponi commit
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -en "📝 Modifiche rilevate. Procedo con commit automatico? [y/N] "
    read -r do_commit
    if [[ "$do_commit" =~ ^[Yy]$ ]]; then
        git add --all ':!*.bak' 2>/dev/null || true
        git commit -m "🔄 sync: README & versions -> v${TARGET_VER}"
        ok "Commit effettuato."
        echo -en "📤 Vuoi fare anche il push su GitHub? [y/N] "
        read -r do_push
        if [[ "$do_push" =~ ^[Yy]$ ]]; then
            git push || die "Errore nel push (credenziali/conflitti?)."
            echo -e "${ROCKET} ${BOLD}Push completato con successo!${NC}"
        else
            warn "Push annullato su richiesta."
        fi
    else
        warn "Commit annullato su richiesta."
    fi
else
    ok "Nessuna modifica da committare."
fi
