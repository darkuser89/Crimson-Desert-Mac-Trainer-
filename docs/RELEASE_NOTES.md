Trainer 0.3.0 aktualisiert die nativen Bindings für Spielversion 2.04.05 / Build 437.
UUID und 76 Prüfstellen mit je 32 Bytes werden exakt geprüft; andere Builds bleiben gesperrt.

Nativer Crimson Desert Trainer für die macOS-Steam-Ausgabe auf Apple Silicon.

- Zwölf Funktionen der Referenzvorlage; Gegenstände und Geld separat bedienbar.
- Unbegrenztes Leben, Ausdauer und Geist; Maximalwerte und Verteidigung setzen.
- Superschaden, Inventarmenge, Geld, Spieltempo und Tageszeit.
- Eigenes App-Icon und Launcher mit „Spiel mit Trainer starten“.
- ⌘ + ^ öffnet das Overlay mit Maus; ⇧F9 nimmt Schaltereffekte zurück.

**Spiel-Build:** 2.04.05 / Bundle 1.0.35 (437), Steam arm64.
Andere Builds bleiben gesperrt. Ingame auf Build 437 geprüft: zehn Schalter mit Rückleseprüfung und Rücknahme,
Verbrauchsblockade für Leben/Ausdauer/Geist, exakt +3.600 Sekunden sowie
Fleisch 14 → 15 → 14 und Geld 797.521 → 797.522 → 797.521.
Der frühere Kampfnachweis stammt aus Build 433; kein neuer Kampfversuch auf Build 437.
Keine Zusage für jeden Boss oder geskriptete Todesereignisse. macOS14/15,
Multiplayer und vollständige Gebietsreisen wurden nicht real getestet.

Der GitHub-Build führt die synthetischen Tests und eine ZIP-Entpack-/Signaturprüfung
aus. Er führt keine Spieltests aus. Die App ist ad hoc signiert, nicht
Apple-notarisiert. Die ZIP-Datei ist für Apple Silicon; keine Intel-Ausgabe.

Geld und Gegenstände können gespeichert werden. ⇧F9 macht ausgeführte
Einmalaktionen nicht rückgängig. Installation und Prüfsummen liegen dem Release bei.

GPL-3.0-only. Keine Spieldateien oder Spielstände enthalten.
