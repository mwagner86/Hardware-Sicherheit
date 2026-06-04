# Literaturzugang & Bezugsquellen

Dieses Dokument dokumentiert die exakten Zugangsmöglichkeiten zu der im Projekt verwendeten Primärliteratur. Der Zugriff auf verlagsgebundene Volltexte erfordert eine aktive VPN-Verbindung in das Netz der Hochschule.

## 1. An analysis of performance interference effects in virtual environments
* **Autoren:** Koh, Y., et al. (2007)
* **Publikationsort:** IEEE ISPASS
* **Direktlink:** [https://ieeexplore.ieee.org/document/4211036](https://ieeexplore.ieee.org/document/4211036)
* **Zugang:** Volltextzugriff lizenziert über Uni-VPN (IEEE Xplore).

## 2. A survey of microarchitectural timing attacks and countermeasures on contemporary hardware
* **Autoren:** Ge, Q., et al. (2018)
* **Publikationsort:** Journal of Cryptographic Engineering, Springer
* **Direktlink:** [https://link.springer.com/article/10.1007/s13389-016-0141-6](https://link.springer.com/article/10.1007/s13389-016-0141-6)
* **Zugang:** Volltextzugriff lizenziert über Uni-VPN (SpringerLink).

## 3. Security Recommendations for Server-based Hypervisor Platforms
* **Autoren:** Chandramouli, R. (NIST)
* **Publikationsart:** NIST Special Publication 800-125A
* **Direktlink:** [https://csrc.nist.gov/pubs/sp/800/125/a/r1/final](https://csrc.nist.gov/pubs/sp/800/125/a/r1/final)
* **Zugang:** Open Access (NIST Computer Security Resource Center).# Literaturzugang & Bezugsquellen

Dieses Dokument dokumentiert die Zugangsmöglichkeiten zu der im Projekt verwendeten Primärliteratur. Der Zugriff auf verlagsgebundene Volltexte (IEEE, Springer) erfordert eine aktive VPN-Verbindung in das Netz der Hochschule zur Nutzung der entsprechenden Campuslizenzen.

## 1. An analysis of performance interference effects in virtual environments
* **Autoren:** Koh, Y., Knauerhase, R., Brett, P., Bowman, M., Wenisch, T. F., & Pu, C. (2007)
* **Publikationsort:** IEEE International Symposium on Performance Analysis of Systems & Software (ISPASS)
* **Bezugsquelle:** IEEE Xplore Digital Library
* **DOI:** `10.1109/ISPASS.2007.363750`
* **Zugang:** Volltextzugriff lizenziert über Uni-VPN.

## 2. A survey of microarchitectural timing attacks and countermeasures on contemporary hardware
* **Autoren:** Ge, Q., Yarom, Y., Cock, D., & Heiser, G. (2018)
* **Publikationsort:** Journal of Cryptographic Engineering, Vol. 8, Springer
* **Bezugsquelle:** SpringerLink
* **DOI:** `10.1007/s13389-017-0152-y`
* **Zugang:** Volltextzugriff lizenziert über Uni-VPN. Alternativ sind Vorabversionen (Preprints) dieser Publikation frei zugänglich auf akademischen Repositorien (z. B. arXiv.org) verfügbar.

## 3. Security Recommendations for Server-based Hypervisor Platforms
* **Autoren:** Chandramouli, R. (2014)
* **Herausgeber:** National Institute of Standards and Technology (NIST)
* **Publikationsart:** NIST Special Publication (SP) 800-125A
* **Bezugsquelle:** Computer Security Resource Center (CSRC)
* **DOI:** `10.6028/NIST.SP.800-125A`
* **Zugang:** Open Access. Als technischer Standard der US-Regierung ist das Dokument vollständig und kostenfrei öffentlich zugänglich.

# Dokumentation der Literaturrecherche: Suchstrings

Die nachfolgenden booleschen Suchabfragen sind für die Verwendung in wissenschaftlichen Literaturdatenbanken (insbesondere IEEE Xplore und SpringerLink) optimiert.

## 1. Hauptthema: Mikroarchitektonische Ressourcen-Interferenzen (Noisy-Neighbor)

### 1.1 Technische Grundlagen und Methodiken
Fokus: Hypervisor-Architektur (KVM), Performance-Benchmarking, Grundlagen geteilter Caches.
* `("virtual machine monitor" OR hypervisor OR KVM) AND ("last level cache" OR LLC OR "shared cache") AND ("performance analysis" OR benchmarking)`
* `("performance isolation" OR "resource sharing") AND "virtualization" AND "CPU pinning"`

### 1.2 Aktuelle Themen
Fokus: Moderne Hardware-Mitigierungen (Intel RDT/CAT), aktuelle Manifestationen des Noisy-Neighbor-Effekts.
*Datenbank-Filter:* Publikationsjahr >= 2020
* `("Intel RDT" OR "Cache Allocation Technology" OR "hardware mitigation") AND ("noisy neighbor" OR "performance interference")`
* `("resource allocation" OR "QoS") AND "last level cache" AND "cloud computing"`

### 1.3 Wissenschaftliche Publikationen
Fokus: Empirische Untersuchungen von mikroarchitektonischen Interferenzen, Cache-Eviction-Angriffen und Performance-Degradation.
* `("microarchitecture" OR "micro-architectural") AND ("cache contention" OR "cache eviction") AND "virtualization"`
* `("denial of service" OR DoS OR "performance degradation") AND "shared cache" AND "hypervisor"`

## 2. Allgemeine aktuelle Literatur zu Virtuellen Maschinen
Fokus: Moderne Performance-Evaluierungen, Ressourcenmanagement und Architektur-Optimierungen in aktuellen Cloud- und Edge-Topologien.
*Datenbank-Filter:* Publikationsjahr >= 2022
* `("virtual machine" OR hypervisor OR KVM) AND ("performance evaluation" OR overhead OR "resource management") AND ("cloud computing" OR "edge computing")`

## 3. Fallback-Strategie: Virtualisierungsparadigmen im Vergleich
Fokus: Empirische Leistungsvergleiche zwischen hardwareunterstützter Virtualisierung (KVM/QEMU) und OS-Level-Virtualisierungen (LXC/Docker/Container) hinsichtlich I/O-Latenz, Durchsatz und System-Overhead.
*Datenbank-Filter:* Publikationsjahr >= 2022
* `(KVM OR QEMU OR hypervisor) AND (LXC OR Docker OR container OR "lightweight virtualization") AND ("performance comparison" OR benchmark OR overhead)`