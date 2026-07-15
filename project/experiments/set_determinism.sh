#!/usr/bin/env bash
# set_determinism.sh — schaltet nicht-invasiven Laufzeit-Determinismus auf dem
# Proxmox-Host. KEINE BIOS-/Bootloader-Änderung, reversibel, ohne Reboot.
# Läuft auf dem CONTROL-NODE, wirkt via SSH auf HOST_HOST (aus config.env).
#
# Hebel:
#   1. Kerntakt der Mess-Kerne (DET_CORES, Default "4 5") auf den Basistakt pinnen
#      (scaling_min=scaling_max=base_frequency) -> kein Turbo, keine Frequenz-Streuung.
#   2. Uncore-/Ring-Takt pinnen (min=max) -> stabile LLC-/Speicher-Frequenz.
#   3. Tiefe C-States (state2/state3) auf DET_CORES deaktivieren; C1 bleibt
#      (Thermal-Puffer) -> geringer Weck-Latenz-Jitter.
# Nur die Mess-Kerne werden gepinnt; die übrigen Kerne (andere VMs) bleiben
# unberührt. Der Vorzustand wird auf dem Host in /run/nn_determinism.state
# gesichert und von --off exakt wiederhergestellt.
#
# Nutzung:
#   ./set_determinism.sh {--on|--off|--status} [--config DATEI]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

CONFIG_FILE="${SCRIPT_DIR}/config.env"
ACTION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --on)      ACTION="on"; shift ;;
        --off)     ACTION="off"; shift ;;
        --status)  ACTION="status"; shift ;;
        --config)  CONFIG_FILE="$2"; shift 2 ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)         die "Unbekanntes Argument: $1" ;;
    esac
done
[[ -n "${ACTION}" ]] || die "Aktion fehlt: --on | --off | --status"
[[ -f "${CONFIG_FILE}" ]] || die "Konfiguration nicht gefunden: ${CONFIG_FILE}"
# shellcheck source=config.env
source "${CONFIG_FILE}"
[[ -n "${HOST_HOST:-}" ]] || die "HOST_HOST nicht gesetzt (in ${CONFIG_FILE})"
DET_CORES="${DET_CORES:-4 5}"
require_cmd ssh

log "Determinismus '${ACTION}' auf Host ${HOST_HOST} (Mess-Kerne: ${DET_CORES}) ..."

# Sendet das folgende Remote-Skript an den Host; Argumente: <aktion> <kern...>.
# (ACTION/DET_CORES expandieren bewusst client-seitig -> SC2029; SSH_OPTS/DET_CORES
#  sollen worttrennen -> SC2086.)
# shellcheck disable=SC2029,SC2086
ssh ${SSH_OPTS} "${HOST_USER:-root}@${HOST_HOST}" "bash -s -- ${ACTION} ${DET_CORES}" <<'REMOTE'
set -u
action="$1"; shift
cores="$*"
CPU=/sys/devices/system/cpu
UNC=$CPU/intel_uncore_frequency/package_00_die_00
STATE=/run/nn_determinism.state
rd() { cat "$1" 2>/dev/null || echo "n/a"; }

case "$action" in
  status)
    echo "no_turbo (global) = $(rd $CPU/intel_pstate/no_turbo)"
    echo "uncore_min_khz    = $(rd $UNC/min_freq_khz)"
    echo "uncore_max_khz    = $(rd $UNC/max_freq_khz)"
    for c in $cores; do
      f=$CPU/cpu$c/cpufreq; i=$CPU/cpu$c/cpuidle
      echo "cpu$c: gov=$(rd $f/scaling_governor) base=$(rd $f/base_frequency) min=$(rd $f/scaling_min_freq) max=$(rd $f/scaling_max_freq) cur=$(rd $f/scaling_cur_freq) C2off=$(rd $i/state2/disable) C3off=$(rd $i/state3/disable)"
    done
    [ -f "$STATE" ] && echo "state_saved       = yes ($STATE)" || echo "state_saved       = no"
    ;;
  on)
    # Vorzustand einmalig sichern (nicht ueberschreiben, falls schon an).
    if [ ! -f "$STATE" ]; then
      { for c in $cores; do
          f=$CPU/cpu$c/cpufreq; i=$CPU/cpu$c/cpuidle
          echo "CORE $c $(rd $f/scaling_min_freq) $(rd $f/scaling_max_freq) $(rd $f/scaling_governor)"
          echo "CST $c 2 $(rd $i/state2/disable)"
          echo "CST $c 3 $(rd $i/state3/disable)"
        done
        echo "UNCORE $(rd $UNC/min_freq_khz) $(rd $UNC/max_freq_khz)"
      } > "$STATE"
    fi
    for c in $cores; do
      f=$CPU/cpu$c/cpufreq; i=$CPU/cpu$c/cpuidle
      base=$(cat "$f/base_frequency" 2>/dev/null || true)
      [ -n "$base" ] || { echo "FEHLER: base_frequency fehlt fuer cpu$c" >&2; exit 3; }
      echo performance > "$f/scaling_governor" 2>/dev/null || true
      echo "$base" > "$f/scaling_max_freq"
      echo "$base" > "$f/scaling_min_freq"
      echo 1 > "$i/state2/disable"
      echo 1 > "$i/state3/disable"
    done
    umax=$(cat "$UNC/initial_max_freq_khz" 2>/dev/null || cat "$UNC/max_freq_khz" 2>/dev/null || true)
    if [ -n "$umax" ]; then echo "$umax" > "$UNC/max_freq_khz"; echo "$umax" > "$UNC/min_freq_khz"; fi
    echo "Determinismus AN: Kerne [$cores] auf Basistakt gepinnt, C2/C3 aus, Uncore gepinnt."
    ;;
  off)
    if [ ! -f "$STATE" ]; then echo "Kein gespeicherter Zustand ($STATE) — nichts zu tun."; exit 0; fi
    while read -r tag a b c d; do
      case "$tag" in
        CORE)  echo "$c" > "$CPU/cpu$a/cpufreq/scaling_max_freq" 2>/dev/null || true
               echo "$b" > "$CPU/cpu$a/cpufreq/scaling_min_freq" 2>/dev/null || true
               [ -n "$d" ] && [ "$d" != "n/a" ] && echo "$d" > "$CPU/cpu$a/cpufreq/scaling_governor" 2>/dev/null || true ;;
        CST)   echo "$c" > "$CPU/cpu$a/cpuidle/state$b/disable" 2>/dev/null || true ;;
        UNCORE) echo "$b" > "$UNC/max_freq_khz" 2>/dev/null || true
                echo "$a" > "$UNC/min_freq_khz" 2>/dev/null || true ;;
      esac
    done < "$STATE"
    rm -f "$STATE"
    echo "Determinismus AUS: Vorzustand wiederhergestellt."
    ;;
  *) echo "unbekannte Aktion: $action" >&2; exit 2 ;;
esac
REMOTE