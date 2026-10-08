"""Socket-only local PostgreSQL race test; minimal catalog fixture, actual command migration."""
import pathlib, subprocess, time, json, uuid
BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-move-in-socket','-p','55440','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_move_in_concurrency'
processes=[]
def sql(query,db=DB):
 r=subprocess.run(BASE+['-d',db],input=query,text=True,capture_output=True)
 if r.returncode:raise AssertionError(r.stderr)
 return r.stdout.strip()
def session(query):
 p=subprocess.Popen(BASE+['-d',DB],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);processes.append(p);p.stdin.write(query);p.stdin.close();return p
def wait(event,p):
 for _ in range(100):
  if p.poll() is not None:raise AssertionError(p.stderr.read())
  if int(sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='"+event+"';"))==1:return
  time.sleep(.05)
 raise AssertionError('No observed contention '+event)
def finish(p,error=None):
 p.wait(timeout=10);out=p.stdout.read();err=p.stderr.read()
 if error:assert p.returncode!=0 and error in err,err
 else:assert p.returncode==0,err
 return out
assert sql('show listen_addresses;','postgres')==''
version=sql('show server_version;','postgres')
sql("do $$ begin if not exists(select from pg_roles where rolname='anon') then create role anon;end if;if not exists(select from pg_roles where rolname='authenticated') then create role authenticated;end if;if not exists(select from pg_roles where rolname='service_role') then create role service_role;end if;end $$;",'postgres')
sql('create database '+DB+';','postgres')
try:
 org,actor,app,draft,reservation,applicant=[str(uuid.uuid4()) for _ in range(6)]
 sql('''create schema auth;create schema private;
 create table auth.users(id uuid primary key,email_confirmed_at timestamptz);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema auth,private,public to authenticated;
 create table public.organizations(id uuid primary key);
 create table public.staff_accounts(user_id uuid primary key,organization_id uuid,role text);
 create table public.rental_applications(id uuid primary key,organization_id uuid,user_id uuid,status text,version integer);
 create table public.application_cosigners(application_id uuid,recipient_user_id uuid,state text);
 create table public.rental_unit_reservations(id uuid primary key,application_id uuid,organization_id uuid,state text);
 create table public.rental_lease_drafts(id uuid primary key,organization_id uuid,application_id uuid,reservation_id uuid,version integer,application_version integer,state text);
 grant select on public.rental_lease_drafts to authenticated;
 ''')
 helper=pathlib.Path('supabase/migrations/20261007024244_verified_staff_collaboration_reads.sql').read_text().split('alter policy')[0]
 sql(helper)
 immutable=pathlib.Path('supabase/migrations/20261007074022_immutable_finance_journals.sql').read_text();start=immutable.index('create function private.guard_finance_immutable()');end=immutable.index('create trigger guard_finance_immutable',start);sql(immutable[start:end])
 sql(pathlib.Path('supabase/migrations/20261008065947_move_in_preparation.sql').read_text())
 sql(f"insert into auth.users values('{actor}',now()),('{applicant}',now());insert into public.organizations values('{org}');insert into public.staff_accounts values('{actor}','{org}','manager');insert into public.rental_applications values('{app}','{org}','{applicant}','approved',5);insert into public.rental_unit_reservations values('{reservation}','{app}','{org}','held');insert into public.rental_lease_drafts values('{draft}','{org}','{app}','{reservation}',1,5,'prepared');")
 identity=f"select set_config('request.jwt.claim.sub','{actor}',true);set local role authenticated;"
 def command(request,kind='unit_readiness',revision=0,state='ready'):
  return f"select public.record_move_in_preparation('{draft}',1,'{kind}',{revision},'{state}','Inspection race fixture','Reviewed race fixture','{request}',true);"
 req=str(uuid.uuid4());first=session('begin;'+identity+command(req)+'select pg_sleep(2);commit;');wait('PgSleep',first)
 second=session('begin;'+identity+command(req)+'commit;');wait('advisory',second);finish(first);finish(second)
 assert sql('select count(*) from public.rental_move_in_preparation_events;')=='1'
 first=session('begin;'+identity+command(str(uuid.uuid4()),revision=1,state='blocked')+'select pg_sleep(2);commit;');wait('PgSleep',first)
 second=session('begin;'+identity+command(str(uuid.uuid4()),revision=1)+'commit;');wait('advisory',second);finish(first);finish(second,'Preparation changed; refresh')
 assert sql('select count(*) from public.rental_move_in_preparation_events;')=='2'
 first=session(f"begin;update public.rental_applications set status='withdrawn',version=6 where id='{app}';select pg_sleep(2);commit;");wait('PgSleep',first)
 second=session('begin;'+identity+command(str(uuid.uuid4()),kind='utilities')+'commit;');wait('transactionid',second);finish(first);finish(second,'Current approval, draft and reservation required')
 assert sql('select count(*) from public.rental_move_in_preparation_events;')=='2'
 first=session(f"begin;select pg_advisory_xact_lock(hashtextextended('{org}',119));delete from public.staff_accounts where user_id='{actor}';select pg_sleep(2);commit;");wait('PgSleep',first)
 second=session('begin;'+identity+command(req)+'commit;');wait('advisory',second);finish(first);finish(second,'Staff authority changed')
 print('PASS: observed exact-retry contention, competing revision denial, approval withdrawal and membership revocation races; isolated PostgreSQL '+version+'; minimal catalog fixture, not production-version acceptance')
finally:
 for p in processes:
  if p.poll() is None:p.terminate();p.wait(timeout=5)
 sql('drop database '+DB+' with(force);','postgres')
