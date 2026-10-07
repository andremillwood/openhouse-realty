import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    { cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(cookies) {
        cookies.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookies.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    } },
  );
  await supabase.auth.getClaims();
  response.headers.set('Cache-Control', 'private, no-store');
  return response;
}
export const config = { matcher: ['/inventory', '/open-houses', '/api/open-house-rsvps', '/listings/:path*', '/realtors', '/staff/:path*', '/api/staff/:path*', '/api/enquiries', '/api/sellers', '/api/applications', '/api/documents', '/api/cosigners', '/cosigners/:path*', '/apply/:path*', '/applications/:path*', '/sell', '/api/viewings', '/account/:path*', '/sign-in', '/auth/:path*'] };
