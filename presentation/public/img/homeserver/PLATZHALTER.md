# Homeserver-Fotos hier ablegen

Lege deine Fotos in diesem Ordner ab und referenziere sie in `slides.md`.

Erwarteter Dateiname auf der Homeserver-Folie:

- `server.jpg` — Foto des Geräts / Racks (Lenovo ThinkCentre M70s)

So einbinden (in `slides.md`, Folie „Homeserver: Proxmox VE"):

1. Den gestrichelten Platzhalter-Block (`📷 Foto: Homeserver / Rack`) löschen.
2. Die auskommentierte Zeile aktivieren:

   ```html
   <img src="/img/homeserver/server.jpg" class="rounded-lg shadow-lg" />
   ```

Weitere Fotos (z. B. Verkabelung, Proxmox-Weboberfläche) lassen sich als
zusätzliche Folien oder in einem Grid analog einbinden. Pfade beginnen immer mit
`/img/...` (relativ zu `public/`).
