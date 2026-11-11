-- New raw data uses immutable compressed objects; legacy SQL samples stay readable.
begin;
alter table public.obd_recording_sessions
  add column storage_format text not null default 'rows-v1'
    check(storage_format in ('rows-v1','gzip-json-v1'));
alter table public.obd_recording_sessions alter column ended_at drop not null;
create table public.obd_recording_chunks (
  session_id uuid not null,
  owner_id uuid not null,
  first_sample_id bigint not null check(first_sample_id > 0),
  last_sample_id bigint not null check(last_sample_id >= first_sample_id),
  previous_sample_id bigint not null check(previous_sample_id >= 0 and previous_sample_id < first_sample_id),
  sample_count integer not null check(sample_count between 1 and 1000),
  byte_count integer not null check(byte_count between 1 and 1048576),
  sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'),
  object_path text not null unique,
  created_at timestamptz not null default now(),
  primary key(session_id, first_sample_id),
  unique(session_id, previous_sample_id),
  foreign key(session_id,owner_id) references public.obd_recording_sessions(id,owner_id)
);
alter table public.obd_recording_chunks enable row level security;
create policy chunk_owner_read on public.obd_recording_chunks for select to anon,authenticated
  using(owner_id = (select public.current_account_id()));
grant select on public.obd_recording_chunks to anon,authenticated;
revoke insert,update,delete on public.obd_recording_chunks from anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values('obd-recordings','obd-recordings',false,1048576,array['application/gzip'])
  on conflict(id) do nothing;
create policy recording_object_read on storage.objects for select to anon,authenticated
  using(bucket_id = 'obd-recordings' and exists (
    select 1 from public.obd_recording_chunks c where c.object_path = name and c.owner_id = (select public.current_account_id())));
create policy recording_object_insert on storage.objects for insert to anon,authenticated
  with check(bucket_id = 'obd-recordings' and exists (
    select 1 from public.obd_recording_chunks c where c.object_path = name and c.owner_id = (select public.current_account_id())));
-- No UPDATE/DELETE policy: a retry must verify an existing immutable object.

create function public.reserve_recording_chunk(
  recording_id uuid, first_id bigint, last_id bigint, previous_id bigint,
  row_count integer, compressed_bytes integer, digest_sha256 text
) returns text language plpgsql security definer set search_path = '' as $$
declare account uuid := public.current_account_id(); run public.obd_recording_sessions;
  existing public.obd_recording_chunks; result text; used bigint;
begin
  if account is null then raise exception 'Sign in to the recording owner account'; end if;
  -- Serializes free-tier reservations across accounts; an interrupted upload
  -- retains its reservation and resumes with the same immutable identity.
  perform pg_advisory_xact_lock(721134909);
  select * into run from public.obd_recording_sessions where id = recording_id and owner_id = account for update;
  if not found or run.storage_format <> 'gzip-json-v1' then raise exception 'Recording is unavailable'; end if;
  select * into existing from public.obd_recording_chunks where session_id = recording_id and first_sample_id = first_id;
  if found then
    if existing.last_sample_id <> last_id or existing.previous_sample_id <> previous_id or existing.sample_count <> row_count
      or existing.byte_count <> compressed_bytes or existing.sha256 <> digest_sha256 then
      raise exception 'Conflicting retry payload';
    end if;
    return existing.object_path;
  end if;
  if run.uploaded_at is not null then raise exception 'Recording is already complete'; end if;
  if previous_id <> coalesce((select max(last_sample_id) from public.obd_recording_chunks where session_id = recording_id),0) then
    raise exception 'Chunk sequence is incomplete';
  end if;
  select coalesce(sum(byte_count),0) into used from public.obd_recording_chunks;
  -- Leave headroom inside the finite 1GB free bucket. Include other objects;
  -- chunk objects already have a reservation and must not be counted twice.
  select used + coalesce(sum(coalesce((o.metadata->>'size')::bigint,0)),0) into used from storage.objects o
    where not exists(select 1 from public.obd_recording_chunks c where o.bucket_id = 'obd-recordings' and o.name = c.object_path);
  if used + compressed_bytes > 850000000 then raise exception 'CLOUD_CAPACITY_FULL: recording remains safe on this phone'; end if;
  result := account::text || '/' || recording_id::text || '/' || first_id::text || '-' || digest_sha256 || '.json.gz';
  insert into public.obd_recording_chunks(session_id,owner_id,first_sample_id,last_sample_id,previous_sample_id,sample_count,byte_count,sha256,object_path)
    values(recording_id,account,first_id,last_id,previous_id,row_count,compressed_bytes,digest_sha256,result);
  return result;
end;
$$;
revoke all on function public.reserve_recording_chunk(uuid,bigint,bigint,bigint,integer,integer,text) from public;
grant execute on function public.reserve_recording_chunk(uuid,bigint,bigint,bigint,integer,integer,text) to anon,authenticated;

create or replace function public.complete_obd_recording(recording_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare run public.obd_recording_sessions; actual_count bigint; missing_count bigint;
begin
  select * into run from public.obd_recording_sessions where id = recording_id
    and owner_id = public.current_account_id() for update;
  if not found then raise exception 'Recording is unavailable'; end if;
  if run.ended_at is null then raise exception 'Stop recording before finalizing'; end if;
  if run.storage_format = 'rows-v1' then
    select count(*) into actual_count from public.obd_recording_samples where session_id = recording_id;
  else
    select coalesce(sum(sample_count),0) into actual_count from public.obd_recording_chunks where session_id = recording_id;
    select count(*) into missing_count from public.obd_recording_chunks c
      left join storage.objects o on o.bucket_id = 'obd-recordings' and o.name = c.object_path
      where c.session_id = recording_id and (o.id is null or coalesce((o.metadata->>'size')::bigint,-1) <> c.byte_count);
    if missing_count <> 0 then raise exception 'Recording objects are missing or incomplete'; end if;
  end if;
  if actual_count <> run.sample_count then raise exception 'Recording upload is incomplete'; end if;
  update public.obd_recording_sessions set uploaded_at = now() where id = recording_id;
end;
$$;
grant execute on function public.complete_obd_recording(uuid) to anon,authenticated;

create function public.recording_cloud_usage() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when public.current_account_id() is null then null else
    jsonb_build_object('reserved_bytes',coalesce(sum(byte_count),0),'budget_bytes',850000000,
      'account_bytes',coalesce(sum(byte_count) filter(where owner_id = public.current_account_id()),0)) end
    from public.obd_recording_chunks;
$$;
revoke all on function public.recording_cloud_usage() from public;
grant execute on function public.recording_cloud_usage() to anon,authenticated;
commit;
