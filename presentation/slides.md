---
theme: default
title: Der Noisy-Neighbor-Effekt
info: |
  ## Hardware-Sicherheit · TH Brandenburg
  Maximilian Wagner — Untersuchung mikroarchitektonischer Ressourcen-Interferenzen
  in virtualisierten Umgebungen (Proxmox VE · Intel Raptor Lake)
class: text-center
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
transition: slide-left
mdc: true
colorSchema: dark
themeConfig:
  primary: '#6B0AEA'
---

# Der Noisy-Neighbor-Effekt

<div class="kicker mt-1">Noisy Neighbor · Proxmox VE · Raptor Lake</div>

<div class="lead mt-3">Mikroarchitektonische Ressourcen-Interferenzen in virtualisierten Umgebungen</div>

<div class="pt-8 opacity-80 leading-relaxed">
  <b>Maximilian Wagner</b><br>
  Hardware-Sicherheit · Technische Hochschule Brandenburg<br>
  <span class="text-sm">Proxmox VE · Intel Raptor Lake · Praxisprojekt</span>
</div>

<!--
Begrüßung. Heute stelle ich den experimentellen Teil meiner Arbeit vor:
Wie lässt sich nachweisen, dass sich virtuelle Maschinen über geteilte Hardware
gegenseitig ausbremsen — obwohl sie logisch isoliert sein sollten?
-->

---
layout: two-cols
---

# Agenda

<v-clicks>

1. **Motivation** — warum dieses Thema?
2. **Hintergrund** — Virtualisierung & Shared Cache
3. **Technische Umsetzung** — der Homeserver
4. **Experiment-Topologie** — der Versuchsaufbau
5. **Methodik** — wie wird gemessen?
6. **Codebasis** — die Automatisierung
7. **Ergebnisse** — PoC & Fallback
8. **Fazit & Ausblick**

</v-clicks>

::right::

<div class="mt-16 ml-6 p-4 border-l-4 border-s1 opacity-90">

**Roter Faden**

Von der abstrakten Bedrohung (logische Isolation ist nicht gleich physische
Isolation) hin zum konkreten, messbaren Beweis auf eigener Hardware.

</div>

<!--
Kurz durch die Agenda. Schwerpunkt liegt klar auf dem praktischen Teil:
Aufbau, Code und Ergebnisse.
-->

---
layout: section
---

# 1 · Motivation

Warum „Noisy Neighbor"?

---

<div class="kicker">Motivation</div>

# Das Problem: geteilte Hardware

<div grid="~ cols-2 gap-8" class="mt-4">

<div>

**Cloud & Multi-Tenancy**

- Mehrere Mandanten teilen sich **einen** physischen Server
- Virtualisierung garantiert **funktionale** Isolation (Speicher, Prozesse)
- **Aber:** CPU-Caches, Speicherbandbreite und I/O bleiben **physisch geteilt**

</div>

<div>

**Der Noisy-Neighbor-Effekt**

- Ein „lauter Nachbar" sättigt gezielt eine geteilte Ressource
- Koexistierende VMs werden spürbar langsamer
- Angriffsvektor: **Denial of Service** über die Mikroarchitektur

</div>

</div>

<div class="mt-8 p-4 bg-s1/10 rounded border border-s1">

> Logische Isolation ≠ physische Isolation. Der **Last Level Cache (LLC)** ist
> die zentrale geteilte Ressource — und damit die Angriffsfläche.

</div>

<!--
Kernbotschaft: Der Hypervisor trennt sauber, was Software sieht. Was er NICHT
trennen kann, ist die geteilte physische Hardware darunter. Genau dort setzt der
Angriff an. NIST SP 800-125A benennt dieses systemische Risiko explizit.
-->

---

# Themenwahl & Forschungsfrage

<div grid="~ cols-2 gap-8">

<div>

**Warum dieses Thema?**

- Schnittstelle aus **Hardware-Sicherheit** und **Systemvirtualisierung**
- Praktisch auf eigener Hardware **reproduzierbar**
- Anknüpfung an die Basisaufgabe 3.4 (Emulation / Para-Virt. / Virtualisierung)

</div>

<div>

**Forschungsfrage**

</div>

</div>

<div class="mt-2 p-5 text-xl text-center border-2 border-s1 rounded-lg">

