\set ON_ERROR_STOP on
begin;
do $$ begin
  if current_database() not like 'quiz\_statistics\_%' escape '\' then
    raise exception 'Requires disposable quiz_statistics_ database';
  end if;
  assert exists(select 1 from public.quiz where id=80);
  assert exists(select 1 from public.quiz where id=100);
end $$;
delete from public.quiz_start_daily_counts;
set local role anon;
select public.record_quiz_start(80);
select public.record_quiz_start(80);
do $$ begin
  begin
    perform public.record_quiz_start(null);
    raise exception 'null accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.record_quiz_start(-9223372036854775807);
    raise exception 'unknown ID accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform * from public.quiz_start_daily_counts;
    raise exception 'anon read allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select public.record_quiz_start(100);
do $$ begin
  assert (select count(*)=0 from public.quiz_start_daily_counts), 'nonadmin can read';
end $$;
reset role;
do $$
declare role_ text; statement_ text; definition_ text;
begin
  assert (select start_count=2 from public.quiz_start_daily_counts where quiz_id=80
    and stat_date=(statement_timestamp() at time zone 'Asia/Seoul')::date);
  assert (select start_count=1 from public.quiz_start_daily_counts where quiz_id=100
    and stat_date=(statement_timestamp() at time zone 'Asia/Seoul')::date);
  update public.quiz_start_daily_counts set updated_at='2000-01-01' where quiz_id=80;
  perform public.record_quiz_start(80);
  assert (select start_count=3 and updated_at>'2000-01-01'::timestamptz
    from public.quiz_start_daily_counts where quiz_id=80);
  assert (select prosecdef and proconfig @> array['search_path=""']
    from pg_proc where oid='public.record_quiz_start(bigint)'::regprocedure);
  assert not exists(select 1 from pg_proc p, lateral aclexplode(p.proacl) a
    where p.oid='public.record_quiz_start(bigint)'::regprocedure and a.grantee=0);
  foreach role_ in array array['anon','authenticated'] loop
    execute format('set local role %I',role_);
    foreach statement_ in array array[
      'insert into public.quiz_start_daily_counts values(80,current_date,999,now())',
      'update public.quiz_start_daily_counts set start_count=999',
      'delete from public.quiz_start_daily_counts'
    ] loop
      begin
        execute statement_;
        raise exception 'direct write unexpectedly allowed';
      exception when insufficient_privilege then null;
      end;
    end loop;
    reset role;
  end loop;
  -- 테스트 트랜잭션 안에서만 서버 시계를 고정하고 종료 시 함수까지 복원한다.
  definition_ := pg_get_functiondef('public.record_quiz_start(bigint)'::regprocedure);
  execute replace(definition_, 'statement_timestamp()', 'timestamptz ''2026-01-01 14:59:59+00''');
  set local time zone 'Pacific/Honolulu';
  perform public.record_quiz_start(80);
  execute replace(definition_, 'statement_timestamp()', 'timestamptz ''2026-01-01 15:00:00+00''');
  set local time zone 'Europe/London';
  perform public.record_quiz_start(80);
  perform public.record_quiz_start(80);
  assert (select start_count=1 and updated_at='2026-01-01 14:59:59+00'::timestamptz
    from public.quiz_start_daily_counts where quiz_id=80 and stat_date='2026-01-01');
  assert (select start_count=2 and updated_at='2026-01-01 15:00:00+00'::timestamptz
    from public.quiz_start_daily_counts where quiz_id=80 and stat_date='2026-01-02');
end $$;
insert into auth.users(id,email,email_confirmed_at)
values('00000000-0000-4000-8000-000000000002','du0788754@gmail.com',now());
insert into auth.identities(id,provider_id,user_id,identity_data,provider)
values('00000000-0000-4000-8000-000000000003','statistics-test',
 '00000000-0000-4000-8000-000000000002',
 '{"email":"du0788754@gmail.com","email_verified":true}', 'google');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $$ begin
  assert public.is_dashboard_admin();
  assert (select count(*)>=2 from public.quiz_start_daily_counts), 'admin cannot read';
end $$;
reset role;
rollback;
