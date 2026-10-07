export const preventiveNoticeKinds=['plan_created','plan_revised','work_issued','date_skipped'] as const;
type Kind=typeof preventiveNoticeKinds[number];
const copy:Record<Kind,{subject:string;message:string}>={
 plan_created:{subject:'A preventive maintenance plan has been approved',message:'Review the approved scope and schedule in the management workspace. A plan does not assign a contractor or authorize entry.'},
 plan_revised:{subject:'A preventive maintenance plan has changed',message:'Review the approved schedule and decision history before arranging work.'},
 work_issued:{subject:'Preventive maintenance work is ready for review',message:'One scheduled occurrence has generated a work order. Review its scope and current status before assigning work. Issuance does not authorize entry or mark maintenance complete.'},
 date_skipped:{subject:'A preventive maintenance date was recorded as skipped',message:'Review the approved exception and scheduled date in the decision history. Skipping creates no work order and does not record maintenance as completed.'}
};
/** Email excludes addresses, unit labels, scope, exception reasons and access instructions. */
export function preventiveNotice(value:unknown,plan:unknown,work:unknown=null){
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 if(typeof value!=='string'||!preventiveNoticeKinds.includes(value as Kind))throw new Error('Unsupported preventive notice.');
 if(typeof plan!=='string'||!uuid.test(plan))throw new Error('Valid preventive plan reference required.');
 if(value==='work_issued'?(typeof work!=='string'||!uuid.test(work)):work!==null)throw new Error('Matching issued-work reference required.');
 const kind=value as Kind,notice=copy[kind];
 return {kind,audience:'management' as const,subject:notice.subject,text:`${notice.message}\n\nPlan reference: ${plan}\n\nSign in to review: `,actionPath:kind==='work_issued'?`/staff/work-orders/${work}`:`/staff/preventive-plans/${plan}/history`};
}