Lässt sich ein Isolationsbruch durch <b>Cache-Interferenz</b> auf moderner
Consumer-Hardware <span class="mark">quantitativ messbar</span> nachweisen?

</div>

<div class="mt-6 text-sm opacity-80">

**Zweistufige Absicherung:** PoC (aktiver Angriff) — und falls
Hardware-Mitigierungen greifen, ein **Fallback**: systematischer Leistungs­vergleich
der drei Virtualisierungs­paradigmen.

</div>

<!--
Die Forschungsfrage ist bewusst quantitativ formuliert: Es geht nicht um "gibt es
das", sondern um "wie groß ist der messbare Effekt". Die Fallback-Strategie sichert
ab, dass die Arbeit auch dann valide Ergebnisse liefert, wenn der Angriff scheitert.
-->

---
layout: section
---

# 2 · Hintergrund

Drei Paradigmen & der geteilte Cache

---

# Drei Virtualisierungs-Paradigmen

<div grid="~ cols-3 gap-4" class="mt-8">

<div class="p-4 border rounded">

### Emulation
**QEMU (TCG)**

CPU-Befehle werden in Software nachgebildet.

- Maximale Isolation
- Maximaler Overhead (~Faktor 30–40)

</div>

<div class="p-4 border rounded">

### Para-Virtualisierung
**LXC (Container)**

Geteilter Host-Kernel, OS-Level-Isolation.

- Nahezu native Leistung
- Schwächste Isolationsgrenze

</div>

<div class="p-4 border rounded border-s1">

### Virtualisierung
**KVM (HW-gestützt)**

Hardware-Beschleunigung (VT-x).

- Native Leistung
- Robuste Isolation

</div>

</div>

<div class="mt-8 text-center opacity-80">

Zunehmende Isolation ⟶ zunehmender Overhead. Die spannende Frage:
**Wie verhält sich diese Isolation unter aktiver Störlast?**

</div>

<!--
Diese drei bilden die Grundlage. Wichtig für später: LXC ist am schnellsten, aber
teilt sich am meisten mit dem Host — Hypothese ist, dass LXC unter Störlast am
stärksten einbricht. KVM sollte robuster sein.
-->

---
layout: two-cols
---

# Geteilter Last Level Cache

Auf **Intel Raptor Lake** teilen sich alle P-Cores **einen** L3-Cache (LLC).

<div class="mt-4">

- Angreifer & Opfer auf **demselben physischen Kern**
- Angreifer verdrängt permanent fremde Cache-Lines (*Eviction*)
- Opfer erleidet Cache-Misses → höhere Latenz, weniger Durchsatz

</div>

<div class="mt-6 p-3 bg-s1-magenta/10 border border-s1-magenta rounded text-sm">
Das Opfer „sieht" nur, dass es langsamer wird — die Ursache bleibt hinter der
Hardware-Abstraktion verborgen.
</div>

::right::

<div class="ml-6 mt-12">

```mermaid {scale: 0.72}
flowchart TB
  A[Angreifer-VM] --> L
  V[Opfer-VM] --> L
  L[("Shared L3 / LLC")]:::shared
  L --> R[(RAM)]
  classDef shared fill:#6B0AEA,stroke:#4C0BA5,color:#fff
```

</div>

<!--
Das ist der mikroarchitektonische Kern. Der LLC ist die letzte Cache-Stufe vor dem
RAM. Wer ihn flutet, zwingt den Nachbarn zu teuren RAM-Zugriffen.
-->

---
layout: section
---

# 3 · Technische Umsetzung

Der Homeserver

---
layout: two-cols
---

# Homeserver: Proxmox VE

**Hardware**

- Lenovo ThinkCentre M70s Gen 4
- **Intel Core i7-13700** (Raptor Lake, Hybrid)
- 32 GB DDR4-3200
- NVMe-SSD (System)

**Plattform**

- Proxmox VE (`pve` @ `192.168.178.50`)
- KVM-VMs **und** LXC-Container nativ
- Netz: vmbr0 (Heimnetz, 2,5 Gbit/s)

::right::

<div class="ml-6">

<div class="border-2 border-dashed border-gray-400 rounded-lg h-[340px] flex items-center justify-center text-center opacity-70">
  📷 <br><br>
  <b>Foto: Homeserver / Rack</b><br>
  <span class="text-xs">Datei nach<br><code>public/img/homeserver/server.jpg</code><br>legen und Platzhalter ersetzen</span>
