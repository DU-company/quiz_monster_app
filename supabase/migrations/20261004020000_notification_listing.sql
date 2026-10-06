begin;

-- Web history is intentionally limited to dashboard jobs; no recipient/token data is exposed.
create function public.notification_list(p_page integer default 1,p_page_size integer default 50)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare jobs_ jsonb; total_ bigint;
begin
  if p_page is null or p_page not between 1 and 10000
    or p_page_size is null or p_page_size not between 1 and 100 then
    raise exception using errcode='PT400',message='invalid_request';
  end if;
  select count(*) into total_ from public.push_jobs where source='dashboard';
  select coalesce(jsonb_agg(public.notification_job_status(j.id) order by j.created_at desc,j.id desc),'[]'::jsonb)
    into jobs_ from (
      select id,created_at from public.push_jobs where source='dashboard'
        order by created_at desc,id desc limit p_page_size offset ((p_page-1)*p_page_size)
    ) j;
  return jsonb_build_object('jobs',jobs_,'total',total_,'page',p_page,'page_size',p_page_size);
end;
$$;
revoke all on function public.notification_list(integer,integer) from public,anon,authenticated,service_role;
grant execute on function public.notification_list(integer,integer) to service_role;
commit;
