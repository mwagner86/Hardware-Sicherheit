# Tutorial: Deployment der Gastsysteme für die Experimente

Dieses Dokument beschreibt Schritt für Schritt, wie die Gastsysteme für den
Noisy-Neighbor-PoC und die Fallback-Strategie unter **Proxmox VE** (Intel Raptor
Lake) aufgesetzt werden. Es ergänzt [`PoC.md`](PoC.md) (Host-Determinismus) und
die Experiment-Suite unter [`../experiments/`](../experiments/).

---

## 0. Überblick: Welche Instanzen werden gebraucht?

Insgesamt **vier Instanzen** — ein Angreifer und drei Opfer:

| Rolle | Paradigma (Aufgabe 3.4) | Proxmox-Typ | ID | Hostname | IP (vmbr0) |
| --- | --- | --- | --- | --- | --- |
| Angreifer | — (konstante Störquelle) | LXC-Container | 200 | `attacker` | `192.168.178.200` |
| Opfer 1 | **Emulation** | QEMU-VM, **KVM aus** | 201 | `victim-qemu` | `192.168.178.201` |
| Opfer 2 | **Para-Virtualisierung** | LXC-Container | 202 | `victim-lxc` | `192.168.178.202` |
| Opfer 3 | **Virtualisierung** | KVM-VM | 203 | `victim-kvm` | `192.168.178.203` |

Alle vier auf **vmbr0 (Heimnetz `192.168.178.0/24`)**, GW Fritz!Box `.1`, DNS
Pi-hole `.55`. Statische IPs außerhalb des DHCP-Pools.

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
   `performance`) — siehe [`PoC.md`](PoC.md), Abschnitt 1–2. Zwingend vor jeder
   Messung.

2. **P-Core identifizieren.** Auf der hybriden Raptor-Lake-Architektur haben nur
   die P-Cores Hyperthreading (zwei logische CPUs pro physischem Kern):

   ```bash
   lscpu -e
   ```

   Suche zwei Zeilen mit **identischer `CORE`-Nummer** (= zwei SMT-Threads
   desselben physischen P-Cores), z. B. `CPU 4` und `CPU 5`. Diese beiden
   logischen Kerne (`4,5`) sind das Pinning-Ziel für **alle** Instanzen.

3. **SSH-Schlüssel** des Control-Nodes (Laptop) bereithalten — der Public Key
   wird beim Anlegen jeder Instanz hinterlegt:

   ```bash
   cat ~/.ssh/id_ed25519.pub   # auf dem Control-Node; Inhalt für unten kopieren
   ```

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

## 3. Opfer 3 — KVM-VM (Hardware-Virtualisierung), ID 203

Das ist die „normale" Proxmox-VM mit Hardwarebeschleunigung.

```bash
qm create 203 --name victim-kvm --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --ostype l26 --scsihw virtio-scsi-pci
qm importdisk 203 /var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2 local-lvm
qm set 203 --scsi0 local-lvm:vm-203-disk-0
qm set 203 --boot order=scsi0
qm set 203 --ide2 local-lvm:cloudinit
qm set 203 --serial0 socket --vga serial0
qm set 203 --ipconfig0 ip=192.168.178.203/24,gw=192.168.178.1
qm set 203 --ciuser root --sshkeys ~/.ssh/id_ed25519.pub
qm set 203 --cpu host          # Gast sieht echte CPU-/Cache-Topologie (LLC!)
qm set 203 --affinity 4,5      # Pinning auf den P-Core (Proxmox 8)
qm start 203
```

> `--cpu host` ist wichtig: Nur so „sieht" der Gast die reale LLC-Topologie, was
> für die mikroarchitektonische Interferenz relevant ist.

---

## 4. Opfer 1 — QEMU-VM (reine Emulation), ID 201

Identisch zur KVM-VM, aber **Hardware-Virtualisierung abgeschaltet** → QEMU läuft
im TCG-Emulationsmodus. **Das ist der einzige Unterschied, der aus einer
Proxmox-VM die „Emulation" der Aufgabenstellung macht.**

```bash
qm create 201 --name victim-qemu --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --ostype l26 --scsihw virtio-scsi-pci
qm importdisk 201 /var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2 local-lvm
qm set 201 --scsi0 local-lvm:vm-201-disk-0
qm set 201 --boot order=scsi0
qm set 201 --ide2 local-lvm:cloudinit
qm set 201 --serial0 socket --vga serial0
qm set 201 --ipconfig0 ip=192.168.178.201/24,gw=192.168.178.1
qm set 201 --ciuser root --sshkeys ~/.ssh/id_ed25519.pub
qm set 201 --kvm 0             # <-- ENTSCHEIDEND: Hardware-Virtualisierung AUS
qm set 201 --cpu qemu64        # mit kvm=0 KEIN '--cpu host' (kein KVM verfügbar)
qm set 201 --affinity 4,5
qm start 201
```

> **Erwartung:** Dieser Gast ist drastisch langsamer (Faktor ~30–40 bei I/O,
> vgl. Dummy-Daten). Das ist kein Fehler, sondern der zu quantifizierende
> Emulations-Overhead. Der Boot dauert spürbar länger.
>
> **UI-Alternative:** VM → `Options` → `KVM hardware virtualization` → `No`.

