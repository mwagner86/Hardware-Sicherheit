#!/usr/bin/env bash
# run_interference.sh — Interferenz-Experiment-Orchestrator, läuft auf dem CONTROL-NODE (Laptop).
#
# Noisy-Neighbor-Experiment: ein Angreifer + ein Opfer auf demselben P-Core.
#   1. Preflight  : Erreichbarkeit + Werkzeuge auf beiden Gästen prüfen
#   2. Deploy     : Skripte nach REMOTE_DIR auf Angreifer & Opfer kopieren
#   3. Baseline   : Opfer-Benchmark N-mal OHNE Störlast
#   4. NoisyNeighbor : Störlast starten, Opfer-Benchmark N-mal, Störlast stoppen
#   5. Aggregation: Mediane + Delta -> data/<ts>/ und interference_summary.csv
#
# Nutzung:
#   ./run_interference.sh [--config DATEI] [--label TEXT] [--deploy-only] [--install] [--no-deploy]
#
# --label kennzeichnet den Lauf in Verzeichnisname, meta.txt und Historie-Index
# (z. B. "determ" / "nodeterm" für den BIOS-Determinismus-Vergleich).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# --- Argumente --------------------------------------------------------------
CONFIG_FILE="${SCRIPT_DIR}/config.env"
DO_DEPLOY=1
DEPLOY_ONLY=0
DO_INSTALL=0
LABEL=""                          # frei wählbar (z. B. Determinismus-Zustand)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)      CONFIG_FILE="$2"; shift 2 ;;
        --label)       LABEL="$2"; shift 2 ;;
        --deploy-only) DEPLOY_ONLY=1; shift ;;
        --no-deploy)   DO_DEPLOY=0; shift ;;
        --install)     DO_INSTALL=1; shift ;;
        -h|--help)     grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)             die "Unbekanntes Argument: $1" ;;
    esac
done
PROFILE="$(basename "${CONFIG_FILE}" .env)"   # smoke|config|demo

[[ -f "${CONFIG_FILE}" ]] || die "Konfiguration nicht gefunden: ${CONFIG_FILE}"
# shellcheck source=config.env
source "${CONFIG_FILE}"
# shellcheck source=lib/orchestrator.sh
source "${SCRIPT_DIR}/lib/orchestrator.sh"

RENV="$(remote_env)"

# Rollenbezogene SSH-Kurzformen
a_ssh() { rssh "${ATTACKER_USER}" "${ATTACKER_HOST}" "$@"; }
v_ssh() { rssh "${VICTIM_USER}"   "${VICTIM_HOST}"   "$@"; }

# --- 1) Preflight -----------------------------------------------------------
preflight() {
    log "Preflight: prüfe Erreichbarkeit ..."
    v_ssh true || die "Opfer (${VICTIM_HOST}) nicht per SSH erreichbar"
    a_ssh true || die "Angreifer (${ATTACKER_HOST}) nicht per SSH erreichbar"

    if [[ "${DO_INSTALL}" -eq 1 ]]; then
        log "Installiere Werkzeuge (apt-get) ..."
        v_ssh "apt-get update -qq && apt-get install -y -qq sysbench fio jq" \
            || warn "Installation auf Opfer fehlgeschlagen"
        a_ssh "apt-get update -qq && apt-get install -y -qq stress-ng" \
            || warn "Installation auf Angreifer fehlgeschlagen"
    fi

    log "Preflight: prüfe Werkzeuge ..."
    v_ssh "command -v sysbench >/dev/null && command -v fio >/dev/null" \
        || die "Opfer: sysbench und/oder fio fehlen (--install nutzen)"
    a_ssh "command -v stress-ng >/dev/null" \
        || die "Angreifer: stress-ng fehlt (--install nutzen)"
    v_ssh "command -v jq >/dev/null" || warn "Opfer: jq fehlt — fio-Parsing nutzt Fallback"

    local gov
    gov="$(v_ssh "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null" || true)"
    [[ "${gov}" == "performance" || -z "${gov}" ]] \
        || warn "Opfer CPU-Governor='${gov}' (erwartet 'performance' — host-seitig setzen)"
}

