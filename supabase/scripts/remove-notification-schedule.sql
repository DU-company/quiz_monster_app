-- 이 기능의 스케줄 두 개만 제거하며 등록된 발송 기록은 보존한다.
select cron.unschedule(jobid) from cron.job
where jobname in ('quiz-monster-weekend-push','quiz-monster-push-worker');
