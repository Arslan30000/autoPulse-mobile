-- Preserve the original asynchronous PID measurements; do not fabricate snapshots.
-- Existing vehicles remain unowned and inaccessible until deliberately migrated.
alter table public.vehicles add column owner_id uuid references auth.users(id);
create index vehicles_owner_idx on public.vehicles(owner_id);
alter table public.vehicles add constraint vehicles_id_owner_unique unique(id, owner_id);
drop index if exists public.vehicles_vin_unique;
create unique index vehicles_owner_vin_unique on public.vehicles(owner_id, upper(vin))
  where vin is not null;

create policy vehicles_owner_select on public.vehicles for select to authenticated
  using (owner_id = (select auth.uid()));
create policy vehicles_owner_insert on public.vehicles for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy vehicles_owner_update on public.vehicles for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

create table public.obd_recording_sessions (
  id uuid primary key,
  owner_id uuid not null references auth.users(id),
  vehicle_id uuid not null,
  vehicle_name text not null,
  adapter_name text not null,
  started_at timestamptz not null,
  ended_at timestamptz not null check (ended_at >= started_at),
  sample_count bigint not null check (sample_count >= 0),
  uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (vehicle_id, owner_id) references public.vehicles(id, owner_id)
);
create index obd_sessions_owner_started_idx
  on public.obd_recording_sessions(owner_id, started_at desc);

create table public.obd_recording_samples (
  session_id uuid not null,
  sample_id bigint not null check (sample_id > 0),
  owner_id uuid not null references auth.users(id),
  pid smallint not null check (pid between 0 and 255),
  value double precision,
  unit text not null,
  quality text not null check (quality in ('valid','unsupported','noData','invalid','timeout')),
  requested_at timestamptz not null,
  received_at timestamptz not null,
  latency_ms integer not null check (latency_ms >= 0),
  ecu_source text,
  primary key (session_id, sample_id),
  foreign key (session_id, owner_id) references public.obd_recording_sessions(id, owner_id),
  check ((quality = 'valid' and value is not null) or
         (quality <> 'valid' and value is null))
);
create index obd_samples_session_time_idx
  on public.obd_recording_samples(session_id, received_at, sample_id);
alter table public.obd_recording_sessions enable row level security;
alter table public.obd_recording_samples enable row level security;

create policy obd_sessions_owner_select on public.obd_recording_sessions for select to authenticated
  using (owner_id = (select auth.uid()));
create policy obd_sessions_owner_insert on public.obd_recording_sessions for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy obd_sessions_owner_update on public.obd_recording_sessions for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy obd_samples_owner_select on public.obd_recording_samples for select to authenticated
  using (owner_id = (select auth.uid()));
create policy obd_samples_owner_insert on public.obd_recording_samples for insert to authenticated
  with check (owner_id = (select auth.uid()));

-- Runs as the caller: RLS also protects the verification query.
create function public.complete_obd_recording(recording_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare expected_count bigint; actual_count bigint;
begin
  select sample_count into expected_count from public.obd_recording_sessions
    where id = recording_id and owner_id = auth.uid();
  if not found then raise exception 'Recording is unavailable'; end if;
  select count(*) into actual_count from public.obd_recording_samples
    where session_id = recording_id;
  if actual_count <> expected_count then
    raise exception 'Recording upload is incomplete';
  end if;
  update public.obd_recording_sessions set uploaded_at = now()
    where id = recording_id and owner_id = auth.uid();
end;
$$;
revoke all on function public.complete_obd_recording(uuid) from public, anon;
grant execute on function public.complete_obd_recording(uuid) to authenticated;
grant select, insert, update on public.vehicles, public.obd_recording_sessions to authenticated;
grant select, insert on public.obd_recording_samples to authenticated;
revoke all on public.obd_recording_sessions, public.obd_recording_samples from anon;
