export function invoiceActions(invoice:{state:string;submitted_by:string;reviewed_by:string|null},userId:string,role:string):('review'|'approve'|'reject')[] {
 if(!['admin','finance'].includes(role)||invoice.submitted_by===userId)return [];
 if(invoice.state==='submitted')return ['review','reject'];
 if(invoice.state==='under_review')return invoice.reviewed_by===userId?['reject']:['approve','reject'];
 return [];
}
