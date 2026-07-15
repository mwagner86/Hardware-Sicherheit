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
* **Bibliographie:** `\bibliography{references}` — `main.tex` nutzt `paper/references.bib` (konsolidierte Datenbank). Quell-PDFs liegen lokal (nicht versioniert) in `paper/HWQuellen/`.
* **CSV-Daten:** `pgfplotstable` liest `../project/experiments/results/interference_summary.csv` direkt zur Kompilierzeit und rendert daraus die Ergebnis-Tabelle. (Das abgegebene Exposé liest separat `legacy/summary.csv`.)

### CSV-Datenformat (`project/experiments/legacy/summary.csv`)

Legacy-Dummy, semikolon-getrennt, erste Zeile ist Header — **nur** vom
abgegebenen Exposé gelesen, eingefroren:

```text
Virtualisierung;Baseline;NoisyNeighbor
QEMU;1200;1100
KVM;45000;31500
LXC;52000;20800
```

Das finale Paper (`main.tex`) liest stattdessen `results/interference_summary.csv` (s. u.).

### Bibliographie-Hierarchie

* `paper/references.bib` — **aktive** Literaturdatenbank des finalen Papers (12 Einträge; von `main.tex` eingebunden). NIST-Key ist `nist2018hypervisor`.
* `project/expose/references_expose.bib` — nur noch für das abgegebene Exposé (`expose_hardware_security.tex`); 3 Einträge, NIST-Key `nist2014hypervisor`.
* Quell-PDFs zu den `references.bib`-Einträgen liegen lokal in `paper/HWQuellen/` (nicht versioniert). Beim Schreiben immer aus der Quelle belegen, keine erfundenen Claims.

## Methodik

**Fokus: der Noisy-Neighbor-Effekt (Interferenz-Experiment).** Das Paper behandelt konkret den
aktiven Interferenz-Effekt; reine Benchmarks **ohne** diesen Effekt treten in den
Hintergrund.

1. **Interferenz-Experiment (primär, erfolgreich):** Zwei Debian-Instanzen (Attacker & Victim) per CPU-Pinning auf denselben physischen P-Core fixiert. Attacker läuft `stress-ng --cache 2 --cache-level 3`, Victim misst mit `sysbench` und `fio`. Der Effekt ist eindeutig messbar (erster echter Lauf `nodeterm`: CPU −21 %, RAM −45 %, IOPS −48 %, p95-Latenz +407 %).
2. **Paradigmen-Vergleich (ergänzende Einordnung):** Der systematische Leistungsvergleich der Virtualisierungsparadigmen QEMU/LXC/KVM fließt als **eigenständige Einordnung** ins Paper ein (nicht Kern der Arbeit — der bleibt das Interferenz-Experiment). Das früher als „Fallback" gedachte Konzept ist **obsolet**, seit das Interferenz-Experiment greift. Die alten Namen „PoC" und „Fallback" sind projektweit gestrichen — sowohl im Paper-Fließtext als auch in den Artefakt-Namen: Skripte/CSVs heißen jetzt `run_interference.sh`/`interference_summary.csv` bzw. `run_paradigms.sh`/`paradigms_summary.csv` (Env-Array `PARADIGM_VICTIMS`, Historie `{interference,paradigms}_runs.csv`, Abbildung `fig:paradigms`, Mock `mock_paradigms.*`).

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

Host: Proxmox `pve` @ `192.168.178.50` (i7-13700, Storage `local-zfs`). Das Interferenz-Experiment nutzt KVM-Opfer (303);
QEMU-Opfer ist NICHT dafür tauglich (Emulation verschluckt den Effekt). Der
Paradigmen-Vergleich (`run_paradigms.sh`) läuft **sequenziell** über alle drei
Opfer → konstanter Angreifer.

### Struktur (`project/experiments/`)

Getrennt nach **wo etwas läuft** (Verzeichnisbaum: `project/experiments/README.md`):

- **Control-Node** (Top-Level + `lib/`):
  - `run_interference.sh` — Interferenz-Experiment (Angreifer + 1 Opfer) → `results/interference_summary.csv`
  - `run_paradigms.sh` — Paradigmen-Vergleich (3 Opfer) → `results/paradigms_summary.csv`
  - `lib/common.sh` (Logging/Median/Delta), `lib/orchestrator.sh` (SSH/Deploy/Collect, geteilt)
  - `config.env` — SSH-Ziele, `REPEATS`, Benchmark-/Last-Parameter, `PARADIGM_VICTIMS`
  - `smoke.env` — verkürztes Profil für die reine Funktionsprüfung (`project/notes/Smoke-Test.md`)
  - `demo.env` — Minimal-Profil (`REPEATS=1`, nur KVM) für die Live-Demo im Vortrag
- **`roles/`** (auf die Gäste deployed, dort ausgeführt):
  - `roles/victim_benchmark.sh` — Opfer: 1 Lauf sysbench(cpu+mem) + fio → `cpu_eps;mem_mibps;iops;lat_p95_ms`
  - `roles/attacker_load.sh` — Angreifer: `start [s]` / `stop` / `run <s>`, stress-ng cache(L3)+hdd
- **`results/`** — Aggregat-CSVs (getrackt, Platzhalter) + `data/` (Rohdaten, gitignored)
- **`legacy/`** — `summary.csv` + `generate_dummy_data.sh`, **nur** fürs abgegebene Exposé (eingefroren)

Erststart: `./run_interference.sh --install --deploy-only` (installiert sysbench/fio/jq
bzw. stress-ng auf den Gästen). SSH-Key-Auth muss vorab stehen (Henne-Ei).
Aggregation = **Median** über `REPEATS` Läufe. Alle Skripte: `bash -n` + `shellcheck -x` sauber.