</div>

<!-- Echtes Foto: einfach diese Zeile aktivieren und den Platzhalter-Block oben löschen
<img :src="'/img/homeserver/server.jpg'" class="rounded-lg shadow-lg" />
-->

</div>

<!--
Hier die Hardware zeigen. Wichtig: Es ist Consumer-Hardware, kein Server-Xeon —
das unterstreicht, dass der Effekt nicht exotisch ist. Foto vom Gerät einblenden.
-->

---

# Host-Determinismus (zwingend)

Ohne deterministische Taktbasis sind Latenzmessungen **wertlos** — moderne CPUs
takten ständig dynamisch um.

<div grid="~ cols-3 gap-4" class="mt-6">

<div class="p-4 border rounded">

**C-States aus**

```text
intel_idle.max_cstate=1
processor.max_cstate=1
idle=poll
```

</div>

<div class="p-4 border rounded">

**Turbo Boost aus**

```bash
echo 1 > .../intel_pstate/no_turbo
```

</div>

<div class="p-4 border rounded">

**Governor: performance**

```bash
echo performance > \
  .../scaling_governor
```

</div>

</div>

<div class="mt-8 p-3 bg-s1/10 border border-s1 rounded text-center">
Erst dadurch werden Messungen <b>reproduzierbar</b> und vergleichbar.
</div>

<!--
Das ist ein oft unterschätzter Punkt. Wenn die CPU während der Messung hoch- und
runtertaktet, misst man Taktschwankungen statt Cache-Effekte. Deshalb: feste
Frequenz, keine Schlafzustände.
-->

---
layout: section
---

# 4 · Experiment-Topologie

Der Versuchsaufbau

---

<div class="kicker">Versuchsaufbau</div>

# Vier Instanzen auf einem P-Core

```mermaid {scale: 0.62}
flowchart TB
  CN["💻 Control-Node (Laptop)<br/>run_experiment.sh"]:::ctl

  subgraph HOST["Proxmox VE Host · pve · i7-13700"]
    subgraph PCORE["Physischer P-Core 4,5 · gemeinsamer L3-Cache (LLC)"]
      direction LR
      ATT["🗡️ Angreifer<br/>LXC 200<br/>stress-ng cache+hdd"]:::att
      subgraph VIC["Opfer (sequenziell, je 1 aktiv)"]
        direction TB
        VQ["🎯 QEMU 201 · Emulation"]:::vic
        VL["🎯 LXC 202 · Para-Virt."]:::vic
        VK["🎯 KVM 203 · HW-Virt."]:::vic
      end
      ATT -. "LLC + I/O Contention" .-> VIC
    end
  end

  CN == "SSH · Störlast" ==> ATT
  CN == "SSH · Messung" ==> VIC

  classDef ctl fill:#6366F1,stroke:#4338CA,color:#fff
  classDef att fill:#FF2D7E,stroke:#BE185D,color:#fff
  classDef vic fill:#9333EA,stroke:#6B21A8,color:#fff
```

<!--
Das Herzstück. Alle vier Instanzen sind auf denselben physischen P-Core gepinnt
(CPU-Affinity 4,5). Die drei Opfer werden NACHEINANDER getestet — so ist immer nur
ein Opfer aktiv und teilt sich den Cache mit dem konstanten Angreifer. Der
Control-Node steuert alles per SSH, misst aber nicht selbst.
-->

---

# Warum dieses Design?

<div grid="~ cols-2 gap-8" class="mt-4">

<div>

**Ein Angreifer, drei Opfer**

- Angreifer = **konstante Störquelle**
- Nur **eine** Variable ändert sich: die Virtualisierung des Opfers
- Sequenzielle Läufe → sauberer Vergleich der Isolationsstärke

</div>

<div>

**Pinning auf einen P-Core**

- Erzwingt geteilten L1/L2/L3 (SMT-Geschwister `4,5`)
- Maximiert die messbare Interferenz
- Adressiert über Proxmox `CPU-Affinity`

</div>

</div>

<div class="mt-8 grid grid-cols-4 gap-3 text-center text-sm">
  <div class="p-3 border rounded border-s1-magenta">🗡️ Angreifer<br><code>.200</code></div>
  <div class="p-3 border rounded">🎯 QEMU<br><code>.201</code></div>
  <div class="p-3 border rounded">🎯 LXC<br><code>.202</code></div>
  <div class="p-3 border rounded border-s1">🎯 KVM<br><code>.203</code></div>
