# Experiment-Suite: Noisy-Neighbor-PoC

Automatisierte Messung mikroarchitektonischer Ressourcen-Interferenzen zwischen
einem **Angreifer-** und einem **Opfer-Gast** unter Proxmox VE (Intel Raptor Lake).
Beide Gäste sind host-seitig per CPU-Affinity auf **denselben physischen P-Core**
gepinnt (siehe [`../notes/PoC.md`](../notes/PoC.md)).

## Topologie

```text
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
| `config.env` | SSH-Ziele, Wiederholungen, Benchmark-/Last-Parameter, `FALLBACK_VICTIMS` |
| `lib/common.sh` | Logging, Median, Delta-Berechnung (geteilt) |
| `lib/orchestrator.sh` | geteilte Control-Node-Helfer: SSH/SCP, Deploy, Collect, Aggregation |
| `victim_benchmark.sh` | **Opfer**: ein Messdurchlauf → `cpu_eps;mem_mibps;iops;lat_p95_ms` |
| `attacker_load.sh` | **Angreifer**: `start [s]` / `stop` / `run <s>` der Störlast |
| `run_experiment.sh` | **PoC**: Angreifer + 1 Opfer → Baseline/Noisy → `poc_summary.csv` |
| `run_fallback.sh` | **Fallback**: 3 Opfer (QEMU/LXC/KVM) sequenziell → `fallback_summary.csv` |
| `data/<ts>/` | PoC je Lauf: `baseline_raw.csv`, `noisy_raw.csv`, `summary.csv` |
| `data/fallback_<ts>/` | Fallback: je Opfer ein Unterordner + `fallback_summary.csv` |
| `poc_summary.csv` | letztes PoC-Aggregat (Paper-Tabelle) |
| `fallback_summary.csv` | letztes Fallback-Aggregat (gruppiertes Balkendiagramm) |

## Nutzung

```bash
# 1. config.env anpassen (ATTACKER_HOST / VICTIM_HOST / ...)

# 2. Werkzeuge einmalig auf den Gästen installieren + Skripte ausrollen
./run_experiment.sh --install --deploy-only

# 3. PoC: Angreifer + 1 Opfer (Deploy + Messung + Aggregation)
./run_experiment.sh

# 4. Fallback: alle 3 Opfer (QEMU/LXC/KVM) sequenziell vergleichen
./run_fallback.sh --install        # erster Lauf installiert auf allen Opfern
./run_fallback.sh                  # weitere Läufe

# Weitere Optionen
./run_experiment.sh --no-deploy        # Skripte schon ausgerollt
./run_experiment.sh --config other.env
```

Welches Opfer der PoC nutzt, steht in `VICTIM_HOST`; die drei Fallback-Opfer in
`FALLBACK_VICTIMS` (`config.env`). Der Angreifer (`ATTACKER_HOST`) ist in beiden
Fällen konstant.

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

- `poc_summary.csv` = **PoC** (run_experiment.sh), Schema
  `Szenario;CPU_Events_per_sec;Memory_MiBps;IOPS_Random_Write;Latenz_p95_ms`.
- `fallback_summary.csv` = **Fallback** (run_fallback.sh), Schema
  `Virtualisierung;CPU_Base;CPU_NN;RAM_Base;RAM_NN;IOPS_Base;IOPS_NN;Lat_Base;Lat_NN`
  — passt zum gruppierten Balkendiagramm (`assets/mock_fallback.tex`).
- `summary.csv` = **Legacy-Dummy** (`generate_dummy_data.sh`, Schema
  `Virtualisierung;Baseline;NoisyNeighbor`); vom abgegebenen Exposé gelesen,
  bewusst unberührt.

Offen (eigener Arbeitsschritt bei der Paper-Integration): `paper/main.tex`
referenziert noch `summary.csv` mit PoC-Spalten → auf `poc_summary.csv` umstellen;
das gruppierte Diagramm auf `fallback_summary.csv` setzen.
