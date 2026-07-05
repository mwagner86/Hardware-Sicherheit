#!/usr/bin/env bash
# Gemeinsame Orchestrierungs-Helfer (laufen auf dem Control-Node).
# Genutzt von run_experiment.sh (PoC) und run_fallback.sh (Fallback).
#
# Wird per `source` eingebunden, NACHDEM common.sh und config.env geladen sind.
# Erwartet gesetzte Variablen: SCRIPT_DIR, SSH_OPTS, REMOTE_DIR, REPEATS sowie
# RENV (Aufrufer setzt: RENV="$(remote_env)").

require_cmd ssh
require_cmd scp

# Generischer SSH-Aufruf. Args: <user> <host> <kommando...>
# (Das Kommando expandiert bewusst client-seitig -> SC2029 ignoriert.)
# shellcheck disable=SC2029,SC2086
rssh() { local u="$1" h="$2"; shift 2; ssh ${SSH_OPTS} "${u}@${h}" "$@"; }

# Generisches SCP. Args: <lokale-datei> <user> <host> <remote-ziel>
# shellcheck disable=SC2086
rscp() { scp ${SSH_OPTS} "$1" "${2}@${3}:${4}"; }

# Baut den Parameter-Präfix, mit dem die Gäste identisch konfiguriert laufen.
remote_env() {
    printf 'WORKDIR=%q ' "${REMOTE_DIR}/work"
    for v in TASKSET_CPU SYSBENCH_CPU_PRIME SYSBENCH_TIME SYSBENCH_MEM_TOTAL \
             FIO_SIZE FIO_RUNTIME FIO_IODEPTH \
             ATTACKER_CACHE_WORKERS ATTACKER_CACHE_LEVEL ATTACKER_HDD_WORKERS ATTACKER_HDD_BYTES; do
        printf '%s=%q ' "$v" "${!v:-}"
    done
}

# Rollt die Skripte auf einen Gast aus. Args: <victim|attacker> <user> <host>
deploy_role() {
    local role="$1" u="$2" h="$3"
    rssh "$u" "$h" "mkdir -p ${REMOTE_DIR}/lib ${REMOTE_DIR}/work"
    rscp "${SCRIPT_DIR}/lib/common.sh" "$u" "$h" "${REMOTE_DIR}/lib/"
    case "$role" in
        victim)
            rscp "${SCRIPT_DIR}/roles/victim_benchmark.sh" "$u" "$h" "${REMOTE_DIR}/"
            rssh "$u" "$h" "chmod +x ${REMOTE_DIR}/victim_benchmark.sh" ;;
        attacker)
            rscp "${SCRIPT_DIR}/roles/attacker_load.sh" "$u" "$h" "${REMOTE_DIR}/"
            rssh "$u" "$h" "chmod +x ${REMOTE_DIR}/attacker_load.sh" ;;
        *) die "deploy_role: unbekannte Rolle '${role}'" ;;
    esac
}

# Führt einen Opfer-Messlauf aus -> Ergebniszeile auf stdout; Gast-stderr
# (Logs/Fehlermeldungen) läuft durch und wird vom Aufrufer in eine Logdatei
# gelenkt. Args: <user> <host>
victim_run() { rssh "$1" "$2" "${RENV} ${REMOTE_DIR}/victim_benchmark.sh"; }

# Sammelt REPEATS Messläufe in eine Roh-CSV; Gast-stderr landet daneben in
# <out ohne .csv>.log (Diagnose bei Benchmark-/Parse-Fehlern).
# Args: <phasen-label> <user> <host> <out-csv>
collect_phase() {
    local label="$1" u="$2" h="$3" out="$4"
    local logf="${out%.csv}.log"
    echo "run;cpu_eps;mem_mibps;iops;lat_p95_ms" > "${out}"
    local i line cpu mem iops lat
    for i in $(seq 1 "${REPEATS}"); do
        log "[${label}] Lauf ${i}/${REPEATS} ..."
        line="$(victim_run "${u}" "${h}" 2>>"${logf}")"
        cpu="$(sed -n 's/.*cpu_eps=\([^;]*\).*/\1/p'    <<< "${line}")"
        mem="$(sed -n 's/.*mem_mibps=\([^;]*\).*/\1/p'  <<< "${line}")"
        iops="$(sed -n 's/.*iops=\([^;]*\).*/\1/p'      <<< "${line}")"
        lat="$(sed -n 's/.*lat_p95_ms=\([^;]*\).*/\1/p' <<< "${line}")"
        [[ -n "${cpu}" && -n "${iops}" ]] || die "[${label}] Lauf ${i}: nicht parsebar: '${line}' — Gast-Log: ${logf}"
        echo "${i};${cpu};${mem};${iops};${lat}" >> "${out}"
    done
}

