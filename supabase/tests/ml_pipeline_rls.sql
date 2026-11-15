begin;
insert into autopulse_private.accounts(id) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
insert into autopulse_private.firebase_identities(subject,account_id) values
  ('ml-owner','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('ml-other','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
insert into public.vehicles(id,owner_id,make,model,year) values
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Synthetic','Yaris',2021);
insert into public.obd_recording_sessions(id,owner_id,vehicle_id,vehicle_name,adapter_name,started_at,ended_at,sample_count,uploaded_at)
  values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
         'cccccccc-cccc-4ccc-8ccc-cccccccccccc','Synthetic','Test',now(),now(),0,now());
do $$ begin
  if (select count(*) from public.ml_jobs) <> 1 then raise exception 'Completed upload did not enqueue'; end if;
end $$;
set local role anon;
select set_config('request.jwt.claims','{"iss":"https://securetoken.google.com/autopulseai-1fca7","aud":"autopulseai-1fca7","sub":"ml-other","email_verified":true}',true);
do $$ begin
  if (select count(*) from public.ml_jobs) <> 0 then raise exception 'Other account saw jobs'; end if;
  if (select count(*) from public.ml_models) <> 0 then raise exception 'Other account saw models'; end if;
  begin perform public.claim_ml_jobs(1); raise exception 'Client claimed server jobs';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"iss":"https://securetoken.google.com/autopulseai-1fca7","aud":"autopulseai-1fca7","sub":"ml-owner","email_verified":true}',true);
do $$ begin
  if (select count(*) from public.ml_jobs) <> 1 then raise exception 'Owner cannot see job'; end if;
  begin insert into public.ml_models(owner_id,vehicle_id,version,status,artifact,training_sessions,training_windows)
    values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc',1,'active','{}',array[]::uuid[],100);
    raise exception 'Client forged model'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
do $$ begin
  if (select count(*) from public.claim_ml_jobs(1)) <> 1 then
    raise exception 'Server worker did not claim completed upload'; end if;
  if (select count(*) from public.claim_ml_jobs(1)) <> 0 then
    raise exception 'Worker claimed the same job twice'; end if;
end $$;
rollback;
