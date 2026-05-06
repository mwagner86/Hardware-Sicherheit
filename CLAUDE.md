# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projektziel & Rahmenbedingungen

* **Format:** Alle wissenschaftlichen Texte müssen strikt im **IEEE Conference Format** verfasst werden (`\documentclass[conference]{IEEEtran}`).
* **Sprache:** Deutsch (wissenschaftlicher Standard).
* **Kernaufgabe:** Untersuchung mikroarchitektonischer Ressourcen-Interferenzen ("Noisy-Neighbor") in virtualisierten Umgebungen auf Intel Raptor Lake (Proxmox VE).

## Build-Befehle

```bash
make paper       # Kompiliert paper/main.tex → paper/main.pdf
make expose      # Kompiliert project/expose/expose_hardware_security.tex
make draft       # Kompiliert paper/literatur_recherche_draft.tex
make all         # Alle drei Dokumente
make clean       # Löscht Hilfsdateien (.aux, .log, .bbl usw.)
make fullclean   # clean + löscht auch PDF-Ausgaben
```

Der Build nutzt `latexmk -pdf -interaction=nonstopmode -file-line-error -synctex=1`. Voraussetzung: `latexmk` und eine vollständige TeX-Distribution (mit `pgfplots`, `pgfplotstable`, `IEEEtran`) sind installiert.

## Code-Architektur & Datenpipeline

### LaTeX-Struktur

`paper/main.tex` ist das Haupt-IEEE-Paper. Es referenziert Ressourcen mit relativen Pfaden:

* **Bilder:** `\graphicspath{{../assets/}}` — alle Grafiken liegen in `/assets/`
* **Bibliographie:** `\bibliography{../project/expose/references_expose}` — die `.bib`-Datei liegt im Exposé-Verzeichnis
* **CSV-Daten:** `pgfplotstable` liest `../project/experiments/summary.csv` direkt zur Kompilierzeit und rendert daraus Tabellen und Diagramme

### CSV-Datenformat (`project/experiments/summary.csv`)

Semikolon-getrennt, erste Zeile ist Header:

```text
Virtualisierung;Baseline;NoisyNeighbor
QEMU;1200;1100
KVM;45000;31500
LXC;52000;20800
```

Änderungen an dieser Datei wirken sich sofort auf die gerenderten Tabellen im Paper aus.

### Bibliographie-Hierarchie

* `project/expose/references_expose.bib` — primäre Literaturdatenbank (wird von `main.tex` und `expose_hardware_security.tex` verwendet)
* `paper/references.bib` — konsolidierte Datenbank für das finale Paper (noch nicht aktiv eingebunden)

## Methodik

**Zweistufiger Ansatz:**

1. **PoC (primär):** Zwei Debian-Instanzen (Attacker & Victim) per CPU-Pinning auf denselben physischen P-Core fixiert. Attacker läuft `stress-ng --cache 2 --cache-level 3`, Victim misst mit `sysbench` und `fio`.
2. **Fallback:** Falls keine messbaren Interferenzen entstehen — systematischer Leistungsvergleich QEMU (Emulation) vs. LXC (Para-Virtualisierung) vs. KVM (Hardware-Virtualisierung).

**Host-Konfiguration (zwingend vor Messungen):**

```bash
# C-States deaktivieren (Kernel-Parameter):
intel_idle.max_cstate=1 processor.max_cstate=1 idle=poll
# Turbo Boost deaktivieren:
echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
# CPU-Governor auf performance setzen
```

## Abgaben & Zwischenstände

| Datei | Beschreibung |
| --- | --- |
| `project/expose/expose_hardware_security.tex` | Exposé (abgegeben) |
| `paper/literatur_recherche_draft.tex` | Literatur-Recherche Zwischenabgabe |
| `paper/main.tex` | Finale Hausarbeit |
