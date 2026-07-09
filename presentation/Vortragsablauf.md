# Vortrags-Runbook — Noisy-Neighbor-Demo

Schritt-für-Schritt: welche Skripte wann, und wie die Live-Demo + das Dashboard
zusammenspielen. Alles läuft vom **Control-Node** (dein Laptop) aus, im
Verzeichnis [`project/experiments/`](../project/experiments/).

**Dashboard:** [`dashboard.html`](dashboard.html) — eigenständige Datei, per
Doppelklick im Browser öffnen (offline, keine Abhängigkeit). Zeigt den echten PoC
+ Paradigmen-Vergleich; Button **„＋ Live-Lauf einblenden"** für die Demo.

> **⚠️ Dashboard ≠ Live-Lauf — die beiden sind NICHT gekoppelt.** Das
> `dashboard.html` ist bewusst statisch/eingebettet (offline, Doppelklick, kein
> Server). Der Button **„＋ Live-Lauf einblenden"** blendet einen **fest
> vorverdrahteten** Lauf ein (`pending`-Block in `dashboard.html`) — hardcodierte
> Zahlen, live ist daran nur der **Zeitstempel** (= jetzt). Die echte
> CSV-Anbindung (`fetch('/api/runs')`) ist absichtlich auskommentiert (Variante B).
> **Konsequenz:** Der Terminal-Lauf erzeugt **echte** Daten auf der Platte (CSV,
> Historie, Datenverzeichnis) — der Dashboard-Button „updated" aber nur
> **kosmetisch** und zeigt immer dieselben eingebetteten Demo-Werte, egal was der
> Lauf tatsächlich gemessen hat. Fürs Publikum unsichtbar und legitim inszeniert;
> nur du als Vortragende:r solltest wissen, dass sie nicht verkoppelt sind.

---

## 0. Zwei Datensorten — nicht verwechseln

