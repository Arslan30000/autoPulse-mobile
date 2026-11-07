-- Synthetic JWTs are injected only in this disposable PostgreSQL test database.
begin;
insert into auth.users(id,email) values('11111111-1111-4111-8111-111111111111','owner@example.test');
-- This newly-created legacy Auth identity is not grandfathered; an unverified
-- Supabase signup must not become a back door around Firebase verification.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $$ begin if public.current_account_id() is not null then raise exception 'New legacy signup bypassed verification'; end if; end $$;
-- Model an account included in the frozen pre-cutover compatibility cohort.
update autopulse_private.accounts set legacy_access=true where id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $$ begin if public.current_account_id() <> '11111111-1111-4111-8111-111111111111' then raise exception 'Legacy compatibility was lost'; end if; end $$;
select set_config('test.link',public.create_account_link()::text,true);

set local role anon;
select set_config('request.jwt.claims','{"iss":"https://securetoken.google.com/autopulseai-1fca7","aud":"autopulseai-1fca7","sub":"firebase-owner","email":"owner@example.test","email_verified":false}',true);
do $$ begin
  if public.current_account_id() is not null then raise exception 'Unverified user obtained access'; end if;
  begin perform public.resolve_firebase_account(); raise exception 'Unverified account was created';
  exception when raise_exception then if sqlerrm <> 'Verify your email before syncing' then raise; end if; end;
end $$;
select set_config('request.jwt.claims','{"iss":"https://securetoken.google.com/autopulseai-1fca7","aud":"autopulseai-1fca7","sub":"firebase-owner","email":"owner@example.test","email_verified":true}',true);
do $$ begin
  begin perform public.resolve_firebase_account(); raise exception 'Email-only account takeover accepted';
  exception when raise_exception then if sqlerrm <> 'LEGACY_LINK_REQUIRED' then raise; end if; end;
  if public.resolve_firebase_account(current_setting('test.link')::uuid) <> '11111111-1111-4111-8111-111111111111' then
    raise exception 'Legacy UUID was not preserved'; end if;
  if public.resolve_firebase_account() <> public.current_account_id() then raise exception 'Identity is not stable'; end if;
end $$;
insert into public.vehicles(id,owner_id,make,model,year) values('33333333-3333-4333-8333-333333333333',public.current_account_id(),'Synthetic','Yaris',2021);
insert into public.obd_recording_sessions(id,owner_id,vehicle_id,vehicle_name,adapter_name,started_at,ended_at,sample_count,storage_format)
  values('55555555-5555-4555-8555-555555555555',public.current_account_id(),'33333333-3333-4333-8333-333333333333','Synthetic','Fixture',now(),null,1,'gzip-json-v1');
select set_config('test.path',public.reserve_recording_chunk('55555555-5555-4555-8555-555555555555',1,1,0,1,10,repeat('a',64)),true);
do $$ begin
  begin update public.obd_recording_sessions set uploaded_at=now() where id='55555555-5555-4555-8555-555555555555';
    raise exception 'Client forged an uploaded marker';
  exception when raise_exception then if sqlerrm <> 'Use complete_obd_recording to finalize' then raise; end if; end;
  if public.reserve_recording_chunk('55555555-5555-4555-8555-555555555555',1,1,0,1,10,repeat('a',64)) <> current_setting('test.path') then
    raise exception 'Retry changed object identity'; end if;
  begin perform public.reserve_recording_chunk('55555555-5555-4555-8555-555555555555',1,1,0,1,11,repeat('b',64));
    raise exception 'Conflicting retry accepted';
  exception when raise_exception then if sqlerrm <> 'Conflicting retry payload' then raise; end if; end;
  begin perform public.complete_obd_recording('55555555-5555-4555-8555-555555555555');
    raise exception 'Active trip was marked complete';
  exception when raise_exception then if sqlerrm <> 'Stop recording before finalizing' then raise; end if; end;
end $$;
update public.obd_recording_sessions set ended_at=now() where id='55555555-5555-4555-8555-555555555555';
do $$ begin
  begin perform public.complete_obd_recording('55555555-5555-4555-8555-555555555555');
    raise exception 'Missing object was accepted';
  exception when raise_exception then if sqlerrm <> 'Recording objects are missing or incomplete' then raise; end if; end;
end $$;
insert into storage.objects(bucket_id,name,metadata) values('obd-recordings',current_setting('test.path'),'{"size":10}');
select public.complete_obd_recording('55555555-5555-4555-8555-555555555555');
do $$ begin
  if (select uploaded_at is null from public.obd_recording_sessions limit 1) then raise exception 'Trip did not finalize'; end if;
  begin update public.obd_recording_sessions set sample_count=2 where id='55555555-5555-4555-8555-555555555555';
    raise exception 'Completed trip count was altered';
  exception when raise_exception then if sqlerrm <> 'Completed recordings are immutable' then raise; end if; end;
end $$;

-- A second verified account and a JWT from another project must see no old data.
select set_config('request.jwt.claims','{"iss":"https://securetoken.google.com/autopulseai-1fca7","aud":"autopulseai-1fca7","sub":"firebase-other","email":"other@example.test","email_verified":true}',true);
select public.resolve_firebase_account();
do $$ begin
  if (select count(*) from public.vehicles) <> 0 or (select count(*) from storage.objects) <> 0 then
    raise exception 'Cross-account access accepted'; end if;
  begin insert into storage.objects(bucket_id,name,metadata) values('obd-recordings','unauthorized.json.gz','{"size":10}');
    raise exception 'Unreserved object accepted'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"iss":"https://securetoken.google.com/another-project","aud":"another-project","sub":"firebase-owner","email_verified":true}',true);
do $$ begin if public.current_account_id() is not null then raise exception 'Wrong Firebase project accepted'; end if; end $$;
select set_config('request.jwt.claims','{}',true);
do $$ begin
  if (select count(*) from public.vehicles) <> 0 or (select count(*) from public.profiles) <> 0 then raise exception 'Anonymous access accepted'; end if;
end $$;
rollback;
