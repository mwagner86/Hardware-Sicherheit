#!/bin/bash
# Generiert hypothetische Testdaten für das LaTeX-Exposé
# Pfad: project/experiments/generate_dummy_data.sh

OUTPUT_FILE="summary.csv"

# Header: Wir nutzen ein Pivot-Format, das sich in PGFPlots (LaTeX) 
# direkt als gruppiertes Balkendiagramm plotten lässt.
echo "Virtualisierung;Baseline;NoisyNeighbor" > "$OUTPUT_FILE"

# Zeilen mit den Erwartungswerten (Hypothese)
echo "QEMU;1200;1100" >> "$OUTPUT_FILE"
echo "KVM;45000;31500" >> "$OUTPUT_FILE"
echo "LXC;52000;20800" >> "$OUTPUT_FILE"

echo "Hypothetische Benchmark-Daten erfolgreich in $OUTPUT_FILE generiert."