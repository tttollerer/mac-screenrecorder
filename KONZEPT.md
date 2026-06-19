# Konzept: Mac Screenrecorder fuer Web-App-Demos

## Zielbild

Ein einfacher, hochwertiger Screenrecorder fuer macOS, optimiert fuer die Praesentation von Web-Apps. Das Tool soll sich wie eine native Mac-App anfuehlen: ruhig, klar, systemnah und ohne ueberladene Videoproduktionsfunktionen.

Der Fokus liegt auf schnellem Aufnehmen, sauberem Ton und professionell wirkenden Demos, die direkt an Kunden, Teams oder in Social-/Produktkommunikation weitergegeben werden koennen.

## Zielgruppe

- Founder, Produktteams und Entwickler, die Web-Apps praesentieren
- Sales- und Customer-Success-Teams fuer kurze Produktdemos
- Designer und PMs fuer Feature-Walkthroughs
- Support-Teams fuer reproduzierbare Bug- oder Erklaervideos

## Produktprinzipien

1. Schnell startklar: Aufnahme in wenigen Sekunden.
2. Native macOS-Anmutung: SwiftUI, Systemmaterialien, klare Toolbar, keine verspielte UI.
3. Wenige, gute Defaults: Standardwerte sollen fuer Web-App-Demos direkt passen.
4. Ton ist erstklassig: Mikrofon und Systemaudio muessen verlaesslich steuerbar sein.
5. Kein Videoschnittprogramm: Nur leichte Nachbearbeitung, Export und Teilen.

## Kernnutzen

Das Tool nimmt Bildschirm, Mikrofon und Systemaudio auf und erzeugt daraus eine saubere Demo-Datei. Es hilft besonders bei Web-App-Praesentationen durch:

- Aufnahme eines Browserfensters oder ausgewaehlten Bildschirmbereichs
- optionalen Cursor-Highlight und Klick-Feedback
- Mikrofonkommentar plus Systemaudio
- Countdown, Pausieren und Fortsetzen
- schnelle Vorschau und Export als MP4

## MVP-Funktionsumfang

### Aufnahme

- Ganzer Bildschirm
- Einzelnes Fenster
- Frei waehlbarer Bereich
- Mikrofon ein/aus mit Pegelanzeige
- Systemaudio ein/aus
- Countdown: 3 Sekunden
- Pause/Fortsetzen
- Stop ueber schwebende Mini-Steuerung oder Menueleisten-Icon

### Demo-Hilfen

- Cursor sichtbar ein/aus
- dezenter Cursor-Spotlight-Modus
- Klick-Animation ein/aus
- automatische Aufnahmebenennung nach Datum und App/Fenster
- optional: Browserfenster automatisch erkennen und vorschlagen

### Nach der Aufnahme

- Sofortige Vorschau
- Trimmen von Anfang und Ende
- Export als MP4
- Speichern in frei waehlbarem Ordner
- Kopieren des Dateipfads
- Teilen ueber macOS Share Sheet

## Nicht im MVP

- Mehrspuriger Videoschnitt
- Text-Overlays und komplexe Animationen
- Cloud-Upload
- Teamverwaltung
- Automatische Untertitel
- Webcam-Bubble

Diese Funktionen koennen spaeter kommen, sollten den ersten Release aber nicht verlangsamen.

## UX-Konzept

### Hauptfenster

Das Hauptfenster ist ein kompaktes Utility-Fenster mit drei Zonen:

1. Aufnahmequelle
   - Bildschirm
   - Fenster
   - Bereich

2. Audio
   - Mikrofon-Auswahl
   - Mikrofon-Pegel
   - Systemaudio-Schalter
   - kurzer Hinweis, falls Berechtigungen fehlen

3. Aufnahmeaktion
   - grosser primaerer Button "Aufnehmen"
   - sekundäre Optionen: Countdown, Cursor, Klicks

Die Oberflaeche sollte eher wie QuickTime + Control Center wirken als wie ein Creator-Tool.

### Schwebende Steuerung

Waehrend der Aufnahme erscheint eine kleine, frei verschiebbare Steuerung:

- Aufnahmedauer
- Pause/Fortsetzen
- Stop
- Mikrofonstatus

Sie soll minimal bleiben und nicht im Aufnahmebereich stoeren. Wenn sie doch im aufzunehmenden Bereich liegt, wird sie aus der Aufnahme ausgeschlossen, sofern technisch moeglich.

### Menueleiste

Ein Menueleisten-Icon ermoeglicht:

- neue Aufnahme starten
- laufende Aufnahme stoppen
- letzten Export oeffnen
- Einstellungen oeffnen

Die App kann trotzdem als normale Dock-App starten. Das Menueleisten-Icon ist eine schnelle Steuerung, nicht die komplette App.

### Vorschau-Ansicht

Nach dem Stoppen oeffnet sich eine ruhige Vorschau:

- Videoplayer
- Anfang/Ende trimmen
- Dateiname
- Speicherort
- Export-Button
- Share-Button