| | rigoros (fürs Ergebnis) | Live-Demo (fürs „es läuft") |
| --- | --- | --- |
| Profil | `config.env` | `demo.env` |
| Wiederholungen | `REPEATS=10` | `REPEATS=1` |
| Opfer | KVM (PoC) bzw. alle 3 (Vergleich) | nur KVM |
| Dauer | ~25 min / ~60 min | **~30–45 s** |
| Zweck | die belastbaren Deltas | beweisen, dass echter Code läuft |

Der **PoC-Effekt** (−48 % IOPS, +407 % p95-Latenz) stammt aus dem `config`-Lauf.
Die **Live-Demo** ist bewusst winzig und verrauscht — sie beweist nur die Pipeline.

---

## 1. Vor dem Vortrag (einmalig, ~5 min vorher)

```bash
cd project/experiments

# a) Gäste erreichbar? (dedizierter Key steckt in SSH_OPTS, kein ssh-agent nötig)
for ip in 210 213; do ssh -o BatchMode=yes -o ConnectTimeout=5 \
  -i ~/.ssh/nn_experiment -o IdentitiesOnly=yes root@192.168.178.$ip true \
  && echo ".$ip ok" || echo ".$ip FEHLT"; done

# b) Werkzeuge + Skripte ausrollen (nimmt apt aus der Live-Demo raus)
./run_experiment.sh --config demo.env --install --deploy-only

# c) Ein stiller Probelauf, damit der Host-Key-Trust & alles sitzt
./run_experiment.sh --config demo.env --no-deploy
```

- **Dashboard** in einem Browser-Tab öffnen (Beamer-tauglich, dunkel).
- **Terminal** groß & lesbar (Schriftgröße hoch), im `project/experiments/`-Verzeichnis.
- **Sicherheitsnetz:** einen Screenshot des Dashboards + einen Mitschnitt der
  Terminal-Ausgabe bereithalten, falls das Heimnetz zickt.

> Host-Determinismus ist für die Demo **nicht** nötig (die Live-Zahlen zählen
> nicht). Der rigorose PoC lief bewusst „nodeterm" — das steht so im Dashboard.

---

## 1b. Rehearsal — manueller Probelauf mit Verifikation

Wie der echte Demo-Lauf, nur dass du hinterher prüfst, dass wirklich Daten
entstanden sind, und danach sauber zurücksetzt. Alles im
`project/experiments/`-Verzeichnis.

```bash
cd project/experiments

# 1) Erreichbarkeit (optional)
for ip in 210 213; do ssh -o BatchMode=yes -o ConnectTimeout=5 \
  -i ~/.ssh/nn_experiment -o IdentitiesOnly=yes root@192.168.178.$ip true \
  && echo ".$ip ok" || echo ".$ip FEHLT"; done

# 2) Der Live-Lauf (~30–45 s) — der eigentliche Demo-Befehl
./run_experiment.sh --config demo.env --no-deploy

# 3) Prüfen, dass ECHTE Daten entstanden sind (das echte "Update")
cat results/poc_summary.csv                  # frisch überschrieben
tail -n 2 results/history/poc_runs.csv       # neuer Historien-Eintrag
ls -td results/data/*_demo* | head -1        # neues Datenverzeichnis
```

**Dashboard prüfen** (Browser): `dashboard.html` öffnen → Button **„＋ Live-Lauf
einblenden"**. Neuer Lauf ploppt oben rein (Puls + Toast). Zeigt die
**eingebetteten** Demo-Werte, nicht die aus Schritt 2 — siehe Warnung ganz oben.

### Nach dem Rehearsal aufräumen

Der Lauf verändert getrackte Dateien und legt ein neues Verzeichnis an. So setzt
du sauber zurück — direkt aus `project/experiments/` (wo du nach der Demo stehst;
die Pfade sind relativ zu diesem Verzeichnis):

```bash
git checkout results/poc_summary.csv results/history/poc_runs.csv
git clean -fd results/data/                          # entfernt das Demo-Datenverzeichnis
ssh -i ~/.ssh/nn_experiment root@192.168.178.210 'pgrep -a stress-ng'  # sollte leer sein
```

Willst du den Demo-Stand behalten, lass das Aufräumen weg — fürs Paper zählt der
`config/nodeterm`-Lauf, nicht `poc_summary.csv`.

---

## 2. Während des Vortrags — die Choreografie

### Folie „Live-Demo: die Pipeline läuft"

**Sagen:** „Das ist kein Foliengemälde — der Code läuft jetzt wirklich."

```bash
# LIVE (~30–45 s): Baseline → Störlast → erneut messen → Delta → CSV
./run_experiment.sh --config demo.env --no-deploy
```

Während es läuft, die Log-Zeilen mitlesen: `Baseline Lauf 1/1` → `Störlast
gestartet` → `NoisyNeighbor Lauf 1/1` → `Störlast gestoppt` → `Fertig. Ergebnis:`
mit der CSV-Zeile. **Das** ist der Beweis, dass echte Daten entstehen.

### Folie „PoC-Ergebnis" → zum Dashboard wechseln

1. **Dashboard zeigen.** Es steht bereits auf dem **echten PoC** (KVM, 10×,
   Determinismus AUS): die vier Stat-Tiles (CPU −21 %, Memory −45 %, IOPS −48 %,
   **Latenz +407 %**) und die Balken. Das ist das Kern-Ergebnis — in Ruhe erklären.
2. **Erst danach** den Live-Lauf sichtbar machen: Button **„＋ Live-Lauf
   einblenden"** klicken. Der eben erzeugte Lauf ploppt oben in die Historie
   (Puls + Toast „Neuer Lauf erfasst"). **Sagen:** „Und der Lauf von gerade eben
   ist genau dieser neue Datenpunkt."
3. Optional den neuen Lauf anklicken → er lädt oben; man sieht, dass die
   Demo-Zahlen (nur 1×, verrauscht) neben dem rigorosen PoC stehen.

> Reihenfolge ist Absicht: **erst das belastbare Ergebnis**, dann der Beweis der
> Live-Datenerzeugung. So wird die Demo nicht mit dem Ergebnis verwechselt.

### Folie „Paradigmen-Vergleich"

Im Dashboard die Metrik-Umschalter (CPU / Memory / IOPS / Latenz) nutzen, um zu
zeigen, wie unterschiedlich LXC vs. KVM unter Störlast einbrechen.

---

## 3. Datenstand pflegen (wenn neue Messungen da sind)

Die realen Werte liegen in `results/history/{poc,fallback}_runs.csv` und je Lauf
in `results/data/<lauf>/summary.csv` (siehe [`Ergebnis-Historie.md`](../project/notes/Ergebnis-Historie.md)).
Zum Aktualisieren des Dashboards die Zahlen im `EMBEDDED`-Block in
[`dashboard.html`](dashboard.html) ersetzen und die Datei neu im Browser öffnen
(kein Deploy nötig). Aktuell noch **vorläufig**: der
Paradigmen-Vergleich (Smoke-Werte) — der echte `config/nodeterm`-Fallback-Lauf
wird eingepflegt, sobald fertig.

---

## 4. Falls etwas klemmt

| Problem | Sofort-Reaktion |
| --- | --- |
| Live-Lauf hängt / Netz weg | abbrechen (`Ctrl-C`), Mitschnitt der Terminal-Ausgabe zeigen; Dashboard-Button trotzdem klicken |
| SSH „Permission denied" | Key-Pfad prüfen: `ls ~/.ssh/nn_experiment`; Gast erreichbar? (Schritt 1a) |
| Angreifer-Restlast | `ssh -i ~/.ssh/nn_experiment root@192.168.178.210 'pgrep -a stress-ng'` (sollte leer sein; sonst `attacker_load.sh stop`) |
| Beamer zu hell für Dark-Mode | Dashboard-Button **◐ Theme** → Light |
