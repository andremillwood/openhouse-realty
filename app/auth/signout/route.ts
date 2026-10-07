import { sameOrigin } from '@/lib/http/origin';
import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) {
    return new NextResponse('Invalid request origin', { status: 403 });
  }
  const client = await createClient();
  const { error } = await client.auth.signOut();
  if (error) return new NextResponse('Unable to sign out. Please retry.', { status: 503 });
  return NextResponse.redirect(new URL('/sign-in', request.url), 303);
}
