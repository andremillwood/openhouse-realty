"""Isolated Unix-socket fixture only. Preventive/work/membership migrations run against minimal local foundation tables."""
import subprocess, pathlib, time, json, uuid

BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_preventive_concurrency'
processes=[]
def sql(query,db=DB,check=True):
    result=subprocess.run(BASE+['-d',db],input=query,text=True,capture_output=True)
    if check and result.returncode: raise AssertionError(result.stderr)
    return result
def session(query):
    process=subprocess.Popen(BASE+['-d',DB],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    processes.append(process);process.stdin.write(query);process.stdin.close();return process
def finish(process,error=None):
    process.wait(timeout=10);out=process.stdout.read();err=process.stderr.read()
    if error: assert process.returncode!=0 and error in err,err
    else: assert process.returncode==0,err
    return out
def wait(event,process=None):
    for _ in range(100):
        if process is not None and process.poll() is not None:
            raise AssertionError('Session ended before '+event+': '+process.stderr.read())
        if sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='"+event+"';").stdout.strip()=='1': return
        time.sleep(.05)
    raise AssertionError('Expected independent-session wait was not observed: '+event)

assert sql('show listen_addresses;','postgres').stdout.strip()=='', 'Fixture must not listen on TCP'
version=sql('show server_version;','postgres').stdout.strip()
sql('create database '+DB+' template postgres;','postgres')
try:
    sql("""create table public.work_orders(id uuid primary key default gen_random_uuid(),property_id uuid references public.properties(id),unit_id uuid references public.units(id),title text,description text,priority text,status text,created_at timestamptz default now());alter table public.work_orders enable row level security;""")
    membership=pathlib.Path('supabase/migrations/20261007054101_audited_staff_membership.sql').read_text().replace('create function private.verified_staff_admin_organization()', 'create or replace function private.verified_staff_admin_organization()')
    sql('drop policy if exists "verified administrators read organization memberships" on public.staff_accounts;')
    sql(membership)
    sql('grant select on public.staff_accounts to authenticated;')
    sql(pathlib.Path('supabase/migrations/20261007024244_verified_staff_collaboration_reads.sql').read_text().split('alter policy')[0])
    for name in ['20261007054742_managed_work_order_intake.sql','20261007111633_preventive_maintenance_plans.sql','20261007113144_preventive_due_history_guard.sql','20261007113746_preventive_skip_decisions.sql']:
        sql(pathlib.Path('supabase/migrations',name).read_text())
    org='55667788-0000-4000-8000-000000000006';actor='55667788-0000-4000-8000-000000000020';admin='55667788-0000-4000-8000-000000000021';prop='55667788-0000-4000-8000-000000000030'
    sql("insert into auth.users(id,email,email_confirmed_at) values('"+actor+"','preventive-manager@example.invalid',now()),('"+admin+"','preventive-admin@example.invalid',now());insert into public.organizations(id,name) values('"+org+"','Isolated preventive fixture');insert into public.staff_accounts(user_id,organization_id,role) values('"+actor+"','"+org+"','manager'),('"+admin+"','"+org+"','admin');insert into public.properties(id,organization_id,name) values('"+prop+"','"+org+"','Preventive fixture');")
    def identity(who=actor):return "select set_config('request.jwt.claim.sub','"+who+"',true);set local role authenticated;"
    manager=identity()
    def create(request):return "select public.manage_preventive_plan('"+request+"','create',null,0,'"+prop+"',null,'Approved inspection','Inspect equipment and document all observed findings.','standard',30,(now() at time zone 'America/Jamaica')::date,'active','Approved isolated inspection',true);"
    def new_plan():return json.loads(sql('begin;'+manager+create(str(uuid.uuid4()))+'commit;').stdout.strip().splitlines()[-1])['id']
    def issue(plan,request,version=1):return "select public.manage_preventive_plan('"+request+"','issue','"+plan+"',"+str(version)+",null,null,null,null,null,null,null,null,'Approved isolated due work',true);"
    def skip(plan,request,version=1):return "select public.skip_preventive_occurrence('"+request+"','"+plan+"',"+str(version)+",'Approved isolated skipped date',true);"
    def pause(plan,version=1):return "select public.manage_preventive_plan(gen_random_uuid(),'revise','"+plan+"',"+str(version)+",null,null,'Approved inspection','Inspect equipment and document all observed findings.','standard',30,(now() at time zone 'America/Jamaica')::date,'paused','Approved isolated plan pause',true);"
    def pair(first_query,second_query,error=None,second_actor=actor):
        first=session('begin;'+manager+first_query+'select pg_sleep(2);commit;');wait('PgSleep',first)
        second=session('begin;'+identity(second_actor)+second_query+'commit;');wait('advisory',second)
        one=finish(first);two=finish(second,error);return one,two
    request=str(uuid.uuid4());a,b=pair(create(request),create(request))
    plan=json.loads(a.strip().splitlines()[-1])['id'];assert json.loads(b.strip().splitlines()[-1])['id']==plan
    assert sql('select count(*) from public.preventive_maintenance_plans;').stdout.strip()=='1'
    request=str(uuid.uuid4());a,b=pair(issue(plan,request),issue(plan,request))
    first_result=json.loads(a.strip().splitlines()[-1]);assert first_result==json.loads(b.strip().splitlines()[-1])
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+plan+"';").stdout.strip()=='1'
    assert sql('select count(*) from public.work_orders;').stdout.strip()=='1'
    assert sql("select version||':'||(next_due_on=(now() at time zone 'America/Jamaica')::date+30)::text from public.preventive_maintenance_plans where id='"+plan+"';").stdout.strip()=='2:true'
    competing=new_plan();pair(issue(competing,str(uuid.uuid4())),issue(competing,str(uuid.uuid4())),'Preventive plan changed; refresh')
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+competing+"';").stdout.strip()=='1'
    paused=new_plan();pair(pause(paused),issue(paused,str(uuid.uuid4())),'Preventive plan changed; refresh')
    assert sql("select state from public.preventive_maintenance_plans where id='"+paused+"';").stdout.strip()=='paused'
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+paused+"';").stdout.strip()=='0'
    issued=new_plan();pair(issue(issued,str(uuid.uuid4())),pause(issued),'Preventive plan changed; refresh')
    assert sql("select count(*) from public.preventive_maintenance_events where plan_id='"+issued+"';").stdout.strip()=='2'
    history_race=new_plan();pair(issue(history_race,str(uuid.uuid4())),pause(history_race,2),'Next due date must follow the latest issued or skipped occurrence')
    assert sql("select version from public.preventive_maintenance_plans where id='"+history_race+"';").stdout.strip()=='2'
    assert sql("select count(*) from public.preventive_maintenance_events where plan_id='"+history_race+"';").stdout.strip()=='2'
    skipped=new_plan();request=str(uuid.uuid4());a,b=pair(skip(skipped,request),skip(skipped,request))
    assert json.loads(a.strip().splitlines()[-1])==json.loads(b.strip().splitlines()[-1])
    assert sql("select count(*) from public.preventive_maintenance_skips where plan_id='"+skipped+"';").stdout.strip()=='1'
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+skipped+"';").stdout.strip()=='0'
    skip_first=new_plan();pair(skip(skip_first,str(uuid.uuid4())),issue(skip_first,str(uuid.uuid4())),'Preventive plan changed; refresh',admin)
    assert sql("select count(*) from public.preventive_maintenance_skips where plan_id='"+skip_first+"';").stdout.strip()=='1'
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+skip_first+"';").stdout.strip()=='0'
    issue_first=new_plan();pair(issue(issue_first,str(uuid.uuid4())),skip(issue_first,str(uuid.uuid4())),'Preventive plan changed; refresh',admin)
    assert sql("select count(*) from public.preventive_maintenance_skips where plan_id='"+issue_first+"';").stdout.strip()=='0'
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+issue_first+"';").stdout.strip()=='1'
    skip_competing=new_plan();pair(skip(skip_competing,str(uuid.uuid4())),skip(skip_competing,str(uuid.uuid4())),'Preventive plan changed; refresh',admin)
    assert sql("select count(*) from public.preventive_maintenance_skips where plan_id='"+skip_competing+"';").stdout.strip()=='1'
    skip_history=new_plan();pair(skip(skip_history,str(uuid.uuid4())),pause(skip_history,2),'Next due date must follow the latest issued or skipped occurrence')
    assert sql("select version from public.preventive_maintenance_plans where id='"+skip_history+"';").stdout.strip()=='2'
    assert sql('select count(*) from public.preventive_maintenance_skips s join public.preventive_maintenance_occurrences o using(plan_id,due_on);').stdout.strip()=='0'
    # Fill the existing shared work-intake limit through its real RPC, then race
    # two plans at the remaining slot. Preventive issuance cannot bypass that quota.
    while int(sql(f"select count(*) from public.work_order_changes where actor_user_id='{actor}' and action='create';").stdout.strip())<29:
        sql('begin;'+manager+"select public.manage_work_order(gen_random_uuid(),'create',null,0,'"+prop+"',null,'Approved work','Approved work description for isolated quota fixture.','standard','Approved isolated quota work');commit;")
    quota_first=new_plan();quota_second=new_plan()
    pair(issue(quota_first,str(uuid.uuid4())),issue(quota_second,str(uuid.uuid4())),'Daily work order limit reached')
    assert sql("select version from public.preventive_maintenance_plans where id='"+quota_second+"';").stdout.strip()=='1'
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+quota_second+"';").stdout.strip()=='0'
    denied=new_plan()
    demote="select public.manage_staff_membership(gen_random_uuid(),'preventive-manager@example.invalid','finance',(select membership_revision from public.staff_accounts where user_id='"+actor+"'),'Approved isolated demotion',true);"
    first=session('begin;'+identity(admin)+demote+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+manager+issue(denied,str(uuid.uuid4()))+'commit;');wait('advisory',second)
    finish(first);finish(second,'Management authority changed')
    assert sql("select count(*) from public.preventive_maintenance_occurrences where plan_id='"+denied+"';").stdout.strip()=='0'
    assert sql('select count(*) from public.work_orders;').stdout.strip()=='30'
    print('PASS: observed duplicate plan/issue retries, competing issuance, pause-first/issue-first revisions, issued-date history, shared work quota, duplicate/competing skips, skip-first/issue-first decisions and membership demotion races (local PostgreSQL '+version+'; minimal foundation fixture)')
finally:
    for process in processes:
        if process.poll() is None:process.terminate();process.wait(timeout=5)
    sql('drop database '+DB+' with (force);','postgres')
