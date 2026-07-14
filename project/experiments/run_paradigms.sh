#!/usr/bin/env bash
# run_paradigms.sh — Paradigmen-Vergleich-Orchestrator, läuft auf dem CONTROL-NODE (Laptop).
#
# Vergleicht die drei Virtualisierungs-Paradigmen (QEMU/LXC/KVM) unter
# identischer, konstanter Angreifer-Störlast. Pro Opfer:
#   Baseline (ohne Last) und NoisyNeighbor (mit Last), je REPEATS Läufe, Median.
#
# Da alle Instanzen auf demselben P-Core gepinnt sind und die Opfer SEQUENZIELL
# getestet werden, ist zu jedem Zeitpunkt nur ein Opfer + der Angreifer aktiv.
#
# Ergebnis: paradigms_summary.csv im Schema
#   Virtualisierung;CPU_Base;CPU_NN;RAM_Base;RAM_NN;IOPS_Base;IOPS_NN;Lat_Base;Lat_NN
# (direkt einsetzbar in das gruppierte Balkendiagramm, vgl. assets/mock_paradigms.tex)
#
# Nutzung:
#   ./run_paradigms.sh [--config DATEI] [--label TEXT] [--install] [--no-deploy]
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
DO_INSTALL=0
LABEL=""                          # frei wählbar (z. B. Determinismus-Zustand)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)    CONFIG_FILE="$2"; shift 2 ;;
        --label)     LABEL="$2"; shift 2 ;;
        --no-deploy) DO_DEPLOY=0; shift ;;
        --install)   DO_INSTALL=1; shift ;;
        -h|--help)   grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)           die "Unbekanntes Argument: $1" ;;
    esac
done
PROFILE="$(basename "${CONFIG_FILE}" .env)"   # smoke|config|demo

[[ -f "${CONFIG_FILE}" ]] || die "Konfiguration nicht gefunden: ${CONFIG_FILE}"
# shellcheck source=config.env
source "${CONFIG_FILE}"
# shellcheck source=lib/orchestrator.sh
source "${SCRIPT_DIR}/lib/orchestrator.sh"

[[ "${#PARADIGM_VICTIMS[@]}" -gt 0 ]] || die "PARADIGM_VICTIMS ist leer (config.env)"
RENV="$(remote_env)"

a_ssh() { rssh "${ATTACKER_USER}" "${ATTACKER_HOST}" "$@"; }

# --- 1) Preflight -----------------------------------------------------------
log "Preflight: prüfe Angreifer + ${#PARADIGM_VICTIMS[@]} Opfer ..."
a_ssh true || die "Angreifer (${ATTACKER_HOST}) nicht per SSH erreichbar"
if [[ "${DO_INSTALL}" -eq 1 ]]; then
    a_ssh "apt-get update -qq && apt-get install -y -qq stress-ng" \
        || warn "Installation auf Angreifer fehlgeschlagen"
fi
a_ssh "command -v stress-ng >/dev/null" || die "Angreifer: stress-ng fehlt (--install nutzen)"

for entry in "${PARADIGM_VICTIMS[@]}"; do
    label="${entry%%:*}"; host="${entry##*:}"
    rssh "${VICTIM_USER}" "${host}" true || die "Opfer ${label} (${host}) nicht erreichbar"
    if [[ "${DO_INSTALL}" -eq 1 ]]; then
        rssh "${VICTIM_USER}" "${host}" "apt-get update -qq && apt-get install -y -qq sysbench fio jq" \
            || warn "Installation auf Opfer ${label} fehlgeschlagen"
    fi
    rssh "${VICTIM_USER}" "${host}" "command -v sysbench >/dev/null && command -v fio >/dev/null" \
        || die "Opfer ${label}: sysbench/fio fehlen (--install nutzen)"
done

# --- 2) Deploy --------------------------------------------------------------
if [[ "${DO_DEPLOY}" -eq 1 ]]; then
    log "Deploy: Angreifer + alle Opfer ..."
    deploy_role attacker "${ATTACKER_USER}" "${ATTACKER_HOST}"
    for entry in "${PARADIGM_VICTIMS[@]}"; do
        deploy_role victim "${VICTIM_USER}" "${entry##*:}"
    done
fi

