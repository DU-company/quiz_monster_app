begin;
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); j uuid := gen_random_uuid(); k uuid := gen_random_uuid();
  c record; summary_ jsonb; n integer; role_ text;
begin
  insert into public.push_tokens(installation_id,credential_hash,fcm_token,enabled) values
    (a,repeat('a',64),'delivery-test-a',true),(b,repeat('b',64),'delivery-test-b',true);
  summary_ := public.notification_enqueue(j,'제목','본문',array[b,a,a]);
  assert (summary_->>'remaining')::int = 2;
  summary_ := public.notification_enqueue(j,'제목','본문',array[a,b]);
  assert (summary_->>'remaining')::int = 2;
  begin
    perform public.notification_enqueue(j,'제목','변경',array[a,b]);
    raise exception 'changed request accepted';
  exception when sqlstate 'PT409' then null; end;
  begin
    perform public.notification_enqueue(k,'제목','본문',array[]::uuid[]);
    raise exception 'empty targets accepted';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.notification_enqueue(k,'제목',repeat('😀',1000),array[a]);
    raise exception 'oversized UTF8 body accepted';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.notification_job_status(k);
    raise exception 'missing job accepted';
  exception when sqlstate 'PT404' then null; end;
  update public.push_tokens set enabled = false where installation_id = b;
  select * into c from public.notification_claim(j,5);
  assert c.installation_id = a and c.attempts = 1;
  select count(*) into n from public.notification_claim(j,5);
  assert n = 0, 'claim duplicated';
  assert public.notification_delivery_current(j,a,c.claim_id);
  assert not public.notification_finish(j,a,gen_random_uuid(),'sent'), 'foreign claim accepted';
  update public.push_tokens set fcm_token = 'delivery-test-a-new' where installation_id = a;
  assert not public.notification_delivery_current(j,a,c.claim_id), 'rotated token still current';
  assert public.notification_finish(j,a,c.claim_id,'invalid');
  assert (select fcm_token = 'delivery-test-a-new' from public.push_tokens where installation_id = a), 'new token invalidated';
  assert not public.notification_finish(j,a,c.claim_id,'sent'), 'finished claim accepted';
  summary_ := public.notification_job_status(j);
  assert summary_->'counts'->>'invalid' = '1' and summary_->'counts'->>'skipped' = '1';

  perform public.notification_enqueue(k,'재시도','본문',array[a]);
  select * into c from public.notification_claim(k,1);
  assert public.notification_finish(k,a,c.claim_id,'retry',600);
  assert (select available_at >= now() + interval '599 seconds' from public.push_deliveries where job_id=k), 'Retry-After shortened';
  select count(*) into n from public.notification_claim(k,1); assert n=0;
  update public.push_deliveries set available_at=now()-interval '1 second' where job_id=k;
  select * into c from public.notification_claim(k,1); assert c.attempts=2;
  assert public.notification_finish(k,a,c.claim_id,'retry',1);
  assert (select available_at >= now() + interval '119 seconds' from public.push_deliveries where job_id=k), 'backoff missing';
  update public.push_deliveries set available_at=now()-interval '1 second' where job_id=k;
  select * into c from public.notification_claim(k,1); assert c.attempts=3;
  assert public.notification_finish(k,a,c.claim_id,'retry');
  assert (select status='failed' from public.push_deliveries where job_id=k);

  k:=gen_random_uuid(); perform public.notification_enqueue(k,'만료','본문',array[a]);
  select * into c from public.notification_claim(k,1);
  update public.push_deliveries set updated_at=now()-interval '6 minutes' where job_id=k;
  assert not public.notification_finish(k,a,c.claim_id,'sent');
  assert (select status='unknown' from public.push_deliveries where job_id=k);
  select count(*) into n from public.notification_claim(k,1); assert n=0;
  k:=gen_random_uuid(); perform public.notification_enqueue(k,'만료 확인','본문',array[a]);
  select * into c from public.notification_claim(k,1);
  update public.push_deliveries set updated_at=now()-interval '6 minutes' where job_id=k;
  assert not public.notification_delivery_current(k,a,c.claim_id);
  assert (select status='unknown' from public.push_deliveries where job_id=k);

  k:=gen_random_uuid(); perform public.notification_enqueue(k,'만료 정리','본문',array[a]);
  select * into c from public.notification_claim(k,1);
  update public.push_deliveries set updated_at=now()-interval '6 minutes' where job_id=k;
  select count(*) into n from public.notification_claim(k,1); assert n=0;
  assert (select status='unknown' from public.push_deliveries where job_id=k);

  k:=gen_random_uuid(); perform public.notification_enqueue(k,'오래된 작업','본문',array[a]);
  update public.push_jobs set created_at=now()-interval '25 hours' where id=k;
  select count(*) into n from public.notification_claim(k,1); assert n=0;
  assert (select status='skipped' from public.push_deliveries where job_id=k);
  k:=gen_random_uuid(); perform public.notification_enqueue(k,'회전 전','본문',array[a]);
  update public.push_tokens set fcm_token='delivery-test-a-newer' where installation_id=a;
  select count(*) into n from public.notification_claim(k,1); assert n=0;
  assert (select status='skipped' from public.push_deliveries where job_id=k);
  k:=gen_random_uuid(); perform public.notification_enqueue(k,'수신 거부','본문',array[a]);
  select * into c from public.notification_claim(k,1);
  update public.push_tokens set enabled=false where installation_id=a;
  assert not public.notification_delivery_current(k,a,c.claim_id);
  assert public.notification_finish(k,a,c.claim_id,'skipped');
  update public.push_tokens set enabled=true where installation_id=a;
  k:=gen_random_uuid(); perform public.notification_enqueue(k,'유효하지 않음','본문',array[a]);
  select * into c from public.notification_claim(k,1);
  assert public.notification_finish(k,a,c.claim_id,'invalid');
  assert (select fcm_token is null and not enabled from public.push_tokens where installation_id=a);

  foreach role_ in array array['anon','authenticated','service_role'] loop
    assert not has_table_privilege(role_,'public.push_jobs','SELECT');
    assert not has_table_privilege(role_,'public.push_deliveries','SELECT');
    assert not has_table_privilege(role_,'public.push_jobs','INSERT');
    assert not has_table_privilege(role_,'public.push_deliveries','UPDATE');
  end loop;
  foreach role_ in array array['anon','authenticated'] loop
    assert not has_function_privilege(role_,'public.notification_enqueue(uuid,text,text,uuid[])','EXECUTE');
    assert not has_function_privilege(role_,'public.notification_claim(uuid,integer)','EXECUTE');
    assert not has_function_privilege(role_,'public.notification_finish(uuid,uuid,uuid,text,integer)','EXECUTE');
  end loop;
  assert has_function_privilege('service_role','public.notification_enqueue(uuid,text,text,uuid[])','EXECUTE');
end;
$$;
rollback;
