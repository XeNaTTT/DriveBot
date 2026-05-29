# Community-Blitzer-Meldungen

DriveBot speichert Community-Meldungen in Supabase in der Tabelle
`public.speed_camera_reports`. Die Flutter-App verwendet nur den öffentlichen
Anon-Key und nie einen `service_role`-Schlüssel.

## Meldetypen und Ablaufzeiten

- `mobile` = **Mobiler Blitzer**, gültig für **3 Tage**.
- `fixed` = **Fester Blitzer**, gültig für **1 Jahr**.

Die Migration `20260529000000_create_speed_camera_reports.sql` setzt
`expires_at` über die Datenbankfunktion `public.set_speed_camera_report_expiry()`
automatisch bei Insert und bei Änderungen an Typ oder Erstellzeitpunkt. Die App
filtert zusätzlich defensiv gegen abgelaufene Meldungen, damit abgelaufene
Blitzer nicht im HUD erscheinen.

## RLS-Modell

Row Level Security ist auf `public.speed_camera_reports` aktiv.

- `anon` und `authenticated` dürfen nur aktive, nicht abgelaufene Meldungen
  lesen: `moderation_status = 'active'` und `expires_at > now()`.
- Nur eingeloggte Nutzer dürfen Remote-Meldungen einfügen.
- Inserts müssen `user_id = auth.uid()`, `report_type in ('mobile', 'fixed')`,
  Koordinaten und `moderation_status = 'active'` erfüllen.
- Eingeloggte Nutzer dürfen nur eigene Zeilen aktualisieren.
- Es gibt keine öffentliche Lesepolicy für abgelaufene, versteckte oder
  abgelehnte Meldungen.

## Gastverhalten

Gäste dürfen DriveBot und die lokale Blitzer-Meldung weiter nutzen. Wenn kein
Login vorhanden ist oder Supabase nicht konfiguriert ist, wird die Meldung nur
lokal gespeichert. Die Oberfläche erklärt auf Deutsch:

> Lokal gespeichert. Melde dich an, um Blitzer mit der Community zu teilen.

Anonyme Remote-Inserts sind nicht erlaubt.

## Anzeige im AR-HUD

Aktive Community-Meldungen werden in Live-Abfragen geladen und in
DriveBot-Warnungen/AR-Marker umgewandelt. Angezeigt werden nur Meldungen mit
validen Koordinaten, aktiver Moderation und nicht überschrittenem `expires_at`.
Der Start-Radius liegt bei 5 km. Mobile und feste Blitzer verwenden hohe
Warnpriorität, werden aber auf wenige nahe Marker begrenzt, damit das HUD nicht
überladen wird.

## Zukünftige Moderation und Deduplizierung

Mögliche nächste Schritte:

- räumliche Deduplizierung nahe beieinanderliegender Meldungen,
- Community-Bestätigungen über `verification_count`,
- automatische Herabstufung alter mobiler Meldungen,
- Moderationsansicht für `hidden` und `rejected`,
- Missbrauchserkennung pro Nutzer und Zeitfenster.
