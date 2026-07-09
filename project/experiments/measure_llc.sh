#!/usr/bin/env bash
# measure_llc.sh — host-seitige LLC-Cache-Contention-Messung (CONTROL-NODE).
#
# Belegt den KAUSALEN Kern des PoC: der Noisy Neighbor erhöht die LLC-Miss-Rate
# auf dem geteilten P-Core. Im KVM-Gast ist KEINE vPMU verfügbar (perf dort
# durchweg "<not supported>", sogar cycles/instructions), daher wird auf dem
# PROXMOX-HOST gemessen — perf stat -C auf dem physischen P-Core, auf den
# Angreifer UND Opfer host-seitig gepinnt sind. Das misst die Contention direkt
# an der geteilten Ressource.
#
# Ablauf je Phase: das Opfer erzeugt konstante Speicherlast, auf dem Host misst
# perf für PERF_WINDOW s die LLC-Loads/Misses auf HOST_PERF_CORES:
#   Baseline      : nur Opfer
#   NoisyNeighbor : Opfer + Angreifer-Störlast (stress-ng cache L3)
# -> results/llc_summary.csv  (Szenario;LLC_Loads;LLC_Load_Misses;Miss_Rate_Pct)
#
# Nutzung: ./measure_llc.sh [--config DATEI] [--label TEXT] [--install]
#   --install   linux-perf auf dem Host installieren (einmalig)
#   --label     kennzeichnet den Lauf (Verzeichnis, meta.txt, Historie-Index)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# --- Argumente --------------------------------------------------------------
CONFIG_FILE="${SCRIPT_DIR}/config.env"
LABEL=""
DO_INSTALL=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)  CONFIG_FILE="$2"; shift 2 ;;
        --label)   LABEL="$2"; shift 2 ;;
        --install) DO_INSTALL=1; shift ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)         die "Unbekanntes Argument: $1" ;;
    esac
done
PROFILE="$(basename "${CONFIG_FILE}" .env)"

[[ -f "${CONFIG_FILE}" ]] || die "Konfiguration nicht gefunden: ${CONFIG_FILE}"
# shellcheck source=config.env
source "${CONFIG_FILE}"
# shellcheck source=lib/orchestrator.sh
source "${SCRIPT_DIR}/lib/orchestrator.sh"

RENV="$(remote_env)"
HOST_PERF_CORES="${HOST_PERF_CORES:-4,5}"   # geteilter P-Core (Angreifer+Opfer gepinnt)
PERF_WINDOW="${PERF_WINDOW:-5}"             # Messfenster je Phase in Sekunden
PERF_EVENTS="LLC-loads,LLC-load-misses"

a_ssh() { rssh "${ATTACKER_USER}"   "${ATTACKER_HOST}" "$@"; }
v_ssh() { rssh "${VICTIM_USER}"     "${VICTIM_HOST}"   "$@"; }
h_ssh() { rssh "${HOST_USER:-root}" "${HOST_HOST}"     "$@"; }

# --- Preflight --------------------------------------------------------------
[[ -n "${HOST_HOST:-}" ]] || die "HOST_HOST fehlt in ${CONFIG_FILE} (Host-Messung zwingend)"
log "Preflight: prüfe Erreichbarkeit ..."
h_ssh true || die "Host (${HOST_HOST}) nicht per SSH erreichbar"
v_ssh true || die "Opfer (${VICTIM_HOST}) nicht per SSH erreichbar"
a_ssh true || die "Angreifer (${ATTACKER_HOST}) nicht per SSH erreichbar"

if [[ "${DO_INSTALL}" -eq 1 ]]; then
    log "Installiere linux-perf auf dem Host ..."
    h_ssh "apt-get update -qq && apt-get install -y -qq linux-perf" \
        || warn "perf-Installation auf dem Host fehlgeschlagen"
fi
h_ssh "command -v perf >/dev/null" || die "Host: perf fehlt (--install nutzen)"

# Konstante Speicherlast im Opfer (Hintergrund, per timeout begrenzt), damit der
# geteilte Core in BEIDEN Phasen identische Opfer-Last sieht — Unterschied ist
# allein der Angreifer.
victim_load_start() {
    v_ssh "nohup timeout $((PERF_WINDOW + 3)) sysbench memory --memory-block-size=1K \
        --memory-total-size=1000G --memory-oper=write --threads=1 run >/dev/null 2>&1 &"
    sleep 1   # Anlauf der Speicherlast
}

