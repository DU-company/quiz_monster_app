alter table public.quiz
  add column priority integer not null default 100;

update public.quiz
set priority = 10
where quiz_group = 'other' and title = '상식 퀴즈';
