#!/usr/bin/env bash
# attacker_load.sh — läuft auf dem ANGREIFER-System.
#
# Erzeugt kombinierte Störlast: LLC-Cache-Eviction (stress-ng --cache) UND
# I/O-Sättigung (stress-ng --hdd). Drei Modi:
#
#   attacker_load.sh start [dauer_s]   Last im Hintergrund starten (PID-Datei)
#   attacker_load.sh stop              laufende Last beenden
#   attacker_load.sh run  <dauer_s>    Last im Vordergrund (mit --metrics-brief)
#
# Der Orchestrator nutzt start/stop, um die Last exakt um die Opfer-Messung
# herum zu klammern. Konfiguration über Umgebungsvariablen / config.env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

CACHE_WORKERS="${ATTACKER_CACHE_WORKERS:-2}"
CACHE_LEVEL="${ATTACKER_CACHE_LEVEL:-3}"
HDD_WORKERS="${ATTACKER_HDD_WORKERS:-1}"
HDD_BYTES="${ATTACKER_HDD_BYTES:-1G}"
TASKSET_CPU="${TASKSET_CPU:-}"
WORKDIR="${WORKDIR:-${SCRIPT_DIR}/work}"
PID_FILE="${WORKDIR}/attacker.pid"
mkdir -p "${WORKDIR}"

PIN=()
if [[ -n "${TASKSET_CPU}" ]]; then
    require_cmd taskset
    PIN=(taskset -c "${TASKSET_CPU}")
fi

require_cmd stress-ng

# Baut das stress-ng-Kommando; $1 = Timeout in Sekunden (0 = ohne --timeout)
build_cmd() {
    local timeout_s="$1"
    local -a cmd=("${PIN[@]}" stress-ng
        --cache "${CACHE_WORKERS}" --cache-level "${CACHE_LEVEL}"
        --hdd "${HDD_WORKERS}" --hdd-bytes "${HDD_BYTES}"
        --temp-path "${WORKDIR}"
        --metrics-brief)
    if [[ "${timeout_s}" != "0" ]]; then
        cmd+=(--timeout "${timeout_s}")
    fi
    printf '%s\n' "${cmd[*]}"
}

stop_load() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid; pid="$(cat "${PID_FILE}")"
        if kill -0 "${pid}" 2>/dev/null; then
            log "Beende Störlast (PID ${pid}) ..."
            kill "${pid}" 2>/dev/null || true
            # stress-ng-Kindprozesse sicherheitshalber mit aufräumen
            pkill -P "${pid}" 2>/dev/null || true
        else
            warn "Störlast (PID ${pid}) lief bereits nicht mehr (Timeout/Absturz?) — Phase evtl. ohne Last gemessen, Werte prüfen!"
        fi
        rm -f "${PID_FILE}"
    fi
    # Sicherheitsnetz: verwaiste stress-ng-Prozesse einsammeln
    pkill -x stress-ng 2>/dev/null || true
    log "Störlast gestoppt."
}

mode="${1:-}"
case "${mode}" in
    start)
        duration="${2:-3600}"   # Default-Sicherheitslimit: 1h
        # Als Schutz vor verwaisten Läufen IMMER mit Timeout starten.
        read -r -a cmd <<< "$(build_cmd "${duration}")"
        log "Starte Störlast im Hintergrund (max ${duration}s): ${cmd[*]}"
        nohup "${cmd[@]}" > "${WORKDIR}/attacker.log" 2>&1 &
        echo "$!" > "${PID_FILE}"
        log "Störlast gestartet (PID $(cat "${PID_FILE}"))."
        ;;
    stop)
        stop_load
        ;;
    run)
        duration="${2:?Nutzung: attacker_load.sh run <dauer_s>}"
        read -r -a cmd <<< "$(build_cmd "${duration}")"
        log "Störlast im Vordergrund (${duration}s): ${cmd[*]}"
        exec "${cmd[@]}"
        ;;
    *)
        die "Nutzung: attacker_load.sh {start [dauer_s] | stop | run <dauer_s>}"
        ;;
esac
