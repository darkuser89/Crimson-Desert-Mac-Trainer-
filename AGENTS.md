# Arbeiten mit dieser Trainer-Vorlage

- Lies `SKILL.md` und `docs/ADAPTER.md`, bevor du einen Spieladapter implementierst.
- Für UI-Anpassungen zusätzlich `docs/UI.md` lesen. Native Glasfläche, Legacy-/
  Kontrast-Fallback und Darstellungscache übernehmen; GameThread-/Cheat-Taktung
  sowie Maus-/Sichtbarkeitsregeln dadurch nicht verändern.
- Das Overlay startet verborgen. ⌘ + ^ öffnet es immer mit bedienbarer Maus;
  kein separater Maus-Hotkey und kein sichtbarer Anzeigemodus ohne Maus. Ein
  echter Adapter muss Engine-Capture/Cursor freigeben und beim Schließen
  wiederherstellen; AppKit allein genügt nicht.
- Die Vorlage ist ein Ausgangspunkt, kein universeller Trainer. Behalte die
  deutliche Demo-Kennzeichnung bei. Simulierte Effekte sind keine Ingame-Nachweise.
- Für ein anderes Spiel `script/create_project.py` in einen neuen Codeordner
  verwenden, sofern der Nutzer nicht ausdrücklich diese Vorlage ändern will.
- Spielprofile bleiben deaktiviert, bis tatsächliche Bundle-ID, Executable,
  Architektur, UUID und die dazugehörige Adapter-Anbindung geprüft sind.
- Original-Spiele-Apps und Saves bleiben unverändert, sofern der Nutzer keine
  konkrete abweichende Aktion autorisiert. Diese Vorlage erlaubt keine
  automatischen Spielstarts oder Änderungen an Schutzfunktionen.
- Eine Engine braucht ihre eigene GameThread-Zustellung. AppKit läuft auf dem
  Hauptthread; ein beliebiger Hintergrundthread ersetzt den GameThread nicht.
- Beim Laden Auswahl behalten, alte eigene Effekte lösen und neue Besitzer
  validieren. Der Netzwerkstatus sperrt Cheats nicht und löscht die Auswahl nicht.
  UI-Steuerung und ⇧F9 müssen auch während Ladepausen funktionieren.
- Einmalaktionen nach einem Kontextwechsel verwerfen. Effekte nur nach bestätigter
  Rückleseprüfung grün anzeigen. Native Besitzer über passende Weak-Handles schützen.
- Keine festen Adressen oder vermeintlichen Signaturen aus einem anderen Spiel
  übernehmen. Neue Profile ohne echte Belege nicht als unterstützt bezeichnen.
- Code, Builds und Audit-Unterlagen getrennt halten. Ein stabiler Buildordner
  außerhalb des Codes; nur die aktuelle App behalten. Keine neuen Archive,
  Backup-Repositories oder Quellkopien als automatische Sicherung anlegen.
- Keine Builds, Apps, Logs, Saves, Schlüssel oder lokalen Konto-/Installationspfade
  einchecken. Ein konkreter neuer Projektcode ist die Ausgabe der Vorlage und
  keine Sicherungskopie.
- Nach Änderungen das Buildskript verwenden; es führt die passenden Tests aus.
  Keine Spiele beenden oder für Tests starten, wenn dies nicht beauftragt wurde.
- Externe Veröffentlichung, Commit und Push nur im Umfang des Nutzerauftrags.
