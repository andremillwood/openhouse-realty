"""Actual pending migration on socket-only PostgreSQL; no production data is touched."""
import pathlib, subprocess, json, uuid, time
BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-move-in-socket','-p','55440','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_target_'+uuid.uuid4().hex[:12]
processes=[]
def sql(query,db=None,error=None):
 r=subprocess.run(BASE+['-d',db or DB],input=query,text=True,capture_output=True)
 if error: assert r.returncode and error in r.stderr,r.stderr
 else: assert r.returncode==0,r.stderr
 return r.stdout.strip()
def session(query):
 p=subprocess.Popen(BASE+['-d',DB],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);processes.append(p);p.stdin.write(query);p.stdin.close();return p
def wait(event,p):
 for _ in range(100):
  assert p.poll() is None,p.stderr.read() if p.poll() is not None else ''
  if sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='"+event+"';")=='1':return
  time.sleep(.05)
 raise AssertionError('No observed '+event+' wait')
def finish(p,error=None):
 p.wait(timeout=10);err=p.stderr.read()
 if error:assert p.returncode and error in err,err
 else:assert p.returncode==0,err
assert sql('show listen_addresses;',db='postgres')==''
sql('create database '+DB+';',db='postgres')
try:
 org,foreign,actor,outsider,anonymous,order,foreign_order=[str(uuid.uuid4()) for _ in range(7)]
 sql('''create schema auth;create schema private;
 create table auth.users(id uuid primary key,email_confirmed_at timestamptz,is_anonymous boolean);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema public,auth,private to authenticated;
 create table public.organizations(id uuid primary key);
 create table public.staff_accounts(user_id uuid primary key,organization_id uuid,role text);
 create table public.work_orders(id uuid primary key,organization_id uuid,revision integer,status text);
 grant select on public.work_orders to authenticated;
 ''')
 source=pathlib.Path('supabase/migrations/20261007074022_immutable_finance_journals.sql').read_text();start=source.index('create function private.guard_finance_immutable()');end=source.index('create trigger guard_finance_immutable',start);sql(source[start:end])
 sql(pathlib.Path('supabase/migrations/20261008074842_work_order_service_targets.sql').read_text())
 sql(pathlib.Path('supabase/migrations/20261008155750_service_target_queue_summary.sql').read_text())
 sql(f"insert into public.organizations values('{org}'),('{foreign}');insert into auth.users values('{actor}',now(),false),('{outsider}',now(),false),('{anonymous}',now(),true);insert into public.staff_accounts values('{actor}','{org}','manager'),('{outsider}','{foreign}','manager'),('{anonymous}','{org}','manager');insert into public.work_orders values('{order}','{org}',3,'triaged'),('{foreign_order}','{foreign}',3,'triaged');")
 def identity(user=actor):return f"select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;"
 def command(request,version=0,kind='response',action='set',target=order,due="'2030-10-09T14:00:00Z'",work_version=3):return f"select public.record_work_order_service_target('{target}',{work_version},'{kind}',{version},'{action}',{due},'Approved target fixture',true,'{request}');"
 def execute(query,user=actor,error=None):return sql('begin;'+identity(user)+query+'commit;',error=error)
 req=str(uuid.uuid4());receipt=json.loads(execute(command(req)).splitlines()[-1]);assert receipt['version']==1 and receipt['work_order_version']==3
 assert json.loads(execute(command(req)).splitlines()[-1])==receipt
 summary=f"select coalesce(jsonb_agg(s),'[]'::jsonb) from public.work_order_service_target_summary(array['{order}'::uuid,'{foreign_order}'::uuid]) s;"
 assert len(json.loads(execute(summary).splitlines()[-1]))==1
 assert json.loads(execute(summary,user=outsider).splitlines()[-1])==[]
 assert json.loads(execute(summary,user=anonymous).splitlines()[-1])==[]
 execute("select * from public.work_order_service_target_summary(array[]::uuid[]);",error='One to twenty-five')
 execute("select * from public.work_order_service_target_summary(array_fill(gen_random_uuid(),array[26]));",error='One to twenty-five')
 execute("select * from public.work_order_service_target_summary(array[null]::uuid[]);",error='One to twenty-five')
 execute(command(req,kind='resolution'),error='Request reference already used')
 execute(command(str(uuid.uuid4())),error='Target changed; refresh')
 execute(command(str(uuid.uuid4()),kind='resolution',due="'2020-01-01'"),error='New target must be in the future')
 execute(command(str(uuid.uuid4()),target=foreign_order),error='Organization work order required')
 execute(command(str(uuid.uuid4())),user=outsider,error='Organization work order required')
 execute(command(str(uuid.uuid4())),user=anonymous,error='Verified organization manager required')
 assert execute('select count(*) from public.work_order_service_target_events;',user=outsider).splitlines()[-1]=='0'
 assert execute('select count(*) from public.work_order_service_target_events;',user=anonymous).splitlines()[-1]=='0'
 execute('delete from public.work_order_service_target_events;',error='permission denied')
 sql('update public.work_order_service_target_events set reason=\'Changed reason\';',error='immutable')
 clear=json.loads(execute(command(str(uuid.uuid4()),version=1,action='clear',due='null')).splitlines()[-1]);assert clear['version']==2 and clear['due_at'] is None
 current=json.loads(execute(summary).splitlines()[-1]);assert len(current)==1 and current[0]['version']==2 and current[0]['action']=='clear' and current[0]['due_at'] is None
 sql(f"update public.work_orders set status='closed',revision=4 where id='{order}';")
 assert json.loads(execute(command(req)).splitlines()[-1])==receipt
 summary=f"select coalesce(jsonb_agg(s),'[]'::jsonb) from public.work_order_service_target_summary(array['{order}'::uuid,'{foreign_order}'::uuid]) s;"
 assert len(json.loads(execute(summary).splitlines()[-1]))==1
 assert json.loads(execute(summary,user=outsider).splitlines()[-1])==[]
 assert json.loads(execute(summary,user=anonymous).splitlines()[-1])==[]
 execute("select * from public.work_order_service_target_summary(array[]::uuid[]);",error='One to twenty-five')
 execute("select * from public.work_order_service_target_summary(array_fill(gen_random_uuid(),array[26]));",error='One to twenty-five')
 execute("select * from public.work_order_service_target_summary(array[null]::uuid[]);",error='One to twenty-five')
 execute(command(str(uuid.uuid4()),version=2,work_version=4),error='Work order changed or closed')
 sql(f"update public.work_orders set status='triaged',revision=3 where id='{order}';")
 race=str(uuid.uuid4());first=session('begin;'+identity()+command(race,version=2)+'select pg_sleep(2);commit;');wait('PgSleep',first)
 second=session('begin;'+identity()+command(race,version=2)+'commit;');wait('advisory',second);finish(first);finish(second)
 assert sql('select count(*) from public.work_order_service_target_events;')=='3'
 first=session('begin;'+identity()+command(str(uuid.uuid4()),version=3)+'select pg_sleep(2);commit;');wait('PgSleep',first)
 second=session('begin;'+identity()+command(str(uuid.uuid4()),version=3)+'commit;');wait('advisory',second);finish(first);finish(second,'Target changed; refresh')
 first=session(f"begin;update public.work_orders set status='closed',revision=4 where id='{order}';select pg_sleep(2);commit;");wait('PgSleep',first)
 second=session('begin;'+identity()+command(str(uuid.uuid4()),version=4)+'commit;');wait('transactionid',second);finish(first);finish(second,'Work order changed or closed')
 first=session(f"begin;select pg_advisory_xact_lock(hashtextextended('{org}',119));delete from public.staff_accounts where user_id='{actor}';select pg_sleep(2);commit;");wait('PgSleep',first)
 second=session('begin;'+identity()+command(req)+'commit;');wait('advisory',second);finish(first);finish(second,'Manager authority changed')
 print('PASS: actual service-target migration, immutable/scoped history, anonymous denial, future/current/replay/clear gates and observed retry/revision/closure/revocation races; minimal isolated PostgreSQL fixture, not live acceptance')
finally:
 for p in processes:
  if p.poll() is None:p.terminate();p.wait(timeout=5)
 sql('drop database '+DB+' with(force);',db='postgres')
