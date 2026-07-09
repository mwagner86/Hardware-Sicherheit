# Experiment-Suite: Noisy-Neighbor-PoC

Automatisierte Messung mikroarchitektonischer Ressourcen-Interferenzen zwischen
einem **Angreifer-** und einem **Opfer-Gast** unter Proxmox VE (Intel Raptor Lake).
Beide Gäste sind host-seitig per CPU-Affinity auf **denselben physischen P-Core**
gepinnt (siehe [`../notes/PoC.md`](../notes/PoC.md)).

## Status (2026-07-05)

- **PoC erfolgreich.** Der erste echte Lauf (Profil `config`, Label `nodeterm`,
  10 Wiederholungen) weist den Effekt eindeutig nach: **CPU −21 %, RAM −45 %,
  IOPS −48 %, p95-Latenz +407 %** (KVM-Opfer unter konstanter L3-Störlast).
  Rohdaten unter `results/data/20260705_141654_config_nodeterm/`, Vergleichs-Index
  in `results/history/poc_runs.csv`.
- **Codebasis komplett, Benchmarks sauber und orchestrierbar.** Pipeline läuft
  vom Control-Node durch (SSH → Deploy → Messen → Median → CSV); Werte sind
  reproduzierbar und für das Paper verwendbar.
- **Determinismus-Lauf steht noch aus.** Die finalen Zahlen fürs IEEE-Paper
  liefert ein Lauf mit BIOS-Determinismus (Label `determ`). Bis dahin bleibt die
  kanonische `results/poc_summary.csv` bewusst auf **Platzhalterwerten** — der
  `nodeterm`-Lauf validiert Methodik und Pipeline, ersetzt aber die Paper-Zahlen
  noch nicht.
- **Fallback zu den Akten gelegt.** Da der PoC eindeutig greift, ist der
  3-Paradigmen-Vergleich (QEMU/LXC/KVM) **nicht mehr Rückfallebene**, sondern
  höchstens ergänzende Einordnung. `run_fallback.sh` bleibt lauffähig (ein
  `nodeterm`-Lauf existiert bereits), wird aber nicht weiter verfolgt.

## Verzeichnisstruktur

```text
experiments/
├── run_experiment.sh     # Control-Node: PoC-Orchestrator     → results/poc_summary.csv
├── run_fallback.sh       # Control-Node: Fallback-Orchestrator → results/fallback_summary.csv
├── measure_llc.sh        # Control-Node: host-seitige LLC-Miss-Messung → results/llc_summary.csv
├── config.env            # SSH-Ziele + Versuchsparameter (voller Lauf)
├── smoke.env             # dito, verkürzt — reine Funktionsprüfung (../notes/Smoke-Test.md)
├── demo.env              # dito, minimal (REPEATS=1, nur KVM) — Live-Demo im Vortrag
├── lib/                  # geteilte Control-Node-Logik
│   ├── common.sh         #   Logging, Median, Delta (auch auf Gäste deployed)
│   └── orchestrator.sh   #   SSH/SCP, Deploy, Collect, Aggregation
├── roles/                # werden auf die GÄSTE deployed und dort ausgeführt
│   ├── victim_benchmark.sh   # Opfer: sysbench (cpu+mem) + fio
│   └── attacker_load.sh      # Angreifer: stress-ng cache(L3)+hdd
├── results/              # ERGEBNISSE (Historie: ../notes/Ergebnis-Historie.md)
│   ├── poc_summary.csv       # kanonisches PoC-Aggregat (Paper-Tabelle) — getrackt, Platzhalter
│   ├── fallback_summary.csv  # kanonisches Fallback-Aggregat (Paper-Diagramm) — getrackt, Platzhalter
│   ├── history/              # append-only Vergleichs-Index je Lauf — getrackt
│   │   ├── poc_runs.csv
│   │   └── fallback_runs.csv
│   └── data/<TS>_<profil>[_<label>]/   # je Lauf: summary.csv + meta.txt (getrackt),
│                                       #          *_raw.csv + *.log (gitignored)
└── legacy/               # eingefroren, NUR für das abgegebene Exposé
    ├── summary.csv           # Dummy-CSV, die expose_hardware_security.tex liest
    └── generate_dummy_data.sh
```

**Trennung „wo läuft was":** Alles im Top-Level + `lib/` läuft auf dem
**Control-Node (Laptop)**; die Skripte in `roles/` werden per SCP auf die Gäste
ausgerollt und dort ausgeführt. Der Control-Node orchestriert nur, er misst nicht
selbst. Voraussetzung: SSH-Key-Auth zu allen Gästen (kein Passwort-Prompt).

## Nutzung

