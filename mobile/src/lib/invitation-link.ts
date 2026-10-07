const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** Rewrite only the invitation route; unrelated authentication callbacks remain intact. */
export function invitationLink(path: string, appUrl?: string): string {
  try {
    let route = path;
    if (!path.startsWith('/') || path.startsWith('//')) {
      const url = new URL(path);
      if (url.username || url.password) return path;
      if (url.protocol === 'openhouse-realty:') {
        route = (url.hostname ? '/' + url.hostname : '') + url.pathname + url.search + url.hash;
      } else {
        if (!appUrl) return path;
        const canonical = new URL(appUrl);
        if (canonical.protocol !== 'https:' || canonical.username || canonical.password || url.origin !== canonical.origin || url.protocol !== 'https:') return path;
        route = url.pathname + url.search + url.hash;
      }
    }
    const match = /^\/account\/invitations\/([^/?#]+)$/.exec(route);
    if (!match || !uuid.test(match[1])) return path;
    return '/team-invitation?id=' + match[1].toLowerCase();
  } catch { return path; }
}

/** Only a single invitation identifier can survive the sign-in handoff. */
export function invitationReturnId(value: unknown): string | null {
  return typeof value === 'string' && uuid.test(value) ? value.toLowerCase() : null;
}
