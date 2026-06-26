# Klickanleitung: BIOS + VM-Erstellung in der Proxmox-Web-UI

Schritt-für-Schritt-Anleitung über die **Proxmox-Weboberfläche**
(`https://192.168.178.50:8006`) und das **Server-BIOS**. Die reine CLI-Variante
(`qm`/`pct`) und die methodische Begründung stehen in
[`VM-Deployment.md`](VM-Deployment.md); der Host-Determinismus in
[`PoC.md`](PoC.md).

> **Zielzustand:** 4 Instanzen, alle auf den physischen P-Core `4,5` gepinnt.
>
> | Rolle | Typ | ID | IP |
> | --- | --- | --- | --- |
> | Angreifer | LXC | 200 | `192.168.178.200` |
> | Opfer · Emulation | QEMU-VM (KVM aus) | 201 | `192.168.178.201` |
> | Opfer · Para-Virt. | LXC | 202 | `192.168.178.202` |
> | Opfer · HW-Virt. | KVM-VM | 203 | `192.168.178.203` |

---

## Teil A · BIOS-Einstellungen (Lenovo ThinkCentre M70s)

Beim Booten **F1** drücken (Lenovo BIOS). Die genauen Menünamen variieren je
BIOS-Version — notfalls die **Suchfunktion** (F-Taste/Lupe) nutzen. Nach jeder
Änderung **F10** (Save & Exit).

### A.1 Pflicht für das Experiment

| Einstellung | Zielwert | Typischer Pfad | Warum |
| --- | --- | --- | --- |
| **Intel Virtualization Technology (VT-x)** | **Enabled** | `Security → Virtualization` | KVM-Virtualisierung (Opfer 203) |
| **Intel VT-d** | **Enabled** | `Security → Virtualization` | IOMMU / saubere Isolation |
| **Hyper-Threading** | **Enabled** | `Advanced → CPU Setup` | liefert die SMT-Geschwister `4,5` eines P-Cores (Pinning-Ziel!) |
| **CPU C-States** (inkl. C1E) | **Disabled** | `Power` bzw. `Advanced → CPU Setup` | deterministische Latenz (keine Schlafzustände) |
| **Intel Turbo Boost** | **Disabled** | `Advanced → CPU Setup` | feste Taktrate (alternativ per OS, s. PoC.md) |

### A.2 Empfohlen (mehr Determinismus)

| Einstellung | Zielwert | Pfad | Hinweis |
| --- | --- | --- | --- |
| **Power Operating Mode** | **Maximum Performance** | `Power` | unterbindet aggressives Energiesparen |
| **Enhanced SpeedStep (EIST)** | Disabled (optional) | `Advanced → CPU Setup` | Governor `performance` erledigt das sonst per OS |
| **E-Cores (Efficient Cores)** | Enabled lassen | `Advanced → CPU Setup` | wir pinnen ohnehin auf P-Cores; nur bei Topologie-Problemen deaktivieren |

> **Wichtig:** Hyper-Threading **muss an** sein — sonst gibt es keine zwei
> logischen Kerne pro P-Core und das Pinning auf `4,5` funktioniert nicht.

Nach dem BIOS: P-Core identifizieren (Host-Shell):

```bash
lscpu -e   # zwei Zeilen mit gleicher CORE-Nummer = ein P-Core, z. B. CPU 4 & 5
```

---

## Teil B · Vorbereitung (Images laden)

### B.1 Debian-ISO (für die VMs)

1. Linke Baumansicht: **`pve → local (pve)`** anklicken.
2. Reiter **`ISO Images`** → Button **`Download from URL`**.
3. URL einer **Debian 12 netinst** ISO einfügen
   (`https://cdimage.debian.org/...debian-12...-netinst.iso`) → **`Query URL`** →
   **`Download`**.

### B.2 LXC-Template (für die Container)

1. **`pve → local (pve)`** → Reiter **`CT Templates`** → Button **`Templates`**.
2. In der Liste **`debian-12-standard`** auswählen → **`Download`**.

---

## Teil C · KVM-VM erstellen (Opfer 203) + Debian installieren

Oben rechts **`Create VM`**:

1. **General:** Node `pve` · VM ID **`203`** · Name **`victim-kvm`** → *Next*
2. **OS:** ISO image = das Debian-netinst · Type `Linux` · Version `6.x - 2.6 Kernel` → *Next*
3. **System:** Machine `q35` · SCSI Controller `VirtIO SCSI single` · **`Qemu Agent` ✓**
   (Haken setzen) → *Next*
4. **Disks:** Bus `SCSI` · Storage `local-lvm` · Disk size **`32` GiB** → *Next*
5. **CPU:** Sockets `1` · Cores **`2`** · **Type = `host`** ← wichtig, damit der Gast
   die echte Cache-/LLC-Topologie sieht → *Next*
