import type {SupabaseClient} from '@supabase/supabase-js';
import {statementQuery} from '../../../lib/finance/statement-query';
import {formatJmdMinor} from '../../../lib/finance/money';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
export {statementQuery,formatJmdMinor};
const money=(v:unknown):v is string=>typeof v==='string'&&/^-?(0|[1-9]\d{0,99})$/.test(v)&&v!=='-0';
const count=(v:unknown):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0;
export async function financeStatement(client:SupabaseClient,owner:string,accountId:string,input:Record<string,string|string[]|undefined>,today:string){
 if(!validId(accountId))throw Error('Valid account reference required.');const query=statementQuery(input,today);
 const access=await financeAccess(client,owner);if(!access)throw Error('Approved finance membership required.');
 const response=await client.rpc('finance_account_statement',{p_account_id:accountId,p_from:query.from,p_to:query.to,p_page:query.page});const r=response.data;
 if(response.error||!r||r.account?.id!==accountId||typeof r.account.code!=='string'||!(/^[A-Z0-9][A-Z0-9._-]{0,39}$/).test(r.account.code)||typeof r.account.name!=='string'||r.account.name.trim().length<2||r.account.name.length>120||!['asset','liability','equity','income','expense'].includes(r.account.class)||r.from!==query.from||r.to!==query.to||r.currency!=='JMD'||!count(r.total)||!count(r.page)||!count(r.pages)||r.pages!==Math.max(1,Math.ceil(r.total/25))||r.page!==Math.min(query.page,r.pages)||!Array.isArray(r.entries)||r.entries.length!==Math.min(25,Math.max(0,r.total-(r.page-1)*25))||typeof r.as_of!=='string'||!Number.isFinite(Date.parse(r.as_of))||![r.opening_minor,r.debit_minor,r.credit_minor,r.closing_minor].every(money)||BigInt(r.debit_minor)<0n||BigInt(r.credit_minor)<0n||BigInt(r.opening_minor)+BigInt(r.debit_minor)-BigInt(r.credit_minor)!==BigInt(r.closing_minor))throw Error('Account statement unavailable.');
 const start=Date.parse(query.from+'T05:00:00Z'),end=Date.parse(query.to+'T05:00:00Z')+86400000;
 const entries=r.entries.map((e:Record<string,unknown>)=>{if(!validId(e.line_id)||!validId(e.journal_id)||typeof e.memo!=='string'||!e.memo.trim()||e.memo.length>1000||typeof e.posted_at!=='string'||!Number.isFinite(Date.parse(e.posted_at))||Date.parse(e.posted_at)<start||Date.parse(e.posted_at)>=end||!money(e.debit_minor)||!money(e.credit_minor)||!money(e.balance_minor)||BigInt(e.debit_minor)<0n||BigInt(e.credit_minor)<0n||BigInt(e.debit_minor)>99999999999999n||BigInt(e.credit_minor)>99999999999999n||(BigInt(e.debit_minor)>0n)===(BigInt(e.credit_minor)>0n))throw Error('Invalid account statement line.');return {id:e.line_id,journal:e.journal_id,memo:e.memo,posted:e.posted_at,debit:e.debit_minor,credit:e.credit_minor,balance:e.balance_minor};});
 if(new Set(entries.map((e:{id:string})=>e.id)).size!==entries.length)throw Error('Duplicate statement lines.');
 for(let i=0;i<entries.length;i++){const e=entries[i];if(i&&Date.parse(e.posted)<Date.parse(entries[i-1].posted))throw Error('Invalid statement order.');if((i||r.page===1)&&BigInt(e.balance)!==BigInt(i?entries[i-1].balance:r.opening_minor)+BigInt(e.debit)-BigInt(e.credit))throw Error('Invalid running balance.');}
 if(entries.length&&r.page===r.pages&&BigInt(entries.at(-1)!.balance)!==BigInt(r.closing_minor))throw Error('Invalid closing balance.');
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Finance membership changed.');
 return {account:{id:accountId,code:r.account.code as string,name:r.account.name as string,classification:r.account.class as string},from:query.from,to:query.to,page:r.page as number,pages:r.pages as number,total:r.total as number,asOf:r.as_of as string,opening:r.opening_minor as string,debit:r.debit_minor as string,credit:r.credit_minor as string,closing:r.closing_minor as string,entries};
}
