#!/usr/bin/env bash
set -euo pipefail

# colori
g() { printf "\033[32m%s\033[0m\n" "$*"; }
y() { printf "\033[33m%s\033[0m\n" "$*"; }
r() { printf "\033[31m%s\033[0m\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null || {
  r "Manca $1"
  exit 1
}; }
need_cmd mdutil
need_cmd find
need_cmd awk
need_cmd sort

reload_spotlight() {
  sudo killall -HUP mds mdworker_shared mds_stores 2>/dev/null || true
  y "Reload Spotlight inviato. Stato volumi:"
  mdutil -a -s || true
}

normalize_path() {
  local p="$1"
  [[ "$p" == "$HOME"* ]] && p="${HOME}/${p#~/}"
  p="${p%\"}"
  p="${p#\"}"
  p="${p%\'}"
  p="${p#\'}"
  printf "%b" "${p//\\ /\\x20}"
}

exclude_dir() {
  local dir
  dir="$(normalize_path "$1")"
  if [[ ! -d "$dir" ]]; then
    r "Cartella non trovata: $dir"
    return 1
  fi
  sudo touch "$dir/.metadata_never_index"
  sudo chflags hidden "$dir/.metadata_never_index" || true
  g "ESCLUSO da Spotlight: $dir"
}

revert_dir() {
  local dir
  dir="$(normalize_path "$1")"
  if [[ -f "$dir/.metadata_never_index" ]]; then
    sudo rm -f "$dir/.metadata_never_index"
    g "RIABILITATO in Spotlight: $dir"
  else
    y "Nessun marker da rimuovere in: $dir"
  fi
}

scan_dev_dirs() {
  local roots=("$HOME/GitHub" "$HOME/Documents/GitHub" "$HOME/Projects" "$HOME/Dev" "$HOME/Desktop")
  read -r -p "Root extra da scansionare per node_modules (INVIO per nessuno): " extra || true
  [[ -n "${extra:-}" ]] && roots+=("$(normalize_path "$extra")")

  # candidati “noti” e pesanti
  local candidates=(
    "$HOME/Library/Developer/Xcode/DerivedData"
    "$HOME/Library/Developer/Xcode/Archives"
    "$HOME/Library/Developer/CoreSimulator"
    "$HOME/go/pkg/mod"
  )

  # aggiungi tutti i node_modules trovati sotto le roots
  local rpath
  for rpath in "${roots[@]}"; do
    [[ -d "$rpath" ]] || continue
    while IFS= read -r nm; do
      candidates+=("$nm")
    done < <(find "$rpath" -type d -name node_modules -prune -print 2>/dev/null)
  done

  # prepara lista unica in un file temporaneo (compat con bash 3.2)
  local listfile
  listfile="/tmp/spotlight_candidates_$(date +%s).lst"
  printf "%s\n" "${candidates[@]}" | awk 'NF' | sort -u >"$listfile"

  local count
  count=$(wc -l <"$listfile" | tr -d ' ')
  if [[ "$count" -eq 0 ]]; then
    rm -f "$listfile"
    y "Nessuna cartella dev trovata."
    return 0
  fi

  echo "Trovate $count cartelle:"
  sed 's/^/ - /' "$listfile"

  read -r -p "Procedo ad ESCLUDERLE tutte? [y/N] " ok
  case "$ok" in
  y | Y)
    local done=0 d
    while IFS= read -r d; do
      [[ -d "$d" ]] || continue
      sudo touch "$d/.metadata_never_index" && sudo chflags hidden "$d/.metadata_never_index" || true
      ((done++))
    done <"$listfile"
    g "Escluse $done cartelle."
    ;;
  *) y "Annullato." ;;
  esac

  rm -f "$listfile"
}

menu() {
  cat <<'M'
================ Spotlight Helper ================
1) Escludi una cartella (ricorsiva, incluse tutte le subdir)
2) Revert: riabilita una cartella precedentemente esclusa
3) Scansiona ed ESCLUDI cartelle da dev (DerivedData, go/pkg/mod, tutti i node_modules trovati)
q) Esci
M
}

main() {
  sudo -v || true
  while true; do
    menu
    read -r -p "Scelta: " c || exit 0
    case "$c" in
    1)
      read -r -p "Percorso cartella da ESCLUDERE: " p
      exclude_dir "$p"
      reload_spotlight
      ;;
    2)
      read -r -p "Percorso cartella da RIABILITARE: " p
      revert_dir "$p"
      reload_spotlight
      ;;
    3)
      scan_dev_dirs
      reload_spotlight
      ;;
    q | Q) exit 0 ;;
    *) y "Scelta non valida." ;;
    esac
  done
}
main
