-- CI-only stand-in for Supabase Auth. Never apply this to a Supabase project.
create role authenticated nologin;
create role anon nologin;
create schema auth;
create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb not null default '{}'::jsonb);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
grant usage on schema auth, public to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;

create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,
    jsonb_build_object('sub',current_setting('request.jwt.claim.sub',true),
      'iss','https://ffedjcrehudjwvdogqiw.supabase.co/auth/v1'));
$$;
grant execute on function auth.jwt() to authenticated,anon;
-- CI-only storage catalog stand-in. Production uses Supabase Storage itself.
create schema storage;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,metadata jsonb,
  unique(bucket_id,name));
alter table storage.objects enable row level security;
grant usage on schema storage to anon,authenticated;
grant select,insert on storage.objects to anon,authenticated;
