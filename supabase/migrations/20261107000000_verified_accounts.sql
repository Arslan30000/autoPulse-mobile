-- Firebase Authentication Spark sends verification mail without custom SMTP.
-- Keep the UUID ownership of every existing Supabase account and recording.
begin;
create schema if not exists autopulse_private;
revoke all on schema autopulse_private from public, anon, authenticated;
create table autopulse_private.accounts (
  id uuid primary key default gen_random_uuid(),
  legacy_access boolean not null default false,
  created_at timestamptz not null default now()
);
insert into autopulse_private.accounts(id,legacy_access) select id,true from auth.users;
create table autopulse_private.firebase_identities (
  subject text primary key check(length(subject) between 1 and 128),
  account_id uuid not null unique references autopulse_private.accounts(id),
  created_at timestamptz not null default now()
);
create table autopulse_private.account_links (
  ticket uuid primary key default gen_random_uuid(),
  account_id uuid not null unique references autopulse_private.accounts(id),
  email text not null,
  expires_at timestamptz not null default now() + interval '15 minutes'
);
revoke all on all tables in schema autopulse_private from public, anon, authenticated;
alter table autopulse_private.accounts enable row level security;
alter table autopulse_private.firebase_identities enable row level security;
alter table autopulse_private.account_links enable row level security;

alter table public.vehicles drop constraint vehicles_owner_id_fkey;
alter table public.vehicles add foreign key(owner_id) references autopulse_private.accounts(id);
alter table public.obd_recording_sessions drop constraint obd_recording_sessions_owner_id_fkey;
alter table public.obd_recording_sessions add foreign key(owner_id) references autopulse_private.accounts(id);
alter table public.obd_recording_samples drop constraint obd_recording_samples_owner_id_fkey;
alter table public.obd_recording_samples add foreign key(owner_id) references autopulse_private.accounts(id);
alter table public.profiles drop constraint profiles_id_fkey;
alter table public.profiles add foreign key(id) references autopulse_private.accounts(id);

create function public.is_verified_firebase() returns boolean
language sql stable set search_path = '' as $$
  select coalesce(auth.jwt()->>'iss' = 'https://securetoken.google.com/autopulseai-1fca7'
    and auth.jwt()->>'aud' = 'autopulseai-1fca7'
    and auth.jwt()->>'email_verified' = 'true'
    and length(auth.jwt()->>'sub') between 1 and 128, false);
$$;

create function public.current_account_id() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare result uuid;
begin
  if public.is_verified_firebase() then
    select account_id into result from autopulse_private.firebase_identities
      where subject = auth.jwt()->>'sub';
  elsif auth.jwt()->>'iss' = 'https://ffedjcrehudjwvdogqiw.supabase.co/auth/v1' then
    -- Do not cast Firebase's arbitrary string UID through auth.uid().
    select id into result from autopulse_private.accounts where id = auth.uid() and legacy_access;
    -- Already-migrated accounts can only use the verified identity for new access.
    if exists(select 1 from autopulse_private.firebase_identities where account_id = result) then
      return null;
    end if;
  end if;
  return result;
end;
$$;
revoke all on function public.current_account_id() from public;
grant execute on function public.current_account_id(), public.is_verified_firebase() to anon, authenticated;

create or replace function public.sync_auth_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into autopulse_private.accounts(id) values(new.id) on conflict do nothing;
  insert into public.profiles(id, display_name)
    values(new.id, left(coalesce(new.raw_user_meta_data->>'display_name',''),100))
    on conflict(id) do update set display_name = excluded.display_name, updated_at = now();
  return new;
end;
$$;

-- A short-lived, single-use ticket proves the caller knows the old password.
-- Email equality alone is deliberately insufficient (legacy email was unverified).
create function public.create_account_link() returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid; account uuid;
begin
  if auth.jwt()->>'iss' is distinct from 'https://ffedjcrehudjwvdogqiw.supabase.co/auth/v1' then
    raise exception 'Sign in to your previous account first';
  end if;
  account := auth.uid();
  if account is null or exists(select 1 from autopulse_private.firebase_identities where account_id = account) then
    raise exception 'Account is unavailable for linking';
  end if;
  insert into autopulse_private.account_links(account_id,email)
    select id,lower(email) from auth.users where id = account
    on conflict(account_id) do update set ticket = gen_random_uuid(), expires_at = now() + interval '15 minutes', email = excluded.email
    returning ticket into result;
  return result;
