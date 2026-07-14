# Tutorial: Deployment der Gastsysteme für die Experimente

Dieses Dokument beschreibt Schritt für Schritt, wie die Gastsysteme für den
Noisy-Neighbor-PoC und die Fallback-Strategie unter **Proxmox VE** (Intel Raptor
Lake) aufgesetzt werden. Es ergänzt [`Interferenz-Experiment.md`](Interferenz-Experiment.md) (Host-Determinismus) und
die Experiment-Suite unter [`../experiments/`](../experiments/).

---

## 0. Überblick: Welche Instanzen werden gebraucht?

Insgesamt **vier Instanzen** — ein Angreifer und drei Opfer:

| Rolle | Paradigma (Aufgabe 3.4) | Proxmox-Typ | ID | Hostname | IP (vmbr0) |
| --- | --- | --- | --- | --- | --- |
| Angreifer | — (konstante Störquelle) | LXC-Container | 300 | `attacker` | `192.168.178.210` |
| Opfer 1 | **Emulation** | QEMU-VM, **KVM aus** | 301 | `victim-qemu` | `192.168.178.211` |
| Opfer 2 | **Para-Virtualisierung** | LXC-Container | 302 | `victim-lxc` | `192.168.178.212` |
| Opfer 3 | **Virtualisierung** | KVM-VM | 303 | `victim-kvm` | `192.168.178.213` |

Alle vier auf **vmbr0 (Heimnetz `192.168.178.0/24`)**, GW Fritz!Box `.1`, DNS
Pi-hole `.55`. Statische IPs außerhalb des DHCP-Pools.

> **ID-/IP-Schema:** Die IDs `2xx` waren auf diesem Host bereits belegt
> (`debian-dev`/`parrot`/`nixos`), daher `3xx`. Da `300` kein gültiges IP-Oktett
> ist, koppeln wir nicht mehr „Oktett = ID", sondern **letzte Ziffer der IP =
> letzte Ziffer der ID** (0/1/2/3 → `.210`–`.213`).
>
> **Storage:** Dieser Host nutzt **ZFS** (`local-zfs`), **nicht** `local-lvm` —
> alle `qm`/`pct`-Befehle unten verwenden entsprechend `local-zfs`.

**Doppelrolle der Opfer:**

- **PoC (primär):** Der Angreifer + *ein* hardwarenahes Opfer (KVM oder LXC) auf
  demselben P-Core → Nachweis des Interferenz-Effekts.
- **Fallback:** Alle drei Opfer nacheinander unter identischer Störlast →
  Vergleich der Isolationsstärke (Baseline vs. Noisy Neighbor je Metrik).

**Warum nur ein Angreifer?** Alle vier Instanzen werden auf **denselben
physischen P-Core** gepinnt. Da die Fallback-Messungen **sequenziell** laufen
(immer nur ein Opfer aktiv), teilt sich zu jedem Zeitpunkt nur ein Opfer + der
Angreifer den Last Level Cache. Der Angreifer ist über alle Läufe die **konstante
Störquelle** — saubere Variation einer einzigen Variable (Opfer-Virtualisierung).

> **Optionale Rigorosität (6 Instanzen):** Für „gematchte Paare" (Angreifer und
> Opfer jeweils gleichen Typs) je Paradigma einen eigenen Angreifer aufsetzen.
> Realistischer, aber zwei Variablen ändern sich zugleich. Für diese Arbeit ist
> der konstante Angreifer (4 Instanzen) die methodisch klarere Wahl.

---

## 1. Voraussetzungen auf dem Host

1. **Host-Determinismus** ist konfiguriert (C-States aus, Turbo aus, Governor
   `performance`) — siehe [`Interferenz-Experiment.md`](Interferenz-Experiment.md), Abschnitt 1–2. Zwingend vor jeder
   Messung.

2. **P-Core identifizieren.** Auf der hybriden Raptor-Lake-Architektur haben nur
   die P-Cores Hyperthreading (zwei logische CPUs pro physischem Kern):

   ```bash
   lscpu -e
   ```

   Suche zwei Zeilen mit **identischer `CORE`-Nummer** (= zwei SMT-Threads
   desselben physischen P-Cores), z. B. `CPU 4` und `CPU 5`. Diese beiden
   logischen Kerne (`4,5`) sind das Pinning-Ziel für **alle** Instanzen.

