-- Only the verified completion RPC can set the uploaded marker. Keep old
-- clients' normal metadata upserts working while preventing false completion.
create function public.guard_recording_completion() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon','authenticated') then
    if tg_op = 'INSERT' then
      if new.uploaded_at is not null then raise exception 'Use complete_obd_recording to finalize'; end if;
    elsif new.uploaded_at is distinct from old.uploaded_at then
      raise exception 'Use complete_obd_recording to finalize';
    end if;
    if tg_op = 'UPDATE' and old.uploaded_at is not null and
      (new.sample_count,new.ended_at,new.storage_format,new.vehicle_id,new.owner_id)
      is distinct from (old.sample_count,old.ended_at,old.storage_format,old.vehicle_id,old.owner_id) then
      raise exception 'Completed recordings are immutable';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_recording_completion() from public,anon,authenticated;
create trigger obd_recording_completion_guard before insert or update on public.obd_recording_sessions
  for each row execute function public.guard_recording_completion();