end;
$$;

create function public.resolve_firebase_account(link_ticket uuid default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid; old_account uuid; firebase_subject text;
begin
  if not public.is_verified_firebase() then raise exception 'Verify your email before syncing'; end if;
  firebase_subject := auth.jwt()->>'sub';
  perform pg_advisory_xact_lock(hashtextextended(firebase_subject,0));
  select account_id into result from autopulse_private.firebase_identities i where i.subject = firebase_subject;
  if result is not null then return result; end if;
  if link_ticket is not null then
    delete from autopulse_private.account_links
      where ticket = link_ticket and expires_at > now() and email = lower(auth.jwt()->>'email')
      returning account_id into result;
    if result is null then raise exception 'Account link expired. Enter your previous account password again'; end if;
  else
    select id into old_account from auth.users where lower(email) = lower(auth.jwt()->>'email');
    if old_account is not null then raise exception 'LEGACY_LINK_REQUIRED'; end if;
    insert into autopulse_private.accounts default values returning id into result;
  end if;
  insert into autopulse_private.firebase_identities(subject,account_id) values(firebase_subject,result);
  insert into public.profiles(id,display_name) values(result,left(coalesce(auth.jwt()->>'name',''),100)) on conflict do nothing;
  return result;
end;
$$;
revoke all on function public.create_account_link(), public.resolve_firebase_account(uuid) from public;
grant execute on function public.create_account_link() to authenticated;
-- Firebase has no custom `role` claim on Spark. `anon` here is a database role,
-- NOT public access: every policy/RPC checks a signed, verified, project-bound JWT.
grant execute on function public.resolve_firebase_account(uuid) to anon, authenticated;

drop policy vehicles_owner_select on public.vehicles;
drop policy vehicles_owner_insert on public.vehicles;
drop policy vehicles_owner_update on public.vehicles;
create policy vehicles_owner_select on public.vehicles for select to anon,authenticated using(owner_id = (select public.current_account_id()));
create policy vehicles_owner_insert on public.vehicles for insert to anon,authenticated with check(owner_id = (select public.current_account_id()));
create policy vehicles_owner_update on public.vehicles for update to anon,authenticated using(owner_id = (select public.current_account_id())) with check(owner_id = (select public.current_account_id()));
drop policy obd_sessions_owner_select on public.obd_recording_sessions;
drop policy obd_sessions_owner_insert on public.obd_recording_sessions;
drop policy obd_sessions_owner_update on public.obd_recording_sessions;
create policy obd_sessions_owner_select on public.obd_recording_sessions for select to anon,authenticated using(owner_id = (select public.current_account_id()));
create policy obd_sessions_owner_insert on public.obd_recording_sessions for insert to anon,authenticated with check(owner_id = (select public.current_account_id()));
create policy obd_sessions_owner_update on public.obd_recording_sessions for update to anon,authenticated using(owner_id = (select public.current_account_id())) with check(owner_id = (select public.current_account_id()));
drop policy obd_samples_owner_select on public.obd_recording_samples;
drop policy obd_samples_owner_insert on public.obd_recording_samples;
create policy obd_samples_owner_select on public.obd_recording_samples for select to anon,authenticated using(owner_id = (select public.current_account_id()));
create policy obd_samples_owner_insert on public.obd_recording_samples for insert to anon,authenticated with check(owner_id = (select public.current_account_id()));
drop policy profiles_owner_select on public.profiles;
create policy profiles_owner_select on public.profiles for select to anon,authenticated using(id = (select public.current_account_id()));
create policy profiles_owner_update on public.profiles for update to anon,authenticated using(id = (select public.current_account_id())) with check(id = (select public.current_account_id()));
grant select,insert,update on public.vehicles,public.obd_recording_sessions to anon;
grant select,insert on public.obd_recording_samples to anon;
grant select on public.profiles to anon;
grant update(display_name,updated_at) on public.profiles to anon,authenticated;
commit;
