import { uuidPattern } from './validation';
export function staffEnquiryInput(input: unknown) {
  if (!input || typeof input !== 'object') throw new Error('Invalid update');
  const value = input as Record<string, unknown>;
  if (typeof value.id !== 'string' || !uuidPattern.test(value.id)) throw new Error('Enquiry required');
  if (!value.action || value.action === 'status') {
    if (typeof value.status !== 'string' || !['new','contacted','closed'].includes(value.status)) throw new Error('Invalid status');
    return { action:'status' as const, id:value.id, status:value.status };
  }
  if (value.action === 'assign') {
    if (value.assignee !== null && (typeof value.assignee !== 'string' || !uuidPattern.test(value.assignee))) throw new Error('Invalid assignee');
    if (typeof value.version !== 'number' || !Number.isSafeInteger(value.version) || value.version < 0 || value.version >= 2147483647) throw new Error('Invalid version');
    return { action:'assign' as const, id:value.id, assignee:value.assignee as string|null, version:value.version };
  }
  if (value.action === 'note') {
    if (typeof value.requestId !== 'string' || !uuidPattern.test(value.requestId) || typeof value.body !== 'string' || value.body.trim().length < 2 || value.body.trim().length > 2000) throw new Error('Invalid note');
    return { action:'note' as const, id:value.id, requestId:value.requestId, body:value.body.trim() };
  }
  throw new Error('Invalid action');
}