# Misst LLC-Events auf dem Host über PERF_WINDOW s. Gibt "loads;misses" aus.
# Auf dem Hybrid-Kern nennt perf die Events "cpu_core/LLC-.../".
host_perf_sample() {
    h_ssh "perf stat -x';' -e ${PERF_EVENTS} -C ${HOST_PERF_CORES} -- sleep ${PERF_WINDOW} 2>&1" \
      | awk -F';' '
            /LLC-load-misses/            { m=$1 }
            /LLC-loads/ && !/LLC-load-m/ { l=$1 }
            END { print (l==""?"NA":l) ";" (m==""?"NA":m) }'
}

# Eine Phase messen. Args: <label> <attacker: 0|1>. Gibt "loads;misses" aus.
measure_phase() {
    local label="$1" attacker="$2" sample
    [[ "${attacker}" -eq 1 ]] && attacker_start "${ATTACKER_USER}" "${ATTACKER_HOST}"
    victim_load_start
    log "[${label}] perf-Sample (${PERF_WINDOW}s) auf Core ${HOST_PERF_CORES} ..."
    sample="$(host_perf_sample)"
    [[ "${attacker}" -eq 1 ]] && attacker_stop "${ATTACKER_USER}" "${ATTACKER_HOST}"
    echo "${sample}"
}

# --- Hauptablauf ------------------------------------------------------------
TS="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${TS}_${PROFILE}_llc${LABEL:+_${LABEL}}"
DATA_DIR="${SCRIPT_DIR}/results/data/${RUN_ID}"
mkdir -p "${DATA_DIR}"
log "Datenverzeichnis: ${DATA_DIR}"

trap 'attacker_stop "${ATTACKER_USER}" "${ATTACKER_HOST}"' EXIT

log "=== Phase 1: Baseline (nur Opfer) ==="
IFS=';' read -r B_LOADS B_MISS <<< "$(measure_phase Baseline 0)"
log "=== Phase 2: NoisyNeighbor (Opfer + Angreifer) ==="
IFS=';' read -r N_LOADS N_MISS <<< "$(measure_phase NoisyNeighbor 1)"

[[ "${B_LOADS}" =~ ^[0-9]+$ && "${N_LOADS}" =~ ^[0-9]+$ ]] \
    || die "LLC-Counter nicht lesbar (loads: '${B_LOADS}'/'${N_LOADS}') — PMU auf dem Host verfügbar?"

miss_rate() { awk -v l="$1" -v m="$2" 'BEGIN { if (l+0==0) { print "NaN"; exit } printf "%.2f", m/l*100 }'; }
B_RATE="$(miss_rate "${B_LOADS}" "${B_MISS}")"
N_RATE="$(miss_rate "${N_LOADS}" "${N_MISS}")"

# --- Aggregat + Historie ----------------------------------------------------
SUMMARY="${DATA_DIR}/summary.csv"
{
    echo "Szenario;LLC_Loads;LLC_Load_Misses;Miss_Rate_Pct"
    echo "Baseline;${B_LOADS};${B_MISS};${B_RATE}"
    echo "NoisyNeighbor;${N_LOADS};${N_MISS};${N_RATE}"
    printf 'Delta-Prozent;%s;%s;%s\n' \
        "$(delta_pct "${B_LOADS}" "${N_LOADS}")" \
        "$(delta_pct "${B_MISS}"  "${N_MISS}")" \
        "$(delta_pct "${B_RATE}"  "${N_RATE}")"
} > "${SUMMARY}"
cp "${SUMMARY}" "${SCRIPT_DIR}/results/llc_summary.csv"

DET="$(host_determinism)"
write_run_meta "${DATA_DIR}" "llc" "${PROFILE}" "${LABEL}" "${DET}"
history_append "${SCRIPT_DIR}/results/history/llc_runs.csv" \
    "timestamp;label;profile;git;perf_cores;window_s;base_miss_pct;nn_miss_pct;miss_rate_delta;datadir" \
    "${TS};${LABEL};${PROFILE};$(run_git_commit);${HOST_PERF_CORES};${PERF_WINDOW};${B_RATE};${N_RATE};$(delta_pct "${B_RATE}" "${N_RATE}");results/data/${RUN_ID}"

log "Fertig. LLC-Ergebnis:"
cat "${SUMMARY}" >&2
log "Roh- und Aggregatdaten unter: ${DATA_DIR}"
log "Historie ergänzt: ${SCRIPT_DIR}/results/history/llc_runs.csv"
