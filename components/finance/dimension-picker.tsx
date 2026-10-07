'use client';
import {useEffect, useRef, useState} from 'react';
type Item = {id: string; label: string};
export function DimensionPicker({kind, value, propertyId = '', onChange}: {kind: 'property' | 'unit'; value: string; propertyId?: string; onChange: (id: string) => void}) {
  const [term, setTerm] = useState(''), [items, setItems] = useState<Item[]>([]), [selected, setSelected] = useState<Item | null>(null);
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const generation = useRef(0);
  useEffect(() => () => {generation.current++;}, []);
  function invalidate() {generation.current++;setItems([]);setBusy(false);setMessage('');}
  async function search() {
    if (kind === 'unit' && !propertyId) return;
    const current = ++generation.current;setBusy(true);setItems([]);setMessage('');
    try {
      const response = await fetch(`/api/staff/finance-dimensions?${new URLSearchParams({kind, q: term, ...(kind === 'unit' ? {property_id: propertyId} : {})})}`, {cache: 'no-store'});
      const result = await response.json();if (generation.current !== current) return;
      if (!response.ok) throw new Error(result.error || 'Unable to search labels.');
      setItems(result.items);setMessage(result.more ? 'Showing 25 results. Refine your search.' : result.items.length ? `Select a ${kind}.` : 'No matching labels.');
    } catch (error) {if (generation.current === current) setMessage(error instanceof Error ? error.message : 'Unable to search labels.');} finally {if (generation.current === current) setBusy(false);}
  }
  return <section><label>Find {kind} (optional)<input value={term} maxLength={120} onChange={event => {invalidate();setTerm(event.target.value);}}/></label><button type="button" disabled={busy || (kind === 'unit' && !propertyId)} onClick={search}>{busy ? 'Searching…' : `Search ${kind} labels`}</button>{kind === 'unit' && !propertyId && <p>Choose a property to search its units.</p>}{items.map(item => <button type="button" key={item.id} onClick={() => {onChange(item.id);setSelected(item);invalidate();}}>{item.label}</button>)}<p role="status">{message}</p>{value && <><p>Selected {kind}: {selected?.id === value ? selected.label : value}</p><button type="button" onClick={() => {onChange('');setSelected(null);invalidate();}}>Clear {kind}</button></>}</section>;
}
