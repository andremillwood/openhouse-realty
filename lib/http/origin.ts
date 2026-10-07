/** Host is the externally routed host; Next may normalize request.url internally. */
export function sameOrigin(request: Request) {
  const origin = request.headers.get('origin');
  const host = request.headers.get('host');
  if (!origin || !host || origin === 'null') return false;
  try {
    const protocol = request.headers.get('x-forwarded-proto') || new URL(request.url).protocol.slice(0,-1);
    if (protocol !== 'http' && protocol !== 'https') return false;
    const expected = new URL(`${protocol}://${host}`);
    const supplied = new URL(origin);
    return !supplied.username && !supplied.password && supplied.origin === expected.origin && supplied.pathname === '/' && !supplied.search && !supplied.hash;
  } catch { return false; }
}
