-- These application tables were created with explicit grants, so service_role
-- needs table privileges in addition to its RLS bypass for server processing.
grant select on public.obd_recording_sessions,
  public.obd_recording_samples,
  public.obd_recording_chunks to service_role;
grant select, insert, update on public.ml_jobs,
  public.ml_models,
  public.ml_run_results to service_role;
