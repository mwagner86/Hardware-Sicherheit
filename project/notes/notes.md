# Notes

## 1. Koh et al. (2007): An Analysis of Performance Interference Effects
* **Performance-Isolation:** Moderne Virtualisierungstechnologien bieten zwar funktionale Sicherheits- und Fehlerisolation, garantieren jedoch keine effektive Performance-Isolation zwischen virtuellen Maschinen (VMs).
* **Mikroarchitektonische Flaschenhälse:** Die gemeinsame Nutzung physischer Hardwarekomponenten führt bei spezifischen Workload-Kombinationen zu signifikanten Leistungsschwankungen (Noisy-Neighbor-Effekt).
* **Interferenz-Faktoren:** Die stärksten messbaren Leistungseinbrüche entstehen durch Cache-Interferenzen (Verdrängung von Cache-Lines im Shared Cache) sowie I/O-Interferenzen bei parallelen Speicherzugriffen.
* **Transparenzproblem:** Da Hypervisor die zugrundeliegende Hardware abstrahieren, bleiben die Ursachen der Interferenz für das Gast-Betriebssystem unsichtbar, was traditionelle Optimierungsstrategien innerhalb der VM nutzlos macht.

## 2. Ge et al. (2018): A Survey of Microarchitectural Timing Attacks
* **Angriffsvektoren in Cloud-Umgebungen:** Die gemeinsame Nutzung mikroarchitektonischer Ressourcen (insbesondere Last Level Cache, Memory Controller) ermöglicht Timing-Angriffe und Informationsabfluss über Isolationsgrenzen hinweg.
* **Cache-Timing-Analysen:** Techniken wie PRIME+PROBE, FLUSH+RELOAD und EVICT+TIME nutzen Latenzunterschiede bei Speicherzugriffen aus, um das Verhalten koexistierender VMs deterministisch zu rekonstruieren (z. B. zur Extraktion kryptografischer Schlüssel).
* **Denial of Service (DoS):** Das gezielte und aggressive Belegen von Shared-Ressourcen (Cache Cleansing, Bus-Sättigung) kann als Angriffsvektor genutzt werden, um die Performance koexistierender Systeme massiv zu degradieren.
* **Mitigierung und Komplexität:** Gegenmaßnahmen wie Cache-Flushing bei Kontextwechseln, Hardware-Partitionierung oder Rauschinjektion existieren, gehen jedoch oftmals mit prohibitiven Performance-Einbußen einher.

## 3. NIST SP 800-125A Rev 1 (2018): Security Recommendations for Hypervisors
* **Plattform-Bedrohungen:** Eines der größten Risiken für Hypervisor-Plattformen sind kompromittierte VMs, die versuchen, die Isolationsgrenzen zu durchbrechen (VM Escape) oder Wirtsressourcen durch unkontrollierten Konsum zu erschöpfen.
* **Hardware-Assistenz zwingend:** Eine rein softwarebasierte Virtualisierung ist unzureichend. Erforderlich sind hardwaregestützte Mechanismen (Instruction Set Virtualization, Hardware-MMU) sowie IOMMU mit DMA-Remapping, um unautorisierte Speicherzugriffe physisch zu unterbinden.
* **Administrative Ressourcenlimitierung:** Um DoS-Szenarien analog zum Noisy-Neighbor-Problem auf Plattformebene zu mitigieren, fordert der Standard die Konfiguration strikter oberer und unterer Schranken (Limits und Reservations) für CPU-Zyklen sowie Speicher- und I/O-Bandbreiten für jede bereitgestellte VM.
