# Supabase

Die Supabase GitHub-Integration für DriveBot nutzt als Working Directory:

```text
supabase
```

## Struktur

- Migrationen liegen in `supabase/migrations`.
- `supabase/seed.sql` bleibt frei von Secrets und Produktionsdaten.
- Die App liest Supabase-Konfiguration über Dart defines, nicht aus committeten `.env`-Dateien.

## Credentials

- Keine Secrets in Git committen.
- In Flutter nur die anon key verwenden.
- Der `service_role` key darf niemals in der App verwendet werden.
- Produktions-Credentials nicht lokal in Code oder Tests hinterlegen.

## Codemagic-Hinweis

Die Variablen sind aktuell optional. Ein späterer Build-Befehl kann sie übergeben mit:

```sh
--dart-define=SUPABASE_URL=$SUPABASE_URL
--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

Wenn diese Variablen fehlen, startet DriveBot weiterhin im Gastmodus.
