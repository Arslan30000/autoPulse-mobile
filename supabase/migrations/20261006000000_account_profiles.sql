-- Profiles contain owner-editable presentation data only. Authentication and
-- email/password storage remain managed by Supabase Auth.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (length(display_name) <= 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy profiles_owner_select on public.profiles for select to authenticated
  using (id = (select auth.uid()));
-- Profiles are mirrored from Auth metadata; clients cannot assign ownership.
create function public.sync_auth_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, display_name)
    values (new.id, left(coalesce(new.raw_user_meta_data->>'display_name', ''), 100))
    on conflict(id) do update set display_name = excluded.display_name, updated_at = now();
  return new;
end;
$$;
revoke all on function public.sync_auth_profile() from public, anon, authenticated;
create trigger autopulse_auth_profile after insert or update of raw_user_meta_data on auth.users
  for each row execute function public.sync_auth_profile();
insert into public.profiles(id, display_name)
  select id, left(coalesce(raw_user_meta_data->>'display_name', ''),100) from auth.users
  on conflict(id) do nothing;
grant select on public.profiles to authenticated;
revoke all on public.profiles from anon;
