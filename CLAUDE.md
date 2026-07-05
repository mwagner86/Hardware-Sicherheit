# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

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
* **CSV-Daten:** `pgfplotstable` liest `../project/experiments/results/poc_summary.csv` direkt zur Kompilierzeit und rendert daraus die Ergebnis-Tabelle. (Das abgegebene Exposé liest separat `legacy/summary.csv`.)

### CSV-Datenformat (`project/experiments/legacy/summary.csv`)

Legacy-Dummy, semikolon-getrennt, erste Zeile ist Header — **nur** vom
abgegebenen Exposé gelesen, eingefroren:

```text
Virtualisierung;Baseline;NoisyNeighbor
QEMU;1200;1100
KVM;45000;31500
LXC;52000;20800
```

Das finale Paper (`main.tex`) liest stattdessen `results/poc_summary.csv` (s. u.).

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

## Experiment-Infrastruktur (Stand: 2026-06-27)

Die automatisierte Testumgebung liegt in `project/experiments/`. Orchestrierung
vom **Control-Node (Laptop)** aus per SSH; die Skripte laufen auf den Gästen.
Details: `project/experiments/README.md`, Deployment: `project/notes/VM-Deployment.md`
(CLI `qm`/`pct`) bzw. `project/notes/Proxmox-Klickanleitung.md` (Web-UI + BIOS),
Topologie-Diagramm (Präsentation): `Experiment-Topologie.canvas`.

### VM-Topologie (4 Instanzen, alle auf P-Core `4,5` gepinnt, Heimnetz vmbr0)

| Rolle | Paradigma | Proxmox-Typ | ID | IP |
| --- | --- | --- | --- | --- |
| Angreifer | konstante Störquelle | LXC | 300 | `192.168.178.210` |
| Opfer | Emulation | QEMU-VM **`--kvm 0`** | 301 | `192.168.178.211` |
| Opfer | Para-Virt. | LXC | 302 | `192.168.178.212` |
| Opfer | HW-Virt. | KVM-VM `--cpu host` | 303 | `192.168.178.213` |

Host: Proxmox `pve` @ `192.168.178.50` (i7-13700, Storage `local-zfs`). PoC nutzt KVM-Opfer (303);
QEMU-Opfer ist NICHT PoC-tauglich (Emulation verschluckt den Effekt). Fallback
läuft **sequenziell** über alle drei Opfer → konstanter Angreifer.

### Struktur (`project/experiments/`)

Getrennt nach **wo etwas läuft** (Verzeichnisbaum: `project/experiments/README.md`):

- **Control-Node** (Top-Level + `lib/`):
  - `run_experiment.sh` — PoC (Angreifer + 1 Opfer) → `results/poc_summary.csv`
  - `run_fallback.sh` — Fallback (3 Opfer) → `results/fallback_summary.csv`
  - `lib/common.sh` (Logging/Median/Delta), `lib/orchestrator.sh` (SSH/Deploy/Collect, geteilt)
  - `config.env` — SSH-Ziele, `REPEATS`, Benchmark-/Last-Parameter, `FALLBACK_VICTIMS`
  - `smoke.env` — verkürztes Profil für die reine Funktionsprüfung (`project/notes/Smoke-Test.md`)
  - `demo.env` — Minimal-Profil (`REPEATS=1`, nur KVM) für die Live-Demo im Vortrag
- **`roles/`** (auf die Gäste deployed, dort ausgeführt):
  - `roles/victim_benchmark.sh` — Opfer: 1 Lauf sysbench(cpu+mem) + fio → `cpu_eps;mem_mibps;iops;lat_p95_ms`
  - `roles/attacker_load.sh` — Angreifer: `start [s]` / `stop` / `run <s>`, stress-ng cache(L3)+hdd
- **`results/`** — Aggregat-CSVs (getrackt, Platzhalter) + `data/` (Rohdaten, gitignored)
- **`legacy/`** — `summary.csv` + `generate_dummy_data.sh`, **nur** fürs abgegebene Exposé (eingefroren)

