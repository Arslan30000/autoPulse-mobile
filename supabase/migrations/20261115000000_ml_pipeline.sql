-- Completed recordings are queued once. The worker uses a server-side key;
-- owners can read only their own results and cannot change model output.
begin;

create table public.ml_jobs (
  session_id uuid primary key references public.obd_recording_sessions(id),
  owner_id uuid not null,
  vehicle_id uuid not null,
  status text not null default 'queued' check (status in ('queued','running','completed','failed')),
  attempts integer not null default 0,
  error text,
  queued_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);
create index ml_jobs_status_queued_idx on public.ml_jobs(status, queued_at);
alter table public.ml_jobs enable row level security;
create policy ml_jobs_owner_read on public.ml_jobs for select to anon, authenticated
  using (owner_id = (select public.current_account_id()));
grant select on public.ml_jobs to anon, authenticated;

create table public.ml_models (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  vehicle_id uuid not null,
  version integer not null,
  status text not null check (status in ('active','retired')),
  artifact jsonb not null,
  training_sessions uuid[] not null,
  training_windows integer not null,
  validation jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(owner_id, vehicle_id, version)
);
create unique index ml_models_one_active_idx on public.ml_models(owner_id, vehicle_id)
  where status = 'active';
alter table public.ml_models enable row level security;
create policy ml_models_owner_read on public.ml_models for select to anon, authenticated
  using (owner_id = (select public.current_account_id()));
grant select on public.ml_models to anon, authenticated;

create table public.ml_run_results (
  session_id uuid primary key references public.obd_recording_sessions(id),
  owner_id uuid not null,
  vehicle_id uuid not null,
  model_id uuid references public.ml_models(id),
  status text not null check (status in ('baseline','scored','insufficient_data')),
  valid_windows integer not null default 0,
  excluded_windows integer not null default 0,
  alert_count integer not null default 0,
  alerts jsonb not null default '[]'::jsonb,
  details jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now()
);
alter table public.ml_run_results enable row level security;
create policy ml_results_owner_read on public.ml_run_results for select to anon, authenticated
  using (owner_id = (select public.current_account_id()));
grant select on public.ml_run_results to anon, authenticated;

create function public.queue_completed_recording_for_ml() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.uploaded_at is not null then
    if tg_op = 'INSERT' then
      insert into public.ml_jobs(session_id, owner_id, vehicle_id)
        values(new.id, new.owner_id, new.vehicle_id)
        on conflict(session_id) do nothing;
    elsif old.uploaded_at is null then
      insert into public.ml_jobs(session_id, owner_id, vehicle_id)
        values(new.id, new.owner_id, new.vehicle_id)
        on conflict(session_id) do nothing;
    end if;
  end if;
  return new;
end;
$$;
create trigger queue_completed_recording_for_ml
  after insert or update of uploaded_at on public.obd_recording_sessions
  for each row execute function public.queue_completed_recording_for_ml();

-- This backfills previously uploaded runs without modifying the recordings.
insert into public.ml_jobs(session_id, owner_id, vehicle_id)
  select id, owner_id, vehicle_id from public.obd_recording_sessions
  where uploaded_at is not null on conflict(session_id) do nothing;

create function public.claim_ml_jobs(max_jobs integer default 4)
returns setof public.ml_jobs language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
    then raise exception 'Server worker only'; end if;
  return query
    update public.ml_jobs j
    set status = 'running', attempts = attempts + 1,
        started_at = now(), error = null
    where j.session_id in (
      select q.session_id from public.ml_jobs q
      where q.status = 'queued' or
        (q.status = 'running' and q.started_at < now() - interval '30 minutes')
      order by q.queued_at limit least(greatest(max_jobs, 1), 20)
      for update skip locked
    )
    returning j.*;
end;
$$;
revoke all on function public.claim_ml_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_ml_jobs(integer) to service_role;
commit;