# Median einer 1-basierten Spalte aus einer ;-CSV mit Header. Args: <csv> <spalte>
col_median() { tail -n +2 "$1" | cut -d';' -f"$2" | median; }

# Startet die Angreifer-Störlast. Bewusst OHNE knapp kalkuliertes Zeitbudget:
# gestoppt wird immer explizit (attacker_stop bzw. EXIT-Trap); das 1h-Default-
# Timeout von attacker_load.sh ist nur Sicherheitsnetz gegen verwaiste Läufe.
# Ein knappes Budget kann mitten in der Messphase ablaufen (sysbench memory ist
# volumen-, nicht zeitgebunden) und die NoisyNeighbor-Werte still verfälschen.
# Args: <user> <host>
attacker_start() {
    rssh "$1" "$2" "${RENV} ${REMOTE_DIR}/attacker_load.sh start"
    sleep 5   # Anlaufzeit der Cache-/I/O-Sättigung
}

# Stoppt die Angreifer-Störlast (idempotent). stderr läuft durch, damit die
# Warnung über vorzeitig beendete Last den Control-Node erreicht. Args: <user> <host>
attacker_stop() {
    rssh "$1" "$2" "${RENV} ${REMOTE_DIR}/attacker_load.sh stop" >/dev/null || true
}

# --- Historie & Metadaten (Ergebnis-Historie.md) ----------------------------

# Kurzer git-Commit des Repos ("n/a", falls kein git).
run_git_commit() { git -C "${SCRIPT_DIR}" rev-parse --short HEAD 2>/dev/null || echo "n/a"; }

# Determinismus-Schnappschuss vom Proxmox-Host. Gibt ";"-getrennt zurück:
#   governor(P-Core 4);no_turbo;max_cstate   (Felder "n/a", wenn nicht lesbar).
# Objektiv statt auf korrektes Labeln angewiesen (mit/ohne BIOS-Determinismus).
host_determinism() {
    [[ -n "${HOST_HOST:-}" ]] || { echo "n/a;n/a;n/a"; return; }
    rssh "${HOST_USER:-root}" "${HOST_HOST}" '
        g=$(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor 2>/dev/null || echo n/a)
        t=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo n/a)
        c=$(cat /sys/module/intel_idle/parameters/max_cstate 2>/dev/null || echo n/a)
        printf "%s;%s;%s" "$g" "$t" "$c"' 2>/dev/null || echo "n/a;n/a;n/a"
}

# Schreibt eine selbsterklärende meta.txt in ein Run-Verzeichnis.
# Args: <datadir> <script> <profile> <label> <det="gov;turbo;cstate">
write_run_meta() {
    local dir="$1" script="$2" profile="$3" label="$4" det="$5"
    local gov="${det%%;*}" rest="${det#*;}"
    {
        echo "timestamp      = $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "script         = ${script}"
        echo "profile        = ${profile}"
        echo "label          = ${label:-}"
        echo "git_commit     = $(run_git_commit)"
        echo "repeats        = ${REPEATS}"
        echo "host           = ${HOST_HOST:-n/a}"
        echo "det_governor   = ${gov}"
        echo "det_no_turbo   = ${rest%%;*}"
        echo "det_max_cstate = ${rest#*;}"
        echo "attacker_host  = ${ATTACKER_HOST}"
        echo "# --- Benchmark-/Last-Parameter ---"
        local v
        for v in SYSBENCH_CPU_PRIME SYSBENCH_TIME SYSBENCH_MEM_TOTAL \
                 FIO_SIZE FIO_RUNTIME FIO_IODEPTH TASKSET_CPU \
                 ATTACKER_CACHE_WORKERS ATTACKER_CACHE_LEVEL ATTACKER_HDD_WORKERS ATTACKER_HDD_BYTES; do
            echo "${v} = ${!v:-}"
        done
    } > "${dir}/meta.txt"
}

# Hängt eine Zeile an eine Index-CSV; legt sie mit Header an, falls neu (nie
# überschrieben). Args: <indexfile> <header> <row>
history_append() {
    local f="$1" header="$2" row="$3"
    mkdir -p "$(dirname "$f")"
    [[ -f "$f" ]] || echo "${header}" > "$f"
    echo "${row}" >> "$f"
}
