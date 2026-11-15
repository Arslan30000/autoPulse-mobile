-- PostgREST sets the request's database role to service_role. The legacy
-- request.jwt.claim.role setting is not populated on current deployments.
-- Run as the caller so current_user reflects the actual API role.
create or replace function public.claim_ml_jobs(max_jobs integer default 4)
returns setof public.ml_jobs language plpgsql security invoker set search_path = '' as $$
begin
  if current_user <> 'service_role' then
    raise exception 'Server worker only';
  end if;
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
