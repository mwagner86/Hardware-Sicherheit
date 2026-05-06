# System-Prompt / Kontext für KI-Agenten: Praxisprojekt "Hardware-Sicherheit"

## 1. Projektziel & Rahmenbedingungen

* **Formatvorgabe:** Alle wissenschaftlichen Texte (Hausarbeit, Literatur-Recherche, Einleitung) müssen strikt im **IEEE Conference Format** verfasst werden.

* **Sprache:** Deutsch (wissenschaftlicher Standard).
* **Kernaufgabe:** Untersuchung der Isolation in Virtualisierungslösungen mit Fokus auf Hardware-Sicherheit.

## 2. Erweiterte Aufgabenstellung (Fokus: Noisy-Neighbor)

Das Projekt erweitert die ursprüngliche Basisaufgabe (Vergleich von Virtualisierungsparadigmen) um eine spezifische Untersuchung mikroarchitektonischer Ressourcen-Interferenzen ("Noisy-Neighbor-Effekt"). Ziel ist die Falsifikation der Hypothese, dass historische Angriffsvektoren auf moderner Hardware (Intel Raptor Lake) durch aktuelle Isolationsmechanismen (z. B. Intel RDT/CAT) vollständig neutralisiert werden.

## 3. Hardware-Szenario & Host-Konfiguration

* **Host:** Proxmox VE auf **Intel Raptor Lake** (hybride P-Core/E-Core Architektur).
* **Shared Resource:** Last Level Cache (LLC), der von P-Cores physisch geteilt wird.
* **Host-Determinismus (zwingend):**
    * Deaktivierung von Deep C-States: `intel_idle.max_cstate=1 processor.max_cstate=1 idle=poll`
    * Deaktivierung Intel Turbo Boost: `echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo`
    * Fixierung CPU-Governor: `performance` auf allen Kernen.

## 4. Methodik & Proof of Concept (PoC)

* **Setup:** Zwei identische Debian-Instanzen (Attacker & Victim).
* **Isolations-Bruch:** Erzwingen von Interferenz durch zwingendes **CPU-Pinning** beider Instanzen auf denselben physischen P-Core (Nutzung der CPU Affinity in Proxmox).
* **Metriken:** Erfassung von Durchsatz (MB/s) und 95. Perzentil-Latenz (ms) mittels `sysbench` und `fio` auf dem Victim-System, während der Attacker mittels `stress-ng --cache 2 --cache-level 3` den LLC sättigt.

## 5. Fallback-Strategie (Prüfungssicherung)

Sollte der PoC fehlschlagen (keine messbaren Interferenzen aufgrund greifender Hardware-Mitigierungen), fällt das Projekt auf die ursprüngliche Aufgabenstellung zurück:
* **Thema:** Vergleich von Emulation, Para-Virtualisierung und hardwareunterstützter Virtualisierung.
* **Fokus:** Untersuchung der Leistungsfähigkeit bei Rechenaufgaben und I/O-Operationen.

## 6. Repository-Ordnerstruktur

Die Code-Basis ist wie folgt strukturiert, um eine saubere Trennung zwischen Experimenten, Dokumentation und dem wissenschaftlichen Paper zu gewährleisten:

```text
.
├── Makefile                   # Zentrales Build-Management (targets: paper, expose, draft)
├── README.md                  # Projektübersicht
├── paper/                     # Wissenschaftliche Hausarbeit (IEEE-Format)
│   ├── main.tex               # Hauptdokument der Hausarbeit
│   ├── references.bib         # Konsolidierte Literaturdatenbank
│   ├── literatur_recherche_draft.tex # Zwischenabgabe Literatur-Recherche
│   └── ieee-template/         # Offizielle IEEE-Stil-Dateien und Klassen
└── project/                   # Projektbegleitende Unterlagen & Experimente
    ├── experiments/           # Skripte und Rohdaten des PoC
    │   ├── benchmark.sh       # Ausführung der Messreihen
    │   └── summary.csv        # Gesammelte Messergebnisse
    ├── expose/                # Einreichung der Projektskizze
    │   ├── expose_hardware_security.tex
    │   └── references_expose.bib
    └── notes/                 # Arbeitsnotizen und Anleitungen
        ├── Aufgabenstellung.md # Offizielle Prüfungsanforderungen
        ├── PoC.md             # Anleitung zur Testumgebung
        ├── literatur_bezugswege.md # Dokumentation der Quellenzugänge
        └── notes.md           # Allgemeine Projektnotizen
```
