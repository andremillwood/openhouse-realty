import {uuidPattern} from '@/lib/enquiries/validation';
export function managedInventoryInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid inventory request.');const input=value as Record<string,unknown>;
 if(typeof input.request_id!=='string'||!uuidPattern.test(input.request_id)||typeof input.action!=='string'||!['property_create','property_update','unit_create','unit_update','listing_link'].includes(input.action)||typeof input.revision!=='number'||!Number.isInteger(input.revision)||input.revision<0||input.revision>=2147483647)throw new Error('Invalid action, request or revision.');
 const target=input.target_id??null;if(target!==null&&(typeof target!=='string'||!uuidPattern.test(target)))throw new Error('Invalid target reference.');if(input.action==='property_create'?(target!==null||input.revision!==0):target===null||input.revision<1)throw new Error('Choose the record and its current revision.');
 const text=(key:string,min:number,max:number)=>{const raw=input[key];if(typeof raw!=='string'||raw.trim().length<min||raw.length>max)throw new Error(`Check ${key.replaceAll('_',' ')}.`);return raw.trim();};
 const number=(key:string,min:number,max:number,step=1,nullable=false)=>{const raw=input[key];if(nullable&&raw===null)return null;if(typeof raw!=='number'||!Number.isFinite(raw)||raw<min||raw>max||raw/step!==Math.round(raw/step))throw new Error(`Check ${key.replaceAll('_',' ')}.`);return raw;};
 let payload:Record<string,unknown>;
 if(input.action.startsWith('property_'))payload={name:text('name',2,160),area:text('area',2,120),address_text:text('address_text',5,500)};
 else if(input.action.startsWith('unit_'))payload={unit_label:text('unit_label',1,80),bedrooms:number('bedrooms',0,50,0.5),bathrooms:number('bathrooms',0,50,0.5),parking_spaces:number('parking_spaces',0,100),floor:number('floor',-10,200,1,true),size_sq_ft:number('size_sq_ft',1,1000000,1,true)};
 else{if(!('unit_id' in input))throw new Error('Choose a unit or explicitly remove its link.');const unit=input.unit_id;if(unit!==null&&(typeof unit!=='string'||!uuidPattern.test(unit)))throw new Error('Choose a managed unit.');payload={unit_id:unit};}
 return {p_request_id:input.request_id,p_action:input.action,p_target_id:target,p_expected_revision:input.revision,p_payload:payload};
}
