# Paper-Finalisierung — Stand & offene Punkte

## Aktueller Stand (2026-07-09)

- **Baut grün:** `make paper` → 3 Seiten, 0 undefined refs/citations.
  - **Voraussetzung:** `texlive-publishers` muss installiert sein (liefert
    `IEEEtran.cls` + `IEEEtran.bst`). War zwischenzeitlich per `apt autoremove`/
    `autoclean` entfernt → Build brach mit `IEEEtran.cls not found`. Fix:
    `sudo apt-get install -y texlive-publishers`.
- **Vorhanden:** Titel, Abstract (**Platzhalter**), Einleitung (2. Version),
  Abb. 1 (TikZ-Topologie), Abschnitt „Methodik und Benchmarking" (**Stub**, 1 Satz),
  Abschnitt „Ergebnisse" mit:
  - **Tab. I** — Interferenz-Experiment am KVM-Opfer, liest `results/interference_summary.csv` (**Platzhalter**)
  - **Tab. II** — LLC-Kausalnachweis, liest `results/llc_summary.csv` (**vorläufige Demo-Werte**)
  - **Abb. 2** — Paradigmen-Vergleich, liest `results/paradigms_summary.csv` (**Platzhalter/Mock**)
- Alle drei CSV-Datenquellen werden zur Compile-Zeit gelesen → echte Läufe
  ersetzen die Zahlen automatisch, ohne `main.tex` anzufassen.

### Update 2026-07-14 — Umbenennung „PoC"/„Fallback" + Smoke-Verifikation
- Artefakte projektweit umbenannt: `run_interference.sh`/`interference_summary.csv`
  (ex-PoC) und `run_paradigms.sh`/`paradigms_summary.csv` (ex-Fallback), Env-Array
  `PARADIGM_VICTIMS`, `fig:paradigms`, `mock_paradigms.*`. Paper baut grün.
- **Beide Skripte nach Reboot aller Gäste smoke-verifiziert (Exit 0):**
  `run_interference.sh` (Angreifer + KVM) und `run_paradigms.sh` (KVM). Pipeline
  (Deploy, Benchmark, fio/jq-Parsing, Median/Delta, CSV-Schreiben) funktioniert
  mit den neuen Namen. Platzhalter-CSVs danach wiederhergestellt.
- **Infra-Fix erledigt:** LXC-Opfer 302 (.212) hatte nach Reboot den
  25-s-`pam_systemd`-SSH-Delay (wie .210 zuvor). `pam_systemd.so`-Session-Zeile in
  `/etc/pam.d/common-session` auskommentiert (Backup `.bak`) → Login 25 s → 0,2 s.
  Voller Paradigmen-Smoke (LXC + KVM sequenziell) danach grün (Exit 0). Damit sind
  **beide** Skripte über alle Code-Pfade verifiziert.

## Offene TODOs zur Finalisierung

### A. Echte Messdaten erheben (ersetzen die Platzhalter automatisch)
- [ ] Host-Determinismus herstellen: C-States/Turbo aus, Governor `performance`
      (siehe `project/notes/Interferenz-Experiment.md` §2)
- [ ] `./run_interference.sh --label determ` → `interference_summary.csv` (echte Interferenz-Zahlen)
- [ ] `./run_paradigms.sh --label determ` → `paradigms_summary.csv`
- [ ] `./measure_llc.sh --install` (einmalig) + `./measure_llc.sh --label determ`
      → `llc_summary.csv` (rigoroser LLC-Lauf statt der Demo-Werte)
- [ ] Dashboard: `llc`-Block in `presentation/dashboard.html` auf die determ-Werte
      setzen + `preliminary:false`

### B. Platzhalter-Markierungen entfernen (nach A)
- [ ] Hinweis-Absatz oben im Ergebnisteil entfernen (`main.tex:139`)
- [ ] Prosa an die realen Deltas anpassen: Interferenz-Absatz (`main.tex:160`), LLC-Absatz,
      Paradigmen-Vergleich-Absatz
