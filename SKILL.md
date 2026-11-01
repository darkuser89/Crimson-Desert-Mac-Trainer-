---
name: mactrainertemplate
description: Create a native macOS game-trainer project from this local source template, with a cached AppKit overlay, native Liquid Glass with legacy/accessibility fallback, hotkeys, a simulated demo, and a separate verified game adapter. Use when adapting this template for a named game; this is not a universal cheat engine.
---

# Mac-Trainer aus der Vorlage

Diese Datei unterstützt andere Chats beim Anpassen des mitgelieferten Codes.
Sie ist nur lokal Bestandteil der Vorlage; keine globale Installation annehmen.

## Einstieg

1. `AGENTS.md` beachten und Zielspiel, gewünschte Funktionen und Ziel-Codeordner
   aus dem Nutzerauftrag entnehmen. Fehlen Details, zuerst unabhängig die Demo
   prüfen und den erhaltenen Spielpfad lesend inspizieren.
2. Neues Projekt mit `script/create_project.py` erzeugen. Zielordner, App-Name und
   Bundle-ID passend zum Auftrag wählen; bestehende Projekte nicht überschreiben.
3. Im neuen Projekt mit `script/build_and_run.sh --build-only` starten. Builds
   bleiben außerhalb des Codes. `--demo` öffnet ausdrücklich nur die Simulation.

## Wiederverwendbare UI

Lies [docs/UI.md](docs/UI.md), bevor du die Oberfläche anpasst. Liquid Glass,
Legacy-/Kontrast-Fallback und der Darstellungscache sind bereits enthalten und
werden bei der Projekterzeugung mitkopiert. `TrainerMaterial` nur über seine
Content-Schnittstelle verwenden; ausschließlich den Inhalt skalieren. Das Overlay startet verborgen. ⌘ + ^ öffnet es samt Maus. Keinen zusätzlichen
Maus-Hotkey oder sichtbaren Modus ohne Maus einführen. `setOverlayInteraction:`
muss im echten Adapter den Engine-Cursor sofort freigeben und beim Schließen
die ursprüngliche Spielsteuerung wiederherstellen. Verborgene
UI behält aktuelle Daten und rendert sie beim Öffnen. Der Cache darf die echte
Cheat-Anwendung und die GameThread-Taktung nicht verändern. Zum Bauen wird
Xcode26+ mit macOS26+-SDK benötigt; die App bleibt ab macOS14 ausführbar.

Der Launcher bietet „Cheat-Auswahl beim nächsten Start laden“. Die Vorlage
speichert Schalter und gültige Zahlenwerte getrennt je Profil und stellt sie
erst in einem gültigen Spielkontext wieder her. Einmalaktionen werden
nie automatisch ausgeführt. Der Netzwerkstatus sperrt die Funktionen nicht und
löscht die Auswahl nicht. Beim Übernehmen in ein Spiel die Benachrichtigung mit Sitzungskennung,
Profil und Prozess-ID erhalten und das Verhalten im echten Spiel prüfen.

## Spielanbindung

Lies [docs/ADAPTER.md](docs/ADAPTER.md) für den Adapter-Vertrag und die Stellen,
an denen Threading, Weak-Handles, Cursor, Besitzer und Sitzungsstatus umgesetzt
werden müssen. `script/inspect_game.py` liefert nur Metadaten und eine lesende
Signaturprüfung; daraus folgen noch keine gültigen Cheat-Adressen.

Der reale Start bleibt gesperrt, solange das Profil deaktiviert ist oder
`MTCreateGameAdapter()` den Unsupported-Adapter liefert. Die sechs Demo-Funktionen
sind austauschbare UI-Beispiele. Nur Funktionen anbieten, für die das konkrete
Spiel eine geprüfte Daten-/Native-Anbindung besitzt.

## Prüfung und Übergabe

Nutze das gemeinsame Buildskript und ergänze Regressionstests für neue native
Anbindungen. Prüfe Effekte, Rücklese-Bestätigung, Wiederherstellung, Besitzer-/
Waffenwechsel, Gebietswechsel, fehlende Objekte, veraltete Aktionen, Netzwerkwechsel
und Maus-/Hotkey-Zustellung entsprechend der Änderung.

Unterscheide in der Übergabe Demo, synthetische Tests und echte Ingame-Beobachtungen.
Nenne fehlende Prüfungen ausdrücklich. Spiele und Saves unverändert lassen;
Originalsignaturen nicht durch Neusignieren des Spiels ersetzen. Ein vorhandener
Nutzerauftrag kann Spieltests erlauben, die Vorlage selbst erteilt diese Erlaubnis
nicht. Release-/Upload-Arbeit nur durchführen, wenn beauftragt.
