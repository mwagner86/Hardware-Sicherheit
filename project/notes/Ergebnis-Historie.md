# Ergebnis-Historie: Speicherung & Vergleich von Messläufen

Wie die Experiment-Suite (`../experiments/`) Testergebnisse **historisiert** und
**differenziert**, damit Läufe (Smoke vs. echt, mit vs. ohne BIOS-Determinismus)
reproduzierbar bleiben und direkt vergleichbar sind.

## Problem

Eine einzelne, bei jedem Lauf überschriebene Datei verliert die Historie. Zudem
war einem Lauf nicht anzusehen, **unter welchen Bedingungen** er entstand
(Profil, Determinismus-Zustand, Code-Stand).

## Drei Ebenen

| Ebene | Ort | Zweck | git |
| --- | --- | --- | --- |
| **Kanonisch (aktuell)** | `results/interference_summary.csv`, `results/paradigms_summary.csv` | „promoteter" Stand, den **das Paper zur Compile-Zeit liest** | getrackt |
| **Pro Lauf** | `results/data/<RUN_ID>/` | `summary.csv` (Aggregat) + `meta.txt` (Metadaten) + Rohdaten | Aggregat+meta getrackt, Rohdaten ignoriert |
| **Index (Vergleich)** | `results/history/interference_runs.csv`, `paradigms_runs.csv` | **append-only**, eine Zeile je Lauf/Opfer mit Kern-Deltas | getrackt |

Die kanonischen CSVs werden weiter überschrieben — das ist gewollt (das Paper
braucht **einen** aktuellen Stand). Die **Historie** liegt daneben und bleibt
vollständig erhalten.

## RUN_ID & Label

Jeder Lauf bekommt ein sprechendes Verzeichnis:

```
results/data/<TS>_<profil>[_<label>]/            # PoC
results/data/fallback_<TS>_<profil>[_<label>]/   # Fallback
```

- **`<profil>`** = Basename der `--config`-Datei (`smoke` | `config` | `demo`) —
  kennzeichnet den **Run-Typ** automatisch.
- **`--label TEXT`** kennzeichnet die **Bedingung** (freie Wahl). Konvention:

  | Lauf | Aufruf | RUN_ID |
  | --- | --- | --- |
  | Smoke (Mechanik) | `--config smoke.env` | `<ts>_smoke` |
  | Echt, **ohne** Determinismus | `--config config.env --label nodeterm` | `<ts>_config_nodeterm` |
  | Echt, **mit** Determinismus | `--config config.env --label determ` | `<ts>_config_determ` |

  → Beim Smoke also **kein** Label (Profil sagt schon „smoke").

## meta.txt (pro Lauf, selbsterklärend)

Enthält Zeitstempel, Skript, Profil, Label, `git_commit`, `repeats`, den
**Determinismus-Schnappschuss vom Host** und alle Benchmark-/Last-Parameter.

Der Determinismus wird **objektiv vom pve-Host** ausgelesen (nicht aus dem Label
geraten) — via `HOST_HOST` in der `*.env`:

- `det_governor` — CPU-Governor des P-Cores (`cat …/cpu4/…/scaling_governor`)
- `det_no_turbo` — `intel_pstate/no_turbo` (`1` = Turbo aus = deterministisch)
- `det_max_cstate` — `intel_idle/parameters/max_cstate` (`1` = C-States begrenzt)

So ist im Nachhinein zweifelsfrei belegt, ob ein Lauf im Determinismus-Modus lief.

## Vergleichen

Der Index ist eine `;`-CSV — direkt tabellarisch lesbar:

```bash
column -t -s';' results/history/interference_runs.csv
column -t -s';' results/history/paradigms_runs.csv
```

Spalten (PoC): `timestamp;label;profile;git;repeats;det_gov;det_no_turbo;det_max_cstate;cpu_delta;mem_delta;iops_delta;lat_delta;datadir`.
Fallback identisch, plus Spalte `victim` (eine Zeile je Opfer).

## Determinismus-Vergleich (der geplante Ablauf)

1. **Ohne Determinismus** (BIOS/Host noch nicht angefasst):
   `./run_interference.sh --config config.env --label nodeterm`
2. BIOS + Host-Determinismus setzen (siehe [Proxmox-Klickanleitung.md](Proxmox-Klickanleitung.md) Teil A+G, [Interferenz-Experiment.md](Interferenz-Experiment.md)).
3. **Mit Determinismus:**
   `./run_interference.sh --config config.env --label determ`
4. Vergleich: `column -t -s';' results/history/interference_runs.csv` — die `det_*`-Spalten
   belegen den Zustand, die Delta-Spalten zeigen den Effekt der Störlast je Bedingung.

## git-Politik

- **Getrackt:** kanonische Summaries, je Lauf `summary.csv` + `meta.txt`,
  `history/*.csv`. Klein, reproduzierbar.
- **Ignoriert** (`results/.gitignore`): Rohdaten je Lauf (`*_raw.csv`, `*.log`) —
  können groß werden; die Aggregate genügen für Historie & Reproduktion.
