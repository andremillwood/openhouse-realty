export function workOrderInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid work order.');const input=value as Record<string,unknown>;
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const id=(key:string,optional=false)=>{const v=input[key];if(optional&&v===null)return null;if(typeof v!=='string'||!uuid.test(v))throw new Error('Check the property, unit or work order reference.');return v;};
 const text=(key:string,min:number,max:number)=>{const v=input[key];if(typeof v!=='string'||v.trim().length<min||v.length>max)throw new Error(`Check ${key}.`);return v.trim();};
 if(typeof input.action!=='string'||!['create','triage','cancel'].includes(input.action))throw new Error('Choose an available work order action.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647)throw new Error('Refresh the work order revision.');
 const priority=()=>{if(typeof input.priority!=='string'||!['low','standard','high','urgent'].includes(input.priority))throw new Error('Choose a priority.');return input.priority;};
 const common={p_request_id:id('request_id')!,p_action:input.action,p_expected_version:input.version,p_reason:text('reason',5,500)};
 if(input.action==='create'){if(input.version!==0||input.work_order_id!==null)throw new Error('New work order revision required.');return {...common,p_work_order_id:null,p_property_id:id('property_id'),p_unit_id:id('unit_id',true),p_title:text('title',3,160),p_description:text('description',20,5000),p_priority:priority()};}
 if(input.version<1)throw new Error('Current work order revision required.');
 return {...common,p_work_order_id:id('work_order_id'),p_property_id:null,p_unit_id:null,p_title:null,p_description:null,p_priority:input.action==='triage'?priority():null};
}
