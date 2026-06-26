# Experiment-Suite: Noisy-Neighbor-PoC

Automatisierte Messung mikroarchitektonischer Ressourcen-Interferenzen zwischen
einem **Angreifer-** und einem **Opfer-Gast** unter Proxmox VE (Intel Raptor Lake).
Beide Gäste sind host-seitig per CPU-Affinity auf **denselben physischen P-Core**
gepinnt (siehe [`../notes/PoC.md`](../notes/PoC.md)).

## Topologie

```
  Control-Node (Laptop)              run_experiment.sh
        │  SSH                          │
        ├──────────────► Opfer-Gast    (victim_benchmark.sh: sysbench, fio)
        └──────────────► Angreifer-Gast (attacker_load.sh: stress-ng cache+hdd)
```

Der Control-Node orchestriert; er misst nicht selbst. Voraussetzung:
SSH-Key-Auth zu beiden Gästen (kein Passwort-Prompt).

## Dateien

| Datei | Rolle |
| --- | --- |
| `config.env` | SSH-Ziele, Wiederholungen, Benchmark-/Last-Parameter |
| `lib/common.sh` | Logging, Median, Delta-Berechnung (geteilt) |
| `victim_benchmark.sh` | **Opfer**: ein Messdurchlauf → `cpu_eps;mem_mibps;iops;lat_p95_ms` |
| `attacker_load.sh` | **Angreifer**: `start [s]` / `stop` / `run <s>` der Störlast |
| `run_experiment.sh` | **Control-Node**: Deploy + Baseline + Noisy + Aggregation |
| `data/<ts>/` | je Lauf: `baseline_raw.csv`, `noisy_raw.csv`, `summary.csv` |
| `poc_summary.csv` | jeweils letztes Aggregat (Paper-Tabelle) |

## Nutzung

```bash
# 1. config.env anpassen (ATTACKER_HOST / VICTIM_HOST / ...)

# 2. Werkzeuge einmalig auf den Gästen installieren + Skripte ausrollen
./run_experiment.sh --install --deploy-only

# 3. Vollständiges Experiment (Deploy + Messung + Aggregation)
./run_experiment.sh

# Weitere Optionen
./run_experiment.sh --no-deploy        # Skripte schon ausgerollt
./run_experiment.sh --config other.env
```

## Messgrößen

| Spalte | Werkzeug | Bedeutung | Richtung |
| --- | --- | --- | --- |
| `CPU_Events_per_sec` | `sysbench cpu` | Rechendurchsatz | höher = besser |
| `Memory_MiBps` | `sysbench memory` | Speicherbandbreite | höher = besser |
| `IOPS_Random_Write` | `fio` (4K randwrite, direct) | I/O-Durchsatz | höher = besser |
| `Latenz_p95_ms` | `fio` clat p95 | I/O-Latenz | niedriger = besser |

`summary.csv` enthält je eine Zeile **Baseline**, **NoisyNeighbor** und
**Delta_Prozent** (prozentuale Veränderung Baseline → Last). Aggregiert wird der
**Median** über `REPEATS` Wiederholungen.

## Host-Determinismus (zwingend, host-seitig)

Vor Messungen auf dem Proxmox-Host: C-States deaktivieren, Turbo Boost aus,
Governor `performance` (siehe [`../notes/PoC.md`](../notes/PoC.md)). Im Gast ist
das oft nicht sichtbar — `run_experiment.sh` warnt nur best-effort.

## Hinweis zur Datenpipeline (offen)

- `poc_summary.csv` = **PoC** (dieses Skript).
- `summary.csv` = aktuell Dummy-Daten der **Fallback**-Strategie (QEMU/LXC/KVM),
  erzeugt von `generate_dummy_data.sh`; wird vom Exposé-Balkendiagramm gelesen.

`paper/main.tex` referenziert derzeit `summary.csv` mit PoC-Spalten — diese
Verknüpfung muss bei der Paper-Integration auf `poc_summary.csv` umgestellt
werden (eigener Arbeitsschritt).
