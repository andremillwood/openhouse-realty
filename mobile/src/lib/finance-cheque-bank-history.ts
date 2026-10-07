import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {financeChequeHistory} from './finance-cheque-history';
import {validId} from './catalog';
const kinds={record_deposit:'deposit',confirm_clear:'clearance',record_return:'return'} as const;
const size=(v:unknown)=>{const s=typeof v==='string'?v:Number.isSafeInteger(v)?String(v):'';if(!/^[1-9]\d{0,6}$/.test(s)||Number(s)>8388608)throw Error('Invalid bank document size.');return Number(s);};
export async function financeChequeBankHistory(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid cheque required.');const access=await financeAccess(client,owner);if(!access)throw Error('Verified finance membership required.');const history=await financeChequeHistory(client,owner,id);
 const decisions=history.rows.filter(e=>e.action in kinds);
 const result=await client.from('cheque_bank_evidence_snapshots').select('event_id,cheque_id,evidence_id,organization_id,decision_version,kind,file_name,mime_type,sha256,actual_size,bank_reference,frozen_at').eq('cheque_id',id).eq('organization_id',access.organization).order('decision_version',{ascending:false}).limit(4);
 if(result.error||!Array.isArray(result.data)||result.data.length!==decisions.length)throw Error('Complete frozen bank evidence unavailable.');
 const rows=[];
 for(const r of result.data){const event=decisions.find(e=>e.id===r.event_id);if(!event||r.cheque_id!==id||r.organization_id!==access.organization||!validId(r.evidence_id)||r.decision_version!==event.version||r.kind!==kinds[event.action as keyof typeof kinds]||typeof r.file_name!=='string'||!r.file_name.trim()||r.file_name.length>160||/[\u0000-\u001f\u007f/\\]/.test(r.file_name)||!['application/pdf','image/jpeg','image/png'].includes(r.mime_type)||typeof r.sha256!=='string'||!/^[a-f0-9]{64}$/.test(r.sha256)||typeof r.bank_reference!=='string'||r.bank_reference.trim().length<3||r.bank_reference.length>120||/[\u0000-\u001f\u007f]/.test(r.bank_reference)||typeof r.frozen_at!=='string'||!Number.isFinite(Date.parse(r.frozen_at)))throw Error('Invalid frozen bank evidence.');const bytes=size(r.actual_size);
 const source=await client.from('cheque_bank_evidence').select('id,cheque_id,organization_id,state,kind,file_name,mime_type,sha256,actual_size,purged_at').eq('id',r.evidence_id).eq('cheque_id',id).eq('organization_id',access.organization).maybeSingle(),s=source.data;
 if(source.error||!s||s.id!==r.evidence_id||s.cheque_id!==id||s.organization_id!==access.organization||s.state!=='uploaded'||s.purged_at!==null||(['kind','file_name','mime_type','sha256'] as const).some(k=>s[k]!==r[k])||size(s.actual_size)!==bytes)throw Error('Frozen document source differs.');
 const audit=await client.from('cheque_custody_events').select('id,cheque_id,organization_id,payload').eq('id',event.id).eq('cheque_id',id).eq('organization_id',access.organization).maybeSingle(),a=audit.data;
 if(audit.error||!a||a.id!==event.id||a.cheque_id!==id||a.organization_id!==access.organization||a.payload?.evidence_id!==r.evidence_id||a.payload?.bank_reference!==r.bank_reference)throw Error('Bank decision source differs.');
 rows.push({event:event.id,evidence:r.evidence_id as string,version:event.version,kind:r.kind as 'deposit'|'clearance'|'return',name:r.file_name as string,mime:r.mime_type as string,size:bytes,bankReference:r.bank_reference as string,frozen:r.frozen_at as string});
 }
 if(new Set(rows.map(r=>r.event)).size!==rows.length||new Set(rows.map(r=>r.evidence)).size!==rows.length)throw Error('Duplicate frozen bank evidence.');
 const latest=await financeChequeHistory(client,owner,id),current=await financeAccess(client,owner);if(latest.cheque.state!==history.cheque.state||latest.cheque.version!==history.cheque.version||!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Cheque or finance authority changed.');return {cheque:history.cheque,rows};
}
