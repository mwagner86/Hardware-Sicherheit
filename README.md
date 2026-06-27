# Hardware Sicherheit — Wissenschaftliche Ausarbeitung (IEEE)

Dieses Repository enthält die Ausarbeitung zum Modul *Hardware-Sicherheit*.
Untersucht werden mikroarchitektonische Ressourcen-Interferenzen
(*Noisy-Neighbor*-Problem) über Virtualisierungsgrenzen hinweg auf Intel Raptor
Lake unter Proxmox VE. Es umfasst Exposé, Literatur-Recherche, das finale
IEEE-Paper, ein Präsentations-Deck sowie die komplette Mess- und
Orchestrierungs-Infrastruktur.

## Methodik

Zweistufiger Ansatz zur Bewertung der Hardware-Isolation:

1. **PoC (primär):** Angreifer- und Opfer-Gast werden host-seitig per
   CPU-Affinity auf **denselben physischen P-Core** gepinnt. Der Angreifer fährt
   mit `stress-ng` eine deterministische Störlast (L3-Cache-Eviction + I/O), das
   Opfer misst parallel mit `sysbench` (CPU/RAM) und `fio` (IOPS/Latenz). Als
   PoC-Opfer dient die **KVM**-Instanz; das QEMU-Opfer ist nicht PoC-tauglich
   (Emulation verschluckt den Effekt).
2. **Fallback:** Vergleichendes Benchmarking der drei Virtualisierungs-Paradigmen
   — Emulation (**QEMU**, `--kvm 0`), Para-Virtualisierung (**LXC**) und
   Hardware-Virtualisierung (**KVM**, `--cpu host`) — **sequenziell** unter
   identischer, konstanter Angreifer-Störlast.

Vor jeder Messreihe wird der Host deterministisch konfiguriert (C-States
deaktiviert, Turbo Boost aus, Governor `performance`); siehe
[project/notes/PoC.md](project/notes/PoC.md).

### VM-Topologie

Vier Instanzen, alle auf P-Core `4,5` gepinnt, im Heimnetz `vmbr0`. Host:
Proxmox `pve` (i7-13700).

| Rolle | Paradigma | Typ | ID | IP |
| --- | --- | --- | --- | --- |
| Angreifer (Störquelle) | konstant | LXC | 200 | `…178.200` |
| Opfer | Emulation | QEMU `--kvm 0` | 201 | `…178.201` |
| Opfer | Para-Virt. | LXC | 202 | `…178.202` |
| Opfer | HW-Virt. | KVM `--cpu host` | 203 | `…178.203` |

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

- `victim_benchmark.sh` — Opfer: ein Messlauf `sysbench` + `fio`.
- `attacker_load.sh` — Angreifer: `start`/`stop`/`run` der `stress-ng`-Störlast.
- `run_experiment.sh` — PoC (Angreifer + 1 Opfer) → `poc_summary.csv`.
- `run_fallback.sh` — Fallback (3 Opfer sequenziell) → `fallback_summary.csv`.
- `lib/common.sh`, `lib/orchestrator.sh` — geteilte Helfer (Logging/Median,
  SSH/Deploy/Collect). `config.env` — SSH-Ziele und Versuchsparameter.

Drei CSV-Schemata werden **nicht** vermischt: `summary.csv` (Legacy-Dummy, vom
abgegebenen Exposé gelesen), `poc_summary.csv` (PoC) und `fallback_summary.csv`
(Fallback, Quelle des gruppierten Balkendiagramms).

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
