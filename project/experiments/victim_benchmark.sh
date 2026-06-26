#!/usr/bin/env bash
# victim_benchmark.sh — läuft auf dem OPFER-System.
#
# Führt einen vollständigen Messdurchlauf aus (sysbench cpu, sysbench memory,
# fio random-write) und gibt EINE maschinenlesbare Zeile auf stdout aus:
#
#   cpu_eps=<float>;mem_mibps=<float>;iops=<float>;lat_p95_ms=<float>
#
# Die Rohausgaben der einzelnen Werkzeuge werden zusätzlich nach
# <workdir>/raw/ geschrieben. Alle Logmeldungen gehen nach stderr.
#
# Konfiguration über Umgebungsvariablen (Defaults siehe unten); der
# Orchestrator exportiert diese aus config.env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# --- Parameter (vom Orchestrator überschreibbar) ---------------------------
SYSBENCH_CPU_PRIME="${SYSBENCH_CPU_PRIME:-20000}"
SYSBENCH_TIME="${SYSBENCH_TIME:-30}"
SYSBENCH_MEM_TOTAL="${SYSBENCH_MEM_TOTAL:-10G}"
FIO_SIZE="${FIO_SIZE:-512M}"
FIO_RUNTIME="${FIO_RUNTIME:-30}"
FIO_IODEPTH="${FIO_IODEPTH:-16}"
TASKSET_CPU="${TASKSET_CPU:-}"
WORKDIR="${WORKDIR:-${SCRIPT_DIR}/work}"

RAW_DIR="${WORKDIR}/raw"
FIO_FILE="${WORKDIR}/fio_testfile"
mkdir -p "${RAW_DIR}"

# taskset-Präfix, falls Pinning innerhalb des Gasts gewünscht ist
PIN=()
if [[ -n "${TASKSET_CPU}" ]]; then
    require_cmd taskset
    PIN=(taskset -c "${TASKSET_CPU}")
fi

require_cmd sysbench
require_cmd fio

cleanup() { rm -f "${FIO_FILE}"; }
trap cleanup EXIT

# --- 1) CPU: sysbench cpu (Events/s) ---------------------------------------
log "sysbench cpu (prime=${SYSBENCH_CPU_PRIME}, ${SYSBENCH_TIME}s) ..."
"${PIN[@]}" sysbench cpu \
    --cpu-max-prime="${SYSBENCH_CPU_PRIME}" \
    --time="${SYSBENCH_TIME}" --threads=1 run \
    > "${RAW_DIR}/sysbench_cpu.txt"
cpu_eps=$(grep -i 'events per second' "${RAW_DIR}/sysbench_cpu.txt" | awk '{print $NF}')
[[ -n "${cpu_eps}" ]] || die "sysbench cpu: Events/s nicht geparst"

# --- 2) Speicher: sysbench memory (MiB/s) ----------------------------------
log "sysbench memory (total=${SYSBENCH_MEM_TOTAL}) ..."
"${PIN[@]}" sysbench memory \
    --memory-block-size=1K \
    --memory-total-size="${SYSBENCH_MEM_TOTAL}" \
    --memory-oper=write --threads=1 run \
    > "${RAW_DIR}/sysbench_mem.txt"
# Zeile: "   10240.00 MiB transferred (1024.00 MiB/sec)"
mem_mibps=$(grep -oP '\(\K[0-9.]+(?= MiB/sec\))' "${RAW_DIR}/sysbench_mem.txt" | head -n1)
[[ -n "${mem_mibps}" ]] || die "sysbench memory: MiB/s nicht geparst"

# --- 3) I/O: fio random write (IOPS + p95-Latenz) --------------------------
log "fio random-write (size=${FIO_SIZE}, ${FIO_RUNTIME}s, iodepth=${FIO_IODEPTH}) ..."
"${PIN[@]}" fio \
    --name=randwrite --filename="${FIO_FILE}" \
    --rw=randwrite --bs=4k --size="${FIO_SIZE}" \
    --runtime="${FIO_RUNTIME}" --time_based \
    --ioengine=libaio --iodepth="${FIO_IODEPTH}" --direct=1 \
    --output-format=json \
    > "${RAW_DIR}/fio.json"

if command -v jq >/dev/null 2>&1; then
    iops=$(jq -r '.jobs[0].write.iops' "${RAW_DIR}/fio.json")
    lat_ns=$(jq -r '.jobs[0].write.clat_ns.percentile["95.000000"] // .jobs[0].write.lat_ns.percentile["95.000000"] // 0' "${RAW_DIR}/fio.json")
else
    warn "jq nicht gefunden — verwende grep-Fallback für fio-JSON (ungenauer)"
    iops=$(grep -oP '"iops"\s*:\s*\K[0-9.]+' "${RAW_DIR}/fio.json" | head -n1)
    lat_ns=$(grep -oP '"95.000000"\s*:\s*\K[0-9.]+' "${RAW_DIR}/fio.json" | head -n1)
fi
[[ -n "${iops}" ]] || die "fio: IOPS nicht geparst"
lat_p95_ms=$(awk -v n="${lat_ns:-0}" 'BEGIN { printf "%.4f", n/1000000 }')

# --- Ergebniszeile ----------------------------------------------------------
printf 'cpu_eps=%s;mem_mibps=%s;iops=%s;lat_p95_ms=%s\n' \
    "${cpu_eps}" "${mem_mibps}" "${iops}" "${lat_p95_ms}"
log "Messung abgeschlossen: cpu_eps=${cpu_eps} mem_mibps=${mem_mibps} iops=${iops} lat_p95_ms=${lat_p95_ms}"
