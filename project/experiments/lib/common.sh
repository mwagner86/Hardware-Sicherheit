#!/usr/bin/env bash
# Gemeinsame Hilfsfunktionen für alle Experiment-Skripte.
# Wird per `source` eingebunden; enthält selbst keine ausführbare Logik.

# --- Logging (alles nach stderr, damit stdout für Messwerte frei bleibt) ----
_ts()  { date "+%Y-%m-%d %H:%M:%S"; }
log()  { printf '[%s] %s\n'   "$(_ts)" "$*" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(_ts)" "$*" >&2; }
err()  { printf '[%s] FEHLER: %s\n' "$(_ts)" "$*" >&2; }
die()  { err "$*"; exit 1; }

# Prüft, ob ein Kommando vorhanden ist.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Benötigtes Kommando nicht gefunden: $1"
}

# Median einer über stdin gelieferten Zahlenliste (eine Zahl pro Zeile).
# Nutzung:  printf '%s\n' "${werte[@]}" | median
median() {
    sort -g | awk '
        { v[NR]=$1 }
        END {
            if (NR==0) { print "NaN"; exit }
            if (NR%2==1) { print v[(NR+1)/2] }
            else { printf "%.4f\n", (v[NR/2] + v[NR/2+1]) / 2 }
        }'
}

# Prozentuale Veränderung von Baseline -> Messwert (negativ = Verschlechterung
# bei "höher ist besser"-Metriken wie IOPS/Events). Args: <baseline> <wert>
delta_pct() {
    awk -v b="$1" -v v="$2" 'BEGIN {
        if (b+0==0) { print "NaN"; exit }
        printf "%.2f", (v - b) / b * 100
    }'
}