Erststart: `./run_experiment.sh --install --deploy-only` (installiert sysbench/fio/jq
bzw. stress-ng auf den Gästen). SSH-Key-Auth muss vorab stehen (Henne-Ei).
Aggregation = **Median** über `REPEATS` Läufe. Alle Skripte: `bash -n` + `shellcheck -x` sauber.

### Drei CSV-Schemata (NICHT vermischen!)

- `legacy/summary.csv` — Legacy-Dummy (`legacy/generate_dummy_data.sh`), `Virtualisierung;Baseline;NoisyNeighbor`, vom **abgegebenen Exposé** gelesen → unberührt lassen.
- `results/poc_summary.csv` — PoC, `Szenario;CPU_Events_per_sec;Memory_MiBps;IOPS_Random_Write;Latenz_p95_ms`. Zeilen: `Baseline`, `NoisyNeighbor`, `Delta-Prozent` (Bindestrich, kein `_` — wegen `string type` im LaTeX-Typeset). Gelesen von `paper/main.tex`.
- `results/fallback_summary.csv` — Fallback, `Virtualisierung;CPU_Base;CPU_NN;RAM_Base;RAM_NN;IOPS_Base;IOPS_NN;Lat_Base;Lat_NN`.

Beide `results/`-Aggregate sind mit **Platzhalterwerten** vorbelegt und werden
getrackt (Paper liest sie zur Compile-Zeit); echte Läufe überschreiben sie.

**Diagramm-Design (entschieden):** gruppierte Balken, Baseline vs. Noisy Neighbor,
ein Diagramm je Metrik. Mock: `assets/mock_fallback.{tex,csv,png}`.

### Paper-Stand `main.tex` (Stand: 2026-06-27)

Das finale Paper ist strukturell aufgesetzt und baut **vollständig grün**
(`make paper` → 3 Seiten, alle Zitate `[1]`–`[3]` aufgelöst) — mit Platzhaltern,
bis die echten Messwerte vorliegen. Verifikation der Abbildungen erfolgte über
gerendertes PDF (`pdftoppm`/`convert`-Crops).

**Fertig:**

- **Titel:** „Der Noisy-Neighbor-Effekt: Eine Untersuchung mikroarchitektonischer
  Ressourcen-Interferenzen in virtualisierten Umgebungen". Maßgebliche Einleitungs-Basis
  ist `paper/einleitungen/einleitung_zweite_version.tex` — **NICHT** die Markdown-Fassung
  `Einleitung.md` (= ältere erste Version).
- **Einleitung:** aus der zweiten Version übernommen; Methodik-Framing geschärft
  (**PoC = primär**, Paradigmen-Vergleich = **Rückfallebene**, falls kein Effekt messbar).
  Zitate `koh2007analysis`, `ge2018survey`, `nist2014hypervisor` (alle in
  `references_expose.bib`). Die kaputten `intelvtx`/`kvmsecurity` sind raus → Bib baut.
- **Abbildung 1** (`fig:setup`, Methodik): Testumgebungs-Topologie als **reines TikZ**
  (kein externes Bild), nachgebaut aus `Experiment-Topologie.canvas`. Control-Node →SSH→
  Host (P-Core 4,5, LLC) mit Angreifer + 3 Opfern, rote Contention-Pfeile.
- **Abbildung 2** (`fig:fallback`, Ergebnisse): gruppierte Balken, 4 Metriken, `figure*`,
  liest `results/fallback_summary.csv`; **eine** gemeinsame Legende (blau=Baseline,
  orange=Noisy Neighbor). Makro `\metricplot` in der Präambel (adaptiert aus `mock_fallback.tex`).
- **Tabelle I** (`tab:results`): PoC-Median aus `results/poc_summary.csv`, Spalten mit
  sauberen Anzeigenamen.
- Ergebnis-Abschnitt mit **Platzhalter-Hinweis** + interpretierender Prosa zu den
  Mock-Werten (klar als Arbeitshypothese markiert, nicht als Messung).

