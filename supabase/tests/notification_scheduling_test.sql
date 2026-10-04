-- Run after all notification migrations, in a disposable DB; every fixture rolls back.
\set ON_ERROR_STOP on
begin;
do $$ begin
  if current_database() not like 'quiz\_notifications\_%' escape '\' then
    raise exception 'Run only in a disposable quiz_notifications_ database';
  end if;
end; $$;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); j uuid:=gen_random_uuid(); k uuid;
  due_ timestamptz:=clock_timestamp()+interval '3 days'; summary_ jsonb; c record; n integer; old_due timestamptz;
begin
  insert into public.push_tokens(installation_id,credential_hash,fcm_token,enabled) values
    (a,repeat('a',64),'scheduling-a',true),(b,repeat('b',64),'scheduling-b',false);
  summary_:=public.notification_schedule(j,'사흘 뒤','본문',array[a,b],due_);
  assert summary_->>'state'='waiting' and summary_->>'source'='dashboard';
  assert summary_->>'started_at' is null;
  assert not exists(select 1 from public.push_deliveries where job_id=j);
  select count(*) into n from public.notification_claim(j,5); assert n=0;
  assert (public.notification_job_status(j)->>'state')='waiting', 'future job expired early';
  perform public.notification_schedule(j,'사흘 뒤','본문',array[b,a,a],due_);
  begin
    perform public.notification_schedule(j,'사흘 뒤','본문',array[a,b],due_+interval '1 minute');
    raise exception 'different date accepted';
  exception when sqlstate 'PT409' then null; end;
  begin
    perform public.notification_schedule(j,'사흘 뒤','본문',array[a,b],null);
    raise exception 'scheduled replay as immediate accepted';
  exception when sqlstate 'PT409' then null; end;
  begin
    perform public.notification_schedule(gen_random_uuid(),'과거','본문',null,clock_timestamp()-interval '1 second');
    raise exception 'past accepted';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.notification_schedule(gen_random_uuid(),'무한','본문',null,'infinity');
    raise exception 'infinite timestamp accepted';
  exception when sqlstate 'PT400' then null; end;
  -- Snapshot includes late consent and excludes withdrawal before the due time.
  update public.push_tokens set enabled=false where installation_id=a;
  update public.push_tokens set enabled=true,fcm_token='scheduling-b-new' where installation_id=b;
  old_due:=clock_timestamp()-interval '1 second';
  update public.push_jobs set scheduled_at=old_due,created_at=clock_timestamp()-interval '3 days' where id=j;
  select * into c from public.notification_claim(j,5);
  assert c.installation_id=b and c.fcm_token='scheduling-b-new';
  assert (select count(*)=1 from public.push_deliveries where job_id=j);
  perform public.notification_schedule(j,'사흘 뒤','본문',array[a,b],old_due); -- Replay after due.
  update public.push_tokens set enabled=true where installation_id=a;
  select count(*) into n from public.notification_claim(j,5); assert n=0;
  assert (select count(*)=1 from public.push_deliveries where job_id=j), 'snapshot expanded';
  update public.push_tokens set enabled=false where installation_id=b;
  assert not public.notification_delivery_current(j,b,c.claim_id), 'withdrawal ignored';
  assert public.notification_finish(j,b,c.claim_id,'skipped');
  -- Immediate dashboard requests keep the original effective due time on retries.
  k:=gen_random_uuid(); summary_:=public.notification_schedule(k,'즉시','본문',array[a],null);
  old_due:=(summary_->>'scheduled_at')::timestamptz;
  summary_:=public.notification_schedule(k,'즉시','본문',array[a],null);
  assert (summary_->>'scheduled_at')::timestamptz=old_due;
  assert summary_->>'is_scheduled'='false';
  select * into c from public.notification_claim(k,5); assert c.installation_id=a;
  assert public.notification_finish(k,a,c.claim_id,'sent');
  -- Empty recipient snapshot cannot be repopulated after a later opt-in.
  update public.push_tokens set enabled=false where installation_id=a;
  k:=gen_random_uuid(); perform public.notification_schedule(k,'대상 없음','본문',array[a],null);
  select count(*) into n from public.notification_claim(k,5); assert n=0;
  summary_:=public.notification_job_status(k);
  assert summary_->>'state'='complete' and summary_->>'started_at' is not null;
  update public.push_tokens set enabled=true where installation_id=a;
  select count(*) into n from public.notification_claim(k,5); assert n=0;
  -- Expired waiting jobs never snapshot, expired pending jobs are skipped.
  k:=gen_random_uuid(); perform public.notification_schedule(k,'만료 전','본문',array[a],null);
  update public.push_jobs set scheduled_at=clock_timestamp()-interval '25 hours' where id=k;
  select count(*) into n from public.notification_claim(k,5); assert n=0;
  assert (public.notification_job_status(k)->>'state')='expired';
  assert not exists(select 1 from public.push_deliveries where job_id=k);
  k:=gen_random_uuid(); perform public.notification_enqueue(k,'기존 즉시','본문',array[a]);
  assert (public.notification_job_status(k)->>'source')='legacy';
  update public.push_jobs set scheduled_at=clock_timestamp()-interval '25 hours' where id=k;
  select count(*) into n from public.notification_claim(k,5); assert n=0;
  assert (select status='skipped' from public.push_deliveries where job_id=k);
  assert (public.notification_job_status(k)->>'state')='complete';
  -- A deadline crossed after claim still blocks the actual send.
  k:=gen_random_uuid(); perform public.notification_enqueue(k,'전송 직전 기한','본문',array[a]);
  select * into c from public.notification_claim(k,1);
  update public.push_jobs set scheduled_at=clock_timestamp()-interval '25 hours' where id=k;
  assert not public.notification_delivery_current(k,a,c.claim_id);
  assert public.notification_finish(k,a,c.claim_id,'skipped');
  assert '2027-01-01 00:00:00+09'::timestamptz='2026-12-31 15:00:00Z'::timestamptz;
  assert not has_function_privilege('anon','public.notification_schedule(uuid,text,text,uuid[],timestamptz,text)','EXECUTE');
  assert not has_function_privilege('authenticated','public.notification_schedule(uuid,text,text,uuid[],timestamptz,text)','EXECUTE');
  assert has_function_privilege('service_role','public.notification_schedule(uuid,text,text,uuid[],timestamptz,text)','EXECUTE');
