#!/bin/bash
# Generiert Testdaten für das LaTeX-Exposé
# Pfad: project/experiments/summary.csv

OUTPUT_FILE="summary.csv"

# Header schreiben
echo "Lauf;CPU_Events_per_sec;IOPS_Random_Write" > "$OUTPUT_FILE"

# 5 Zeilen mit realistischen KVM-Werten füllen
echo "1;4850.12;12400" >> "$OUTPUT_FILE"
echo "2;4848.55;12350" >> "$OUTPUT_FILE"
echo "3;4852.10;12410" >> "$OUTPUT_FILE"
echo "4;4849.90;12380" >> "$OUTPUT_FILE"
echo "5;4851.05;12405" >> "$OUTPUT_FILE"

echo "Testdaten erfolgreich in $OUTPUT_FILE erstellt."