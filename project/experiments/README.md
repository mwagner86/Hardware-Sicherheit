# Experiment-Suite: Noisy-Neighbor-PoC

Automatisierte Messung mikroarchitektonischer Ressourcen-Interferenzen zwischen
einem **Angreifer-** und einem **Opfer-Gast** unter Proxmox VE (Intel Raptor Lake).
Beide Gäste sind host-seitig per CPU-Affinity auf **denselben physischen P-Core**
gepinnt (siehe [`../notes/PoC.md`](../notes/PoC.md)).

## Verzeichnisstruktur

```text
experiments/
├── run_experiment.sh     # Control-Node: PoC-Orchestrator     → results/poc_summary.csv
├── run_fallback.sh       # Control-Node: Fallback-Orchestrator → results/fallback_summary.csv
├── config.env            # SSH-Ziele + Versuchsparameter (voller Lauf)
├── smoke.env             # dito, verkürzt — reine Funktionsprüfung (../notes/Smoke-Test.md)
├── demo.env              # dito, minimal (REPEATS=1, nur KVM) — Live-Demo im Vortrag
├── lib/                  # geteilte Control-Node-Logik
│   ├── common.sh         #   Logging, Median, Delta (auch auf Gäste deployed)
│   └── orchestrator.sh   #   SSH/SCP, Deploy, Collect, Aggregation
├── roles/                # werden auf die GÄSTE deployed und dort ausgeführt
│   ├── victim_benchmark.sh   # Opfer: sysbench (cpu+mem) + fio
│   └── attacker_load.sh      # Angreifer: stress-ng cache(L3)+hdd
├── results/              # ERGEBNISSE
│   ├── poc_summary.csv       # PoC-Aggregat (Paper-Tabelle) — getrackt, Platzhalter
│   ├── fallback_summary.csv  # Fallback-Aggregat (Paper-Diagramm) — getrackt, Platzhalter
│   └── data/                 # Rohdaten + Gast-Logs je Lauf (gitignored)
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

# 4. Fallback: 3 Opfer (QEMU/LXC/KVM) sequenziell → results/fallback_summary.csv
./run_fallback.sh --install        # erster Lauf installiert auf allen Opfern
./run_fallback.sh                  # weitere Läufe

# Weitere Optionen
./run_experiment.sh --no-deploy        # Skripte schon ausgerollt
./run_experiment.sh --config smoke.env # Smoke-Test-Profil (kurze Läufe)
./run_experiment.sh --config demo.env  # Live-Demo: REPEATS=1, nur KVM (~30–45 s)
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
| `legacy/summary.csv` | `legacy/generate_dummy_data.sh` | `Virtualisierung;Baseline;NoisyNeighbor` | **abgegebenes** Exposé — eingefroren |

Die beiden `results/`-Aggregate sind mit **Platzhalterwerten** vorbelegt und
werden **getrackt** (das Paper liest sie zur Compile-Zeit). Echte Messläufe
überschreiben sie; die Rohdaten unter `results/data/` sind gitignored.

## Host-Determinismus (zwingend, host-seitig)

Vor Messungen auf dem Proxmox-Host: C-States deaktivieren, Turbo Boost aus,
Governor `performance` (siehe [`../notes/PoC.md`](../notes/PoC.md)). Im Gast ist
das oft nicht sichtbar — `run_experiment.sh` warnt nur best-effort.
