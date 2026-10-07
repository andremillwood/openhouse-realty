export function EntryPermitSummary({permit}: {permit: {id?: string; state: string; valid_from: string; valid_until: string; shared_instructions: string}}) {
  const date = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  const expired = Date.parse(permit.valid_until) <= Date.now();
  return <section className="staff-editor"><h2>Entry authorization</h2>{permit.id && <p>Permit reference for property security: {permit.id}</p>}<p>{permit.state === 'authorized' && expired ? 'Expired' : permit.state === 'authorized' ? 'Approved access window' : 'Revoked'}</p><p>{date(permit.valid_from)} → {date(permit.valid_until)} (Jamaica time)</p><p className="enquiry-message">{permit.shared_instructions}</p><p>The property representative must verify your identity and current authorization before entry.</p></section>;
}
