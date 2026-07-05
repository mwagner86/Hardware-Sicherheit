# Hardware Sicherheit — Wissenschaftliche Ausarbeitung (IEEE)

Dieses Repository enthält die Ausarbeitung zum Modul *Hardware-Sicherheit*.
Untersucht werden mikroarchitektonische Ressourcen-Interferenzen
(*Noisy-Neighbor*-Problem) über Virtualisierungsgrenzen hinweg auf Intel Raptor
Lake unter Proxmox VE. Es umfasst Exposé, Literatur-Recherche, das finale
IEEE-Paper, ein Präsentations-Deck sowie die komplette Mess- und
Orchestrierungs-Infrastruktur.

## Methodik

Im Zentrum steht der **Noisy-Neighbor-Effekt** selbst: die Arbeit behandelt
konkret die aktive Ressourcen-Interferenz. Reine Benchmarks **ohne** diesen
Effekt (Paradigmen-Leistungsvergleich) treten dahinter zurück.

1. **PoC (primär, erfolgreich):** Angreifer- und Opfer-Gast werden host-seitig
   per CPU-Affinity auf **denselben physischen P-Core** gepinnt. Der Angreifer
   fährt mit `stress-ng` eine deterministische Störlast (L3-Cache-Eviction + I/O),
   das Opfer misst parallel mit `sysbench` (CPU/RAM) und `fio` (IOPS/Latenz). Als
   PoC-Opfer dient die **KVM**-Instanz; das QEMU-Opfer ist nicht PoC-tauglich
   (Emulation verschluckt den Effekt). Der Effekt ist eindeutig messbar — der
   erste echte Lauf zeigt IOPS −48 % und p95-Latenz +407 % unter Störlast.
2. **Paradigmen-Vergleich (zu den Akten gelegt):** Das vergleichende Benchmarking
   der drei Virtualisierungs-Paradigmen — Emulation (**QEMU**, `--kvm 0`),
   Para-Virtualisierung (**LXC**) und Hardware-Virtualisierung (**KVM**,
   `--cpu host`) — war als Rückfallebene für den Fall gedacht, dass kein Effekt
   messbar ist. Da der PoC eindeutig greift, wird es **nicht weiter verfolgt**;
   die Suite (`run_fallback.sh`) bleibt lauffähig für eine optionale Einordnung.

Vor jeder Messreihe wird der Host deterministisch konfiguriert (C-States
deaktiviert, Turbo Boost aus, Governor `performance`); siehe
[project/notes/PoC.md](project/notes/PoC.md).

### VM-Topologie

Vier Instanzen, alle auf P-Core `4,5` gepinnt, im Heimnetz `vmbr0`. Host:
Proxmox `pve` (i7-13700).

| Rolle | Paradigma | Typ | ID | IP |
| --- | --- | --- | --- | --- |
| Angreifer (Störquelle) | konstant | LXC | 300 | `…178.210` |
| Opfer | Emulation | QEMU `--kvm 0` | 301 | `…178.211` |
| Opfer | Para-Virt. | LXC | 302 | `…178.212` |
| Opfer | HW-Virt. | KVM `--cpu host` | 303 | `…178.213` |

## Projektstruktur

- [paper/](paper/) — finale Hausarbeit ([main.tex](paper/main.tex)) und
  Literatur-Recherche-Zwischenabgabe ([literatur_recherche_draft.tex](paper/literatur_recherche_draft.tex)).
- [project/expose/](project/expose/) — abgegebenes Exposé und primäre
  Literaturdatenbank (`references_expose.bib`).
- [project/experiments/](project/experiments/) — automatisierte Mess-Suite
  (Orchestrierung vom Control-Node per SSH); Details in
  [project/experiments/README.md](project/experiments/README.md).
- [project/notes/](project/notes/) — PoC-/Deployment-Anleitungen und
  Recherche-Notizen ([PoC.md](project/notes/PoC.md),
  [VM-Deployment.md](project/notes/VM-Deployment.md),
  [Proxmox-Klickanleitung.md](project/notes/Proxmox-Klickanleitung.md)).
- [presentation/](presentation/) — Slidev-Deck zum experimentellen Teil
  (lokal hostbar + PDF-exportierbar); siehe [presentation/README.md](presentation/README.md).
- [assets/](assets/) — zentrale Bild-/Diagramm-Ablage (`\graphicspath`, von allen
  `.tex`-Dokumenten referenziert).

### Mess-Suite ([project/experiments/](project/experiments/))

Getrennt nach **wo etwas läuft** (Details + Verzeichnisbaum in
[project/experiments/README.md](project/experiments/README.md)):

- **Control-Node** (Top-Level + `lib/`): `run_experiment.sh` (PoC →
  `results/poc_summary.csv`), `run_fallback.sh` (Paradigmen-Vergleich, 3 Opfer
  sequenziell → `results/fallback_summary.csv`; zu den Akten gelegt, s. Methodik),
  `config.env`/`smoke.env`, `lib/{common,orchestrator}.sh`.
- **`roles/`** (auf die Gäste deployed): `victim_benchmark.sh` (Opfer:
  `sysbench`+`fio`), `attacker_load.sh` (Angreifer: `stress-ng`-Störlast).
- **`results/`**: Aggregat-CSVs (getrackt, Platzhalter) + `data/` (Rohdaten, gitignored).
- **`legacy/`**: eingefrorene Dummy-CSV `summary.csv` + Generator, **nur** fürs
  abgegebene Exposé.

Drei CSV-Schemata werden **nicht** vermischt: `legacy/summary.csv` (Legacy-Dummy,
vom abgegebenen Exposé gelesen), `results/poc_summary.csv` (PoC, gelesen von
`paper/main.tex`) und `results/fallback_summary.csv` (Fallback, Quelle des
gruppierten Balkendiagramms).

## Build

LaTeX-Dokumente werden über `make` gebaut (`latexmk -pdf`, IEEEtran; `pgfplots`/
`pgfplotstable` importieren die CSV-Daten zur Kompilierzeit und rendern Tabellen
und Diagramme automatisch):

```bash
make paper      # paper/main.tex → paper/main.pdf
make expose     # Exposé
make draft      # Literatur-Recherche
make all        # alle drei Dokumente
make clean      # Hilfsdateien löschen   (fullclean: zusätzlich PDFs)
```

Präsentation:

```bash
cd presentation && npm install
npm run dev      # Live-Preview :3030
npm run export   # PDF (Abgabeformat)
```
