# Supabase Manual Verification

Run these SQL checks in the Supabase SQL editor after applying migrations.

## Tables exist

```sql
select table_schema, table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('profiles', 'user_settings')
order by table_name;
```

## RLS is enabled

```sql
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('profiles', 'user_settings')
order by tablename;
```

## Policies exist

```sql
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles', 'user_settings')
order by tablename, policyname;
```

## No public read policies

```sql
select schemaname, tablename, policyname, roles, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles', 'user_settings')
  and cmd = 'SELECT'
  and ('public' = any(roles) or 'anon' = any(roles));
```

Expected result: zero rows.
