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
  - **Tab. I** — PoC am KVM-Opfer, liest `results/poc_summary.csv` (**Platzhalter**)
  - **Tab. II** — LLC-Kausalnachweis, liest `results/llc_summary.csv` (**vorläufige Demo-Werte**)
  - **Abb. 2** — Fallback-Paradigmenvergleich, liest `results/fallback_summary.csv` (**Platzhalter/Mock**)
- Alle drei CSV-Datenquellen werden zur Compile-Zeit gelesen → echte Läufe
  ersetzen die Zahlen automatisch, ohne `main.tex` anzufassen.

## Offene TODOs zur Finalisierung

### A. Echte Messdaten erheben (ersetzen die Platzhalter automatisch)
- [ ] Host-Determinismus herstellen: C-States/Turbo aus, Governor `performance`
      (siehe `project/notes/PoC.md` §2)
- [ ] `./run_experiment.sh --label determ` → `poc_summary.csv` (echte PoC-Zahlen)
- [ ] `./run_fallback.sh --label determ` → `fallback_summary.csv`
- [ ] `./measure_llc.sh --install` (einmalig) + `./measure_llc.sh --label determ`
      → `llc_summary.csv` (rigoroser LLC-Lauf statt der Demo-Werte)
- [ ] Dashboard: `llc`-Block in `presentation/dashboard.html` auf die determ-Werte
      setzen + `preliminary:false`

### B. Platzhalter-Markierungen entfernen (nach A)
- [ ] Hinweis-Absatz oben im Ergebnisteil entfernen (`main.tex:139`)
- [ ] Prosa an die realen Deltas anpassen: PoC-Absatz (`main.tex:160`), LLC-Absatz,
      Fallback-Absatz
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
