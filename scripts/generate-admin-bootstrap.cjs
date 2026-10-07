const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function bootstrapBlock({email,organizationId}){
 if(typeof email!=='string'||email.length>254||! /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()))throw Error('Provide the approved administrator email.');
 if(typeof organizationId!=='string'||!uuid.test(organizationId))throw Error('Provide the existing approved organization UUID.');
 const quotedEmail="'"+email.trim().toLowerCase().replaceAll("'","''")+"'",org="'"+organizationId.toLowerCase()+"'::uuid";
 return `declare
 target_id uuid;target_count integer;existing public.staff_accounts;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(${org}::text,119));
 if not exists(select 1 from public.organizations where id=${org}) then raise exception 'Approved organization does not exist';end if;
 select count(*) into target_count from auth.users where lower(email)=${quotedEmail};
 if target_count<>1 then raise exception 'Exactly one approved account is required';end if;
 select id into target_id from auth.users where lower(email)=${quotedEmail} and email_confirmed_at is not null for update;
 if target_id is null then raise exception 'The approved account must verify its email first';end if;
 select * into existing from public.staff_accounts where user_id=target_id for update;
 if existing.user_id is not null then
  if existing.organization_id is distinct from ${org} or existing.role<>'admin' then raise exception 'Existing membership cannot be reassigned or upgraded by bootstrap';end if;
  return;
 end if;
 if exists(select 1 from public.staff_accounts where organization_id=${org} and role='admin') then raise exception 'An administrator already exists; use the administrator membership workflow';end if;
 insert into public.staff_accounts(user_id,organization_id,role) values(target_id,${org},'admin');
end`;
}
function bootstrapSQL(input){return `-- Run only through the approved trusted database administration channel.\n-- This transaction assigns the approved verified first administrator only.\nbegin;\ndo $bootstrap$\n${bootstrapBlock(input)}\n$bootstrap$;\ncommit;\n`;}
if(require.main===module){
 const args=process.argv.slice(2);let input={};
 try{for(let index=0;index<args.length;index+=2){if(!['--email','--organization'].includes(args[index])||!args[index+1])throw Error('Usage: node scripts/generate-admin-bootstrap.cjs --email approved@example.com --organization UUID');const key=args[index]==='--email'?'email':'organizationId';if(input[key])throw Error('Duplicate option.');input[key]=args[index+1];}process.stdout.write(bootstrapSQL(input));}
 catch(error){process.stderr.write(error.message+'\n');process.exitCode=1;}
}
module.exports={bootstrapBlock,bootstrapSQL};