3. **SSH-Schlüssel** des Control-Nodes (Laptop) muss auf dem Host in
   `/root/.ssh/authorized_keys` hinterlegt sein. Da `.50` **nur** `publickey`
   akzeptiert (kein Passwort-Login), lässt sich der Key **nicht** per
   `ssh-copy-id` von der VM aus pushen — einmalig über die Proxmox-Web-Shell
   (`Datacenter → pve → Shell`) oder eine bereits funktionierende Session
   eintragen:

   ```bash
   # AUF DEM HOST (Web-Shell), Public Key des Control-Nodes anhängen:
   mkdir -p /root/.ssh && chmod 700 /root/.ssh
   echo 'ssh-ed25519 AAAA... control-node' >> /root/.ssh/authorized_keys
   chmod 600 /root/.ssh/authorized_keys
   ```

   Die `qm`/`pct`-Befehle unten reichen dann `~/.ssh/authorized_keys` (des
   Hosts) an die Gäste — diese Datei enthält den Control-Node-Key bereits, damit
   ist der passwortlose Zugang vom Orchestrator gesichert. Für automatisierte
   Läufe den Key im `ssh-agent` entsperren (`ssh-add ~/.ssh/id_ed25519`), sonst
   blockt die Passphrase die `BatchMode`-Aufrufe.

---

## 2. Templates beschaffen (einmalig auf dem Host)

**VM-Cloud-Image (für QEMU/KVM-Opfer):**

```bash
cd /var/lib/vz/template/iso
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
```

**LXC-Template (für Angreifer + LXC-Opfer):**

```bash
pveam update
pveam available | grep debian-12-standard
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

---

## 3. Opfer 3 — KVM-VM (Hardware-Virtualisierung), ID 303

Das ist die „normale" Proxmox-VM mit Hardwarebeschleunigung. Das Cloud-Root ist
nur ~3 GB — mit `qm resize +6G` auf ~9 GB vergrößern, sonst wird es mit
sysbench/fio + Testdateien zu eng.

```bash
IMG=/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2
qm create 303 --name victim-kvm --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --ostype l26 --scsihw virtio-scsi-pci
qm importdisk 303 "$IMG" local-zfs
qm set 303 --scsi0 local-zfs:vm-303-disk-0
qm set 303 --boot order=scsi0
qm set 303 --ide2 local-zfs:cloudinit
qm set 303 --serial0 socket --vga serial0
qm resize 303 scsi0 +6G
qm set 303 --ipconfig0 ip=192.168.178.213/24,gw=192.168.178.1
qm set 303 --nameserver 192.168.178.55
qm set 303 --ciuser root --sshkeys ~/.ssh/authorized_keys
qm set 303 --cpu host          # Gast sieht echte CPU-/Cache-Topologie (LLC!)
qm set 303 --affinity 4,5      # Pinning auf den P-Core (Proxmox 8)
qm start 303
```

> **Verifiziert:** `systemd-detect-virt` im Gast meldet `kvm` (echte
> HW-Virtualisierung), Boot in ~10 s.
>
> `--cpu host` ist wichtig: Nur so „sieht" der Gast die reale LLC-Topologie, was
> für die mikroarchitektonische Interferenz relevant ist.

---

## 4. Opfer 1 — QEMU-VM (reine Emulation), ID 301

Identisch zur KVM-VM, aber **Hardware-Virtualisierung abgeschaltet** → QEMU läuft
im TCG-Emulationsmodus. **Das ist der einzige Unterschied, der aus einer
Proxmox-VM die „Emulation" der Aufgabenstellung macht.**

```bash
IMG=/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2
qm create 301 --name victim-qemu --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --ostype l26 --scsihw virtio-scsi-pci
qm importdisk 301 "$IMG" local-zfs
qm set 301 --scsi0 local-zfs:vm-301-disk-0
qm set 301 --boot order=scsi0
qm set 301 --ide2 local-zfs:cloudinit
qm set 301 --serial0 socket --vga serial0
qm resize 301 scsi0 +6G
qm set 301 --ipconfig0 ip=192.168.178.211/24,gw=192.168.178.1
qm set 301 --nameserver 192.168.178.55
qm set 301 --ciuser root --sshkeys ~/.ssh/authorized_keys
qm set 301 --kvm 0             # <-- ENTSCHEIDEND: Hardware-Virtualisierung AUS
qm set 301 --cpu qemu64        # mit kvm=0 KEIN '--cpu host' (kein KVM verfügbar)
qm set 301 --affinity 4,5
qm start 301
```

> **Erwartung:** Dieser Gast ist drastisch langsamer (Faktor ~30–40 bei I/O,
> vgl. Dummy-Daten). Das ist kein Fehler, sondern der zu quantifizierende
> Emulations-Overhead. Der Boot dauert spürbar länger — hier ~45 s (vs. ~10 s
> bei KVM); `systemd-detect-virt` im Gast meldet `qemu`.
>
> **UI-Alternative:** VM → `Options` → `KVM hardware virtualization` → `No`.

---

## 5. Opfer 2 — LXC-Container (Para-Virtualisierung), ID 302

```bash
pct create 302 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname victim-lxc --memory 2048 --cores 2 --rootfs local-zfs:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.178.212/24,gw=192.168.178.1 --ostype debian \
  --nameserver 192.168.178.55 \
  --ssh-public-keys ~/.ssh/authorized_keys --unprivileged 1