6. **Memory:** **`2048`** MiB (für Determinismus „Ballooning" deaktivieren) → *Next*
7. **Network:** Bridge **`vmbr0`** · Model `VirtIO (paravirtualized)` → *Next*
8. **Confirm:** prüfen → **`Finish`**.

**Installieren:** VM `203` auswählen → **`Start`** → **`Console`**.
Debian-Installer durchklicken; dabei:

- **Statische IP** setzen: `192.168.178.203` / `255.255.255.0`, Gateway
  `192.168.178.1`, DNS `192.168.178.55`.
- Hostname `victim-kvm`.
- Bei der Software-Auswahl **`SSH server`** anhaken (Desktop abwählen).
- Nach der Installation: deinen SSH-Public-Key in `~/.ssh/authorized_keys` des
  genutzten Users hinterlegen (Key-Auth ist Pflicht, siehe README der Suite).

---

## Teil D · QEMU-VM per Klon (Opfer 201) + KVM abschalten

Statt erneut zu installieren: die KVM-VM **klonen** und nur die
Hardware-Virtualisierung deaktivieren.

1. Rechtsklick auf **`victim-kvm` (203) → `Clone`**.
2. Mode **`Full Clone`** · VM ID **`201`** · Name **`victim-qemu`** → **`Clone`**.
3. VM `201` → **`Options`** → **`KVM hardware virtualization`** → **`Edit`** →
   Haken **entfernen** (= Emulation/TCG).
4. VM `201` → **`Hardware`** → **`Processors`** → **`Edit`** → Type von `host` auf
   **`qemu64`** ändern (mit KVM aus ist `host` ungültig).
5. Im Gast (Console): Hostname auf `victim-qemu` und **IP auf
   `192.168.178.201`** ändern (sonst Konflikt mit dem Klon-Original!).

> Dieser Gast bootet/läuft deutlich langsamer — das ist der gewollte
> Emulations-Overhead, kein Fehler.

---

## Teil E · LXC-Container (Angreifer 200 + Opfer-LXC 202)

Oben rechts **`Create CT`** — zweimal, mit diesen Werten:

| Feld | Angreifer | Opfer-LXC |
| --- | --- | --- |
| **CT ID** | `200` | `202` |
| **Hostname** | `attacker` | `victim-lxc` |
| **SSH public key** | *(deinen Key einfügen)* | *(deinen Key einfügen)* |
| **Template** | `debian-12-standard` | `debian-12-standard` |
| **Disk (rootfs)** | `8` GiB | `8` GiB |
| **CPU Cores** | `2` | `2` |
| **Memory** | `2048` MiB | `2048` MiB |
| **Network IPv4** | static `192.168.178.200/24` | static `192.168.178.202/24` |
| **Gateway** | `192.168.178.1` | `192.168.178.1` |
| **DNS** | `192.168.178.55` | `192.168.178.55` |

Klick-Ablauf je Container: **General** (ID, Hostname, SSH-Key) → **Template** →
**Disks** → **CPU** → **Memory** → **Network** (IPv4 *Static*, Adresse + Gateway)
→ **DNS** → **Confirm → Finish**. Danach **`Start`**.

---

## Teil F · CPU-Pinning auf den P-Core `4,5`

### F.1 VMs (201 + 203) — per Klick

Für **jede** VM: **`Hardware` → `Processors` → `Edit`** → Abschnitt
**`Advanced`** aufklappen → Feld **`CPU affinity`** = **`4,5`** → **`OK`**.

### F.2 LXC-Container (200 + 202) — ein Shell-Schritt nötig

Die GUI bietet **kein** CPU-Affinity-Feld für Container. Daher einmalig in der
**Host-Shell** (`pve → Shell` oder SSH zum Host):

```bash
echo 'lxc.cgroup2.cpuset.cpus: 4,5' >> /etc/pve/lxc/200.conf
echo 'lxc.cgroup2.cpuset.cpus: 4,5' >> /etc/pve/lxc/202.conf
pct reboot 200; pct reboot 202
```

### F.3 Verifikation (Host-Shell)

```bash
qm config 201 | grep affinity        # -> affinity: 4,5
qm config 203 | grep affinity
grep cpuset /etc/pve/lxc/200.conf /etc/pve/lxc/202.conf
```

---

## Teil G · Host-Determinismus (nach dem BIOS, vor den Messungen)

Auch mit BIOS-Einstellungen müssen Governor und Turbo per OS gesetzt werden
(volatil, siehe [`PoC.md`](PoC.md)). In der **Host-Shell**:

```bash
echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

Für die persistente C-State-Unterdrückung per Kernel-Parameter (`intel_idle...`)
siehe [`PoC.md`](PoC.md), Abschnitt 2.

---

## Danach

IPs in [`../experiments/config.env`](../experiments/config.env) sind bereits auf
dieses Schema gesetzt. Weiter mit:

```bash
cd project/experiments
./run_experiment.sh --install --deploy-only   # Werkzeuge + Skripte ausrollen
./run_experiment.sh                            # PoC
./run_fallback.sh --install                    # Fallback-Vergleich
```
