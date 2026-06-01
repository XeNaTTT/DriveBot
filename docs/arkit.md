# ARKit-Grundlage für das DriveBot AR-HUD

## Diagnose des bisherigen Verhaltens

Die bisherige AR-Darstellung war **keine geostationäre AR-Verankerung**. Die App zeigte zwar „AR aktiv“, aber die sichtbaren Warnmarker wurden weiterhin in Flutter als HUD-Overlay gerendert:

- `ArProjectionMapper` projizierte Warnungen anhand von Bearing, Fahrer-Heading und horizontalem FOV auf eine normalisierte X-Position.
- `ArMarkerLayer` zeichnete diese Marker als Flutter-Widgets über Kamera oder ARKit-PlatformView.
- iOS `ArKitView` startete nur `ARWorldTrackingConfiguration` als Kamerahintergrund; es wurden keine nativen AR-Anker für Warnobjekte synchronisiert.

Damit waren Marker screen-/FOV-projiziert und nicht an reale Positionen gebunden. Diese Fallback-Projektion bleibt erhalten, ist aber jetzt nur eine Ebene der Hierarchie.

## Integrationsansatz

DriveBot nutzt weiterhin das Flutter-HUD als führende Präsentationsschicht. Auf iOS kann darunter optional eine native ARKit-Kamerafläche als `PlatformView` gerendert werden. Die bestehenden Flutter-Marker, Filter, Warnkarten und Reporting-Elemente bleiben darüber liegen.

Die neue Grundlage kombiniert:

- GPS-Koordinaten als autoritative Quelle für Entfernung und Bearing
- lokale ENU-Umrechnung relativ zur Nutzerposition
- ARKit-World-Tracking mit `.gravityAndHeading` zur Stabilisierung lokaler Weltanker
- bestehende Flutter-FOV-Projektion als Fallback, wenn ARKit oder Tracking nicht stabil genug sind

Wichtig: DriveBot nutzt hier **keine ARKit GeoAnchors / ARGeoTrackingConfiguration** und behauptet daher keine präzise ARKit-Geo-Anchor-Funktion. Die Anker sind geo-abgeleitete lokale World-Tracking-Anker.

## AR-Ankermodelle

Die AR-Domäne unterscheidet jetzt mehrere Ebenen:

- `ArGeoAnchorCandidate`: UI-agnostischer Kandidat mit `id`, `latitude`, `longitude`, optionaler `altitude`, GPS-basierter `distanceMeters`, `bearingDegrees`, `relativeBearing`, `source`, `label`, `type` und `confidence`.
- `ArAnchorProjection`: lokale Projektion eines Kandidaten mit ENU-Koordinate und ARKit-Koordinate.
- `ArWorldAnchorState`: Rückmeldung der nativen Schicht, ob ein lokaler World-Tracking-Anker angelegt wurde und welche Tracking-Qualität gilt.
- `ArTrackingQuality`: gemeinsame Qualitätsstufe für `stable`, `limited`, `unavailable` und `unknown`.

## Geo-zu-AR-Konvertierung

`GeoArCoordinateMapper` isoliert die Koordinatenlogik:

1. Haversine-Distanz zwischen Nutzer und Ziel berechnen.
2. Initial Bearing von Nutzer zu Ziel berechnen.
3. ENU-artige lokale Koordinate bilden:
   - `eastMeters = sin(bearing) * distance`
   - `northMeters = cos(bearing) * distance`
   - `upMeters = targetAltitude - currentAltitude`, standardmäßig `0`
4. In ARKit-Konvention mappen:
   - `x = east/right`
   - `y = up`
   - `z = -north/forward`

Die Entfernung im Marker bleibt GPS-basiert und wird nicht aus ARKit-Koordinaten abgeleitet.

## Native iOS-Schicht

Die native Schicht liegt in `ios/Runner`:

- `ArKitRuntimeController.swift` prüft ARKit-Verfügbarkeit, stellt den MethodChannel `drivebot/arkit_runtime` bereit und nimmt `syncAnchors` entgegen.
- `ArKitViewFactory.swift` registriert die PlatformView `drivebot/arkit_view`.
- `ArKitView.swift` rendert eine `ARSCNView`, startet `ARWorldTrackingConfiguration` mit `.gravityAndHeading` und verwaltet geo-abgeleitete `ARAnchor`-Instanzen.
- Anchor-IDs entsprechen den Flutter-Objekt-IDs.
- Anker werden nicht auf jedem Tick neu erstellt; sie werden nur aktualisiert, wenn sich die lokale Zielposition um mehr als fünf Meter ändert.
- Bei eingeschränktem oder nicht verfügbarem Tracking liefert iOS Status zurück, statt zu crashen.

Die App nutzt weiter CocoaPods und die bestehende Runner-Konfiguration. Bundle ID, Signing, Team ID und AppIcon bleiben unverändert.

## Flutter-Laufzeitabstraktion

Die Flutter-Seite kapselt ARKit hinter einer Runtime-Abstraktion:

- `ArRuntimeService` beschreibt Status, Support, Start, Stop und Anchor-Synchronisierung.
- `IosArKitRuntimeService` spricht über den MethodChannel mit iOS.
- `ArRuntimeState` hält Support, Verfügbarkeit, Laufstatus, Berechtigungsstatus, Tracking-Qualität und Fallback-Grund.
- `ArAnchorProjectionService` wählt zwischen World-Anchor-Grundlage, stabilisierter Projektion und Fallback.
- `ArKitCameraBackground` entscheidet zwischen nativer ARKit-PlatformView und bestehendem Kamera-Fallback.

Deutsch sichtbare Statuslabels sind:

- „AR verankert“
- „AR aktiv“
- „Tracking eingeschränkt“
- „Kamera-Fallback“
- „Standort erforderlich“

## Fallback-Verhalten

ARKit ist optional. Wenn ARKit, iOS, Kamera-Berechtigung, Location/Heading oder die native Bridge nicht verfügbar sind, bleibt DriveBot im sicheren HUD-Fallback:

1. **ARKit-Anker verfügbar und Tracking stabil:** geo-abgeleitete lokale ARKit-World-Anker werden synchronisiert; Flutter-Marker bleiben als sichere UI darüber.
2. **ARKit aktiv, aber Anker/Tracking nicht nutzbar:** stabilisierte Bearing-/FOV-Projektion oder reduzierter Markerumfang; Status „Tracking eingeschränkt“.
3. **ARKit nicht verfügbar:** bestehender Kamera-/FOV-Fallback bleibt aktiv.
4. **Location/Heading fehlt:** geospatiale Marker werden nicht verankert; das HUD zeigt weiter die nicht-AR Bottom-Warnung bzw. den Status „Standort erforderlich“.

## Marker-Stabilität

- Markerpositionen werden auf Flutter-Seite geglättet, um Sprünge zu reduzieren.
- Native AR-Anker werden nur bei relevanter Positionsänderung aktualisiert.
- Entfernungstexte bleiben live und GPS-basiert.
- Bei eingeschränktem Tracking werden geospatiale Marker reduziert/ausgeblendet, statt falsche Präzision zu suggerieren.

## Validierung

Die Flutter-Schicht kann lokal per Analyzer und Tests geprüft werden. Die native ARKit-Kompilierung benötigt macOS/Xcode und muss in Codemagic/TestFlight final validiert werden, weil Linux keine iOS-Builds ausführen kann. Fahrtests auf einem echten iPhone müssen insbesondere Heading-Qualität, Drift, Anchor-Update-Schwellen und Lesbarkeit im Fahrzeug prüfen.
