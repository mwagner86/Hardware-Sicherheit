# Erstellungs-Dokumentation: Erste Version der Einleitung

**Generiertes Dokument:** `einleitung_erste_version.tex`
**KI-Werkzeug:** Claude Sonnet 4.6 (Anthropic)
**Datum:** 2026-05-06

---

## Verwendeter System-Kontext

Der folgende Kontext wurde dem KI-Werkzeug als persistente Instruktionsgrundlage bereitgestellt.

### Projektziel & Rahmenbedingungen

* **Format:** IEEE Conference Format (`\documentclass[conference]{IEEEtran}`)
* **Sprache:** Deutsch (wissenschaftlicher Standard)
* **Kernaufgabe:** Untersuchung der Isolation in Virtualisierungslösungen mit Fokus auf Hardware-Sicherheit

### Erweiterte Aufgabenstellung (Noisy-Neighbor)

Falsifikation der Hypothese, dass historische Angriffsvektoren auf moderner Hardware (Intel Raptor Lake) durch aktuelle Isolationsmechanismen (Intel RDT/CAT) vollständig neutralisiert werden.

### Hardware-Szenario & Host-Konfiguration

* **Host:** Proxmox VE auf Intel Raptor Lake (hybride P-Core/E-Core Architektur)
* **Shared Resource:** Last Level Cache (LLC), physisch geteilt von P-Cores
* **Host-Determinismus (zwingend):**
  * Deep C-States deaktivieren: `intel_idle.max_cstate=1 processor.max_cstate=1 idle=poll`
  * Turbo Boost deaktivieren: `echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo`
  * CPU-Governor: `performance` (alle Kerne)

### Methodik & Proof of Concept (PoC)

* **Setup:** Zwei identische Debian-Instanzen (Attacker & Victim)
* **Isolations-Bruch:** CPU-Pinning beider Instanzen auf denselben physischen P-Core (CPU Affinity in Proxmox)
* **Metriken:** Durchsatz (MB/s) und 95. Perzentil-Latenz (ms) via `sysbench` und `fio` auf dem Victim-System; Attacker läuft `stress-ng --cache 2 --cache-level 3`

### Fallback-Strategie

Greift, wenn keine messbaren Interferenzen auftreten:

* **Thema:** Vergleich von Emulation (QEMU), Para-Virtualisierung (LXC) und hardwareunterstützter Virtualisierung (KVM)
* **Fokus:** Leistungsfähigkeit bei Rechen- und I/O-Operationen

---

## Verwendeter Prompt

Der folgende Prompt wurde zur Generierung der Einleitung eingesetzt. Das KI-Werkzeug erhielt diesen Prompt zusammen mit dem System-Kontext sowie den Quelldateien `expose_hardware_security.tex`, `literatur_recherche_draft.tex` und `references.bib`.

---

> **Rollenprofil:** Wissenschaftlicher Autor im Fachbereich IT-Sicherheit und Hardware-Architektur.
>
> **Aufgabe:** Erstellung eines inhaltlichen Entwurfs der Einleitung (Ausgabe als Markdown-Dokument `Einleitung.md`) für eine wissenschaftliche Hausarbeit im IEEE-Format. Die inhaltliche Struktur muss strikt und sequenziell den folgenden sechs Leitfragen folgen.
>
> **Eingabedaten (zwingend zu berücksichtigen):**
> - System-Kontext: `ki_agent_context_projekt.md`
> - Projektskizze: `project/expose/expose_hardware_security.tex`
> - Stand der Forschung: `paper/literatur_recherche_draft.tex`
> - Literaturdatenbank: `paper/references.bib`
>
> **Inhaltliche Strukturierung (Absatzweise abzuarbeiten):**
>
> 1. **Worum geht es? (Thematische Einführung):** Sachliche Einführung in die Konzepte der Virtualisierung, die logische Isolation von Gastsystemen und die physische Teilung mikroarchitektonischer Ressourcen (insbesondere Caches).
> 2. **Warum ist das Thema relevant? (Gefährdungspotenzial & Aktualität):** Einordnung der Relevanz für moderne Cloud-Infrastrukturen. Darstellung des „Noisy-Neighbor-Effekts" als systemische Schwachstelle, die zu unautorisierter Leistungsdegradation oder Timing-Angriffen (Denial-of-Service auf Hardware-Ebene) führen kann.
> 3. **Was ist das Ziel dieser Hausarbeit? (Zielsetzung & Problemstellung):** Definition der primären Forschungsfrage. Ziel ist die Falsifikation der Hypothese, dass historische Interferenz-Vektoren auf aktuellen, hardware-mitigierten Architekturen (Intel Raptor Lake) unter produktiven Hypervisor-Bedingungen (Proxmox VE) weiterhin quantifizierbare Isolationsbrüche verursachen.
> 4. **Was ist der Lösungsansatz?:** Die methodische Herangehensweise durch empirische Quantifizierung der Performance-Isolation unter kontrollierter Störlast.
> 5. **Was wird im praktischen Teil demonstriert?:** Präzise Skizzierung des Proof of Concepts. Nennung des Setups (CPU-Pinning auf physische P-Cores, LLC-Sättigung via `stress-ng`, Baseline- und Degradationsmessung via `sysbench` und `fio`). Zwingende Integration der Fallback-Strategie (akademischer Leistungsvergleich von Emulation, Para-Virtualisierung und hardwareunterstützter Virtualisierung), für den Fall, dass hardwareseitige Mitigierungen (z.B. Intel RDT) den Isolationsbruch neutralisieren.
> 6. **Wie ist die Gliederung der Arbeit?:** Ein kurzer, rein deskriptiver Ausblick auf den Aufbau der nachfolgenden Kapitel (Stand der Forschung, Methodik, Evaluation, Fazit).
>
> **Stilistische und formale Vorgaben:**
> - Sprache: Wissenschaftliches, objektives Deutsch
> - Terminologie: Korrekte Fachsprache der Domäne (IT-Security/Hardware-Architektur), keine unnötigen Vereinfachungen
> - Wissenschaftlicher Standard: Differenzierung zwischen Fakt (Architekturgegebenheiten) und Hypothese
> - Formatierung: Ausgabe ausschließlich als validierbarer Markdown-Codeblock, keine Meta-Kommentare
> - Referenzierung: Nutzung von Platzhaltern im `\cite{}`-Format, korrespondierend zu den Einträgen in der `references.bib`