end;
$$;
-- Six concurrent campaigns must all receive a slot across two batches of five.
do $$
declare ids uuid[]; targets uuid[]; i integer; c record; n integer;
begin
  select array_agg(gen_random_uuid()) into targets from generate_series(1,8);
  insert into public.push_tokens(installation_id,credential_hash,fcm_token,enabled)
    select t,repeat('c',64),'fair-'||t,true from unnest(targets) t;
  select array_agg(gen_random_uuid()) into ids from generate_series(1,6);
  for i in 1..6 loop perform public.notification_schedule(ids[i],'공정성','본문',targets,null); end loop;
  -- Remove unrelated ready rows from the preceding test (inside rollback transaction only).
  update public.push_deliveries set status='skipped' where status in ('pending','retry','sending');
  for i in 1..2 loop
    for c in select * from public.notification_claim(null,5) loop
      assert public.notification_finish(c.job_id,c.installation_id,c.claim_id,'sent');
    end loop;
  end loop;
  select count(distinct job_id) into n from public.push_deliveries where job_id=any(ids) and attempts>0;
  assert n=6, 'campaign starvation';
end;
$$;
-- Synthetic SQL-only throughput; no network or actual FCM calls.
do $$
declare targets uuid[]; j uuid:=gen_random_uuid(); c record; n integer:=0; began timestamptz:=clock_timestamp();
begin
  select array_agg(gen_random_uuid()) into targets from generate_series(1,1000);
  insert into public.push_tokens(installation_id,credential_hash,fcm_token,enabled)
    select t,repeat('d',64),'load-'||t,true from unnest(targets) t;
  -- All eligible targets: assert only this isolated fixture count via job scope.
  update public.push_tokens set enabled=false where not(installation_id=any(targets));
  perform public.notification_schedule(j,'처리량','본문',null,null);
  loop
    for c in select * from public.notification_claim(j,5) loop
      assert public.notification_finish(c.job_id,c.installation_id,c.claim_id,'sent');
      n:=n+1;
    end loop;
    exit when n>=1000;
    assert clock_timestamp()-began<interval '30 seconds', 'synthetic queue stalled';
  end loop;
  assert n=1000 and (public.notification_job_status(j)->>'state')='complete';
  raise notice '1000 mocked deliveries SQL elapsed: %',clock_timestamp()-began;
end;
$$;
rollback;
