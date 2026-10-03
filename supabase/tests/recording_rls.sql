-- Run after both migrations in a disposable database. All fixtures roll back.
begin;
insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
insert into public.vehicles(id, owner_id, make, model, year) values
  ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 'Synthetic', 'A', 2020),
  ('44444444-4444-4444-8444-444444444444', '22222222-2222-4222-8222-222222222222', 'Synthetic', 'B', 2020);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
do $$ begin
  if (select count(*) from public.vehicles) <> 1 then
    raise exception 'Vehicle RLS failed';
  end if;
  begin
    insert into public.vehicles(owner_id, make, model, year) values
      ('22222222-2222-4222-8222-222222222222', 'Synthetic', 'Spoof', 2020);
    raise exception 'Spoofed ownership was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.obd_recording_sessions(id, owner_id, vehicle_id, vehicle_name,
      adapter_name, started_at, ended_at, sample_count) values
      ('55555555-5555-4555-8555-555555555555', auth.uid(),
       '44444444-4444-4444-8444-444444444444', 'Synthetic B', 'Fixture', now(), now(), 1);
    raise exception 'Cross-owner vehicle association was accepted';
  exception when foreign_key_violation then null;
  end;
end $$;

insert into public.obd_recording_sessions(id, owner_id, vehicle_id, vehicle_name,
  adapter_name, started_at, ended_at, sample_count) values
  ('55555555-5555-4555-8555-555555555555', auth.uid(),
   '33333333-3333-4333-8333-333333333333', 'Synthetic A', 'Fixture', now(), now(), 1);
do $$ begin
  begin
    perform public.complete_obd_recording('55555555-5555-4555-8555-555555555555');
    raise exception 'Incomplete upload was finalized';
  exception when raise_exception then
    if sqlerrm <> 'Recording upload is incomplete' then raise; end if;
  end;
end $$;

insert into public.obd_recording_samples(session_id, sample_id, owner_id, pid,
  value, unit, quality, requested_at, received_at, latency_ms, ecu_source) values
  ('55555555-5555-4555-8555-555555555555', 1, auth.uid(), 12,
   null, 'rpm', 'noData', now(), now(), 100, '7E8');
-- Simulate a replay after acknowledgment loss. The immutable sample is unchanged.
insert into public.obd_recording_samples(session_id, sample_id, owner_id, pid,
  value, unit, quality, requested_at, received_at, latency_ms) values
  ('55555555-5555-4555-8555-555555555555', 1, auth.uid(), 12,
   1000, 'rpm', 'valid', now(), now(), 100)
  on conflict (session_id, sample_id) do nothing;
select public.complete_obd_recording('55555555-5555-4555-8555-555555555555');
do $$ begin
  if (select count(*) from public.obd_recording_samples) <> 1 then
    raise exception 'Replay produced duplicate samples';
  end if;
  if (select value from public.obd_recording_samples limit 1) is not null then
    raise exception 'Replay overwrote the original measurement';
  end if;
  if (select uploaded_at from public.obd_recording_sessions limit 1) is null then
    raise exception 'Complete upload was not finalized';
  end if;
  begin
    insert into public.obd_recording_samples(session_id, sample_id, owner_id, pid,
      value, unit, quality, requested_at, received_at, latency_ms) values
      ('55555555-5555-4555-8555-555555555555', 2, auth.uid(), 12,
       1000, 'rpm', 'noData', now(), now(), 100);
    raise exception 'Invalid measurement quality was accepted';
  exception when check_violation then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
do $$ begin
  if exists (select 1 from public.obd_recording_sessions) or
     exists (select 1 from public.obd_recording_samples) then
    raise exception 'Cross-owner recording data was visible';
  end if;
  begin
    perform public.complete_obd_recording('55555555-5555-4555-8555-555555555555');
    raise exception 'Another owner finalized the upload';
  exception when raise_exception then
    if sqlerrm <> 'Recording is unavailable' then raise; end if;
  end;
end $$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$ begin
  begin
    perform 1 from public.obd_recording_samples;
    raise exception 'Anonymous sample access was accepted';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