</div>

<!--
Der methodische Clou: Indem der Angreifer konstant bleibt, isoliere ich exakt eine
Variable. Das macht den Vergleich wissenschaftlich sauber.
-->

---
layout: section
---

# 5 · Methodik

Wie wird gemessen?

---

# Messablauf: Baseline → Störlast → Delta

```mermaid {scale: 0.7}
flowchart LR
  B["① Baseline<br/>Opfer misst<br/>(ohne Last)"] --> S["② Störlast<br/>Angreifer startet<br/>stress-ng"]
  S --> M["③ Messung<br/>Opfer misst<br/>(unter Last)"]
  M --> D["④ Delta<br/>= Isolationsbruch"]:::res
  classDef res fill:#6B0AEA,stroke:#4C0BA5,color:#fff
```

<div grid="~ cols-2 gap-8" class="mt-8">

<div>

**Werkzeuge am Opfer**

- `sysbench cpu` → Events/s (Rechenlast)
- `sysbench memory` → MiB/s (Bandbreite)
- `fio` (4K random write) → IOPS + p95-Latenz

</div>

<div>

**Werkzeug am Angreifer**

- `stress-ng --cache 2 --cache-level 3` (LLC-Eviction)
- `stress-ng --hdd 1` (I/O-Sättigung)

</div>

</div>

<div class="mt-4 text-sm opacity-80 text-center">
Jede Phase läuft <b>N-mal</b> — aggregiert wird der <b>Median</b> (robust gegen Ausreißer).
</div>

<!--
Vier Metriken decken beide geforderten Lastarten ab: Rechenaufgaben (CPU/RAM) und
I/O. Der Median statt Mittelwert macht die Ergebnisse robust gegen einzelne
Ausreißer.
-->

---
layout: section
---

# 6 · Codebasis

Die Automatisierung

---

# Architektur der Test-Suite

<div grid="~ cols-2 gap-6" class="mt-2">

<div>

```mermaid {scale: 0.6}
flowchart TB
  RE[run_experiment.sh<br/>PoC] --> O
  RF[run_fallback.sh<br/>Fallback] --> O
  O[lib/orchestrator.sh<br/>SSH · Deploy · Collect]
  O --> VB[victim_benchmark.sh]
  O --> AL[attacker_load.sh]
  O --> C[lib/common.sh<br/>Median · Delta]
```

</div>

<div class="text-sm">

**Control-Node-Skripte**
- `run_experiment.sh` — PoC-Orchestrierung
- `run_fallback.sh` — 3-Paradigmen-Vergleich
- `lib/orchestrator.sh` — geteilte SSH/Deploy-Logik

**Gast-Skripte** (per SSH ausgerollt)
- `victim_benchmark.sh` — misst
- `attacker_load.sh` — erzeugt Last

**Prinzip:** ein agnostisches Opfer-Skript läuft in **jedem** Gasttyp identisch.

</div>

</div>

<div class="mt-4 text-xs opacity-70 text-center">
Vollständig per <code>shellcheck</code> geprüft · Konfiguration zentral in <code>config.env</code>
</div>

<!--
Der Aufbau ist bewusst modular: Die gemeinsame Orchestrator-Lib wird von PoC und
Fallback geteilt. Das Opfer-Skript ist virtualisierungs-agnostisch — derselbe Code
läuft in QEMU, LXC und KVM. Das macht den Vergleich fair.
-->

---

# Code: kontrollierte Störlast

Der Angreifer wird über SSH **exakt** um die Messung herum gestartet und gestoppt:

```bash {all|2-3|5-7|9-11}{lines:true}
# attacker_load.sh — startet stress-ng im Hintergrund mit Zeitbudget
build_cmd() {
  stress-ng --cache "$CACHE_WORKERS" --cache-level "$CACHE_LEVEL" \
            --hdd "$HDD_WORKERS" --hdd-bytes "$HDD_BYTES" \
            --timeout "$1" --metrics-brief
}

start)  # PID merken → sauberes Stoppen, kein verwaister Prozess
  nohup "${cmd[@]}" > "$WORKDIR/attacker.log" 2>&1 &
  echo "$!" > "$PID_FILE" ;;
```

