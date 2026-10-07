export const invitationActions=['create','accept','decline','revoke'] as const;
export const invitedStaffRoles=['admin','realtor','manager','finance'] as const;
/** Authority, invited identity and the accepted role are derived by the database. */
export function invitationInput(value:unknown){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Invalid staff invitation request.');
 const input=value as Record<string,unknown>,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 if(typeof input.request_id!=='string'||!uuid.test(input.request_id)||typeof input.action!=='string'||!invitationActions.includes(input.action as typeof invitationActions[number]))throw new Error('Choose an available invitation action.');
 if(typeof input.version!=='number'||!Number.isInteger(input.version)||input.version<0||input.version>=2147483647)throw new Error('Refresh the invitation revision.');
 if(typeof input.reason!=='string'||input.reason.trim().length<5||input.reason.length>500||input.approved!==true)throw new Error('Record a reason and explicit invitation approval or consent.');
 let email:string|null=null,role:string|null=null,id:string|null=null;
 if(input.action==='create'){
  if(input.invitation_id!=null||input.version!==0)throw new Error('Create a new invitation without an existing reference.');
  if(typeof input.email!=='string'||input.email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim()))throw new Error('Provide the approved recipient email.');
  if(typeof input.role!=='string'||!invitedStaffRoles.includes(input.role as typeof invitedStaffRoles[number]))throw new Error('Choose an approved staff role.');
  email=input.email.trim().toLowerCase();role=input.role;
 }else{
  if(typeof input.invitation_id!=='string'||!uuid.test(input.invitation_id)||input.version<1||input.email!=null||input.role!=null)throw new Error('Use the current invitation and its fixed approved role.');id=input.invitation_id;
 }
 return {p_request_id:input.request_id,p_action:input.action as typeof invitationActions[number],p_invitation_id:id,p_expected_version:input.version,p_email:email,p_role:role,p_reason:input.reason.trim(),p_approved:true};
}
