# Berlin traffic data for DriveBot

DriveBot consumes Berlin traffic warnings only from public data products. It must not call the private Concert/OCIT-C service, must not use private credentials, and must not add API keys unless a future endpoint explicitly requires a secret-backed configuration.

## Verified repositories

- `digitale-plattform-stadtverkehr-berlin/service-baustellen` exists and documents a service that reads Concert traffic messages over OCIT-C, transforms them to GeoJSON, and writes `baustellen_sperrungen.json` to cloud storage.
- `service-baustellen` names the private OCIT-C object types `TrafficMessage_RoadWorks` and `TrafficMessage_Incidents`.
- `masterportal-dps-config` references the public Masterportal layer `Baustellen_OCIT` with the GeoJSON URL `https://api.viz.berlin.de/daten/baustellen_sperrungen.json`.
- `datenablage` provides the public browser for the traffic-detection data archive at `https://api.viz.berlin.de/daten/verkehrsdetektion` and shows that the backing public blob host is `https://mdhopendata.blob.core.windows.net/`.

## Public endpoints

| Data need | Public URL | Format | Notes |
| --- | --- | --- | --- |
| Baustellen, Sperrungen, sonstige Störungen / Verkehrseinschränkungen | `https://api.viz.berlin.de/daten/baustellen_sperrungen.json` | GeoJSON FeatureCollection | Public DPS/Masterportal layer `Baustellen_OCIT`; configured as GeoJSON in `masterportal-dps-config`. Used as DriveBot's first endpoint. |
| Baustellen, Sperrungen, sonstige Störungen - Verkehrsredaktion | `https://api.viz.berlin.de/daten/baustellen_sperrungen.json` | JSON/GeoJSON | Berlin Open Data lists the Verkehrsredaktion resource as JSON/GeoJSON; this appears to be the same public DPS endpoint used by the Masterportal. |
| Baustellen, Sperrungen, sonstige Störungen - Landesmeldestelle | `https://api.viz.berlin.de/tic3/baustellen_sperrungen_tic.json` | JSON/GeoJSON | Berlin Open Data lists a second parallel resource during the current system transition. DriveBot keeps it as a public fallback endpoint. |
| Verkehrsdetektion archive | `https://api.viz.berlin.de/daten/verkehrsdetektion` | Browser over public blob files (CSV/archives vary by folder) | Useful for traffic-volume analytics, not currently used for HUD warnings because it is historical/archive-oriented rather than event warnings. |
| Verkehrsdetektion SensorThings (TEU) | `https://api.viz.berlin.de/FROST-Server-TEU` | SensorThings API | Public Masterportal service for passive infrared detection. Not used for warnings in this change. |
| Wärmebildkamera traffic detection | `https://api.viz.berlin.de/FROST-Server-ThermiCam` | SensorThings API | Public Masterportal service. Not used for warnings in this change. |

## Data shape used by DriveBot

The roadworks endpoint is parsed defensively as GeoJSON:

- root: `FeatureCollection`
- feature properties observed/configured by DPS: `subtype`, `severity`, `validity.from`, `validity.to`, `street`, `section`, `content`, and `icon`
- geometry: `Point`, `LineString`, nested coordinate arrays, or `GeometryCollection`
- coordinates: GeoJSON order `[longitude, latitude]`

DriveBot accepts schema changes gracefully: missing properties produce default German labels, and entries without extractable coordinates are ignored for AR markers.

## Type mapping

DriveBot maps the public Berlin feed to German warning types as follows:

1. `subtype`/`icon` containing `Sperrung` -> `Sperrung` (highest severity)
2. `subtype`/`icon` containing `Baustelle` or `Bauarbeiten` -> `Baustelle`
3. text containing `Einschränkung` or `Störung` -> `Verkehrseinschränkung`
4. all other public event messages -> `Verkehrsmeldung`

## License and attribution

- Berlin Open Data states the dataset license as `Datenlizenz Deutschland – Namensnennung – Version 2.0 (dl-de-by-2.0)`.
- Required attribution text: `Digitale Plattform Stadtverkehr Berlin / [Titel des Datensatzes]`.
- The Masterportal layer attribution is `Quelle: Senatsverwaltung für Verkehr Berlin`.
- The traffic-detection archive states `Datenlizenz Deutschland – Namensnennung – Version 2.0 (dl-de-by-2.0)` with attribution `Digitale Plattform Stadtverkehr Berlin / Verkehrsdetektion Berlin`.

DriveBot UI source label: `Berlin Verkehr`.

## Refresh/update frequency

- Berlin Open Data lists the roadworks dataset temporal granularity as hourly.
- `service-baustellen` README says the data query and GeoJSON write happen once per hour, while the current service code schedules the import job every five minutes. Treat the public data as near-real-time but not guaranteed to refresh faster than hourly.

## Limitations and safety rules

- The public dataset is not the complete set of all Berlin traffic restrictions; Berlin Open Data describes it as events of special traffic relevance, curated by VIZ.
- Berlin Open Data currently notes two parallel resources during a technical/system transition: Verkehrsredaktion and Landesmeldestelle.
- DriveBot does not call `vizconcs2.concert.viz`, does not use OCIT-C credentials, and does not access Azure connection strings.
- The app must keep fallback mode: if Berlin data is unavailable, invalid, empty, expired, outside radius, or times out, DriveBot falls back through the existing warning repository composition.
