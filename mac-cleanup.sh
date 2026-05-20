#!/usr/bin/env bash
# mac-cleanup.sh — nettoyage hebdomadaire macOS
# Usage : mac-cleanup.sh [--dry-run]

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
DEV_DIR="$HOME/dev"
LOG_DIR="$HOME/.local/share/mac-cleanup"
INACTIVITY_DAYS=30
DRY_RUN=false

# ─── Flags ───────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
  esac
done

# ─── Init logs ───────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
if $DRY_RUN; then
  LOG_FILE="$LOG_DIR/dry-run_$TIMESTAMP.log"
else
  LOG_FILE="$LOG_DIR/cleanup_$TIMESTAMP.log"
fi

TOTAL_FREED=0

# ─── Helpers ─────────────────────────────────────────────────────────────────
log() {
  echo "$1" | tee -a "$LOG_FILE"
}

# Retourne la taille en octets d'un dossier (0 si inexistant)
dir_size_bytes() {
  local path="$1"
  if [ -d "$path" ]; then
    du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}'
  else
    echo 0
  fi
}

# Formate des octets en unité lisible
human_size() {
  local bytes=$1
  if   [ "$bytes" -ge 1073741824 ]; then printf "%.1f Go" "$(echo "scale=1; $bytes/1073741824" | bc)"
  elif [ "$bytes" -ge 1048576 ];    then printf "%.1f Mo" "$(echo "scale=1; $bytes/1048576" | bc)"
  elif [ "$bytes" -ge 1024 ];       then printf "%.1f Ko" "$(echo "scale=1; $bytes/1024" | bc)"
  else printf "%d o" "$bytes"
  fi
}

# Supprime (ou simule) un dossier et comptabilise
remove_dir() {
  local path="$1"
  local label="$2"

  if [ ! -d "$path" ]; then
    return
  fi

  local size
  size=$(dir_size_bytes "$path")
  local human
  human=$(human_size "$size")

  if $DRY_RUN; then
    log "  [DRY-RUN] Supprimerait : $label ($human)"
  else
    rm -rf "$path"
    log "  ✓ Supprimé : $label ($human)"
    TOTAL_FREED=$((TOTAL_FREED + size))
  fi
}

# Vérifie si le dossier projet (parent) est inactif depuis N jours
is_project_inactive() {
  local project_root="$1"
  # date de dernière modif du projet (fichiers à la racine, hors .git)
  local last_modified
  last_modified=$(find "$project_root" -maxdepth 2 -not -path "*/.git/*" \
    -newer "$project_root" -print -quit 2>/dev/null | wc -l)
  # si rien de plus récent que le dossier lui-même depuis INACTIVITY_DAYS
  local ref_date
  ref_date=$(date -v-${INACTIVITY_DAYS}d +%s 2>/dev/null || \
             date -d "${INACTIVITY_DAYS} days ago" +%s 2>/dev/null)
  local mod_date
  mod_date=$(stat -f "%m" "$project_root" 2>/dev/null || \
             stat -c "%Y" "$project_root" 2>/dev/null)
  [ "$mod_date" -lt "$ref_date" ]
}

# ─── Début du rapport ─────────────────────────────────────────────────────────
log "═══════════════════════════════════════════════════════"
if $DRY_RUN; then
  log "  mac-cleanup — DRY RUN — $(date '+%d/%m/%Y %H:%M')"
else
  log "  mac-cleanup — $(date '+%d/%m/%Y %H:%M')"
fi
log "═══════════════════════════════════════════════════════"

# ─── 1. Nettoyages inconditionnels ───────────────────────────────────────────
log ""
log "── Nettoyages inconditionnels ──────────────────────────"

# Chrome OptGuideOnDeviceModel (modèle Gemini Nano embarqué)
remove_dir \
  "$HOME/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel" \
  "Chrome OptGuideOnDeviceModel"

# Claude vm_bundles (VM Claude in Chrome — recréée à la demande)
remove_dir \
  "$HOME/Library/Application Support/Claude/vm_bundles" \
  "Claude vm_bundles"

# Claude Cache
remove_dir \
  "$HOME/Library/Application Support/Claude/Cache" \
  "Claude Cache"

# Homebrew
if command -v brew &>/dev/null; then
  if $DRY_RUN; then
    log "  [DRY-RUN] Exécuterait : brew cleanup --prune=all"
  else
    log "  → brew cleanup..."
    brew_before=$(df / | awk 'NR==2 {print $3}')
    brew cleanup --prune=all >> "$LOG_FILE" 2>&1 || true
    brew_after=$(df / | awk 'NR==2 {print $3}')
    brew_freed=$(( (brew_after - brew_before) * 512 ))
    [ "$brew_freed" -lt 0 ] && brew_freed=0
    TOTAL_FREED=$((TOTAL_FREED + brew_freed))
    log "  ✓ brew cleanup ($(human_size $brew_freed) récupérés)"
  fi
