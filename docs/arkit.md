# ARKit-Grundlage für das DriveBot AR-HUD

## Diagnose des bisherigen Verhaltens

DriveBot nutzte bereits ARKit als Kamerahintergrund, aber die sichtbare Markerposition war weiterhin überwiegend eine **Flutter-2D-Projektion**:

- iOS startete `ARWorldTrackingConfiguration` mit `.gravityAndHeading` und verwaltete einfache `ARAnchor`-Instanzen, wenn Flutter bereits vorberechnete `x/y/z`-Werte per `syncAnchors` sendete.
- Flutter berechnete Marker-X aus Bearing, Fahrer-Heading und horizontalem FOV.
- Flutter berechnete Marker-Y aus einem Horizon-/Pitch-Fallbackmodell statt aus der aktiven ARKit-Kamera.
- ARFrame-Kamera-Transform und ARKit-Kameraprojektion wurden nicht genutzt, um Flutter-Marker auf dem Screen zu positionieren.
- ARKit-Anker wurden zwar nicht auf jedem Frame neu erstellt, aber es gab keine Session-Origin-Rekalibrierung nach ARKit-CoreLocation-Muster und keine native Rückmeldung für „versteckt wegen Tracking“ oder „versteckt wegen FOV“.

Dadurch fühlten sich Marker nicht sauber horizon-anchored an: Pitch/Roll wirkten nur über ein vereinfachtes Flutter-Modell, die Projektion war an Heading/FOV statt an die ARKit-Kamerapose gekoppelt, und entfernte Ziele konnten visuell eher wie Screen-Overlays als geostationäre Objekte wirken. Die Fallback-Projektion bleibt erhalten, ist aber jetzt eindeutig die zweite Wahl.

## Referenzmuster und Integrationsansatz

Die neue Architektur orientiert sich konzeptionell an bewährten ARKit + CoreLocation / Geo-AR-Patterns:

- **Location Nodes:** Ziele behalten stabile IDs und werden als lokale Weltpositionen relativ zu einem Session-Origin geführt.
- **Geo -> ENU -> ARKit:** Latitude/Longitude werden in East/North/Up-Meter übersetzt; SceneKit/ARKit nutzt `x = east`, `y = up`, `z = -north`.
- **Rekalibrierung statt Per-Frame-Neubau:** Native Anker werden nur bei sinnvoller Nutzerbewegung, Heading-Drift, Tracking-State-Wechsel oder relevanter Zielpositionsänderung neu gesetzt.
- **ARKit-Kameraprojektion:** Die native Schicht projiziert 3D-Weltpunkte mit der aktiven `ARFrame.camera` in Screen-Koordinaten. Flutter rendert weiterhin die bekannten DriveBot-Marker an diesen nativen `x/y`-Positionen.

DriveBot nutzt weiterhin keine `ARGeoTrackingConfiguration`/`ARGeoAnchor` als harte Voraussetzung, weil deren Verfügbarkeit regional/geräteabhängig ist. Der aktuelle MVP setzt auf robuste, geo-abgeleitete ARKit-World-Tracking-Anker mit Fallback.

## AR-Ankermodelle

Die AR-Domäne unterscheidet mehrere Ebenen:

- `ArGeoAnchorCandidate`: UI-agnostischer Kandidat mit stabiler ID, Latitude/Longitude, optionaler Altitude, GPS-Distanz/Bearing, Typ, Quelle und Confidence.
- `ArAnchorProjection`: Übergabemodell an iOS mit ENU-/ARKit-Koordinate plus aktueller Nutzerposition und Heading.
- `ArWorldAnchorState`: native Rückmeldung mit `projectionSource`, optionalem nativen Screen-`normalizedX/top`, Tracking-Confidence, Visibility, Hidden-Reason und Rekalibrierungsalter.
- `ArTrackingQuality`: gemeinsame Qualitätsstufe für `stable`, `limited`, `unavailable` und `unknown`.

## Geo-zu-AR-Konvertierung

Flutter berechnet weiterhin eine UI-agnostische lokale Koordinate für Tests, Fallback und Payloads:

1. Lokale Tangentialebene relativ zur Nutzer-/Session-Origin-Position bilden.
2. Latitude-/Longitude-Deltas in ENU-Meter übersetzen:
   - `eastMeters = deltaLongitudeRadians * cos(originLatitudeRadians) * earthRadius`
   - `northMeters = deltaLatitudeRadians * earthRadius`
   - `upMeters = targetAltitude - currentAltitude`, sonst stabil `0`
3. GPS-Distanz und Bearing nur noch für Labels, Fallback und Debug ableiten.
4. In ARKit-Konvention mappen:
   - `x = east/right`
   - `y = up`
   - `z = -north/forward`

Die iOS-Schicht berechnet aus aktueller Nutzerposition und Ziel-Lat/Lon erneut eine native Session-Origin-relative ENU-Position. Fehlende Altitude wird nicht künstlich gestreut; `y` bleibt stabil auf Horizont-/Bodenebene, bis eine verlässliche Altitude vorliegt. Entfernungstexte bleiben GPS-basiert und werden nicht aus ARKit-Koordinaten abgeleitet.

