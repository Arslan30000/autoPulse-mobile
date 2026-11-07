-- Freeze the legacy compatibility cohort: opening Supabase signups later must
-- not bypass Firebase email verification. Fresh installations already have
-- this column from the verified_accounts migration; preserve their false flags.
do $$ begin
  if not exists(select 1 from information_schema.columns where table_schema='autopulse_private'
    and table_name='accounts' and column_name='legacy_access') then
    alter table autopulse_private.accounts add column legacy_access boolean not null default false;
    update autopulse_private.accounts a set legacy_access=true where exists(select 1 from auth.users u where u.id=a.id);
  end if;
end $$;
create or replace function public.current_account_id() returns uuid
language plpgsql stable security definer set search_path='' as $$
declare result uuid;
begin
  if public.is_verified_firebase() then
    select account_id into result from autopulse_private.firebase_identities where subject=auth.jwt()->>'sub';
  elsif auth.jwt()->>'iss'='https://ffedjcrehudjwvdogqiw.supabase.co/auth/v1' then
    select id into result from autopulse_private.accounts where id=auth.uid() and legacy_access;
    if exists(select 1 from autopulse_private.firebase_identities where account_id=result) then return null; end if;
  end if;
  return result;
end;
$$;