- [ ] Captions bereinigen: Tab. I „(Platzhalterwerte)" (`main.tex:144`),
      Tab. II „(vorläufige Demo-Messung …)", Abb. 2 „(Platzhalter/Mock-Daten)"
- [ ] Abb. 2: `nodes near coords` ggf. entzerren, falls Balken eng beieinanderliegen

### C. Fehlende Abschnitte schreiben (die Einleitung verspricht sie, `main.tex:74`)
Real vorhanden: I Einleitung · II Methodik/Benchmarking (Stub) · III Ergebnisse.
Versprochen: II Stand der Forschung · III Versuchsaufbau · IV Ergebnisse ·
V Diskussion · VI Fazit. → Struktur in Deckung bringen:
- [ ] **II Stand der Forschung** (mikroarch. Interferenz-Vektoren,
      Virtualisierungskonzepte, Intel RDT/CAT)
- [ ] **III Versuchsaufbau** ausbauen: konkretes 4-Instanz-Setup, CPU-Pinning,
      Werkzeuge, Host-/Gast-Konfiguration — den „Methodik und Benchmarking"-Stub
      (`main.tex:76`) hierzu ausbauen/umbenennen (diese Details bewusst NICHT in
      der Einleitung)
- [ ] **V Diskussion**: Implikationen im Kontext der Hypothese (greifen RDT/CAT?)
- [ ] **VI Fazit** + Ausblick
- [ ] Abschnittsnummerierung mit „Aufbau der Arbeit" (`main.tex:74`) abgleichen

### D. Feinschliff
- [ ] **Abstract** ausformulieren (aktuell generischer Platzhalter) — an Titel/Scope
      und die realen Kernzahlen angleichen (u. a. LLC-Miss-Rate als Kausalbeleg)
- [ ] Literatur konsolidieren: `references_expose.bib` vs. `paper/references.bib`
      (Letztere noch nicht aktiv eingebunden)
- [ ] Build-Abhängigkeit absichern: ggf. `IEEEtran.cls` + `IEEEtran.bst` ins Repo
      vendorn (z. B. nach `paper/`), damit ein erneutes `apt autoremove` den Build
      nicht wieder bricht

### E. Betreuer-Feedback einarbeiten (Zwischenabgaben)
Aus den benoteten Bewertungen (`project/notes/Bewertungen/`); Details in den
Memories `paper-einleitung-revision`, `writing-style-guidance`, `expose-feedback`.
- [ ] **Einleitung überarbeiten** (Schwerpunkt Schreibstil): gerügte Formulierungen
      ersetzen (`main.tex:72,74` — noch alte Prosa mit „PoC"/„Rückfallebene");
      „fundamentales Defizit", „manifestiert sich", „unautorisierte Degradation",
      „Sättigung des LLC" → „Auslastung des LLC" usw.
- [ ] **Höher abstrahieren:** konkrete Technologienamen aus der Einleitung nehmen
      (Proxmox VE, Raptor Lake, RDT/CAT, QEMU/LXC/KVM) — gehören in Abschnitt III.
- [ ] **Fallback-Framing** aus der Einleitung entfernen (Konzept ist obsolet, s. o.).
- [ ] Schreibstil-Prinzipien auf **das gesamte Paper** anwenden (keine überhöhten
      Adjektive/Floskeln, klare Kernaussage pro Satz).
- [ ] **DOIs** im Literaturverzeichnis ergänzen (wo möglich).
- [ ] „Noisy Neighbor" **explizit einführen** (nicht nur beiläufig in Klammern).
- [ ] Abb. 2 Datenlabels „1.2" statt „1,200" (Achse skaliert mit 10^4) → weniger
      Überlappung; ggf. mit `nodes near coords`-Entzerrung (Abschnitt B) zusammen.
