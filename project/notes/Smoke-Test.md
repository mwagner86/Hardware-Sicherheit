# Smoke-Test: Pipeline validieren (vor dem Host-Determinismus)

Ziel dieses Durchlaufs ist **ausschließlich die Funktionsprüfung** der Mess-Suite
— SSH-Key-Auth, Deploy nach `REMOTE_DIR`, Benchmark-Aufruf auf den Gästen,
fio/`jq`-Parsing, Median/Delta-Aggregation und das CSV-Schreiben. Er läuft
**bewusst ohne** den Host-Determinismus aus [`PoC.md`](PoC.md) (C-States, Turbo,
Governor) und liefert daher **keine belastbaren Zahlen**.

> **Reihenfolge:** erst hier die Mechanik grün bekommen → dann BIOS/Bootloader
> (Determinismus) → dann der echte Messlauf mit [`../experiments/config.env`](../experiments/config.env).

Profil: [`../experiments/smoke.env`](../experiments/smoke.env) (kurze Läufe,
`REPEATS=2`, nur schnelle Opfer). Für die Live-Demo im Vortrag gibt es zusätzlich
[`../experiments/demo.env`](../experiments/demo.env) (noch minimaler: `REPEATS=1`,
nur KVM-Opfer, ~30–45 s; PoC-only via `run_experiment.sh`).

---

## 1. Voraussetzungen

- **Alle vier Instanzen existieren und laufen**, jeweils mit gesetztem
  CPU-Pinning auf `4,5` (das ist VM-Config, *nicht* BIOS — siehe
  [`VM-Deployment.md`](VM-Deployment.md), inkl. Verifikation in Abschnitt 8).
  Der Determinismus darf noch fehlen.
- **SSH-Key-Auth steht** vom Control-Node (Laptop) zu allen Gästen
  (kein Passwort-Prompt). Henne-Ei: das kann das Skript nicht selbst lösen.
  Schnelltest:

  ```bash
  for ip in 200 202 203; do ssh -o BatchMode=yes root@192.168.178.$ip true \
    && echo ".$ip ok" || echo ".$ip FEHLT"; done
  ```

  (Das QEMU-Opfer `.201` lassen wir im Smoke-Test bewusst außen vor — als
  Emulation ist es zäh; der Code-Pfad ist identisch zu den anderen Opfern.)

---

## 2. Ablauf

Alles vom **Control-Node** aus, im Verzeichnis [`../experiments/`](../experiments/):

```bash
cd project/experiments

# (a) Einmalig: Werkzeuge auf den Gästen installieren + Skripte ausrollen
./run_experiment.sh --config smoke.env --install --deploy-only

# (b) PoC-Mechanik prüfen (Angreifer 200 + KVM-Opfer 203)
./run_experiment.sh --config smoke.env

# (c) Fallback-Mechanik prüfen (LXC 202 + KVM 203, sequenziell)
./run_fallback.sh --config smoke.env
```

Erwartete Dauer: jeweils ~1–2 min (mit den Kurz-Parametern aus `smoke.env`).

---

## 3. Erfolgskriterien

Der Test ist **grün**, wenn alle drei Aufrufe mit **Exit-Code 0** enden und
folgende Artefakte plausibel gefüllt sind. (Die Orchestrierung `die`t bei einer
nicht parsebaren Messzeile — ein sauberer Durchlauf beweist also bereits, dass
das Parsing funktioniert.)

```bash
echo "exit: $?"            # muss 0 sein

# PoC: 3 Zeilen (Baseline / NoisyNeighbor / Delta-Prozent), keine leeren Felder
cat results/poc_summary.csv

# Fallback: Header + je eine Zeile pro Opfer (LXC, KVM)
cat results/fallback_summary.csv

# Rohdaten je Phase: Header + REPEATS(=2) Datenzeilen
ls -1 results/data/*/ | tail
```

Konkret prüfen:

| Check | Soll |
| --- | --- |
| Exit-Code aller drei Aufrufe | `0` |
| `results/data/<ts>/baseline_raw.csv` / `noisy_raw.csv` | Header + **2** Datenzeilen, alle Spalten gefüllt |
| `results/poc_summary.csv` | 3 Zeilen, Schema `Szenario;CPU_Events_per_sec;Memory_MiBps;IOPS_Random_Write;Latenz_p95_ms` |
| `results/fallback_summary.csv` | Header + 2 Opfer-Zeilen, Schema `Virtualisierung;CPU_Base;CPU_NN;...;Lat_NN` |
| Werte | numerisch, **kein** `NaN`, IOPS/Events > 0 |

> Die absoluten Zahlen und das `Delta-Prozent` sind hier **bedeutungslos** (ohne
> Determinismus stark verrauscht, Vorzeichen ggf. zufällig). Geprüft wird nur,
> *dass* Werte sauber erzeugt, geparst und aggregiert werden.

---

## 4. Worauf besonders achten (typische Stolpersteine)

- **`jq` fehlt auf dem Opfer.** Dann nutzt [`roles/victim_benchmark.sh:81`](../experiments/roles/victim_benchmark.sh#L81)
  einen grep-Fallback für fio-JSON (ungenauer) und der Preflight `warn`t nur.
  Für saubere Latenz-Perzentile `--install` laufen lassen (installiert `jq` mit).
- **fio `--direct=1` + `libaio` im unprivilegierten LXC (202).** O_DIRECT/AIO
  kann je nach Storage-Backend im Container scheitern. Genau so ein Fund ist der
  Sinn des Smoke-Tests: bricht fio dort ab, fällt es hier auf — *bevor* du Stunden
  in den echten Lauf steckst. (Auf der KVM-VM 203 unkritisch.)
- **Governor-Warnung im Preflight** ([`run_experiment.sh:70`](../experiments/run_experiment.sh#L70))
  ist hier **erwartet und harmlos** — der Determinismus steht ja noch nicht. Sie
  `die`t nicht.
- **Restlast des Angreifers.** `attacker_stop` ist als EXIT-Trap idempotent
  hinterlegt; nach einem Abbruch trotzdem kurz gegenprüfen:
  `ssh root@192.168.178.200 'pgrep -a stress-ng'` (sollte leer sein).

---

## 5. Übergang zum echten Lauf

Nach grünem Smoke-Test:

1. Host-Determinismus herstellen — [`PoC.md`](PoC.md) Abschnitt 1–2 (GRUB-Kernel-
   cmdline + `reboot`, danach Turbo aus / Governor `performance`). Der Reboot
   stoppt die Gäste kurz; ihre Definitionen überleben — anschließend wieder
   starten (bzw. Autostart).
2. Pinning erneut verifizieren ([`VM-Deployment.md`](VM-Deployment.md) Abschnitt 8).
3. Echte Läufe **ohne** `--config smoke.env` (nutzt dann
   [`config.env`](../experiments/config.env) mit vollen Parametern):

   ```bash
   ./run_experiment.sh           # PoC  -> results/poc_summary.csv
   ./run_fallback.sh             # alle drei Opfer -> results/fallback_summary.csv
   ```

`smoke.env` bleibt als Profil liegen und kann jederzeit erneut für reine
Mechanik-Checks genutzt werden.