Keine Timeline mit vielen Spuren. Nur das, was fuer schnelle Demos gebraucht wird.

## Visueller Stil

- Native SwiftUI-Komponenten
- systemadaptive Farben fuer Light/Dark Mode
- dezente Materialien statt harter Custom-Flaechen
- kompakte Toolbars
- SF Symbols fuer Aktionen
- klare Typografie mit System Font
- keine Marketing-Hero-Optik
- keine bunten Gradients oder dekorativen Karten

Der Look soll nach macOS Sonoma/Tahoe Utility-App aussehen: praezise, hochwertig, unaufdringlich.

## Einstellungen

Eigene macOS-Settings-Szene mit:

- Standard-Speicherort
- Standard-Format: MP4
- Countdown an/aus
- Cursor anzeigen
- Klicks hervorheben
- Standard-Mikrofon
- Systemaudio standardmaessig aktivieren
- Tastenkurzel fuer Start/Stop

## Technisches Konzept

### Plattform

- macOS native App
- SwiftUI fuer UI und Szenen
- AppKit nur fuer noetige Fenster-/Panel-Details
- Ziel: moderne macOS-Versionen mit ScreenCaptureKit-Unterstuetzung

### Bildschirmaufnahme

ScreenCaptureKit ist die naheliegende Basis fuer:

- Display Capture
- Window Capture
- Region Capture ueber Crop/Filter-Logik
- Cursor-Aufnahme
- Systemaudio-Capture, sofern vom System erlaubt

### Mikrofon

Mikrofonaufnahme ueber AVFoundation/AVAudioEngine:

- Geraeteauswahl
- Pegelmessung
- Synchronisation mit Videostream
- Mischen mit Systemaudio vor dem Export

### Encoding

AVAssetWriter fuer:

- H.264/H.265 Video
- AAC Audio
- MP4/MOV Pipeline

Fuer den MVP ist MP4 als Standardformat sinnvoll, weil es fuer Web, Slack, Mail und Praesentationen am kompatibelsten ist.

### Berechtigungen

Die App braucht klare, freundliche Berechtigungsflows fuer:

- Screen Recording
- Microphone
- ggf. Accessibility fuer globale Shortcuts oder Cursor-/Klickfeatures

Wenn eine Berechtigung fehlt, zeigt die UI keine technische Fehlermeldung, sondern eine konkrete Aktion: "Bildschirmaufnahme in Systemeinstellungen erlauben".

## Architekturvorschlag

- `App/`: App-Einstieg, Scenes, Menueleiste
- `Views/`: Hauptfenster, Aufnahmeauswahl, Audiosektion, Vorschau, Settings
- `Models/`: Aufnahmequelle, Audioquelle, Exportoptionen, Aufnahmestatus
- `Stores/`: User Defaults, Aufnahmehistorie, Settings
- `Services/`: ScreenCaptureService, AudioCaptureService, RecordingCoordinator, ExportService, PermissionService
- `Support/`: Formatierung, Dateinamen, Shortcuts, Logging

Der `RecordingCoordinator` ist die zentrale Schicht zwischen UI und Capture/Export. Dadurch bleibt die SwiftUI-Oberflaeche schlank und testbar.

## Hauptflow

1. App oeffnen
2. Aufnahmequelle waehlen
3. Mikrofon und Systemaudio pruefen
4. Aufnehmen klicken
5. Countdown
6. Schwebende Steuerung zeigt Laufzeit
7. Stop
8. Vorschau oeffnet sich
9. Optional trimmen
10. Exportieren oder teilen

## Roadmap nach dem MVP

### Version 1.1

- Webcam-Bubble
- automatische Browserfenster-Erkennung
- Aufnahme-Presets fuer Chrome, Safari und Arc
- GIF-Export fuer kurze Clips

### Version 1.2

- einfache Textmarker waehrend der Aufnahme
- automatische Lautheitsnormalisierung
- Kapitelmarken
- Export-Presets fuer LinkedIn, YouTube und interne Demos

### Version 2.0

- Cloud-Sharing
- Kommentarlinks
- Team-Library
- automatische Transkription und Untertitel

## Risiken und offene Punkte

- Systemaudio-Capture muss auf den Ziel-macOS-Versionen sauber validiert werden.
- Audio-/Video-Synchronitaet ist kritisch und sollte frueh mit laengeren Testaufnahmen geprueft werden.
- Das Ausschliessen der eigenen Floating Controls aus der Aufnahme kann je nach Capture-Modus technische Grenzen haben.
- Globale Shortcuts und Klick-Visualisierung koennen zusaetzliche Berechtigungen erfordern.
- Region Capture braucht eine sehr polierte Auswahlinteraktion, sonst wirkt das Tool sofort weniger hochwertig.

## MVP-Erfolgskriterium

Eine Person kann innerhalb von 30 Sekunden eine Web-App-Demo mit Mikrofonkommentar und Systemaudio aufnehmen, das Ergebnis direkt anschauen, kurz trimmen und als MP4 teilen.
