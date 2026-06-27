#!/bin/bash
# Generiert hypothetische Testdaten für das LaTeX-Exposé
# Pfad: project/experiments/legacy/generate_dummy_data.sh
# Legacy: schreibt summary.csv (in cwd) NUR für das abgegebene Exposé
# (expose_hardware_security.tex). Für PoC/Fallback NICHT verwenden.

OUTPUT_FILE="summary.csv"

# Header: Wir nutzen ein Pivot-Format, das sich in PGFPlots (LaTeX) 
# direkt als gruppiertes Balkendiagramm plotten lässt.
echo "Virtualisierung;Baseline;NoisyNeighbor" > "$OUTPUT_FILE"

# Zeilen mit den Erwartungswerten (Hypothese)
echo "QEMU;1200;1100" >> "$OUTPUT_FILE"
echo "KVM;45000;31500" >> "$OUTPUT_FILE"
echo "LXC;52000;20800" >> "$OUTPUT_FILE"

echo "Hypothetische Benchmark-Daten erfolgreich in $OUTPUT_FILE generiert."