-- Synthetic users only, with no email delivery or persisted test data.
begin;
insert into auth.users(id,raw_user_meta_data) values
  ('66666666-6666-4666-8666-666666666666', '{"display_name":"Owner A"}'),
  ('77777777-7777-4777-8777-777777777777', '{"display_name":"Owner B"}');
do $$ begin
  if (select display_name from public.profiles where id='66666666-6666-4666-8666-666666666666') <> 'Owner A' then
    raise exception 'Signup profile trigger failed';
  end if;
end $$;
update auth.users set raw_user_meta_data='{"display_name":"Updated owner"}' where id='66666666-6666-4666-8666-666666666666';
set local role authenticated;
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
do $$ begin
  if (select count(*) from public.profiles) <> 1 or
     (select display_name from public.profiles limit 1) <> 'Updated owner' then
    raise exception 'Profile update or owner isolation failed';
  end if;
  begin
    update public.profiles set display_name='Spoofed';
    raise exception 'Direct profile modification was accepted';
  exception when insufficient_privilege then null;
  end;
end $$;
set local role anon;
do $$ begin
  begin
    perform 1 from public.profiles;
    raise exception 'Anonymous profile access was accepted';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
