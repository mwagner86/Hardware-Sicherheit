# Proof of Concept: Noisy-Neighbor-Interferenzen unter Proxmox VE (Intel Raptor Lake)

Dieses Dokument spezifiziert die methodische Vorbereitung, Durchführung und Bereinigung der Testumgebung zur Quantifizierung mikroarchitektonischer Ressourcen-Interferenzen (Shared Cache/LLC). Die Deaktivierung dynamischer Energiesparmechanismen auf dem Host ist zwingend erforderlich, um Latenzschwankungen durch asynchrone Taktskalierung auszuschließen.

## 1. Erstellung des Rücksetzpunktes (Host-Backup)

Da Modifikationen der CPU-Frequenzskalierung im virtuellen Dateisystem (`sysfs`) volatil sind, beschränkt sich die Sicherung auf die persistente Bootloader-Konfiguration.

1. Öffne die Shell des Proxmox-Hosts.
2. Erstelle eine Kopie der aktuellen GRUB-Konfiguration:

   ```bash
   cp /etc/default/grub /etc/default/grub.bak_pre_poc
   ```

## 2. Konfiguration der Host-Parameter

Die folgenden Schritte erzwingen eine deterministische Hardware-Basis durch Deaktivierung von C-States und dynamischem Scaling.

1. Editiere die GRUB-Konfiguration:

   ```bash
   nano /etc/default/grub
   ```

2. Ergänze die Zeile `GRUB_CMDLINE_LINUX_DEFAULT` um die Parameter zur Unterdrückung der Deep C-States:

   ```text
   intel_idle.max_cstate=1 processor.max_cstate=1 idle=poll
   ```

3. Aktualisiere den Bootloader und erzwinge einen Neustart:

   ```bash
   update-grub
   reboot
   ```

4. Deaktiviere nach dem Neustart den Intel Turbo Boost und setze den CPU-Governor auf maximale Leistung:

   ```bash
   echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
   echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   ```

5. Identifiziere die Performance-Cores (P-Cores) der hybriden Architektur für das anschließende Pinning:

   ```bash
   lscpu -e
   ```

   *Notiere zwei logische Kerne, die demselben physischen P-Core zugeordnet sind (z. B. 4 und 5).*

## 3. Provisionierung der Gastsysteme

1. Erstelle zwei identische Debian-basierte Instanzen (Attacker und Victim) über die Proxmox UI.
2. Isoliere beide Instanzen auf den zuvor identifizierten P-Core. Navigiere für beide Instanzen zu:
   `Select Instance` -> `Hardware` -> `Processors` -> `Edit` -> `Advanced` -> `CPU Affinity` (Wert eintragen, z. B. `4,5`).

## 4. Installation der Toolchains

1. Installiere die Benchmarking-Werkzeuge auf dem Victim-System:

   ```bash
   apt-get update && apt-get install sysbench fio -y
   ```

2. Installiere das Lastgenerierungs-Werkzeug auf dem Attacker-System:

   ```bash
   apt-get update && apt-get install stress-ng -y
   ```

## 5. Durchführung des Proof of Concepts

1. Ermittle die Baseline auf dem Victim-System ohne aktive Störlast:

   ```bash
   sysbench memory --memory-block-size=1K --memory-total-size=10G run
   ```

2. Initiiere die Sättigung des Last Level Caches (LLC) auf dem Attacker-System:

   ```bash
   stress-ng --cache 2 --cache-level 3 --metrics-brief
   ```
   
3. Führe den `sysbench`-Befehl auf dem Victim-System erneut aus, während die Störlast aktiv ist. Das resultierende Delta der Metriken (Operations pro Sekunde, Latenz) quantifiziert die Interferenz.

## 6. Wiederherstellung des Ursprungszustands

Nach Abschluss der Datenerhebung muss die deterministische Fixierung des Hosts aufgehoben werden.

1. Überschreibe die modifizierte GRUB-Konfiguration auf dem Host mit dem initialen Backup:

   ```bash
   cp /etc/default/grub.bak_pre_poc /etc/default/grub
   ```

2. Aktualisiere den Bootloader:

   ```bash
   update-grub
   ```

3. Führe einen Neustart des Hosts durch. Dies reaktiviert die C-States und verwirft die volatilen `sysfs`-Parameter (Turbo Boost, CPU-Governor):

   ```bash
   reboot
   ```

4. Entferne die temporären Gastsysteme über die Proxmox UI:
   `Select Instance` -> `More` -> `Remove` -> `Purge from job configurations` aktivieren -> VM ID eingeben -> `Remove`.
