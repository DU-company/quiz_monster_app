"""Run only against a disposable local quiz_statistics_ database."""
import concurrent.futures
import subprocess
import sys
import threading

container, database = sys.argv[1:]
if not database.startswith('quiz_statistics_'):
    raise SystemExit('Requires disposable quiz_statistics_ database')


def sql(query):
    result = subprocess.run(
        ['docker', 'exec', '-i', container, 'psql', '-U', 'postgres',
         '-d', database, '-v', 'ON_ERROR_STOP=1', '-Atq'],
        input=query, text=True, capture_output=True, check=True)
    return result.stdout.strip()


assert sql('select count(*) from public.quiz_start_daily_counts') == '0'
barrier = threading.Barrier(8)


def increment(_):
    barrier.wait()
    sql('begin; set local role anon; '
        'select public.record_quiz_start(80) from generate_series(1,25); commit;')


with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    list(pool.map(increment, range(8)))
assert sql('select sum(start_count) from public.quiz_start_daily_counts where quiz_id=80') == '200'
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    list(pool.map(increment, range(8)))
assert sql('select sum(start_count) from public.quiz_start_daily_counts where quiz_id=80') == '400'
print('8 concurrent connections: initial insert and existing-row updates total 400 starts')
