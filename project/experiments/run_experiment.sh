#!/usr/bin/env bash
# run_experiment.sh — Orchestrator, läuft auf dem CONTROL-NODE (Laptop).
#
# Steuert das Noisy-Neighbor-PoC-Experiment per SSH:
#   1. Preflight  : Erreichbarkeit + Werkzeuge auf beiden Gästen prüfen
#   2. Deploy     : Skripte nach REMOTE_DIR auf Angreifer & Opfer kopieren
#   3. Baseline   : Opfer-Benchmark N-mal OHNE Störlast
#   4. NoisyNeighbor : Störlast starten, Opfer-Benchmark N-mal, Störlast stoppen
#   5. Aggregation: Mediane + Delta -> data/<ts>/ und summary.csv
#
# Nutzung:
#   ./run_experiment.sh [--config DATEI] [--deploy-only] [--install] [--no-deploy]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# --- Argumente --------------------------------------------------------------
CONFIG_FILE="${SCRIPT_DIR}/config.env"
DO_DEPLOY=1
DEPLOY_ONLY=0
DO_INSTALL=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)      CONFIG_FILE="$2"; shift 2 ;;
        --deploy-only) DEPLOY_ONLY=1; shift ;;
        --no-deploy)   DO_DEPLOY=0; shift ;;
        --install)     DO_INSTALL=1; shift ;;
        -h|--help)     grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)             die "Unbekanntes Argument: $1" ;;
    esac
done

[[ -f "${CONFIG_FILE}" ]] || die "Konfiguration nicht gefunden: ${CONFIG_FILE}"
# shellcheck source=config.env
source "${CONFIG_FILE}"

require_cmd ssh
require_cmd scp

# --- SSH/SCP-Wrapper --------------------------------------------------------
# shellcheck disable=SC2086
a_ssh() { ssh ${SSH_OPTS} "${ATTACKER_USER}@${ATTACKER_HOST}" "$@"; }
# shellcheck disable=SC2086
v_ssh() { ssh ${SSH_OPTS} "${VICTIM_USER}@${VICTIM_HOST}" "$@"; }

# Exportiert die für die Remote-Skripte relevanten Variablen als Präfix-String,
# damit die Gäste mit identischen Parametern arbeiten.
remote_env() {
    printf 'WORKDIR=%q ' "${REMOTE_DIR}/work"
    for v in TASKSET_CPU SYSBENCH_CPU_PRIME SYSBENCH_TIME SYSBENCH_MEM_TOTAL \
             FIO_SIZE FIO_RUNTIME FIO_IODEPTH \
             ATTACKER_CACHE_WORKERS ATTACKER_CACHE_LEVEL ATTACKER_HDD_WORKERS ATTACKER_HDD_BYTES; do
        printf '%s=%q ' "$v" "${!v:-}"
    done
}
RENV="$(remote_env)"

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

    # Determinismus best-effort prüfen (im Gast oft nicht sichtbar -> nur Hinweis)
    local gov
    gov="$(v_ssh "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null" || true)"
    [[ "${gov}" == "performance" || -z "${gov}" ]] \
        || warn "Opfer CPU-Governor='${gov}' (erwartet 'performance' — host-seitig setzen)"
}

# --- 2) Deploy --------------------------------------------------------------
deploy() {
    log "Deploy: rolle Skripte nach ${REMOTE_DIR} aus ..."
    # Opfer
    v_ssh "mkdir -p ${REMOTE_DIR}/lib ${REMOTE_DIR}/work"
    # shellcheck disable=SC2086
    scp ${SSH_OPTS} "${SCRIPT_DIR}/victim_benchmark.sh" "${VICTIM_USER}@${VICTIM_HOST}:${REMOTE_DIR}/"
    # shellcheck disable=SC2086
    scp ${SSH_OPTS} "${SCRIPT_DIR}/lib/common.sh" "${VICTIM_USER}@${VICTIM_HOST}:${REMOTE_DIR}/lib/"
    v_ssh "chmod +x ${REMOTE_DIR}/victim_benchmark.sh"
    # Angreifer
    a_ssh "mkdir -p ${REMOTE_DIR}/lib ${REMOTE_DIR}/work"
    # shellcheck disable=SC2086
    scp ${SSH_OPTS} "${SCRIPT_DIR}/attacker_load.sh" "${ATTACKER_USER}@${ATTACKER_HOST}:${REMOTE_DIR}/"
    # shellcheck disable=SC2086
    scp ${SSH_OPTS} "${SCRIPT_DIR}/lib/common.sh" "${ATTACKER_USER}@${ATTACKER_HOST}:${REMOTE_DIR}/lib/"
    a_ssh "chmod +x ${REMOTE_DIR}/attacker_load.sh"
    log "Deploy abgeschlossen."
}

# Führt einen Opfer-Messlauf aus und gibt die Ergebniszeile zurück.
victim_run() {
    v_ssh "${RENV} ${REMOTE_DIR}/victim_benchmark.sh 2>/dev/null"
}