```bash
# 1. config.env anpassen (ATTACKER_HOST / VICTIM_HOST / FALLBACK_VICTIMS)

# 2. Werkzeuge einmalig auf den Gästen installieren + Skripte ausrollen
./run_experiment.sh --install --deploy-only

# 3. PoC: Angreifer + 1 Opfer  → results/poc_summary.csv
./run_experiment.sh

# 4. Fallback (zu den Akten gelegt, s. Status): 3 Opfer (QEMU/LXC/KVM) sequenziell
./run_fallback.sh --install        # erster Lauf installiert auf allen Opfern
./run_fallback.sh                  # weitere Läufe

# Weitere Optionen
./run_experiment.sh --no-deploy        # Skripte schon ausgerollt
./run_experiment.sh --config smoke.env # Smoke-Test-Profil (kurze Läufe)
./run_experiment.sh --config demo.env  # Live-Demo: REPEATS=1, nur KVM (~30–45 s)

# Kausalnachweis Cache-Contention: LLC-Miss-Rate am geteilten Core (host-seitig,
# da der KVM-Gast keine vPMU hat). Erststart mit --install (perf auf dem Host).
./measure_llc.sh --install             # perf auf dem Host installieren
./measure_llc.sh --label determ        # Baseline vs. NN → results/llc_summary.csv
```

Welches Opfer der PoC nutzt, steht in `VICTIM_HOST`; die drei Fallback-Opfer in
`FALLBACK_VICTIMS` (`config.env`). Der Angreifer (`ATTACKER_HOST`) ist in beiden
Fällen konstant.

> **Vor dem ersten echten Lauf:** Pipeline mit dem Smoke-Test-Profil prüfen —
> siehe [`../notes/Smoke-Test.md`](../notes/Smoke-Test.md). Erst danach den
> Host-Determinismus herstellen und voll messen.

## Diagnose & Sicherheitsnetz

- **Gast-Logs:** stderr der Opfer-Benchmarks (Fortschritt, Fehlermeldungen)
  landet je Phase neben der Roh-CSV, z. B. `results/data/<ts>/baseline_raw.log`.
  Bricht der Orchestrator mit „nicht parsebar" ab, zuerst dort nachsehen.
- **Störlast-Sicherheitsnetz:** `attacker_load.sh start` läuft mit 1 h
  Default-Timeout — reiner Schutz vor verwaisten Läufen (etwa bei Absturz des
  Control-Node); regulär stoppt der Orchestrator die Last immer explizit.
  Bewusst kein knapp kalkuliertes Zeitbudget: das könnte mitten in der
  Messphase ablaufen (sysbench memory ist volumen-, nicht zeitgebunden) und
  die NoisyNeighbor-Werte still verfälschen. Meldet `stop` die Warnung
  „Störlast … lief bereits nicht mehr", endete die Last vorzeitig — die
  NoisyNeighbor-Werte dieser Phase sind dann nicht belastbar.

## Messgrößen

| Spalte | Werkzeug | Bedeutung | Richtung |
| --- | --- | --- | --- |
| `CPU_Events_per_sec` | `sysbench cpu` | Rechendurchsatz | höher = besser |
| `Memory_MiBps` | `sysbench memory` | Speicherbandbreite | höher = besser |
| `IOPS_Random_Write` | `fio` (4K randwrite, direct) | I/O-Durchsatz | höher = besser |
| `Latenz_p95_ms` | `fio` clat p95 | I/O-Latenz | niedriger = besser |

`roles/victim_benchmark.sh` gibt je Lauf eine Zeile
`cpu_eps;mem_mibps;iops;lat_p95_ms` aus. Aggregiert wird der **Median** über
`REPEATS` Wiederholungen.

## Drei CSV-Schemata (NICHT vermischen)

| Datei | Erzeuger | Schema | gelesen von |
| --- | --- | --- | --- |
| `results/poc_summary.csv` | `run_experiment.sh` | `Szenario;CPU_Events_per_sec;Memory_MiBps;IOPS_Random_Write;Latenz_p95_ms` | `paper/main.tex` (Tabelle) |
| `results/fallback_summary.csv` | `run_fallback.sh` | `Virtualisierung;CPU_Base;CPU_NN;RAM_Base;RAM_NN;IOPS_Base;IOPS_NN;Lat_Base;Lat_NN` | gruppiertes Balkendiagramm (vgl. `assets/mock_fallback.tex`) |
| `results/llc_summary.csv` | `measure_llc.sh` | `Szenario;LLC_Loads;LLC_Load_Misses;Miss_Rate_Pct` | Kausalnachweis (host-seitig, fürs Paper vorgesehen) |
| `legacy/summary.csv` | `legacy/generate_dummy_data.sh` | `Virtualisierung;Baseline;NoisyNeighbor` | **abgegebenes** Exposé — eingefroren |

Die beiden `results/`-Aggregate sind mit **Platzhalterwerten** vorbelegt und
werden **getrackt** (das Paper liest sie zur Compile-Zeit). Echte Messläufe
überschreiben sie. Zusätzlich historisiert jeder Lauf nach
`results/data/<TS>_<profil>[_<label>]/` (`summary.csv` + `meta.txt` getrackt,
Rohdaten `*_raw.csv`/`*.log` gitignored) und ergänzt den Vergleichs-Index unter
`results/history/`. Läufe per **`--label`** kennzeichnen (`nodeterm`/`determ`);
Details: [`../notes/Ergebnis-Historie.md`](../notes/Ergebnis-Historie.md).

## Host-Determinismus (zwingend, host-seitig)

Vor Messungen auf dem Proxmox-Host: C-States deaktivieren, Turbo Boost aus,
Governor `performance` (siehe [`../notes/PoC.md`](../notes/PoC.md)). Im Gast ist
das oft nicht sichtbar — `run_experiment.sh` warnt nur best-effort.
