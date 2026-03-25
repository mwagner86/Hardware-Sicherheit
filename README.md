# Hardware Sicherheit — Scientific Paper (IEEE Template)

Dieses Repository enthält die wissenschaftliche Ausarbeitung zum Modul *Hardware-Sicherheit*.
Es umfasst das Exposé, das finale IEEE-Paper sowie alle zugehörigen Benchmarking-Skripte und Messdaten.

## Projektstruktur

- `/assets/`: Zentrale Ablage für Bilder und Diagramme (wird von allen `.tex`-Dokumenten referenziert).
- `/paper/`: Finales Paper (IEEE-Template).
- `/project/experiments/`: Bash-Skripte für die KVM-Benchmarks (`benchmark.sh`) und resultierende Daten (`summary.csv`).
- `/project/expose/`: Vorbereitendes Exposé und lokale Literaturdatenbank (`references_expose.bib`).
- `/project/notes/`: Markdown-Notizen und Literaturrecherchen.

## Workflow & Build-Prozess

Das Repository ist für die Bearbeitung in **VS Code** (mit den Erweiterungen *LaTeX Workshop* und *LTeX*) vorkonfiguriert.

1. **Datenerhebung:** Messdaten werden auf dem Testsystem (Debian/Proxmox) generiert.
2. **Datenintegration:** Die Datei `summary.csv` muss im Verzeichnis `/project/experiments/` bereitgestellt werden.
3. **Kompilierung:** Beim Speichern einer `.tex`-Datei führt LaTeX Workshop im Hintergrund `latexmk -pdf` aus. Das Paket `pgfplotstable` liest die CSV-Daten zur Laufzeit in das Dokument ein.