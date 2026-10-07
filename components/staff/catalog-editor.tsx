'use client';
import { useState, useRef, type FormEvent } from 'react';
type Row = Record<string, unknown> & { id: string };
const listingFields = ['title','area','price_jmd','bedrooms','bathrooms','parking_spaces','photo_url','approximate_latitude','approximate_longitude','location_label'];
const realtorFields = ['display_name','photo_url','service_areas','supported_intents'];
const choices: Record<string,string[]> = { intent:['rent','sale'], property_type:['apartment','townhouse','house','land','commercial'], status:['draft','published','paused'], communication_style:['thoughtful','direct','collaborative'],guidance_style:['step-by-step','data-led','independent'],decision_pace:['considered','decisive','flexible'] };
export function CatalogEditor({ listings, realtors,initialListingId="",initialKind='listing' }: { listings: Row[]; realtors: Row[];initialListingId?:string;initialKind?:'listing'|'realtor' }) {
  const kind=initialKind;
  const [selected, setSelected] = useState(initialListingId);
  const rows = kind === 'listing' ? listings : realtors;
  return <section className="staff-catalog"><div className="filter-bar"><label>Catalog<select value={kind} onChange={e => { window.location.assign(`/staff?catalog=${e.target.value}`); }}><option value="listing">Properties</option><option value="realtor">Realtors</option></select></label><label>Record<select value={selected} onChange={e => setSelected(e.target.value)}><option value="">Create a new draft</option>{rows.map(row => <option key={row.id} value={row.id}>{String(row.title || row.display_name)} · {String(row.status || (row.is_published ? 'published' : 'draft'))}</option>)}</select></label></div><EditorForm key={`${kind}-${selected}`} kind={kind} row={rows.find(row => row.id === selected)} /></section>;
}
function EditorForm({ kind, row }: { kind: 'listing'|'realtor'; row?: Row }) {
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState('');
  const retry=useRef<{payload:string;id:string}|null>(null);
  const fields = kind === 'listing' ? listingFields : realtorFields;
  const selectKeys = kind === 'listing' ? ['intent','property_type','status'] : ['communication_style','guidance_style','decision_pace'];
  const value = (key: string) => Array.isArray(row?.[key]) ? (row?.[key] as string[]).join(', ') : String(row?.[key] ?? '');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    const data = new FormData(event.currentTarget); const input: Record<string, unknown> = { kind, ...(row ? { id: row.id } : {}) };
    [...fields, ...selectKeys, kind === 'listing' ? 'description' : 'bio'].forEach(key => { input[key] = String(data.get(key) || '').trim(); });
    if (kind === 'listing') {
      ['price_jmd','bedrooms','bathrooms','parking_spaces'].forEach(key => { input[key] = Number(input[key]); });
      ['approximate_latitude','approximate_longitude'].forEach(key => { input[key] = input[key] === '' ? null : Number(input[key]); });
    } else { ['service_areas','supported_intents'].forEach(key => { input[key] = String(input[key]).split(',').map(x => x.trim()).filter(Boolean); }); input.is_published = data.get('is_published') === 'on';input.expected_revision=row?.authoring_revision??0;input.reason=String(data.get('reason')||'').trim();input.approved=data.get('approved')==='on';const payload=JSON.stringify(input);if(retry.current?.payload!==payload)retry.current={payload,id:crypto.randomUUID()};input.request_id=retry.current.id; }
    try {
      const response = await fetch('/api/staff/catalog', { method:'POST', headers:{ 'Content-Type':'application/json' }, body:JSON.stringify(input) });
      const result = await response.json();
      if (!response.ok) {if(response.status<500)retry.current=null;throw new Error(result.error || 'Unable to save.');}
      window.location.assign(`/staff?saved=${kind}&${kind}=${encodeURIComponent(result.id)}`);
    } catch (error) { setMessage(error instanceof Error ? error.message : 'Unable to save. Please retry.'); }
    finally { setBusy(false); }
  }
  return <form onSubmit={submit} className="staff-editor"><h2>{row ? 'Edit' : 'Create'} {kind === 'listing' ? 'property' : 'realtor profile'}</h2>{kind==='listing'&&row&&<p><a href={`/staff/properties?listing=${row.id}${row.property_id?`&property=${row.property_id}`:""}`}>Manage private property/unit linkage ↗</a></p>}<p>Publish approved content only. Map coordinates must represent an approximate public neighborhood location.</p><div className="staff-fields">{fields.map(key => <label key={key}>{key.replaceAll('_',' ')}<input name={key} defaultValue={value(key)} type={key === 'photo_url' ? 'url' : ['price_jmd','bedrooms','bathrooms','parking_spaces','approximate_latitude','approximate_longitude'].includes(key) ? 'number' : 'text'} step="any" required={['title','area','display_name','price_jmd','bedrooms','bathrooms','parking_spaces'].includes(key)} maxLength={key === 'photo_url' ? 2048 : kind==='realtor'&&['service_areas','supported_intents'].includes(key)?6050:200} /></label>)}{selectKeys.map(key => <label key={key}>{key.replaceAll('_',' ')}<select name={key} defaultValue={value(key) || choices[key][0]}>{choices[key].map(option => <option key={option}>{option}</option>)}</select></label>)}</div><label>{kind === 'listing' ? 'Description' : 'Biography'}<textarea name={kind === 'listing' ? 'description' : 'bio'} defaultValue={value(kind === 'listing' ? 'description' : 'bio')} maxLength={kind === 'listing' ? 10000 : 5000} rows={6} /></label>{kind === 'realtor' && <><p>Separate service areas and supported intents with commas. Supported intents: buy, rent, sell.</p><label>Change reason<textarea name="reason" required minLength={5} maxLength={500}/></label><label><input type="checkbox" name="approved"/> I confirm the biography, service coverage and working styles are approved for publication.</label><label><input type="checkbox" name="is_published" defaultChecked={row?.is_published === true} /> Publish this approved profile</label>{row&&<p><a href={`/staff/realtors/${row.id}/history`}>Review profile change history ↗</a></p>}</>}<button className="primary" disabled={busy}>{busy ? 'Saving…' : 'Save catalog record'}</button><p role="status">{message}</p></form>;
}
