# Präsentation: Der Noisy-Neighbor-Effekt

Slide-Deck (Slidev) zum experimentellen Teil der Hausarbeit. Lokal lauffähig,
als statische Website baubar und nach **PDF** exportierbar (Abgabe-Anforderung).

## Voraussetzungen

- Node.js **18+** (getestet mit Node 20)

## Befehle

```bash
npm install            # einmalig: Abhängigkeiten installieren
npm run dev            # Live-Preview unter http://localhost:3030
npm run build          # statische Website nach dist/  (lokal hostbar/offline)
npm run export         # PDF nach dist/Praesentation-Noisy-Neighbor.pdf
```

### PDF-Export

`npm run export` nutzt `playwright-chromium` (als optionale Dependency
vorgesehen). Schlägt der Export mit „please install it via …" fehl, wurde die
Browser-Komponente beim `npm install` übersprungen (z. B. eingeschränktes Netz).
Dann einmalig nachholen:

```bash
npm i -D playwright-chromium     # Paket installieren
npx playwright install chromium  # Browser-Binary laden
npm run export                   # -> dist/Praesentation-Noisy-Neighbor.pdf
```

Jede Folie wird zu genau einer PDF-Seite.

### Statisch hosten / offline

`npm run build` erzeugt `dist/`. Inhalt mit jedem Static-Server ausliefern
(`npx serve dist`) oder offline öffnen. Für Unterverzeichnis-Hosting:
`npm run build -- --base /pfad/`.

## Inhalte anpassen

- **Folien:** `slides.md` (eine Datei, Folien durch `---` getrennt).
- **Homeserver-Fotos:** in `public/img/homeserver/` ablegen, siehe dortige
  `PLATZHALTER.md`.
- **Ergebnisse:** Die Folien „PoC-Ergebnis" und „Fallback-Ergebnis" sind als
  `PLATZHALTER` markiert.
  - PoC: Tabelle aus `../project/experiments/results/poc_summary.csv` füllen.
  - Fallback: `public/img/mock_fallback.png` durch das echte Diagramm ersetzen
    (gleicher Dateiname → keine weitere Änderung nötig).
- **Speaker-Notes:** stehen je Folie im `<!-- ... -->`-Block, im Presenter-Mode
  sichtbar (Taste `p` bzw. Button in der Dev-Ansicht).

## Bezug zu den Experimenten

Die Code-Snippets stammen 1:1 aus `../project/experiments/`. Die Topologie-Folie
ist die Slidev/Mermaid-Variante von `../Experiment-Topologie.canvas`.
