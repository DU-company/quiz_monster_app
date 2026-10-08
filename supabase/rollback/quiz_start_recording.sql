-- 통계 API 전송만 중단하며 기존 누적 데이터와 테이블 권한은 보존한다.
begin;
drop function public.record_quiz_start(bigint);
commit;
