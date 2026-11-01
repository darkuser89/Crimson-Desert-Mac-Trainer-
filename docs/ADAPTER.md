# Einen echten Spieladapter implementieren

## Architektur

`Launcher → Runtime → GameBridge → GameAdapter → Spiel`

Der Launcher speichert auf Wunsch die Auswahl getrennt je Profil. `Runtime`
übergibt die normalisierten Schalter und Zahlenwerte an `GameBridge`, bevor der
erste Poll beginnt. Die Bridge wartet bei Ladepausen auf einen gültigen
Spielkontext. Einmalaktionen bleiben beim Wiederherstellen aus; der Netzwerkstatus
sperrt weder Cheats noch löscht er die Auswahl. Änderungen sendet die Runtime nur mit passender
Sitzungskennung, Profil-ID und Prozess-ID an den Launcher zurück. Bei eigener
Adapter-Implementierung diese Start- und Rückmeldekette beibehalten.

Die UI übergibt ausschließlich Funktions-ID und Zahlenwert. Sie greift nie auf
native Spielobjekte zu. `GameBridge` verwaltet Auswahl, Kontextkennung und eine
begrenzte serielle Warteschlange. Der Adapter besitzt alle engine-spezifischen
Handles, Aufrufe, Baselines und Rücknahmen. `DemoAdapter` bleibt davon getrennt.

## 1. Tatsächlichen Build bestimmen

`script/inspect_game.py` liest App-Metadaten, Architektur/UUID, Signaturstatus und
Signaturdetails. Im Profil `Resources/TrainerConfig.json` die realen Werte
`bundleIdentifier`, `executable`, `uuids`, optional `version` und
`teamIdentifier` eintragen. Mehrere Store-Editionen erhalten getrennte Profile.
Erst nach Adapter-Prüfung `enabled` setzen. Die UUID-Liste darf keine erfundenen
Werte enthalten; der enthaltene Leser unterstützt nur dünne arm64-Mach-O-Dateien.

Die Runtime begrenzt sich zusätzlich auf den tatsächlichen Executable-Pfad,
Bundle-ID und UUID des vom Launcher gestarteten Prozesses. Ein leerer oder
fehlender Konfigurationspfad darf keinen Fehler im Zielprozess auslösen.

## 2. Die sechs Adapter-Methoden

| Methode | Verantwortung |
| --- | --- |
| `onGameThread:` | Arbeit asynchron auf den tatsächlichen Gameplay-Thread des Spiels zustellen; nicht blind auf eine eigene Dispatch-Queue |
| `captureContext` | Unsupported, Loading, Solo oder Network sowie eine Identität für Welt/Spieler/Besitzer liefern |
| `releaseEffects` | Ausschließlich eigene Gründe, Flags, Faktoren und Baselines lösen; Auswahl bleibt in der Bridge |
| `applyFeature:wanted:value:` | Kontext/Objekte prüfen, Originalwerte einmal erfassen, gewünschten Effekt anwenden und zurücklesen |
| `performOneShot:value:` | Eine explizite einmalige Aktion ausführen; keine Wiederholung beim Polling |
| `setOverlayInteraction:` | Cursor und Engine-Eingabemodus übernehmen bzw. exakt zurückgeben; unabhängig vom Sitzungsstatus |

`MTCreateGameAdapter()` muss anschließend den eigenen Adapter erzeugen. Der
Launcher verweigert mit dem unveränderten Unsupported-Adapter den Spielstart.
Neue Adapter-Quelldateien in der `CORE`-Liste des Buildskripts registrieren.
Für den Funktionskatalog sind 1 bis 26 Einträge vorgesehen; bei neuer Anordnung
auch Hotkey-Eindeutigkeit und manuelle Panel-Geometrie prüfen.

## 3. Native Effekte und Besitzer

- Adressen aus dem konkreten Build ermitteln, ASLR berücksichtigen und native
  Funktionssignaturen genau abgleichen. Nichts aus einem fremden Spiel übernehmen.
- Geeignete Engine-Weak-Handles verwenden. Ein gecasteter Pointer, `__weak void *`
  oder ein UObject-Outer ist kein Nachweis des lokalen Besitzers.
- Waffen und Handler vom tatsächlichen Ausrüstungs-Slot her prüfen. Ein fremder,
  zerstörter oder alter Besitzer darf nicht verändert werden.
