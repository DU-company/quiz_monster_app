\set ON_ERROR_STOP on
begin;
do $$ begin
  if current_database() not like 'quiz\_notifications\_%' escape '\' then
    raise exception 'Run only in a disposable quiz_notifications_ database';
  end if;
end; $$;
do $$
declare response_ jsonb; before_ jsonb; after_ jsonb; value_ integer; role_ text;
begin
  -- Isolation is required because fixture times and exact pagination are intentionally deterministic.
  assert not exists(select 1 from public.push_jobs), 'Test expects empty job table';
  perform public.notification_enqueue('00000000-0000-4000-8000-000000000004','legacy','excluded');
  perform public.notification_schedule('00000000-0000-4000-8000-000000000001','first','body',null,null);
  perform public.notification_schedule('00000000-0000-4000-8000-000000000002','second','body',null,clock_timestamp()+interval '3 days');
  perform public.notification_schedule('00000000-0000-4000-8000-000000000003','third','body',null,null);
  update public.push_jobs set created_at='2026-10-04T00:00:00Z';
  select jsonb_agg(to_jsonb(j) order by id) into before_ from public.push_jobs j;
  response_:=public.notification_list(1,2);
  assert response_->>'total'='3' and response_->>'page'='1' and response_->>'page_size'='2';
  assert jsonb_array_length(response_->'jobs')=2;
  assert response_->'jobs'->0->>'job_id'='00000000-0000-4000-8000-000000000003';
  assert response_->'jobs'->1->>'job_id'='00000000-0000-4000-8000-000000000002';
  assert response_->'jobs'->1->>'state'='waiting';
  assert (response_->'jobs'->1->>'is_scheduled')::boolean;
  assert response_->'jobs'->1 ?& array['title','body','scheduled_at','created_at','started_at','counts','remaining'];
  response_:=public.notification_list(2,2);
  assert jsonb_array_length(response_->'jobs')=1;
  assert response_->'jobs'->0->>'job_id'='00000000-0000-4000-8000-000000000001';
  response_:=public.notification_list(10000,100);
  assert response_->'jobs'='[]'::jsonb and response_->>'total'='3';
  response_:=public.notification_list();
  assert response_->>'page'='1' and response_->>'page_size'='50';
  foreach value_ in array array[null,0,-1,10001] loop
    begin
      perform public.notification_list(value_,1);
      raise exception 'bad page accepted';
    exception when sqlstate 'PT400' then null; end;
  end loop;
  foreach value_ in array array[null,0,-1,101] loop
    begin
      perform public.notification_list(1,value_);
      raise exception 'bad size accepted';
    exception when sqlstate 'PT400' then null; end;
  end loop;
  select jsonb_agg(to_jsonb(j) order by id) into after_ from public.push_jobs j;
  assert before_=after_, 'list mutated jobs';
  assert not exists(select 1 from public.push_deliveries), 'list created recipient snapshot';
  foreach role_ in array array['anon','authenticated'] loop
    assert not has_function_privilege(role_,'public.notification_list(integer,integer)','EXECUTE');
  end loop;
  assert has_function_privilege('service_role','public.notification_list(integer,integer)','EXECUTE');
  assert not has_table_privilege('service_role','public.push_jobs','SELECT');
end; $$;
rollback;
