"""Isolated Unix-socket fixture only. Storage metadata is simulated; no cloud credentials."""
import subprocess, pathlib, time, json

BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_staff_invitation_concurrency'
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


assert sql('show listen_addresses;','postgres').stdout.strip()==''
version=sql('show server_version;','postgres').stdout.strip()
sql('create database '+DB+' template postgres;','postgres')
try:
    # Template supplies minimal Auth/finance schemas. All changes stay in this clone.
    # Notification delivery is verified remotely; this fixture exercises admission locks.
    membership=pathlib.Path('supabase/migrations/20261007054101_audited_staff_membership.sql').read_text().replace('create function private.verified_staff_admin_organization()', 'create or replace function private.verified_staff_admin_organization()')
    sql('drop policy if exists "verified administrators read organization memberships" on public.staff_accounts;')
    sql(membership)
    sql('grant select on public.staff_accounts to authenticated;')
    sql(pathlib.Path('supabase/migrations/20261007094059_approved_staff_invitations.sql').read_text())
    fixture=pathlib.Path('scripts/sql/verify-staff-invitations.sql').read_text().split("select set_config('request.jwt.claim.sub'")[0]
    sql(fixture+'commit;')
    def identity(n):return "select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-"+str(n).zfill(12)+"',true);set local role authenticated;"
    def create(email,request,role='finance'):
        return "select public.manage_staff_invitation('44556600-0000-4000-8000-"+str(request).zfill(12)+"','create',null,0,'"+email+"','"+role+"','Approved concurrency fixture',true);"
    def invite(email,request,admin=1,role='finance'):
        return json.loads(sql('begin;'+identity(admin)+create(email,request,role)+'commit;').stdout.strip().splitlines()[-1])['id']
    def accept(inv,request):return "select public.manage_staff_invitation('44556600-0000-4000-8000-"+str(request).zfill(12)+"','accept','"+inv+"',1,null,null,'Accept approved concurrency role',true);"
    first=session('begin;'+identity(1)+create('other-owner@example.invalid',70)+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+identity(1)+create('other-owner@example.invalid',70)+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.staff_invitations where invite_email='other-owner@example.invalid';").stdout.strip()=='1'
    inv=sql("select id from public.staff_invitations where invite_email='other-owner@example.invalid';").stdout.strip()
    first=session('begin;'+identity(4)+accept(inv,71)+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+identity(4)+accept(inv,71)+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.staff_membership_changes where invitation_id='"+inv+"';").stdout.strip()=='1'
    assert sql("select count(*) from public.staff_invitation_events where invitation_id='"+inv+"';").stdout.strip()=='2'
    own=invite('staff-decline@example.invalid',72);foreign=invite('staff-decline@example.invalid',73,6,'manager')
    first=session('begin;'+identity(7)+accept(own,74)+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+identity(7)+accept(foreign,75)+'commit;');wait('transactionid',second)
    finish(first);finish(second,'Existing staff access must be managed')
    assert sql("select organization_id||':'||role from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000007';").stdout.strip()=='44556600-0000-4000-8000-000000000010:finance'
    assert sql("select state from public.staff_invitations where id='"+foreign+"';").stdout.strip()=='pending'
    assert sql("select count(*) from public.staff_membership_changes where target_user_id='44556600-0000-4000-8000-000000000007';").stdout.strip()=='1'
    changing=invite('staff-expired@example.invalid',76)
    first=session("begin;update auth.users set email='changed-invitation@example.invalid' where id='44556600-0000-4000-8000-000000000008';select pg_sleep(2);commit;");wait('PgSleep',first)
    second=session('begin;'+identity(8)+accept(changing,77)+'commit;');wait('transactionid',second)
    finish(first);finish(second,'Verified invited identity required')
    assert sql("select count(*) from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000008';").stdout.strip()=='0'
    sql("update auth.users set email='staff-expired@example.invalid' where id='44556600-0000-4000-8000-000000000008';")
    first=session('begin;'+identity(14)+"select public.manage_staff_membership(gen_random_uuid(),'staff-expired@example.invalid','manager',null,'Approved direct membership fixture',true);select pg_sleep(2);commit;");wait('PgSleep',first)
    second=session('begin;'+identity(8)+accept(changing,78)+'commit;');wait('advisory',second)
    finish(first);finish(second,'Existing staff access must be managed')
    assert sql("select role from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000008';").stdout.strip()=='manager'
    stale=invite('staff-revoked@example.invalid',79)
    first=session('begin;'+identity(14)+"select public.manage_staff_membership(gen_random_uuid(),'owner-admin@example.invalid',null,(select membership_revision from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000001'),'Withdraw inviting administrator fixture',true);select pg_sleep(2);commit;");wait('PgSleep',first)
    second=session('begin;'+identity(9)+accept(stale,80)+'commit;');wait('advisory',second)
    finish(first);finish(second,'Inviting administrator approval is no longer current')
    assert sql("select count(*) from public.staff_accounts where user_id='44556600-0000-4000-8000-000000000009';").stdout.strip()=='0'
    print('PASS: observed create/accept retry contention, single cross-organization membership, changed Auth email, prior membership grant and revoked inviter races (local PostgreSQL '+version+'; notification transport not simulated)')
finally:
    for process in processes:
        if process.poll() is None:process.terminate();process.wait(timeout=5)
    sql('drop database '+DB+' with (force);','postgres')