fi

# Go build cache
if command -v go &>/dev/null; then
  if $DRY_RUN; then
    go_size=$(dir_size_bytes "$HOME/Library/Caches/go-build")
    log "  [DRY-RUN] Supprimerait : Go build cache ($(human_size $go_size))"
  else
    go_size=$(dir_size_bytes "$HOME/Library/Caches/go-build")
    go clean -cache 2>/dev/null || true
    log "  ✓ Go build cache (~$(human_size $go_size))"
    TOTAL_FREED=$((TOTAL_FREED + go_size))
  fi
fi

# pip cache
if command -v pip3 &>/dev/null; then
  if $DRY_RUN; then
    pip_size=$(dir_size_bytes "$HOME/Library/Caches/pip")
    log "  [DRY-RUN] Supprimerait : pip cache ($(human_size $pip_size))"
  else
    pip_size=$(dir_size_bytes "$HOME/Library/Caches/pip")
    pip3 cache purge >> "$LOG_FILE" 2>&1 || true
    log "  ✓ pip cache (~$(human_size $pip_size))"
    TOTAL_FREED=$((TOTAL_FREED + pip_size))
  fi
fi

# Docker — containers stoppés, réseaux orphelins, build cache dangling
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  if $DRY_RUN; then
    log "  [DRY-RUN] Exécuterait : docker system prune -f (sans -a)"
  else
    log "  → docker system prune..."
    docker_output=$(docker system prune -f 2>&1 || true)
    docker_freed=$(echo "$docker_output" | grep "Total reclaimed" | grep -oE '[0-9]+(\.[0-9]+)? [kKmMgGtT]?B' | tail -1 || true)
    echo "$docker_output" >> "$LOG_FILE"
    log "  ✓ Docker prune (${docker_freed:-0 o} récupérés)"
  fi
fi

# ─── 2. Nettoyages conditionnels (inactivité 30j) ────────────────────────────
log ""
log "── node_modules inactifs (>${INACTIVITY_DAYS}j) ────────────────────────"

while IFS= read -r nm_path; do
  project_root=$(echo "$nm_path" | sed 's|/node_modules||')
  if is_project_inactive "$project_root"; then
    remove_dir "$nm_path" "node_modules @ ${project_root#$HOME/dev/}"
  else
    log "  ○ Actif, ignoré : ${project_root#$HOME/dev/}/node_modules"
  fi
done < <(find "$DEV_DIR" -name "node_modules" -type d -prune 2>/dev/null)

log ""
log "── Rust target/ inactifs (>${INACTIVITY_DAYS}j) ─────────────────────────"

while IFS= read -r target_path; do
  # Remonte jusqu'au dossier projet (parent du src-tauri ou direct)
  project_root=$(dirname "$target_path")
  # Si le parent s'appelle src-tauri, on remonte encore
  if [ "$(basename "$project_root")" = "src-tauri" ]; then
    project_root=$(dirname "$project_root")
  fi
  if is_project_inactive "$project_root"; then
    remove_dir "$target_path" "target/ @ ${project_root#$HOME/dev/}"
  else
    log "  ○ Actif, ignoré : ${project_root#$HOME/dev/}/target"
  fi
done < <(find "$DEV_DIR" -name "target" -type d -prune 2>/dev/null)

# ─── 3. Résumé ───────────────────────────────────────────────────────────────
log ""
log "═══════════════════════════════════════════════════════"
if $DRY_RUN; then
  log "  DRY RUN terminé — rien n'a été supprimé"
else
  log "  Total récupéré : $(human_size $TOTAL_FREED)"
  log "  Log complet    : $LOG_FILE"
fi
log "  Espace disque  : $(df -h / | awk 'NR==2 {print $4}') disponibles"
log "═══════════════════════════════════════════════════════"

# Notification macOS
if $DRY_RUN; then
  osascript -e "display notification \"Simulation terminée — rien supprimé\" with title \"mac-cleanup [dry-run]\" sound name \"Glass\""
else
  osascript -e "display notification \"$(human_size $TOTAL_FREED) récupérés\" with title \"mac-cleanup ✓\" sound name \"Glass\""
fi

# Rotation des logs — garde les 10 derniers
ls -t "$LOG_DIR"/*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
