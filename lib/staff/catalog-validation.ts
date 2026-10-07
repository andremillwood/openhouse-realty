export function catalogInput(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid catalog record.');
  const input = value as Record<string, unknown>;
  const text = (key: string, max: number, required = true) => {
    const raw = input[key];
    if (typeof raw !== 'string' || raw.length > max || (required && !raw.trim())) throw new Error(`Check ${key.replaceAll('_', ' ')}.`);
    return raw.trim();
  };
  const choice = (key: string, choices: string[]) => { const v = text(key, 50); if (!choices.includes(v)) throw new Error(`Invalid ${key}.`); return v; };
  const number = (key: string, max: number) => { const v = input[key]; if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > max) throw new Error(`Check ${key}.`); return v; };
  const https = (key: string) => { const v = text(key, 2048, false); if (!v) return null; try { const url = new URL(v); if (url.protocol !== 'https:' || url.username || url.password) throw new Error(); return url.href; } catch { throw new Error('Use a public HTTPS photo URL.'); } };
  const id = input.id;
  if (id !== undefined && (typeof id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))) throw new Error('Invalid record ID.');
  if (input.kind === 'listing') {
    const lat = input.approximate_latitude, lng = input.approximate_longitude;
    if (!(lat === null && lng === null) && !(typeof lat === 'number' && Number.isFinite(lat) && lat >= -90 && lat <= 90 && typeof lng === 'number' && Number.isFinite(lng) && lng >= -180 && lng <= 180)) throw new Error('Provide both approximate coordinates, or leave both blank.');
    const record = { title: text('title', 160), area: text('area', 120), intent: choice('intent', ['sale', 'rent']), property_type: choice('property_type', ['apartment','townhouse','house','land','commercial']), status: choice('status',['draft','published','paused']), price_jmd: number('price_jmd',999999999999), bedrooms: number('bedrooms',99), bathrooms: number('bathrooms',99), parking_spaces: number('parking_spaces',100), description: text('description',10000,false), photo_url: https('photo_url'), approximate_latitude: lat as number | null, approximate_longitude: lng as number | null, location_label: text('location_label',160,false) };
    if (!Number.isInteger(record.parking_spaces)) throw new Error('Parking spaces must be a whole number.');
    if (record.status === 'published' && (record.title.length < 3 || record.description.length < 20 || !record.photo_url || record.price_jmd <= 0)) throw new Error('Publication needs a positive approved price, title, description of at least 20 characters, and an approved photo.');
    return { id, kind: 'listing' as const, record };
  }
  if (input.kind === 'realtor') {
    if(typeof input.request_id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.request_id))throw new Error('Invalid profile request ID.');
    if(typeof input.expected_revision!=='number'||!Number.isInteger(input.expected_revision)||input.expected_revision<0||input.expected_revision>=2147483647)throw new Error('Invalid profile revision.');
    const reason=text('reason',500);if(reason.length<5)throw new Error('Provide a change reason of at least five characters.');
    if(typeof input.approved!=='boolean')throw new Error('Choose whether this profile is approved.');
    const list = (key: string) => { const v = input[key]; if (!Array.isArray(v) || v.length > 50 || v.some(x => typeof x !== 'string' || !x.trim() || x.length > 120)) throw new Error(`Check ${key}.`); return [...new Set(v.map(x => (x as string).trim()))]; };
    if (typeof input.is_published !== 'boolean') throw new Error('Invalid publication status.');
    const record = { display_name: text('display_name',160), bio: text('bio',5000,false), photo_url: https('photo_url'), service_areas: list('service_areas'), supported_intents: list('supported_intents'), communication_style: choice('communication_style',['thoughtful','direct','collaborative']), guidance_style: choice('guidance_style',['step-by-step','data-led','independent']), decision_pace: choice('decision_pace',['considered','decisive','flexible']), is_published: input.is_published };
    if (record.supported_intents.some(x => !['buy','rent','sell'].includes(x))) throw new Error('Invalid service intent.');
    if(record.display_name.length<2)throw new Error('Provide a complete display name.');
    if (record.is_published && (!input.approved||record.bio.length < 20 || !record.service_areas.length || !record.supported_intents.length)) throw new Error('Publication needs explicit approval, a complete bio, service areas and intents.');
    return { id, kind: 'realtor' as const, record,request_id:input.request_id,expected_revision:input.expected_revision,reason,approved:input.approved };
  }
  throw new Error('Invalid catalog type.');
}