<div class="mt-4 text-sm opacity-80">
Ein EXIT-Trap im Orchestrator garantiert: nach dem Lauf läuft <b>nie</b> eine
Störlast weiter.
</div>

<!--
Hier sieht man die Kombination aus Cache- und I/O-Last. Das Zeitbudget und die
PID-Datei sorgen dafür, dass nie eine Last verwaist weiterläuft — wichtig für
reproduzierbare Messreihen.
-->

---

# Code: Messen & Aggregieren

```bash {all|3-4|6-9|11-12}{lines:true}
# lib/orchestrator.sh — N Messläufe sammeln, Median bilden
collect_phase() {
  for i in $(seq 1 "$REPEATS"); do
    line="$(victim_run "$user" "$host")"   # via SSH
    # "cpu_eps=..;iops=..;.." → Spalten extrahieren
    iops="$(sed -n 's/.*iops=\([^;]*\).*/\1/p' <<< "$line")"
    echo "$i;$cpu;$mem;$iops;$lat" >> "$out"
  done
}
# Median einer Spalte (robust gegen Ausreißer)
col_median() { tail -n +2 "$1" | cut -d';' -f"$2" | median; }
```

<div class="mt-4 text-sm opacity-80">
Ergebnis je Lauf: eine maschinenlesbare Zeile → CSV → direkt in LaTeX/Diagramm.
</div>

<!--
Der Datenfluss ist durchgängig automatisiert: SSH-Messung → CSV → Median → fertige
Tabelle/Diagramm im Paper. Kein manuelles Abtippen, volle Reproduzierbarkeit.
-->

---

# Live-Demo: die Pipeline läuft

<div class="text-sm opacity-80 mb-4">
Verkürztes Profil <code>demo.env</code> — <b>ein</b> Durchlauf, nur das KVM-Opfer.
Es geht um <b>„es läuft echt"</b>, nicht um belastbare Zahlen.
</div>

```bash
# vor dem Vortrag (einmalig): Werkzeuge + Skripte ausrollen
./run_experiment.sh --config demo.env --install --deploy-only

# LIVE — nur die Messung (~30–45 s)
./run_experiment.sh --config demo.env --no-deploy
```

<div grid="~ cols-2 gap-6" class="mt-6 text-sm">

<div>

**Was hier passiert**
- Baseline am Opfer messen
- Angreifer-Störlast starten
- erneut messen → **Delta**
- Median → CSV → Tabelle

</div>

<div>

**Bewusst klein gehalten**
- `REPEATS=1`, 5-Sekunden-Läufe
- kein Host-Determinismus nötig
- die **echten** Deltas: nächste Folie

</div>

</div>

<div class="mt-4 text-xs opacity-70 text-center">
Sicherheitsnetz: Mitschnitt des Laufs als Fallback, falls das Heimnetz streikt.
</div>

<!--
Hier lasse ich die Suite live laufen. Wichtig zu sagen: das demo.env ist absichtlich
winzig (ein Durchlauf, 5-s-Benchmarks, nur das KVM-Opfer) und OHNE Host-Determinismus
— es beweist, dass es echter, laufender Code ist, keine Folien-Behauptung. Die Zahlen
sind hier verrauscht und NICHT die Ergebnisse; die echten Deltas zeige ich gleich.
Falls das Netz spinnt: ich habe einen Mitschnitt als Fallback.
-->

---
layout: section
---

# 7 · Ergebnisse

PoC & Fallback

---

# PoC-Ergebnis · Platzhalter

<div class="absolute top-20 right-12 px-3 py-1 bg-amber-500 text-white text-xs rounded rotate-3">
PLATZHALTER — echte Daten folgen
</div>

Delta der Metriken am **KVM-Opfer**, Baseline vs. Noisy Neighbor:

<div class="mt-6">

| Metrik | Baseline | Noisy Neighbor | Delta |
|---|---|---|---|
| CPU (Events/s) | — | — | **— %** |
| Speicher (MiB/s) | — | — | **— %** |
| I/O (IOPS) | — | — | **— %** |
| Latenz p95 (ms) | — | — | **— %** |

</div>

<div class="mt-6 text-sm opacity-70">
Quelle nach der Messung: <code>project/experiments/results/poc_summary.csv</code> —
Tabelle wird automatisch aus dem CSV befüllt.<br>
Werte aus dem <b>vollen</b> Lauf (Host-Determinismus) — <b>nicht</b> die Live-Demo.
</div>