- Originalwerte nur beim Aktivieren/Bindungswechsel erfassen. Wiederholtes Polling
  darf Faktoren und eigene XP-/Inventarergänzungen nicht erneut multiplizieren.
- Nur eigene Modifikator-IDs, Gründe oder Flags lösen. Fremde Buffs und Spielmenüs
  nicht zurücksetzen. Aktive Farbe erst nach Rückleseprüfung setzen.
- `MemoryAccess` erlaubt nur bereits schreibbare Datenseiten. Es ist weder ein
  Scanner noch ein Hook- oder Schutzumgehungssystem.

## 4. Ladepausen und Sitzungswechsel

Fehlt die Spielfigur kurzzeitig, ist das zunächst eine Ladepause. Ein fehlender
Pointer allein ist kein Netzwerk-Nachweis. Bei Loading und tatsächlichem
Welt-/Spielerwechsel alte Wirkungen lösen und nach validiertem Spielkontext neu
binden. Die Kontextidentität muss auch Besitzer- und relevante Sessionwechsel
abbilden. Raw-Pointer-Adressen allein können durch Wiederverwendung täuschen.

Eine bestätigte Netzwerksitzung bleibt ein nutzbarer Kontext. Bei ihrem Beginn
werden alte Wirkungen gelöst und die gewählte Auswahl auf gültige neue Besitzer
angewandt. ⇧F9 und die Rückgabe der Maus bleiben möglich. One-Shots tragen die alte
Kontextkennung und dürfen nach einem Wechsel nicht nachgeholt werden.

## 5. Cursor und Klicks

Die Runtime leitet lokale Mausklicks direkt an das Overlay weiter, bevor das
Spielfenster sie konsumiert. Nur im Panel begonnene Sequenzen gehören dem Overlay;
Drag und Mouse-up bleiben auch außerhalb beziehungsweise nach dem Schließen
zugeordnet. Ein sichtbares Overlay fordert immer die Maus an; verborgenes
Overlay reicht Klicks an das Spiel durch.

Ein sichtbarer AppKit-Cursor bedeutet noch nicht, dass die Engine die Mausbindung
freigegeben hat. Im Spiel die nativen Capture-/Lock-/Hide-/Ignore-Einstellungen,
Cursorart und Controllerbits sichern. Nur eigene UI-Übernahme zurücknehmen;
bestehende oder später geöffnete Spielmenüs nicht überschreiben. Keine globalen
`NSCursor hide/unhide`-Zähler als Ersatz für Engine-Capture verwenden.
`setOverlayInteraction:YES` muss die Maus für das sichtbare Overlay ohne weiteren
Hotkey freigeben und den Erfolg zurückmelden. `NO` stellt die vorherige
Spielsteuerung wieder her. Beides im echten Spiel prüfen.

Native ⌘-^-Hotkeys und lokale Tastenereignisse haben getrennte Zuständigkeiten;
ein natives Ereignis darf nicht über den AppKit-Echo-Weg erneut umschalten.
Registrierungen nur bei aktivem Spielfenster halten. AppKit-Arbeit auf dem
Hauptthread, Engine-Zugriffe auf dem überprüften GameThread ausführen.

## 6. Grenzen und Prüfung

Bibliotheksladen via `DYLD_INSERT_LIBRARIES` ist pro Spiel/Store zu prüfen.
Hardened Runtime, Library Validation, Sandbox und Startdienste können es verhindern.
Dann die Grenze melden; nicht das Originalspiel patchen oder neu signieren, um
eine erfolgreiche Anbindung zu behaupten. Kein Uncut-/DRM- oder Schutz-Bypass
ist Bestandteil dieser Vorlage.

Die enthaltenen Tests verwenden ausschließlich Demo-Werte und selbst erzeugte
Mach-O-Fixtures. Neue Native-Anbindungen mit eigenen, aussagekräftigen Tests
für Besitzerprüfung, Wiederherstellung und abgelehnte Änderungen ergänzen.
Echte Ingame-Tests nur im Umfang des Nutzerauftrags; keine gespeicherte Testmatrix
oder Kompatibilitätszusage aus synthetischen Tests ableiten.

Beim Veröffentlichen Quellcode und App-Build zusammenhalten, lokale Buildpfade
entfernen und signierte ZIPs nach dem Entpacken prüfen. GPL-3.0-only und Herkunft
beibehalten. Ad-hoc-Signierung ist keine Notarisierung.