# --- Hauptablauf ------------------------------------------------------------
preflight
if [[ "${DO_DEPLOY}" -eq 1 ]]; then
    log "Deploy: rolle Skripte aus ..."
    deploy_role victim   "${VICTIM_USER}"   "${VICTIM_HOST}"
    deploy_role attacker "${ATTACKER_USER}" "${ATTACKER_HOST}"
fi
if [[ "${DEPLOY_ONLY}" -eq 1 ]]; then
    log "Nur Deploy angefordert — Ende."
    exit 0
fi

TS="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${TS}_${PROFILE}${LABEL:+_${LABEL}}"   # sprechend: <ts>_<profil>[_<label>]
DATA_DIR="${SCRIPT_DIR}/results/data/${RUN_ID}"
mkdir -p "${DATA_DIR}"
log "Datenverzeichnis: ${DATA_DIR}"

# Sicherstellen, dass am Ende (auch bei Fehler) keine Störlast weiterläuft.
cleanup() { attacker_stop "${ATTACKER_USER}" "${ATTACKER_HOST}"; }
trap cleanup EXIT

log "=== Phase 1: Baseline (ohne Störlast) ==="
collect_phase "Baseline" "${VICTIM_USER}" "${VICTIM_HOST}" "${DATA_DIR}/baseline_raw.csv"

log "=== Phase 2: Noisy Neighbor (mit Störlast) ==="
attacker_start "${ATTACKER_USER}" "${ATTACKER_HOST}"
collect_phase "NoisyNeighbor" "${VICTIM_USER}" "${VICTIM_HOST}" "${DATA_DIR}/noisy_raw.csv"
attacker_stop "${ATTACKER_USER}" "${ATTACKER_HOST}"

# --- Aggregation ------------------------------------------------------------
log "=== Aggregation ==="
declare -A B N
for col in 2 3 4 5; do   # 2=cpu_eps 3=mem_mibps 4=iops 5=lat_p95_ms
    B[$col]="$(col_median "${DATA_DIR}/baseline_raw.csv" "${col}")"
    N[$col]="$(col_median "${DATA_DIR}/noisy_raw.csv"   "${col}")"
done

SUMMARY="${DATA_DIR}/summary.csv"
{
    echo "Szenario;CPU_Events_per_sec;Memory_MiBps;IOPS_Random_Write;Latenz_p95_ms"
    echo "Baseline;${B[2]};${B[3]};${B[4]};${B[5]}"
    echo "NoisyNeighbor;${N[2]};${N[3]};${N[4]};${N[5]}"
    printf 'Delta-Prozent;%s;%s;%s;%s\n' \
        "$(delta_pct "${B[2]}" "${N[2]}")" \
        "$(delta_pct "${B[3]}" "${N[3]}")" \
        "$(delta_pct "${B[4]}" "${N[4]}")" \
        "$(delta_pct "${B[5]}" "${N[5]}")"
} > "${SUMMARY}"

cp "${SUMMARY}" "${SCRIPT_DIR}/results/interference_summary.csv"

# --- Metadaten + Historie (nie überschrieben) -------------------------------
DET="$(host_determinism)"; IFS=';' read -r DET_GOV DET_TURBO DET_CST <<< "${DET}"
write_run_meta "${DATA_DIR}" "interference" "${PROFILE}" "${LABEL}" "${DET}"
history_append "${SCRIPT_DIR}/results/history/interference_runs.csv" \
    "timestamp;label;profile;git;repeats;det_gov;det_no_turbo;det_max_cstate;cpu_delta;mem_delta;iops_delta;lat_delta;datadir" \
    "${TS};${LABEL};${PROFILE};$(run_git_commit);${REPEATS};${DET_GOV};${DET_TURBO};${DET_CST};$(delta_pct "${B[2]}" "${N[2]}");$(delta_pct "${B[3]}" "${N[3]}");$(delta_pct "${B[4]}" "${N[4]}");$(delta_pct "${B[5]}" "${N[5]}");results/data/${RUN_ID}"

log "Fertig. Ergebnis:"
cat "${SUMMARY}" >&2
log "Roh- und Aggregatdaten unter: ${DATA_DIR}"
log "Paper-Tabelle aktualisiert: ${SCRIPT_DIR}/results/interference_summary.csv"
log "Historie ergänzt: ${SCRIPT_DIR}/results/history/interference_runs.csv"
