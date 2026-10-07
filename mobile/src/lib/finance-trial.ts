import type {SupabaseClient} from '@supabase/supabase-js';
import {statementQuery} from '../../../lib/finance/statement-query';
import {formatJmdMinor} from '../../../lib/finance/money';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
export {statementQuery,formatJmdMinor};
const money=(v:unknown):v is string=>typeof v==='string'&&/^(0|[1-9]\d{0,99})$/.test(v);
const count=(v:unknown):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0;
export async function financeTrial(client:SupabaseClient,owner:string,input:Record<string,string|string[]|undefined>,today:string){
 const through=input.through===undefined?today:input.through,query=statementQuery({from:through,to:through,page:input.page},today);
 const access=await financeAccess(client,owner);if(!access)throw Error('Approved finance membership required.');
 const response=await client.rpc('finance_trial_balance',{p_through:query.to,p_page:query.page}),r=response.data;
 if(response.error||!r||r.through!==query.to||r.currency!=='JMD'||!money(r.debit_minor)||!money(r.credit_minor)||typeof r.balanced!=='boolean'||r.balanced!==(BigInt(r.debit_minor)===BigInt(r.credit_minor))||!count(r.total)||!count(r.page)||!count(r.pages)||r.pages!==Math.max(1,Math.ceil(r.total/25))||r.page!==Math.min(query.page,r.pages)||!Array.isArray(r.accounts)||r.accounts.length!==Math.min(25,Math.max(0,r.total-(r.page-1)*25))||typeof r.as_of!=='string'||!Number.isFinite(Date.parse(r.as_of)))throw Error('Trial balance unavailable.');
 const accounts:{id:string;code:string;name:string;classification:string;debit:string;credit:string}[]=r.accounts.map((a:Record<string,unknown>)=>{if(!validId(a.id)||typeof a.code!=='string'||!(/^[A-Z0-9][A-Z0-9._-]{0,39}$/).test(a.code)||typeof a.name!=='string'||a.name.trim().length<2||a.name.length>120||typeof a.class!=='string'||!['asset','liability','equity','income','expense'].includes(a.class)||!money(a.debit_minor)||!money(a.credit_minor)||(BigInt(a.debit_minor)>0n&&BigInt(a.credit_minor)>0n))throw Error('Invalid trial balance account.');return {id:a.id,code:a.code,name:a.name,classification:a.class,debit:a.debit_minor,credit:a.credit_minor};});
 if(new Set(accounts.map(a=>a.id)).size!==accounts.length||new Set(accounts.map(a=>a.code)).size!==accounts.length)throw Error('Duplicate trial accounts.');
 const debit=accounts.reduce((sum,a)=>sum+BigInt(a.debit),0n),credit=accounts.reduce((sum,a)=>sum+BigInt(a.credit),0n);
 if(debit>BigInt(r.debit_minor)||credit>BigInt(r.credit_minor)||(r.pages===1&&(debit!==BigInt(r.debit_minor)||credit!==BigInt(r.credit_minor))))throw Error('Invalid trial totals.');
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Finance membership changed.');
 return {through:query.to,debit:r.debit_minor as string,credit:r.credit_minor as string,balanced:r.balanced as boolean,total:r.total as number,page:r.page as number,pages:r.pages as number,asOf:r.as_of as string,accounts};
}