# Sammelt REPEATS Läufe; schreibt Roh-CSV; gibt Pfad zur Roh-CSV zurück.
# Args: <phase-label> <raw-csv-pfad>
collect_phase() {
    local label="$1" out="$2"
    echo "run;cpu_eps;mem_mibps;iops;lat_p95_ms" > "${out}"
    for i in $(seq 1 "${REPEATS}"); do
        log "[${label}] Lauf ${i}/${REPEATS} ..."
        local line; line="$(victim_run)"
        # "k=v;k=v;..." -> reine Werte in Spaltenreihenfolge
        local cpu mem iops lat
        cpu="$(sed -n 's/.*cpu_eps=\([^;]*\).*/\1/p'   <<< "${line}")"
        mem="$(sed -n 's/.*mem_mibps=\([^;]*\).*/\1/p' <<< "${line}")"
        iops="$(sed -n 's/.*iops=\([^;]*\).*/\1/p'     <<< "${line}")"
        lat="$(sed -n 's/.*lat_p95_ms=\([^;]*\).*/\1/p'<<< "${line}")"
        [[ -n "${cpu}" && -n "${iops}" ]] || die "[${label}] Lauf ${i}: Ergebnis nicht parsebar: '${line}'"
        echo "${i};${cpu};${mem};${iops};${lat}" >> "${out}"
    done
}

# Median einer Spalte (1-basiert) aus einer ;-getrennten CSV mit Header.
col_median() {
    local csv="$1" col="$2"
    tail -n +2 "${csv}" | cut -d';' -f"${col}" | median
}

# --- Hauptablauf ------------------------------------------------------------
preflight
[[ "${DO_DEPLOY}" -eq 1 ]] && deploy
if [[ "${DEPLOY_ONLY}" -eq 1 ]]; then
    log "Nur Deploy angefordert — Ende."
    exit 0
fi

TS="$(date +%Y%m%d_%H%M%S)"
DATA_DIR="${SCRIPT_DIR}/data/${TS}"
mkdir -p "${DATA_DIR}"
log "Datenverzeichnis: ${DATA_DIR}"

# Sicherstellen, dass am Ende (auch bei Fehler) keine Störlast weiterläuft.
cleanup() { a_ssh "${RENV} ${REMOTE_DIR}/attacker_load.sh stop" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# 3) Baseline
log "=== Phase 1: Baseline (ohne Störlast) ==="
collect_phase "Baseline" "${DATA_DIR}/baseline_raw.csv"

# 4) Noisy Neighbor
log "=== Phase 2: Noisy Neighbor (mit Störlast) ==="
# Last großzügig über die gesamte Messdauer starten; cleanup stoppt sie.
LOAD_BUDGET=$(( (SYSBENCH_TIME * 2 + FIO_RUNTIME + 30) * REPEATS ))
a_ssh "${RENV} ${REMOTE_DIR}/attacker_load.sh start ${LOAD_BUDGET}"
sleep 5   # Anlaufzeit der Cache-/I/O-Sättigung
collect_phase "NoisyNeighbor" "${DATA_DIR}/noisy_raw.csv"
a_ssh "${RENV} ${REMOTE_DIR}/attacker_load.sh stop"

# 5) Aggregation
log "=== Aggregation ==="
declare -A B N
# Spalten: 2=cpu_eps 3=mem_mibps 4=iops 5=lat_p95_ms
for col in 2 3 4 5; do
    B[$col]="$(col_median "${DATA_DIR}/baseline_raw.csv" "${col}")"
    N[$col]="$(col_median "${DATA_DIR}/noisy_raw.csv"   "${col}")"
done

SUMMARY="${DATA_DIR}/summary.csv"
{
    echo "Szenario;CPU_Events_per_sec;Memory_MiBps;IOPS_Random_Write;Latenz_p95_ms"
    echo "Baseline;${B[2]};${B[3]};${B[4]};${B[5]}"
    echo "NoisyNeighbor;${N[2]};${N[3]};${N[4]};${N[5]}"
    printf 'Delta_Prozent;%s;%s;%s;%s\n' \
        "$(delta_pct "${B[2]}" "${N[2]}")" \
        "$(delta_pct "${B[3]}" "${N[3]}")" \
        "$(delta_pct "${B[4]}" "${N[4]}")" \
        "$(delta_pct "${B[5]}" "${N[5]}")"
} > "${SUMMARY}"

# Aktuelles Ergebnis zusätzlich als kanonische summary.csv für das Paper ablegen.
cp "${SUMMARY}" "${SCRIPT_DIR}/poc_summary.csv"

log "Fertig. Ergebnis:"
cat "${SUMMARY}" >&2
log "Roh- und Aggregatdaten unter: ${DATA_DIR}"
log "Paper-Tabelle aktualisiert: ${SCRIPT_DIR}/poc_summary.csv"
