export function preventivePlanInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid preventive plan request.');
 const input=value as Record<string,unknown>,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const id=(key:string,optional=false)=>{const v=input[key];if(optional&&v===null)return null;if(typeof v!=='string'||!uuid.test(v))throw new Error('Check the plan, property or unit reference.');return v;};
 const text=(key:string,min:number,max:number)=>{const v=input[key];if(typeof v!=='string'||v.trim().length<min||v.length>max)throw new Error(`Check ${key.replaceAll('_',' ')}.`);return v.trim();};
 if(typeof input.action!=='string'||!['create','revise','issue','skip'].includes(input.action))throw new Error('Choose an available preventive plan action.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647)throw new Error('Refresh the preventive plan revision.');
 if(input.approved!==true)throw new Error('Explicit management approval is required.');
 const common={p_request_id:id('request_id')!,p_action:input.action,p_expected_version:input.version,p_reason:text('reason',5,500),p_approved:true};
 if(input.action==='create'&&(input.plan_id!==null||input.version!==0))throw new Error('Start a new plan with revision zero.');
 if(input.action!=='create'&&input.version<1)throw new Error('Current preventive plan revision required.');
 const reference={p_plan_id:input.action==='create'?null:id('plan_id'),p_property_id:input.action==='create'?id('property_id'):null,p_unit_id:input.action==='create'?id('unit_id',true):null};
 if(input.action==='issue'||input.action==='skip')return {...common,...reference,p_title:null,p_description:null,p_priority:null,p_interval_days:null,p_next_due_on:null,p_state:null};
 if(typeof input.priority!=='string'||!['low','standard','high','urgent'].includes(input.priority))throw new Error('Choose a priority.');
 if(typeof input.interval_days!=='number'||!Number.isInteger(input.interval_days)||input.interval_days<1||input.interval_days>366)throw new Error('Choose a fixed interval from 1 to 366 days.');
 if(typeof input.state!=='string'||!['active','paused','retired'].includes(input.state)||input.action==='create'&&input.state==='retired')throw new Error('Choose an available plan state.');
 const date=input.next_due_on;if(typeof date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(date)||date<'2000-01-01'||date>'2200-01-01')throw new Error('Choose a valid next due date.');
 const parsed=new Date(date+'T00:00:00Z');if(!Number.isFinite(parsed.getTime())||parsed.toISOString().slice(0,10)!==date)throw new Error('Choose a real calendar due date.');
 return {...common,...reference,p_title:text('title',3,160),p_description:text('description',20,5000),p_priority:input.priority,p_interval_days:input.interval_days,p_next_due_on:date,p_state:input.state};
}
