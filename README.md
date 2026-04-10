# Hardware Sicherheit — Scientific Paper (IEEE Template)

Dieses Repository enthält die wissenschaftliche Ausarbeitung zum Modul *Hardware-Sicherheit*. 
Das Projekt untersucht mikroarchitektonische Ressourcen-Interferenzen (Noisy-Neighbor-Problem) über Virtualisierungsgrenzen hinweg. Es umfasst das Exposé, das finale IEEE-Paper sowie alle zugehörigen Orchestrierungs-Skripte und Messdaten.

## Projektmethodik

Das Projekt verfolgt eine zweistufige Methodik zur Evaluierung der Hardware-Isolation:
1. **Proof of Concept (PoC):** Quantifizierung von Leistungseinbrüchen (I/O und Cache) unter deterministischer Noisy-Neighbor-Last (`stress-ng`) auf fest zugewiesenen physischen CPU-Kernen.
2. **Baseline (Fallback):** Vergleichendes Leistungs-Benchmarking von reiner Emulation (QEMU), Para-Virtualisierung (LXC) und Hardware-Virtualisierung (KVM) unter strikter Limitierung von Host-Interferenzen (C-States, CPU-Governor).

## Projektstruktur

- `/assets/`: Zentrale Ablage für Bilder und Diagramme (wird von allen `.tex`-Dokumenten referenziert).
- `/paper/`: Finales Paper (IEEE-Template).
- `/project/experiments/`: Bash-Skripte für die Orchestrierung der Interferenz-Tests (`benchmark.sh`, `generate_dummy_data.sh`) und resultierende Daten (`summary.csv`).
- `/project/expose/`: Vorbereitendes Exposé und lokale Literaturdatenbank (`references_expose.bib`).
- `/project/notes/`: Markdown-Notizen und Literaturrecherchen.

## Workflow & Build-Prozess

Das Repository ist für die Bearbeitung in **VS Code** (mit den Erweiterungen *LaTeX Workshop* und *LTeX*) vorkonfiguriert.

1. **Host-Präparation:** Vor der Ausführung der Tests müssen auf dem Proxmox-Host zwingend C-States limitiert und die dynamische Frequenzskalierung (`performance` governor) deaktiviert werden, um Messrauschen zu minimieren.
2. **Datenerhebung:** Die orchestrierten Testreihen (`sysbench`, `fio` parallel zu `stress-ng`) werden auf dem Testsystem (Debian/Proxmox) ausgeführt.
3. **Datenintegration:** Das Ausgabeformat `summary.csv` muss im Verzeichnis `/project/experiments/` bereitgestellt werden.
4. **Kompilierung:** Beim Speichern einer `.tex`-Datei führt LaTeX Workshop im Hintergrund `latexmk -pdf` aus. Die Pakete `pgfplots` und `pgfplotstable` importieren die CSV-Daten zur Laufzeit und rendern die Diagramme automatisch.