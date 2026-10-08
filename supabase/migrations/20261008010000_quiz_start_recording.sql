-- 통계 API 전송: 선택한 퀴즈의 서버 KST 일별 시작 횟수를 1 증가시킨다.
create function public.record_quiz_start(p_quiz_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  recorded_at_ timestamptz := statement_timestamp();
  stat_date_ date := (recorded_at_ at time zone 'Asia/Seoul')::date;
begin
  if p_quiz_id is null or not exists (
    select 1 from public.quiz where id = p_quiz_id
  ) then
    raise exception 'Unknown quiz ID' using errcode = '22023';
  end if;

  insert into public.quiz_start_daily_counts as counts
    (quiz_id, stat_date, start_count, updated_at)
  values (p_quiz_id, stat_date_, 1, recorded_at_)
  on conflict (quiz_id, stat_date) do update
    set start_count = counts.start_count + 1,
        updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.record_quiz_start(bigint) from public;
grant execute on function public.record_quiz_start(bigint) to anon, authenticated;
