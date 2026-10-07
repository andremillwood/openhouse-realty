export function VisitSummary({visit}: {visit: {state: string; starts_at: string; ends_at: string; shared_note: string}}) {
  const date = (value: string) => new Date(value).toLocaleString('en-JM', {timeZone: 'America/Jamaica'});
  return <section className="staff-editor"><h2>{visit.state === 'confirmed' ? 'Confirmed appointment' : 'Proposed appointment'}</h2><p>{date(visit.starts_at)} → {date(visit.ends_at)} (Jamaica time)</p><p className="enquiry-message">{visit.shared_note}</p><p>The appointment reserves a time window. Entry must be authorized separately.</p></section>;
}