### Drei CSV-Schemata (NICHT vermischen!)

- `legacy/summary.csv` — Legacy-Dummy (`legacy/generate_dummy_data.sh`), `Virtualisierung;Baseline;NoisyNeighbor`, vom **abgegebenen Exposé** gelesen → unberührt lassen.
- `results/interference_summary.csv` — Interferenz-Experiment, `Szenario;CPU_Events_per_sec;Memory_MiBps;IOPS_Random_Write;Latenz_p95_ms`. Zeilen: `Baseline`, `NoisyNeighbor`, `Delta-Prozent` (Bindestrich, kein `_` — wegen `string type` im LaTeX-Typeset). Gelesen von `paper/main.tex`.
- `results/paradigms_summary.csv` — Paradigmen-Vergleich, `Virtualisierung;CPU_Base;CPU_NN;RAM_Base;RAM_NN;IOPS_Base;IOPS_NN;Lat_Base;Lat_NN`.

Beide `results/`-Aggregate sind mit **Platzhalterwerten** vorbelegt und werden
getrackt (Paper liest sie zur Compile-Zeit); echte Läufe überschreiben sie.

**Ergebnis-Historie (Methodik: `project/notes/Ergebnis-Historie.md`):** Die
kanonischen `*_summary.csv` bleiben der „aktuelle" Stand fürs Paper. Daneben
historisiert **jeder Lauf** unter `results/data/<TS>_<profil>[_<label>]/` mit
`summary.csv` + selbsterklärender `meta.txt` (Determinismus-Snapshot vom Host:
governor/no_turbo/max_cstate, git-Commit, Parameter). Append-only Vergleichs-Index:
`results/history/{interference,paradigms}_runs.csv`. Neu: **`--label TEXT`** (beide Run-Skripte)
kennzeichnet die Bedingung — Konvention `nodeterm`/`determ` für den
BIOS-Determinismus-Vergleich (Smoke: kein Label). `results/.gitignore` trackt
Aggregate/meta/Index, ignoriert Rohdaten (`*_raw.csv`, `*.log`). Determinismus-
Snapshot braucht `HOST_HOST` in der `*.env` (nn_experiment-Key auch auf dem Host).

**Diagramm-Design (entschieden):** gruppierte Balken, Baseline vs. Noisy Neighbor,
ein Diagramm je Metrik. Mock: `assets/mock_paradigms.{tex,csv,png}`.

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
- **Einleitung:** aus der zweiten Version übernommen (**Interferenz-Experiment = primär**).
  Zitate `koh2007analysis`, `ge2018survey`, `nist2014hypervisor` (alle in
  `references_expose.bib`). Die kaputten `intelvtx`/`kvmsecurity` sind raus → Bib baut.
  **Achtung:** Die zweite Version rahmt den Paradigmen-Vergleich noch als
  „Fallback/Rückfallebene" — das ist **obsolet** (das Interferenz-Experiment greift). Bei der finalen
  Überarbeitung wird der Begriff „Fallback" gestrichen und der Vergleich als
  eigenständige Einordnung geführt.
- **Abbildung 1** (`fig:setup`, Methodik): Testumgebungs-Topologie als **reines TikZ**
  (kein externes Bild), nachgebaut aus `Experiment-Topologie.canvas`. Control-Node →SSH→
  Host (P-Core 4,5, LLC) mit Angreifer + 3 Opfern, rote Contention-Pfeile.
- **Abbildung 2** (`fig:paradigms`, Ergebnisse): gruppierte Balken, 4 Metriken, `figure*`,
  liest `results/paradigms_summary.csv`; **eine** gemeinsame Legende (blau=Baseline,
  orange=Noisy Neighbor). Makro `\metricplot` in der Präambel (adaptiert aus `mock_paradigms.tex`).
- **Tabelle I** (`tab:results`): Median des Interferenz-Experiments aus `results/interference_summary.csv`, Spalten mit
  sauberen Anzeigenamen.
- Ergebnis-Abschnitt mit **Platzhalter-Hinweis** + interpretierender Prosa zu den
  Mock-Werten (klar als Arbeitshypothese markiert, nicht als Messung).

**Sobald echte Messwerte da sind — nächste Schritte:**

1. `./run_interference.sh` + `./run_paradigms.sh` laufen lassen → überschreiben die
   Platzhalter in `results/interference_summary.csv` / `results/paradigms_summary.csv`.
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

Slidev-Deck zum experimentellen Teil, lokal hostbar + **PDF-exportierbar**
(harte Abgabe-Anforderung). Node 18+ nötig. **Zeitrahmen (Aufgabenstellung):
insgesamt 10 min für Vortrag + technische Demo + Fragen** — Deck entsprechend
knapp halten.

```bash
cd presentation
npm install
npm run dev      # Live-Preview :3030
npm run build    # statische Website -> dist/
npm run export   # PDF (braucht playwright-chromium; siehe presentation/README.md)
```

- **Folien:** `slides.md` (eine Datei, `---`-getrennt, Speaker-Notes je Folie).
  Inhalt: Motivation/Themenwahl, Hintergrund, Homeserver, Topologie (Mermaid),
  Methodik, Codebasis (echte Snippets), Ergebnis-**Platzhalter** (Tabelle des Interferenz-Experiments +
  Paradigmen-Vergleich-Bild).
- **Platzhalter ersetzen:** Fotos → `public/img/homeserver/server.jpg`;
  Paradigmen-Vergleich-Diagramm → `public/img/mock_paradigms.png` überschreiben;
  Tabelle des Interferenz-Experiments aus `results/interference_summary.csv`.
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
