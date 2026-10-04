\set ON_ERROR_STOP on
begin;
do $$
declare
  first_id uuid := '55dca53f-c281-4c88-854c-2d3b064a0001';
  second_id uuid := '55dca53f-c281-4c88-854c-2d3b064a0002';
  credential text := repeat('a', 64);
  result jsonb;
  role_name text;
  function_name text;
begin
  foreach role_name in array array['anon', 'authenticated'] loop
    if has_table_privilege(role_name, 'public.push_tokens', 'SELECT,INSERT,UPDATE,DELETE') or has_table_privilege(role_name, 'public.push_token_rate_limits', 'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'public role has table privileges: %', role_name;
    end if;
    foreach function_name in array array['notification_register(uuid,text)', 'notification_sync(uuid,text,bigint,boolean,text)', 'notification_invalidate_token(uuid,text)', 'notification_active_tokens()', 'notification_take_rate_limit(text,integer,integer)'] loop
      if has_function_privilege(role_name, 'public.' || function_name, 'EXECUTE') then raise exception 'public role can execute: %', function_name; end if;
      if not has_function_privilege('service_role', 'public.' || function_name, 'EXECUTE') then raise exception 'service cannot execute: %', function_name; end if;
    end loop;
  end loop;
  if public.notification_token_hash('abc') <> decode('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'hex') then raise exception 'token hash incorrect'; end if;
  if (select provolatile from pg_proc where oid = 'public.notification_token_hash(text)'::regprocedure) <> 'i' then raise exception 'token hash not immutable'; end if;
  foreach role_name in array array['anon', 'authenticated', 'service_role'] loop
    if has_function_privilege(role_name, 'public.notification_token_hash(text)', 'EXECUTE') then raise exception 'internal hash exposed to %', role_name; end if;
  end loop;
  if (select count(*) from pg_class where oid in ('public.push_tokens'::regclass, 'public.push_token_rate_limits'::regclass) and relrowsecurity) <> 2 then raise exception 'RLS missing'; end if;
  if (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'push_tokens') <> 6 then raise exception 'unexpected push token columns'; end if;
  result := public.notification_register(first_id, credential);
  if result->>'revision' <> '0' or (result->>'enabled')::boolean then raise exception 'register initial state'; end if;
  if exists(select 1 from public.notification_active_tokens() where installation_id = first_id) then raise exception 'register must be inactive'; end if;
  perform public.notification_register(first_id, credential);
  begin
    perform public.notification_register(first_id, repeat('b',64));
    raise exception 'wrong register credential accepted';
  exception when sqlstate 'PT401' then null; end;
  begin
    perform public.notification_sync(first_id, repeat('b',64), 1, true, 'test-one');
    raise exception 'wrong sync credential accepted';
  exception when sqlstate 'PT401' then null; end;
  result := public.notification_sync(first_id, credential, 1, true, 'test-one');
  if not (result->>'enabled')::boolean or not exists(select 1 from public.notification_active_tokens() where installation_id = first_id and fcm_token = 'test-one') then raise exception 'ON inactive'; end if;
  perform public.notification_sync(first_id, credential, 1, true, 'test-one');
  begin
    perform public.notification_sync(first_id, credential, 1, false, 'test-one');
    raise exception 'same revision mutation accepted';
  exception when sqlstate 'PT409' then null; end;
  perform public.notification_register(second_id, credential);
  begin
    perform public.notification_sync(second_id, credential, 1, true, 'test-one');
    raise exception 'duplicate token accepted';
  exception when sqlstate 'PT409' then
    if sqlerrm <> 'token_conflict' then raise; end if;
  end;
  if not public.notification_invalidate_token(first_id, 'test-one') then raise exception 'invalidation failed'; end if;
  if exists(select 1 from public.notification_active_tokens() where installation_id = first_id) then raise exception 'invalidated token active'; end if;
  if exists(select 1 from public.push_tokens where installation_id = first_id and (fcm_token is not null or enabled or revision <> 1)) then raise exception 'invalidation state incorrect'; end if;
  begin
    perform public.notification_sync(first_id, credential, 1, true, 'test-one');
    raise exception 'retry restored invalid token';
  exception when sqlstate 'PT409' then null; end;
  perform public.notification_sync(first_id, credential, 2, true, 'test-new');
  if public.notification_invalidate_token(first_id, 'test-one') then raise exception 'old token invalidated replacement'; end if;
  if not exists(select 1 from public.notification_active_tokens() where installation_id = first_id and fcm_token = 'test-new') then raise exception 'replacement inactive'; end if;
  result := public.notification_sync(first_id, credential, 3, false, null);
  if (result->>'enabled')::boolean then raise exception 'OFF enabled'; end if;
  begin
    perform public.notification_sync(first_id, credential, 2, true, 'test-new');
    raise exception 'stale ON accepted';
  exception when sqlstate 'PT409' then null; end;
  if exists(select 1 from public.notification_active_tokens() where installation_id = first_id) then raise exception 'OFF in sender list'; end if;
  begin
    perform public.notification_sync(first_id, credential, 4, true, '  ');
    raise exception 'blank token accepted';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.notification_sync(first_id, credential, 9007199254740992, true, 'test');
    raise exception 'unsafe revision accepted';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.notification_register(null, credential);
    raise exception 'null installation accepted';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.notification_register(gen_random_uuid(), null);
    raise exception 'null credential accepted';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.notification_sync(gen_random_uuid(), credential, 1, true, 'unknown');
    raise exception 'unregistered sync accepted';
  exception when sqlstate 'PT401' then null; end;
  perform public.notification_sync(second_id, credential, 1, true, repeat('x',4096));
  result := public.notification_register(second_id, credential);
  if result->>'revision' <> '1' or not (result->>'enabled')::boolean then raise exception 'register replay reset state'; end if;
  begin
    perform public.notification_sync(second_id, credential, 2, true, repeat('x',4097));
    raise exception 'oversized token accepted';
  exception when sqlstate 'PT400' then null; end;
  if not public.notification_take_rate_limit('test-bucket',2) or not public.notification_take_rate_limit('test-bucket',2) or public.notification_take_rate_limit('test-bucket',2) then raise exception 'rate limit incorrect'; end if;
  update public.push_token_rate_limits set expires_at = now() - interval '1 second' where bucket = 'test-bucket';
  if not public.notification_take_rate_limit('test-bucket',2) then raise exception 'expired rate limit not reset'; end if;
end;
$$;
set local role anon;
do $$
begin
  begin perform * from public.push_tokens; raise exception 'anon read accepted'; exception when insufficient_privilege then null; end;
  begin perform public.notification_active_tokens(); raise exception 'anon RPC accepted'; exception when insufficient_privilege then null; end;
end;
$$;
reset role;
set local role authenticated;
do $$
begin
  begin delete from public.push_tokens; raise exception 'authenticated delete accepted'; exception when insufficient_privilege then null; end;
  begin perform public.notification_register(gen_random_uuid(), repeat('a',64)); raise exception 'authenticated register accepted'; exception when insufficient_privilege then null; end;
end;
$$;
reset role;
set local role service_role;
select public.notification_register('55dca53f-c281-4c88-854c-2d3b064a0003', repeat('c',64));
select * from public.notification_active_tokens();
reset role;
rollback;
