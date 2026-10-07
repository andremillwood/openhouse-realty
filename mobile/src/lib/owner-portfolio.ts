import type {SupabaseClient} from '@supabase/supabase-js';
import {statementQuery} from '../../../lib/finance/statement-query';
import {formatJmdMinor} from '../../../lib/finance/money';
import {validId} from './catalog';
export {formatJmdMinor,statementQuery};
async function verified(client:SupabaseClient,owner:string){const r=await client.auth.getUser();if(r.error||r.data.user?.id!==owner||!r.data.user.email_confirmed_at||r.data.user.is_anonymous)throw new Error('Verified owner account required.');}
export async function ownerPortfolio(client:SupabaseClient,owner:string,input:Record<string,string|string[]|undefined>,today:string){
 const query=statementQuery(input,today);await verified(client,owner);const response=await client.rpc('owner_portfolio_summary',{p_from:query.from,p_to:query.to,p_page:query.page});const r=response.data;
 const count=(v:unknown):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0;
 const money=(v:unknown):v is string=>typeof v==='string'&&/^-?(0|[1-9]\d{0,99})$/.test(v);
 if(response.error||!r||r.from!==query.from||r.to!==query.to||r.currency!=='JMD'||r.occupancy_available!==false||!count(r.total)||!count(r.page)||!count(r.pages)||r.pages!==Math.max(1,Math.ceil(r.total/25))||r.page!==Math.min(query.page,r.pages)||!Array.isArray(r.properties)||r.properties.length>25||typeof r.as_of!=='string'||!Number.isFinite(Date.parse(r.as_of)))throw new Error('Approved portfolio unavailable.');
 const properties:{id:string;name:string;area:string|null;units:number;openWork:number;income:string;expenses:string;net:string}[]=r.properties.map((p:Record<string,unknown>)=>{if(!validId(p.id)||typeof p.name!=='string'||!p.name.trim()||p.name.length>500||p.area!==null&&(typeof p.area!=='string'||p.area.length>500)||!count(p.managed_units)||!count(p.current_open_work_orders)||!money(p.posted_income_minor)||!money(p.posted_expense_minor)||!money(p.posted_net_minor)||BigInt(p.posted_income_minor)-BigInt(p.posted_expense_minor)!==BigInt(p.posted_net_minor)||p.occupancy!==null)throw new Error('Invalid portfolio property.');return {id:p.id as string,name:p.name,area:p.area as string|null,units:p.managed_units,openWork:p.current_open_work_orders,income:p.posted_income_minor,expenses:p.posted_expense_minor,net:p.posted_net_minor};});
 if(new Set(properties.map((p:{id:string})=>p.id)).size!==properties.length||properties.length>r.total)throw new Error('Invalid portfolio properties.');await verified(client,owner);return {from:query.from,to:query.to,page:r.page as number,pages:r.pages as number,total:r.total as number,asOf:r.as_of as string,properties};
}
