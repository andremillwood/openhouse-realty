/** Normalize approved invoice intake/review; authority and accounting are server-derived. */
export function invoiceInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid invoice request.');
  const input = value as Record<string, unknown>;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const validId = (v: unknown): v is string => typeof v === 'string' && uuid.test(v);
  if (!validId(input.request_id) || typeof input.action !== 'string' || !['submit','review','approve','reject'].includes(input.action)) throw new Error('Choose an available invoice action and request reference.');
  if (typeof input.version !== 'number' || !Number.isInteger(input.version) || input.version < 0 || input.version >= 2147483647) throw new Error('Refresh the invoice revision.');
  if (typeof input.reason !== 'string' || input.reason.trim().length < 5 || input.reason.length > 500 || input.approved !== true) throw new Error('Record a reason and explicit approval.');
  let invoice: string | null = null, property: string | null = null, work: string | null = null, vendor: string | null = null, number: string | null = null, amount: number | null = null;
  if (input.action === 'submit') {
    if (input.invoice_id !== null || input.version !== 0) throw new Error('New invoice revision required.');
    if (!(input.property_id === null || validId(input.property_id)) || !(input.work_order_id === null || validId(input.work_order_id)) || input.work_order_id !== null && input.property_id === null) throw new Error('Check the property and work order binding.');
    if (typeof input.vendor_name !== 'string' || input.vendor_name.trim().length < 2 || input.vendor_name.length > 160 || typeof input.invoice_number !== 'string' || input.invoice_number.trim().length < 1 || input.invoice_number.length > 80) throw new Error('Provide the approved vendor and invoice number.');
    if (typeof input.amount_minor !== 'number' || !Number.isSafeInteger(input.amount_minor) || input.amount_minor < 1 || input.amount_minor > 99999999999999) throw new Error('Provide a positive whole-minor-unit JMD invoice amount.');
    property=input.property_id;work=input.work_order_id;vendor=input.vendor_name.trim();number=input.invoice_number.trim();amount=input.amount_minor;
  } else {
    if (!validId(input.invoice_id) || input.version < 1) throw new Error('Current invoice reference and revision required.');
    for (const key of ['property_id','work_order_id','vendor_name','invoice_number','amount_minor']) if (input[key] != null) throw new Error('Submitted invoice details cannot change during review.');
    invoice=input.invoice_id;
  }
  return {p_request_id:input.request_id,p_action:input.action,p_invoice_id:invoice,p_expected_version:input.version,p_property_id:property,p_work_order_id:work,p_vendor_name:vendor,p_invoice_number:number,p_amount_minor:amount,p_reason:input.reason.trim(),p_approved:true};
}
