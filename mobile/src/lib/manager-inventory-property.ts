import type {SupabaseClient} from '@supabase/supabase-js';
import {managerAccess} from './manager-access';
import {validId} from './catalog';
function text(v:unknown,min:number,max:number){return typeof v==='string'&&v.trim().length>=min&&v.length<=max;}
function revision(v:unknown){return typeof v==='number'&&Number.isInteger(v)&&v>=1&&v<2147483647;}
export async function managerInventoryProperty(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Property reference required.');const access=await managerAccess(client,owner);if(!access)throw Error('Approved management membership required.');
 const response=await client.from('properties').select('id,organization_id,name,area,address_text,management_revision').eq('id',id).eq('organization_id',access.organization).maybeSingle();const r=response.data;if(response.error)throw Error('Private property unavailable.');
 if(r&&(r.id!==id||r.organization_id!==access.organization||!text(r.name,2,160)||!text(r.area,2,120)||!text(r.address_text,5,500)||!revision(r.management_revision)))throw Error('Invalid private property.');
 const current=await managerAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Management access changed.');
 return r?{id:r.id as string,name:r.name as string,area:r.area as string,address:r.address_text as string,version:r.management_revision as number}:null;
}
export async function managerInventoryUnits(client:SupabaseClient,owner:string,property:string,pageInput:number){
 const access=await managerAccess(client,owner),parent=await managerInventoryProperty(client,owner,property);if(!access||!parent)throw Error('Private property access required.');
 const query=(head=false)=>client.from('units').select('id,property_id,unit_label,bedrooms,bathrooms,parking_spaces,floor,size_sq_ft,management_revision',{head,count:'exact'}).eq('property_id',property);
 const count=await query(true);if(count.error||!Number.isSafeInteger(count.count)||count.count!<0)throw Error('Unit count unavailable.');const total=count.count!,pages=Math.max(1,Math.ceil(total/25)),page=Math.min(Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1),pages);
 const response=total?await query().order('unit_label',{ascending:true}).order('id',{ascending:true}).range((page-1)*25,page*25-1):{data:[],error:null};if(response.error||!Array.isArray(response.data)||response.data.length>25)throw Error('Units unavailable.');
 const number=(v:unknown,min:number,max:number,step=1)=>typeof v==='number'&&Number.isFinite(v)&&v>=min&&v<=max&&v/step===Math.round(v/step);
 const rows=response.data.map(r=>{if(!validId(r.id)||r.property_id!==property||!text(r.unit_label,1,80)||!number(r.bedrooms,0,50,0.5)||!number(r.bathrooms,0,50,0.5)||!number(r.parking_spaces,0,100)||r.floor!==null&&!number(r.floor,-10,200)||r.size_sq_ft!==null&&!number(r.size_sq_ft,1,1000000)||!revision(r.management_revision))throw Error('Invalid unit record.');return {id:r.id as string,label:r.unit_label as string,bedrooms:r.bedrooms as number,bathrooms:r.bathrooms as number,parking:r.parking_spaces as number,floor:r.floor as number|null,size:r.size_sq_ft as number|null,version:r.management_revision as number};});if(new Set(rows.map(r=>r.id)).size!==rows.length)throw Error('Duplicate unit records.');
 const reservations=rows.length?await client.from('rental_unit_reservations').select('unit_id,state,organization_id').eq('organization_id',access.organization).in('unit_id',rows.map(r=>r.id)).in('state',['held','converted']):{data:[],error:null};if(reservations.error||!Array.isArray(reservations.data)||reservations.data.some(r=>r.organization_id!==access.organization||!rows.some(u=>u.id===r.unit_id)||!['held','converted'].includes(r.state)))throw Error('Unit tenancy protections unavailable.');
 const current=await managerAccess(client,owner),latest=await managerInventoryProperty(client,owner,property);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision||!latest||latest.version!==parent.version)throw Error('Property or access changed.');
 return {total,pages,page,property:parent,rows:rows.map(r=>({...r,protected:reservations.data.some(v=>v.unit_id===r.id)}))};
}
