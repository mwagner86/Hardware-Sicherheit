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
- [x] **Nicht-invasiver Determinismus** (2026-07-15): `set_determinism.sh --on`
      (Kerne 4/5 Basistakt-Pin, Uncore-Pin, tiefe C-States aus; Host danach `--off`).
- [x] `./run_interference.sh --label determ` → `interference_summary.csv`
      (CPU −18 %, RAM −44 %, IOPS −59 %, p95 +422 %).
- [x] `./run_paradigms.sh --label determ` → `paradigms_summary.csv`.
- [x] `./measure_llc.sh --label determ` (2026-07-15, unter Determinismus, 10-s-Fenster)
      → `llc_summary.csv`: Miss-Rate 34,4 % → 59,5 %, LLC-Traffic ×27–48. Tab. II real.
- [ ] Dashboard: `llc`-Block in `presentation/dashboard.html` auf die determ-Werte
      setzen + `preliminary:false`

### B. Platzhalter-Markierungen entfernen (nach A)
- [x] Hinweis-Absatz oben im Ergebnisteil entfernt (2026-07-15); Ergebnis-Prosa
      (Interferenz + Paradigmen) auf reale Deltas umgeschrieben, inkl. ehrlichem
      Absatz zur KVM≫LXC-IOPS-Auffälligkeit (Writeback-Cache vs. `O_DIRECT`).
- [x] Captions Tab. I + Abb. 2 bereinigt; `ymax` je Metrik an reale Werte angepasst
      (Latenz-Subplot lief sonst über: QEMU 26 ms). Tab. I kompakter (Overfull weg).
- [x] Tab. II auf reale Determinismus-Messung umgestellt (2026-07-15): Caption
      „10-Sekunden-Fenster", Prosa auf 34→60 % Miss-Rate + LLC-Traffic-Vervielfachung.
- [ ] Abb. 2: `nodes near coords` bei eng beieinanderliegenden Balken entzerren
      (QEMU-Speicher/-IOPS-Labels überlappen leicht); Exposé-Tipp „1.2 statt 1200".

### C. Fehlende Abschnitte schreiben (die Einleitung verspricht sie, `main.tex:74`)
Aktuell: I Einleitung · II Stand der Forschung · III Versuchsaufbau · IV Ergebnisse.
Noch offen laut Einleitung: V Diskussion · VI Fazit.
- [x] **Versuchsaufbau** (§III) geschrieben: Hardware/Topologie, Determinismus,
      Last/Messgrößen/Ablauf.
- [x] **Stand der Forschung** (§II) geschrieben (2026-07-16), **quellenbasiert**:
      alle 12 PDFs in `paper/sources/` gelesen, jede Aussage belegt. Nummerierung
      damit konsistent zur Einleitung (III Versuchsaufbau, IV Ergebnisse).
- [ ] **V Diskussion**: Implikationen im Kontext der Hypothese (greifen RDT/CAT?);
      KVM≫LXC-IOPS-Anomalie mit Lit. einordnen (li2017: Container nicht immer
      I/O-stärker; nikounia2018: nicht nur LLC, auch Scheduling).
- [ ] **VI Fazit** + Ausblick.

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
- [x] **Einleitung überarbeitet** (2026-07-14): alle gerügten Formulierungen
      ersetzt („fundamentales Defizit", „erhebliches Gefährdungspotenzial",
      „manifestiert sich", „unautorisierte Degradation", unklarer Messansatz-Satz,
      „bereinigtes Fundament"); „Sättigung des LLC" entfernt. Baut grün (3 S.).
- [x] **Höher abstrahiert:** konkrete Technologienamen aus der Einleitung entfernt
      (Proxmox VE, Raptor Lake, RDT/CAT, QEMU/LXC/KVM, C-States/Turbo/Governor,
      Debian, CPU-Affinity) — gehören in Abschnitt III.
- [x] **Fallback-Framing** aus der Einleitung entfernt; Paradigmen-Vergleich jetzt
      als integraler erster Teil dargestellt (Pflichtkern 3.4), NN als Aufbau darauf.
- [x] „Noisy Neighbor" in der Einleitung **explizit** definiert (nicht in Klammern).
- [ ] Schreibstil-Prinzipien auf **das restliche Paper** anwenden (keine überhöhten
      Adjektive/Floskeln, klare Kernaussage pro Satz) — beim Schreiben von II/III/V/VI.
- [ ] **DOIs** im Literaturverzeichnis ergänzen (wo möglich).
- [ ] Abb. 2 Datenlabels „1.2" statt „1,200" (Achse skaliert mit 10^4) → weniger
      Überlappung; ggf. mit `nodes near coords`-Entzerrung (Abschnitt B) zusammen.
