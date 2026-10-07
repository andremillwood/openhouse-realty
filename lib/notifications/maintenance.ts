export const maintenanceNoticeKinds = ['offer_created', 'offer_closed', 'visit_proposed', 'visit_confirmed', 'visit_cancelled', 'entry_updated', 'report_submitted', 'changes_requested', 'work_completed', 'return_visit'] as const;
export type MaintenanceNoticeKind = typeof maintenanceNoticeKinds[number];
const copy: Record<MaintenanceNoticeKind, {subject: string; message: string; audience: 'contractor' | 'management'}> = {
  offer_created: {subject: 'A work offer is ready for your review', message: 'Review the approved scope and expiry in your account. The assignment is confirmed only after you accept it.', audience: 'contractor'},
  offer_closed: {subject: 'Your work offer has changed', message: 'Review the current assignment status before making work or travel arrangements.', audience: 'contractor'},
  visit_proposed: {subject: 'A work appointment needs your response', message: 'Review the proposed appointment in your account and confirm or decline it. Travel only after confirmation and approved entry authorization.', audience: 'contractor'},
  visit_confirmed: {subject: 'A work appointment has been confirmed', message: 'Review the confirmed appointment and current entry authorization in your account before travelling.', audience: 'contractor'},
  visit_cancelled: {subject: 'A work appointment has been cancelled', message: 'Do not travel using the cancelled appointment or its previous entry authorization. Review the current assignment in your account.', audience: 'contractor'},
  entry_updated: {subject: 'Work entry authorization has changed', message: 'Review the current approved entry window and instructions in your account before travelling. This email is not an entry permit.', audience: 'contractor'},
  report_submitted: {subject: 'A contractor report is ready for review', message: 'Review the submitted work report and evidence in the management workspace. Submission does not mark the work complete.', audience: 'management'},
  changes_requested: {subject: 'Your work report needs corrections', message: 'Review the shared feedback in your account. Submit a revised report when ready; additional on-site work requires an approved return appointment.', audience: 'contractor'},
  work_completed: {subject: 'Your completed work has been approved', message: 'Management has approved the completion report. Review the decision in your account. Completion approval does not confirm payment.', audience: 'contractor'},
  return_visit: {subject: 'A correction visit has been approved', message: 'Review the shared correction feedback in your account. A new appointment must be proposed, confirmed and authorized before you return to the property.', audience: 'contractor'},
};
/** Deliberately excludes job titles, addresses, reports, evidence and security instructions. */
export function maintenanceNotice(value: unknown, reference: unknown) {
  if (typeof value !== 'string' || !maintenanceNoticeKinds.includes(value as MaintenanceNoticeKind)) throw new Error('Unsupported maintenance notice.');
  if (typeof reference !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(reference)) throw new Error('Valid maintenance reference required.');
  const kind = value as MaintenanceNoticeKind, notice = copy[kind];
  const actionPath = notice.audience === 'management' ? `/staff/work-orders/${reference}/completion` : `/account/work-offers/${reference}`;
  return {kind, audience: notice.audience, subject: notice.subject, text: `${notice.message}\n\nReference: ${reference}\n\nSign in to review: `, actionPath};
}
