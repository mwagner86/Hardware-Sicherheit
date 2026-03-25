# Exposé – Hardware-Sicherheit

Dieses Verzeichnis enthält das wissenschaftliche Exposé zur Untersuchung von Performance-Overheads und Hardware-Isolationsmechanismen unter Proxmox VE. Es definiert den Rahmen, die Methodik und das experimentelle Setup der Untersuchung.

## Abhängigkeiten (Kompilierung)

Das Dokument bindet externe Daten und Grafiken dynamisch ein. Damit der LaTeX-Build (`latexmk`) nicht abbricht, müssen folgende Vorbedingungen erfüllt sein:

1. **Grafiken:** Das Dokument erwartet das Vorhandensein von Bilddateien im relativen Pfad `../../assets/`.
2. **Messdaten:** Das Paket `pgfplotstable` erfordert zwingend die Datei `../experiments/summary.csv` (semikolongetrennt). 

> **Hinweis zur Testumgebung:**
> Falls noch keine echten Benchmark-Daten des Proxmox-Servers vorliegen, muss das Skript `../experiments/generate_dummy_data.sh` ausgeführt werden. Dieses erzeugt eine formell korrekte Platzhalter-CSV, die den Build-Prozess ermöglicht.

## Kontakt
Maximilian Wagner
Technische Hochschule Brandenburg
maximilian.wagner@th-brandenburg.de