<!--
Diese Tabelle fülle ich nach der echten Messung. Erwartung: deutlicher Einbruch
bei IOPS und Anstieg der Latenz, moderater Effekt bei CPU.
-->

---

# Fallback-Ergebnis · Platzhalter

<div class="absolute top-20 right-12 px-3 py-1 bg-amber-500 text-white text-xs rounded rotate-3">
PLATZHALTER — Mock-Daten
</div>

<div class="flex justify-center mt-2">
  <img :src="'/img/mock_fallback.png'" class="h-[360px] rounded shadow-lg border" />
</div>

<div class="mt-3 text-center text-sm opacity-70">
Gruppierte Balken je Metrik · Baseline vs. Noisy Neighbor · QEMU/LXC/KVM<br>
<span class="text-xs">Mock-Werte — wird durch <code>fallback_summary.csv</code> ersetzt</span>
</div>

<!--
Das ist das Mock-Diagramm mit hypothetischen Werten. Die Geschichte, die ich
erwarte: LXC bricht bei I/O am stärksten ein (schwächste Isolation), KVM moderat,
QEMU kaum. Nach der echten Messung tausche ich nur das Bild aus.
-->

---

# Erwartete Kernaussage

<div class="mt-8 text-center text-xl">

LXC ist <b>am schnellsten</b>, aber unter Störlast <span class="mark">am schwächsten isoliert</span>.<br>
KVM „bezahlt" Isolation mit Leistung — und ist dafür <b>robuster</b>.

</div>

<div class="mt-10 grid grid-cols-3 gap-4 text-center">
  <div class="p-4 border rounded">QEMU<br><span class="stat text-4xl">≈ 0%</span><br><span class="text-xs opacity-70">Emulation puffert</span></div>
  <div class="p-4 border rounded border-s1">KVM<br><span class="stat text-4xl">~ −30%</span><br><span class="text-xs opacity-70">moderat</span></div>
  <div class="p-4 border rounded border-s1-magenta">LXC<br><span class="stat text-4xl">~ −60%</span><br><span class="text-xs opacity-70">stärkster Einbruch</span></div>
</div>

<div class="mt-6 text-xs opacity-60 text-center">Prozentwerte = hypothetische IOPS-Degradation (Mock)</div>

<!--
Diese Folie bringt die zentrale Aussage auf den Punkt — auch ohne echte Zahlen
schon klar kommunizierbar. Werte nach Messung anpassen.
-->

---
layout: section
---

# 8 · Fazit & Ausblick

---
layout: two-cols
---

# Fazit & Ausblick

**Erreicht**

- Vollautomatisierte, reproduzierbare Test-Suite
- Sauberer Versuchsaufbau (Pinning, Determinismus)
- Durchgängige Pipeline: SSH → CSV → Paper

**Nächste Schritte**

- VMs aufsetzen, echte Messreihen fahren
- Daten ins IEEE-Paper integrieren
- Einordnung der Mitigierungen (Intel RDT/CAT)

::right::

<div class="ml-6 mt-4 p-4 border-l-4 border-s1">

**Einordnung**

NIST SP 800-125A benennt geteilte Hardware als systemisches Hypervisor-Risiko.
Gegenmaßnahmen (Cache-Partitionierung, Limits/Reservations) existieren — meist mit
Leistungs­einbußen.

</div>

<div class="ml-6 mt-8 text-center text-lg">
Vielen Dank! — Fragen?
</div>

<!--
Abschluss: Die Infrastruktur steht, jetzt folgen die echten Daten. Überleitung zu
Fragen. Backup-Folien für Detailfragen bereit.
-->

---
layout: center
class: text-center
---

# Backup & Quellen

<div class="text-sm opacity-80 mt-4 leading-relaxed">

Koh et al. (2007) — Performance Interference · Ge et al. (2018) — Microarchitectural Timing Attacks<br>
NIST SP 800-125A Rev. 1 (2018) — Security Recommendations for Hypervisors

</div>

<div class="mt-8 text-sm">

Repository: <code>github.com/mwagner86/Hardware-Sicherheit</code><br>
Code-Basis: <code>project/experiments/</code> · Topologie: <code>Experiment-Topologie.canvas</code>

</div>

<!--
Quellen und Repo-Verweis. Hier kann ich bei Detailfragen auf Code oder Topologie
zurückgreifen.
-->