## Native iOS-Schicht

Die native Schicht liegt in `ios/Runner`:

- `ArKitRuntimeController.swift` prüft ARKit-Verfügbarkeit, stellt den MethodChannel `drivebot/arkit_runtime` bereit und nimmt `syncAnchors` entgegen.
- `ArKitViewFactory.swift` registriert die PlatformView `drivebot/arkit_view`.
- `ArKitView.swift` rendert eine `ARSCNView`, startet `ARWorldTrackingConfiguration` mit `.gravityAndHeading`, verwaltet geo-abgeleitete `ARAnchor`-Instanzen und projiziert Weltpunkte per aktiver `ARFrame.camera` auf Screen-Koordinaten.

Native Stabilisierung:

- Session-Origin wird aus aktueller Nutzer-Lat/Lon/Heading gebildet.
- Rekalibrierung erfolgt bei mehr als 5 m Nutzerbewegung, mehr als 8° Heading-Drift oder ARKit-Tracking-State-Wechsel.
- Anchors behalten stabile IDs und werden nur bei mehr als 2 m lokaler Positionsänderung neu gesetzt.
- Projektionspunkte werden native geglättet, bevor Flutter sie erhält.
- Bei eingeschränktem Tracking liefert iOS `hiddenReason = tracking`; bei außerhalb der Kamera/FOV `hiddenReason = fov`.

Die App nutzt weiter CocoaPods und die bestehende Runner-Konfiguration. Bundle ID, Signing, Team ID und AppIcon bleiben unverändert.

## Flutter-Laufzeitabstraktion

Die Flutter-Seite kapselt ARKit hinter einer Runtime-Abstraktion:

- `ArRuntimeService` beschreibt Status, Support, Start, Stop und Anchor-Synchronisierung.
- `IosArKitRuntimeService` sendet Kandidaten inklusive Nutzerposition, Zielposition, Heading und ARKit-Koordinate über den MethodChannel.
- `ArRuntimeState` hält Support, Verfügbarkeit, Laufstatus, Berechtigungsstatus, Tracking-Qualität und Fallback-Grund.
- `ArAnchorProjectionService` bevorzugt native Screen-Koordinaten aus `ArWorldAnchorState`, fällt bei fehlender nativer Projektion auf Bearing/FOV/Horizon zurück und zählt Hidden-Gründe getrennt.
- `HudScreen` hält native Anchor-States in Memory, ohne Warnrepositories auf Sensor-/AR-Ticks neu zu fetchen.
- `ArKitCameraBackground` entscheidet zwischen nativer ARKit-PlatformView und bestehendem Kamera-Fallback.

Deutsch sichtbare Statuslabels bleiben:

- „AR verankert“
- „Tracking eingeschränkt“
- „Kamera-Fallback“
- „Standort erforderlich“

## Fallback-Verhalten

ARKit ist optional. Wenn ARKit, iOS, Kamera-Berechtigung, Location/Heading oder die native Bridge nicht verfügbar sind, bleibt DriveBot im sicheren HUD-Fallback:

1. **ARKit-Projektion verfügbar und Tracking stabil:** native ARKit-Kameraprojektion liefert Screen-X/Y; Flutter rendert die bestehenden DriveBot-Marker an diesen Positionen.
2. **ARKit aktiv, aber Tracking/FOV nicht nutzbar:** geospatiale Marker werden ausgeblendet oder de-priorisiert; Debug zeigt Tracking-/FOV-Gründe.
3. **Native Projektion fehlt:** stabilisierte Bearing-/FOV-Projektion mit Horizon-Modell.
4. **Location/Heading fehlt:** geospatiale Marker werden nicht verankert; das HUD zeigt weiter sichere Fallback-Informationen.

## Debug-Modus

Wenn die Debug-/Datenquellenanzeige aktiv ist, zeigt DriveBot jetzt zusätzlich:

- AR-Projektion: `native` oder `fallback`
- ARKit-Tracking-State
- Zielanzahl
- projizierte Markeranzahl
- versteckt wegen Tracking
- versteckt wegen FOV
- letzte Rekalibrierung

Es werden keine Secrets und keine rohen User-IDs angezeigt.

## Validierung und bekannte Grenzen

Die Flutter-Schicht kann lokal per Analyzer und Tests geprüft werden. Native Swift/XCTest-Strukturen sind in dieser Linux-Umgebung nicht praktisch ausführbar; die ARKit-Kompilierung und native Projektion müssen in Codemagic/TestFlight final validiert werden, weil Linux keine iOS-Builds ausführen kann. Fahrtests auf einem echten iPhone müssen insbesondere Heading-Qualität, Drift, Rekalibrierungsschwellen, FOV-Ausblendung und Lesbarkeit im Fahrzeug prüfen.

`ARGeoAnchor` bleibt ein zukünftiger Upgrade-Pfad für Geräte/Regionen, in denen Apple Geographic Location Tracking zuverlässig verfügbar ist. Der aktuelle MVP nutzt absichtlich geo-abgeleitete World-Tracking-Anker plus Fallback, damit Kamera-Startup, Supabase-Login, Community-Reporting und Fallback-Modus unverändert robust bleiben.
