# Authentifizierung

DriveBot unterstützt Supabase Auth für E-Mail/Passwort-Konten und bleibt ohne Login nutzbar.

## Nutzerflüsse

- **Anmelden**: Nutzer können sich mit E-Mail und Passwort anmelden.
- **Konto erstellen**: Neue Nutzer können ein Konto registrieren.
- **Passwort zurücksetzen**: Die App löst eine Supabase-E-Mail zum Zurücksetzen aus.
- **Ohne Konto fortfahren**: Der HUD bleibt im Gastmodus verfügbar.
- **Profil**: Der Profileinstieg zeigt Gaststatus oder angemeldete E-Mail sowie erste Basiseinstellungen.

## Fallback- und Gastmodus

Wenn `SUPABASE_URL` oder `SUPABASE_ANON_KEY` fehlen, initialisiert die App Supabase nicht. DriveBot startet dann direkt im Gastmodus, damit HUD, Kamera, Sensorstatus und Warnhinweise weiter nutzbar bleiben.

## Sicherheit

- Die Flutter-App verwendet ausschließlich die Supabase anon key über `--dart-define`.
- Keine `.env`-Dateien und keine Secrets werden committet.
- Der `service_role` key darf nie in der App verwendet werden.