TS="$(date +%Y%m%d_%H%M%S)"
RUN_ID="paradigms_${TS}_${PROFILE}${LABEL:+_${LABEL}}"
DATA_DIR="${SCRIPT_DIR}/results/data/${RUN_ID}"
mkdir -p "${DATA_DIR}"
log "Datenverzeichnis: ${DATA_DIR}"

# Determinismus-Schnappschuss + meta.txt einmal pro Lauf (gilt für alle Opfer).
DET="$(host_determinism)"; IFS=';' read -r DET_GOV DET_TURBO DET_CST <<< "${DET}"
write_run_meta "${DATA_DIR}" "paradigms" "${PROFILE}" "${LABEL}" "${DET}"
GIT="$(run_git_commit)"
FB_HISTORY="${SCRIPT_DIR}/results/history/paradigms_runs.csv"
FB_HEADER="timestamp;label;profile;git;repeats;det_gov;det_no_turbo;det_max_cstate;victim;cpu_delta;mem_delta;iops_delta;lat_delta;datadir"

cleanup() { attacker_stop "${ATTACKER_USER}" "${ATTACKER_HOST}"; }
trap cleanup EXIT

SUMMARY="${DATA_DIR}/paradigms_summary.csv"
echo "Virtualisierung;CPU_Base;CPU_NN;RAM_Base;RAM_NN;IOPS_Base;IOPS_NN;Lat_Base;Lat_NN" > "${SUMMARY}"

# --- 3) Pro Opfer: Baseline + Noisy Neighbor -------------------------------
for entry in "${PARADIGM_VICTIMS[@]}"; do
    label="${entry%%:*}"; host="${entry##*:}"
    vdir="${DATA_DIR}/${label}"; mkdir -p "${vdir}"
    log "=== Opfer ${label} (${host}) ==="

    log "[${label}] Baseline ..."
    collect_phase "${label}/Baseline" "${VICTIM_USER}" "${host}" "${vdir}/baseline_raw.csv"

    log "[${label}] Noisy Neighbor ..."
    attacker_start "${ATTACKER_USER}" "${ATTACKER_HOST}"
    collect_phase "${label}/NoisyNeighbor" "${VICTIM_USER}" "${host}" "${vdir}/noisy_raw.csv"
    attacker_stop "${ATTACKER_USER}" "${ATTACKER_HOST}"

    # Mediane je Metrik (Spalten: 2=cpu 3=mem 4=iops 5=lat)
    cpuB="$(col_median "${vdir}/baseline_raw.csv" 2)"; cpuN="$(col_median "${vdir}/noisy_raw.csv" 2)"
    ramB="$(col_median "${vdir}/baseline_raw.csv" 3)"; ramN="$(col_median "${vdir}/noisy_raw.csv" 3)"
    ioB="$(col_median  "${vdir}/baseline_raw.csv" 4)"; ioN="$(col_median  "${vdir}/noisy_raw.csv" 4)"
    latB="$(col_median "${vdir}/baseline_raw.csv" 5)"; latN="$(col_median "${vdir}/noisy_raw.csv" 5)"
    echo "${label};${cpuB};${cpuN};${ramB};${ramN};${ioB};${ioN};${latB};${latN}" >> "${SUMMARY}"
    log "[${label}] fertig: IOPS ${ioB} -> ${ioN} ($(delta_pct "${ioB}" "${ioN}")%)"

    # Historie: eine Zeile je Opfer (nie überschrieben).
    history_append "${FB_HISTORY}" "${FB_HEADER}" \
        "${TS};${LABEL};${PROFILE};${GIT};${REPEATS};${DET_GOV};${DET_TURBO};${DET_CST};${label};$(delta_pct "${cpuB}" "${cpuN}");$(delta_pct "${ramB}" "${ramN}");$(delta_pct "${ioB}" "${ioN}");$(delta_pct "${latB}" "${latN}");results/data/${RUN_ID}"
done

# Kanonische Paradigmen-Vergleich-CSV fürs Paper-Diagramm ablegen.
cp "${SUMMARY}" "${SCRIPT_DIR}/results/paradigms_summary.csv"

log "Fertig. Aggregat:"
cat "${SUMMARY}" >&2
log "Rohdaten je Opfer unter: ${DATA_DIR}"
log "Paper-Diagramm-Daten: ${SCRIPT_DIR}/results/paradigms_summary.csv"
log "Historie ergänzt: ${FB_HISTORY}"
