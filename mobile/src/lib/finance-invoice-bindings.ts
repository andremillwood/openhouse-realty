import type {SupabaseClient} from '@supabase/supabase-js';
import {invoiceAccess} from './invoice-access';
import {validId} from './catalog';
export async function financeInvoiceBindings(client:SupabaseClient,owner:string,kind:'property'|'work',term:string,property:string|null){
 if(!['property','work'].includes(kind)||typeof term!=='string'||term.length>120||kind==='work'&&!validId(property)||kind==='property'&&property!==null)throw Error('Check invoice binding search.');
 const access=await invoiceAccess(client,owner);if(!access)throw Error('Approved finance membership required.');
 const response=await client.rpc('search_invoice_bindings',{p_kind:kind,p_term:term.trim(),p_property_id:property}),r=response.data;
 if(response.error||!r||!Array.isArray(r.items)||r.items.length>25||typeof r.more!=='boolean'||r.more&&r.items.length!==25)throw Error('Invoice bindings unavailable.');
 const items:{id:string;label:string}[]=r.items.map((i:Record<string,unknown>)=>{if(!validId(i.id)||typeof i.label!=='string'||!i.label.trim()||i.label.length>500)throw Error('Invalid invoice binding.');return {id:i.id,label:i.label};});
 if(new Set(items.map(i=>i.id)).size!==items.length)throw Error('Duplicate invoice bindings.');
 const current=await invoiceAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Invoice membership changed.');
 return {organization:access.organization,revision:access.revision,role:access.role,items,more:r.more as boolean,kind,property,term:term.trim()};
}
