"""Local Unix-socket fixture only; never accepts remote database credentials."""
import subprocess, pathlib, time, json
BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_finance_concurrency'
def sql(query, db=DB, check=True):
    r=subprocess.run(BASE+['-d',db],input=query,text=True,capture_output=True)
    if check and r.returncode: raise AssertionError(r.stderr)
    return r

def session(query):
    p=subprocess.Popen(BASE+['-d',DB],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    p.stdin.write(query);p.stdin.close();return p

def wait_for(predicate):
    for _ in range(100):
        if predicate(): return
        time.sleep(.05)
    raise AssertionError('Expected database session state was not observed')

def finish(p):
    out=p.stdout.read();err=p.stderr.read();code=p.wait(timeout=10)
    assert code==0,err
    return out

sql('create database '+DB+' template postgres;', 'postgres')
try:
    fixture=pathlib.Path('scripts/sql/verify-finance-posting.sql').read_text().split("select set_config('request.jwt.claim.sub'")[0]
    sql(fixture+'commit;')
    admin="select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000001',true);set local role authenticated;"
    accounts=sql("begin;"+admin+"select public.author_finance_account(gen_random_uuid(),'CON-A','Concurrent asset','asset','Approved fixture chart',true);select public.author_finance_account(gen_random_uuid(),'CON-L','Concurrent liability','liability','Approved fixture chart',true);commit;").stdout.strip().splitlines()[-2:]
    assert len(accounts)==2
    lines=json.dumps([dict(account_id=accounts[0],debit_minor=10001,credit_minor=0),dict(account_id=accounts[1],debit_minor=0,credit_minor=10001)])
    auth="select set_config('request.jwt.claim.sub','33445500-0000-4000-8000-000000000002',true);set local role authenticated;"
    post="select public.post_finance_journal('33445500-0000-4000-8000-000000000070','JMD','Concurrent fixture posting','Approved fixture posting',true,'"+lines+"'::jsonb);"
    first=session("begin;"+auth+post+"select pg_sleep(2);commit;")
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='PgSleep';").stdout.strip()=='1')
    second=session('begin;'+auth+post+'commit;')
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='advisory';").stdout.strip()=='1')
    finish(first);finish(second)
    assert sql('select count(*) from public.finance_journals;').stdout.strip()=='1'
    assert sql('select count(*) from public.finance_journal_lines;').stdout.strip()=='2'
    journal=sql('select id from public.finance_journals;').stdout.strip()
    late="insert into public.finance_journal_lines(journal_id,organization_id,line_number,account_id,debit_minor,credit_minor) values('"+journal+"','33445500-0000-4000-8000-000000000010',3,'"+accounts[0]+"',1,0),('"+journal+"','33445500-0000-4000-8000-000000000010',4,'"+accounts[1]+"',0,1);"
    r=sql(late,check=False);assert r.returncode and 'Journal/account organization binding required' in r.stderr
    reverse="select public.reverse_finance_journal('33445500-0000-4000-8000-000000000071','"+journal+"','Approved concurrent reversal',true);"
    first=session('begin;'+auth+reverse+'select pg_sleep(2);commit;')
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='PgSleep';").stdout.strip()=='1')
    second=session('begin;'+auth+reverse+'commit;')
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='advisory';").stdout.strip()=='1')
    finish(first);finish(second)
    assert sql('select count(*) from public.finance_journal_reversals;').stdout.strip()=='1'
    assert sql('select count(*) from public.finance_journals;').stdout.strip()=='2'
    assert sql('select count(*) from public.finance_journal_lines;').stdout.strip()=='4'
    # Different request IDs cannot independently reverse the same original.
    original=sql('begin;'+auth+post.replace('000000000070','000000000072')+'commit;').stdout.strip().splitlines()[-1]
    competing="select public.reverse_finance_journal('33445500-0000-4000-8000-000000000073','"+original+"','Approved competing reversal',true);"
    first=session('begin;'+auth+competing+'select pg_sleep(2);commit;')
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='PgSleep';").stdout.strip()=='1')
    second=session('begin;'+auth+competing.replace('000000000073','000000000074')+'commit;')
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='advisory';").stdout.strip()=='1')
    finish(first);out=second.stdout.read();err=second.stderr.read();assert second.wait(timeout=10)!=0 and 'already reversed' in err
    assert sql('select count(*) from public.finance_journal_reversals;').stdout.strip()=='2'
    # Posting wins the resource lock; waiting parent/organization edits must see history.
    prop='33445500-0000-4000-8000-000000000080';other='33445500-0000-4000-8000-000000000081';unit='33445500-0000-4000-8000-000000000082'
    sql("insert into public.properties(id,organization_id,name) values('"+prop+"','33445500-0000-4000-8000-000000000010','Concurrent property'),('"+other+"','33445500-0000-4000-8000-000000000010','Other property');insert into public.units(id,property_id,unit_label) values('"+unit+"','"+prop+"','A');")
    dimension_lines=json.loads(lines);dimension_lines[0].update(property_id=prop,unit_id=unit)
    dimension_post=post.replace('000000000070','000000000075').replace(lines,json.dumps(dimension_lines))
    first=session('begin;'+auth+dimension_post+'select pg_sleep(2);commit;')
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='PgSleep';").stdout.strip()=='1')
    property_edit=session("update public.properties set organization_id='33445500-0000-4000-8000-000000000011' where id='"+prop+"';")
    unit_edit=session("update public.units set property_id='"+other+"' where id='"+unit+"';")
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event_type='Lock';").stdout.strip()=='2')
    finish(first)
    for process,expected in [(property_edit,'Journal history protects property organization'),(unit_edit,'Journal history protects unit property')]:
        out=process.stdout.read();err=process.stderr.read();assert process.wait(timeout=10)!=0 and expected in err,err
    assert sql("select property_id from public.units where id='"+unit+"';").stdout.strip()==prop
    # Organization change wins first: the waiting posting must reject the stale dimension.
    fresh_property='33445500-0000-4000-8000-000000000083'
    sql("insert into public.properties(id,organization_id,name) values('"+fresh_property+"','33445500-0000-4000-8000-000000000010','Move-first property');")
    before=sql('select count(*) from public.finance_journals;').stdout.strip()
    first=session("begin;update public.properties set organization_id='33445500-0000-4000-8000-000000000011' where id='"+fresh_property+"';select pg_sleep(2);commit;")
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='PgSleep';").stdout.strip()=='1')
    changed_lines=json.loads(lines);changed_lines[0]['property_id']=fresh_property
    second=session('begin;'+auth+post.replace('000000000070','000000000076').replace(lines,json.dumps(changed_lines))+'commit;')
    wait_for(lambda: sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event_type='Lock';").stdout.strip()=='1')
    finish(first);out=second.stdout.read();err=second.stderr.read();assert second.wait(timeout=10)!=0 and 'Organization property required' in err,err
    assert sql('select count(*) from public.finance_journals;').stdout.strip()==before
    print('PASS: observed posting/reversal contention, retry deduplication, competing reversal denial, post-commit append rejection and property/unit update races (local PostgreSQL 14)')
finally:
    sql('drop database '+DB+' with (force);','postgres')
