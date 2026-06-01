# ARKit-Grundlage für das DriveBot AR-HUD

## Integrationsansatz

DriveBot nutzt weiterhin das Flutter-HUD als führende Präsentationsschicht. Auf iOS kann darunter optional eine native ARKit-Kamerafläche als `PlatformView` gerendert werden. Die bestehenden Flutter-Marker, Filter, Warnkarten und Reporting-Elemente bleiben darüber liegen.

Der Ansatz ist bewusst eine Grundlage:

- native iOS-ARKit-Kamera und World-Tracking als Hintergrund
- Flutter-HUD-Overlay für Labels, Trefferflächen und Warnlogik
- Fallback auf die bestehende Flutter-Kamera, wenn ARKit nicht verfügbar ist
- keine Pflicht, ARKit oder Login zu verwenden, um den HUD-Modus zu starten

## Native iOS-Schicht

Die native Schicht liegt in `ios/Runner`:

- `ArKitRuntimeController.swift` prüft ARKit-Verfügbarkeit und stellt den MethodChannel `drivebot/arkit_runtime` bereit.
- `ArKitViewFactory.swift` registriert die PlatformView `drivebot/arkit_view`.
- `ArKitView.swift` rendert eine `ARSCNView`, startet minimales World-Tracking und pausiert die Session bei Entsorgung.
- `AppDelegate.swift` registriert MethodChannel und PlatformView minimal beim Start.

Die App nutzt weiter CocoaPods und die bestehende Runner-Konfiguration. Bundle ID, Signing, Team ID und AppIcon bleiben unverändert.

## Flutter-Laufzeitabstraktion

Die Flutter-Seite kapselt ARKit hinter einer kleinen Runtime-Abstraktion:

- `ArRuntimeService` beschreibt Status, Support, Start und Stop.
- `IosArKitRuntimeService` spricht über den MethodChannel mit iOS.
- `ArRuntimeState` hält Support, Verfügbarkeit, Laufstatus, Berechtigungsstatus, Tracking-Qualität und Fallback-Grund.
- `ArKitCameraBackground` entscheidet zwischen nativer ARKit-PlatformView und bestehendem Kamera-Fallback.

Deutsch sichtbare Statuslabels sind:

- „AR aktiv“
- „AR nicht verfügbar“
- „Kamera-Fallback“
- „Tracking eingeschränkt“
- „Tracking stabil“

## Fallback-Verhalten

ARKit ist optional. Wenn ARKit, iOS, Kamera-Berechtigung oder die native Bridge nicht verfügbar sind, bleibt DriveBot im bestehenden Kamera-HUD:

1. ARKit verfügbar und Kamera erlaubt: native ARKit-Kamera im Hintergrund, Flutter-HUD darüber, kompakter Status „AR aktiv“.
2. ARKit nicht verfügbar: bestehender `CameraPreview`-Fallback, kompakter Status „Kamera-Fallback“ oder „AR nicht verfügbar“.
3. Kamera nicht verfügbar: bestehender Mock-/Grid-Hintergrund bleibt aktiv.

## Berechtigungen

Folgende iOS-Zwecktexte sind erforderlich und deutsch gepflegt:

- `NSCameraUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`, weil bereits vorhanden
- `NSMotionUsageDescription`

Es wird keine Hintergrundortung aktiviert und kein `UIBackgroundModes`-Eintrag für Location hinzugefügt.

## Jetzt implementiert

- ARKit-Hintergrund und Tracking-Grundlage per iOS PlatformView
- Flutter-HUD bleibt als Overlay verantwortlich für Warnungen und Interaktion
- AR-Runtime-Status mit deutschen kompakten HUD-Pills
- generisches AR-Ankermodell für Warnungen, Blitzer, Ladestationen und Navigationsziele
- Mapper für bestehende HUD-Marker und Community-Blitzer als AR-Ankerkandidaten
- Fallback auf die bestehende Flutter-Kamera ohne ARKit-Pflicht

## Noch nicht implementiert

- keine präzisen ARKit GeoAnchors
- keine vollständige Turn-by-Turn-Navigation
- keine Objekterkennung
- keine native Synchronisierung von POI-Ankern in ARKit
- keine Produktfunktion für vollständige ARKit-Navigation

## Nächste Schritte

- Geo-verankerte POIs evaluieren, sobald Standortqualität und Geräte-Support zuverlässig sind
- Community-Blitzer als native oder hybride AR-Anker testen
- Ladestationen und Navigationsziele als Anchor-Quellen anbinden
- Routenhinweise als kameraunterstützte AR-Hinweise vorbereiten
- ARKit-Trackingqualität und Re-Lokalisierung mit realen Fahrtests verbessern

## Validierung

Die Flutter-Schicht kann lokal per Analyzer geprüft werden. Die native ARKit-Kompilierung benötigt macOS/Xcode und muss in Codemagic/TestFlight final validiert werden, weil Linux keine iOS-Builds ausführen kann.