# CPU-Pinning für Container: cpuset in die Config schreiben
echo 'lxc.cgroup2.cpuset.cpus: 4,5' >> /etc/pve/lxc/302.conf
pct start 302
```

> LXC ist streng genommen OS-Level-Virtualisierung; im Projekt wird sie gemäß
> Exposé der Kategorie „Para-Virtualisierung" zugeordnet — diese Zuordnung
> beibehalten, damit Paper und Daten konsistent bleiben.

---

## 6. Angreifer — LXC-Container, ID 300

Container gewählt, weil der nahezu native Cache-Zugriff die stärkste, am besten
reproduzierbare LLC-Eviction erzeugt (maximiert die Chance, dass der PoC einen
messbaren Effekt zeigt).

```bash
pct create 300 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname attacker --memory 2048 --cores 2 --rootfs local-zfs:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.178.210/24,gw=192.168.178.1 --ostype debian \
  --nameserver 192.168.178.55 \
  --ssh-public-keys ~/.ssh/authorized_keys --unprivileged 1
echo 'lxc.cgroup2.cpuset.cpus: 4,5' >> /etc/pve/lxc/300.conf
pct start 300
```

> **Strikteres SMT-Co-Pinning (optional):** Angreifer auf Thread `4`, aktives
> Opfer auf Thread `5` desselben physischen Kerns legen (`cpuset.cpus: 4` bzw.
> `--affinity 5`). Erzwingt echte gleichzeitige Ausführung auf einem Kern statt
> Zeitscheiben. Für den Einstieg genügt `4,5` für alle (gemäß [`Interferenz-Experiment.md`](Interferenz-Experiment.md)).

---

## 7. Gemeinsame Gast-Vorbereitung (alle vier Instanzen)

Die **Werkzeuge** (`sysbench`, `fio`, `jq`, `stress-ng`) installiert der
Orchestrator später automatisch per `--install`. Vorab nur sicherstellen, dass
**SSH erreichbar** ist (Henne-Ei: das kann das Skript nicht selbst leisten):

1. **IP-Adressen** sind durch das statische Schema bereits festgelegt
   (`.210`–`.213`, letzte Ziffer der IP = letzte Ziffer der ID). Diese Adressen
   müssen **außerhalb des Fritz!Box-DHCP-Pools** liegen — ggf. den DHCP-Bereich
   entsprechend einschränken, um Kollisionen zu vermeiden. Gegenprüfen (Host-seitig):

   ```bash
   qm guest cmd 301 network-get-interfaces   # VMs (Guest-Agent nötig)
   pct exec 302 -- ip -4 addr show eth0       # Container
   ```

2. **SSH-Login testen** (vom Control-Node):

   ```bash
   ssh root@<IP-des-Gasts> true && echo "SSH ok"
   ```

   - Cloud-Image-VMs (301/303): Key + `root`-Login sind via cloud-init bereits
     gesetzt.
   - LXC-Container (300/302): `--ssh-public-keys` hat den Key hinterlegt;
     `openssh-server` ist im Debian-Standard-Template enthalten und aktiv.

3. **Diese IPs in [`../experiments/config.env`](../experiments/config.env)
   eintragen** — pro Fallback-Lauf wird `VICTIM_HOST` auf das jeweilige Opfer
   gesetzt, `ATTACKER_HOST` bleibt konstant auf dem Angreifer (300).

---

## 8. Verifikation des Pinnings

Auf dem Host prüfen, dass alle Instanzen auf `4,5` laufen:

```bash
# VMs
qm config 301 | grep affinity
qm config 303 | grep affinity
# Container
grep cpuset /etc/pve/lxc/300.conf /etc/pve/lxc/302.conf
```

Innerhalb der Gäste bestätigt `nproc`=2 und (bei Containern)
`cat /sys/fs/cgroup/cpuset.cpus.effective` → `4-5` das Pinning. Optional unter
Last gegenprüfen (Host): `ps -eLo pid,psr,comm | grep -E 'kvm|stress'` zeigt, auf
welchen logischen CPUs (`PSR`) die Threads tatsächlich laufen.

---

## 9. Anschluss an die Experimente

- **PoC:** `ATTACKER_HOST=`192.168.178.210, `VICTIM_HOST=`192.168.178.213 (KVM,
  303) in `config.env`, dann `./run_interference.sh --install --deploy-only`
  (einmalig), danach `./run_interference.sh` → `results/interference_summary.csv`.
- **Fallback:** `./run_paradigms.sh` testet die drei Opfer (301/302/303)
  sequenziell unter konstanter Störlast → `results/paradigms_summary.csv`
  (Schema `Virtualisierung;CPU_Base;CPU_NN;...;Lat_NN`).

---

## 10. Aufräumen

```bash
qm stop 301 303;  pct stop 300 302
qm destroy 301 --purge;  qm destroy 303 --purge
pct destroy 300 --purge; pct destroy 302 --purge
```

Anschließend Host-Determinismus zurücksetzen — siehe [`Interferenz-Experiment.md`](Interferenz-Experiment.md),
Abschnitt 6.