**Sobald echte Messwerte da sind — nächste Schritte:**

1. `./run_experiment.sh` + `./run_fallback.sh` laufen lassen → überschreiben die
   Platzhalter in `results/poc_summary.csv` / `results/fallback_summary.csv`.
   `make paper` zieht die Zahlen automatisch in Tabelle I + Abbildung 2.
2. **Platzhalter-Hinweis** im Ergebnis-Abschnitt entfernen und die Prosa an die realen
   Deltas anpassen (aktuell auf Mock-Werte getextet).
3. Captions bereinigen (Tabelle I „Platzhalterwerte", Abbildung 2 „Platzhalter/Mock-Daten").

**Noch offen / bewusst zurückgestellt (keine Blocker):**

- Abschnitte **II Stand der Forschung, III Versuchsaufbau, V Diskussion, VI Fazit**
  fehlen — die Einleitung („Aufbau der Arbeit") verspricht sie bereits.
- **Abstract** ist noch generischer Platzhalter (an Titel/Scope angleichen).
- Konkretes 4-Instanz-Setup/Tools bewusst **nicht** in der Einleitung (gehört nach
  Abschnitt III; die 2. Version hat solche Details absichtlich gestrichen).
- `\usepackage[demo]{graphicx}` + `picture.jpg` werden nicht mehr genutzt (entfernbar).
- Bei echten Daten ggf. `nodes near coords`-Labels in Abbildung 2 entzerren
  (überlappen bei eng beieinanderliegenden Balken).

## Präsentation (`presentation/`)

Slidev-Deck zum experimentellen Teil (~15 min), lokal hostbar + **PDF-exportierbar**
(harte Abgabe-Anforderung). Node 18+ nötig.

```bash
cd presentation
npm install
npm run dev      # Live-Preview :3030
npm run build    # statische Website -> dist/
npm run export   # PDF (braucht playwright-chromium; siehe presentation/README.md)
```

- **Folien:** `slides.md` (eine Datei, `---`-getrennt, Speaker-Notes je Folie).
  Inhalt: Motivation/Themenwahl, Hintergrund, Homeserver, Topologie (Mermaid),
  Methodik, Codebasis (echte Snippets), Ergebnis-**Platzhalter** (PoC-Tabelle +
  Fallback-Bild).
- **Platzhalter ersetzen:** Fotos → `public/img/homeserver/server.jpg`; Fallback-
  Diagramm → `public/img/mock_fallback.png` überschreiben; PoC-Tabelle aus
  `results/poc_summary.csv`.
- **Farbschema:** SentinelOne-inspiriert (Dark-Mode, Primär `#6B0AEA`, Magenta
  `#FF2D7E`). Zentral in `presentation/style.css`. **Wichtig:** Slidev merged
  KEINE `uno.config.ts` — die `s1`-Akzentklassen (`border-s1`, `bg-s1/10`,
  `*-s1-magenta`) sind daher als manuelle CSS-Klassen in `style.css` definiert.
- **Typo-/Eyecatcher-System** (ebenfalls `style.css`): automatische Akzente für
  `strong` (violett), Inline-`code` (magenta), Überschriften-Balken, Zitate,
  Tabellen; plus Klassen `.kicker .lead .hl .hl-m .mark .stat .muted`.
- **Public-Assets:** im Markdown als `<img :src="'/img/...'" />` einbinden
  (gebundener String), sonst behandelt Vite den Pfad als Build-Import und bricht ab.

## Abgaben & Zwischenstände

| Datei | Beschreibung |
| --- | --- |
| `project/expose/expose_hardware_security.tex` | Exposé (abgegeben) |
| `paper/literatur_recherche_draft.tex` | Literatur-Recherche Zwischenabgabe |
| `paper/main.tex` | Finale Hausarbeit |
| `presentation/slides.md` | Präsentations-Deck (Slidev, PDF-Abgabe) |