---

## 5. Opfer 2 — LXC-Container (Para-Virtualisierung), ID 202

```bash
pct create 202 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname victim-lxc --memory 2048 --cores 2 --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.178.202/24,gw=192.168.178.1 --ostype debian \
  --ssh-public-keys ~/.ssh/id_ed25519.pub --unprivileged 1
# CPU-Pinning für Container: cpuset in die Config schreiben
echo 'lxc.cgroup2.cpuset.cpus: 4,5' >> /etc/pve/lxc/202.conf
pct start 202
```

> LXC ist streng genommen OS-Level-Virtualisierung; im Projekt wird sie gemäß
> Exposé der Kategorie „Para-Virtualisierung" zugeordnet — diese Zuordnung
> beibehalten, damit Paper und Daten konsistent bleiben.

---

## 6. Angreifer — LXC-Container, ID 200

Container gewählt, weil der nahezu native Cache-Zugriff die stärkste, am besten
reproduzierbare LLC-Eviction erzeugt (maximiert die Chance, dass der PoC einen
messbaren Effekt zeigt).

```bash
pct create 200 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname attacker --memory 2048 --cores 2 --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.178.200/24,gw=192.168.178.1 --ostype debian \
  --ssh-public-keys ~/.ssh/id_ed25519.pub --unprivileged 1
echo 'lxc.cgroup2.cpuset.cpus: 4,5' >> /etc/pve/lxc/200.conf
pct start 200
```

> **Strikteres SMT-Co-Pinning (optional):** Angreifer auf Thread `4`, aktives
> Opfer auf Thread `5` desselben physischen Kerns legen (`cpuset.cpus: 4` bzw.
> `--affinity 5`). Erzwingt echte gleichzeitige Ausführung auf einem Kern statt
> Zeitscheiben. Für den Einstieg genügt `4,5` für alle (gemäß [`PoC.md`](PoC.md)).

---

## 7. Gemeinsame Gast-Vorbereitung (alle vier Instanzen)

Die **Werkzeuge** (`sysbench`, `fio`, `jq`, `stress-ng`) installiert der
Orchestrator später automatisch per `--install`. Vorab nur sicherstellen, dass
**SSH erreichbar** ist (Henne-Ei: das kann das Skript nicht selbst leisten):

1. **IP-Adressen** sind durch das statische Schema bereits festgelegt
   (`.200`–`.203`, letztes Oktett = ID). Diese Adressen müssen **außerhalb des
   Fritz!Box-DHCP-Pools** liegen — ggf. den DHCP-Bereich entsprechend einschränken,
   um Kollisionen zu vermeiden. Gegenprüfen (Host-seitig):

   ```bash
   qm guest cmd 201 network-get-interfaces   # VMs (Guest-Agent nötig)
   pct exec 202 -- ip -4 addr show eth0       # Container
   ```

2. **SSH-Login testen** (vom Control-Node):

   ```bash
   ssh root@<IP-des-Gasts> true && echo "SSH ok"
   ```

   - Cloud-Image-VMs (201/203): Key + `root`-Login sind via cloud-init bereits
     gesetzt.
   - LXC-Container (200/202): `--ssh-public-keys` hat den Key hinterlegt;
     `openssh-server` ist im Debian-Standard-Template enthalten und aktiv.

3. **Diese IPs in [`../experiments/config.env`](../experiments/config.env)
   eintragen** — pro Fallback-Lauf wird `VICTIM_HOST` auf das jeweilige Opfer
   gesetzt, `ATTACKER_HOST` bleibt konstant auf dem Angreifer (200).

---

## 8. Verifikation des Pinnings

Auf dem Host prüfen, dass alle Instanzen auf `4,5` laufen:

```bash
# VMs
qm config 201 | grep affinity
qm config 203 | grep affinity
# Container
grep cpuset /etc/pve/lxc/200.conf /etc/pve/lxc/202.conf
```

Optional unter Last gegenprüfen (Host): `ps -eLo pid,psr,comm | grep -E 'kvm|stress'`
zeigt, auf welchen logischen CPUs (`PSR`) die Threads tatsächlich laufen.

---

## 9. Anschluss an die Experimente

- **PoC:** `ATTACKER_HOST=`200, `VICTIM_HOST=`203 (KVM) in `config.env`, dann
  `./run_experiment.sh --install --deploy-only` (einmalig), danach
  `./run_experiment.sh` → `poc_summary.csv`.
- **Fallback:** drei Läufe (Opfer 201/202/203), Aggregation in `summary.csv` im
  Schema `Virtualisierung;...;_Base;_NN` — Automatisierung folgt mit
  `run_fallback.sh` (nächster Arbeitsschritt).

---

## 10. Aufräumen

```bash
qm stop 201 203;  pct stop 200 202
qm destroy 201 --purge;  qm destroy 203 --purge
pct destroy 200 --purge; pct destroy 202 --purge
```

Anschließend Host-Determinismus zurücksetzen — siehe [`PoC.md`](PoC.md),
Abschnitt 6.
