import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import {authReturnPath} from '@/lib/auth-return';

export async function GET(request: NextRequest) {
  const next=authReturnPath(request.nextUrl.searchParams.get('next'));
  const failure=new URL('/sign-in',request.url);failure.searchParams.set('error','confirmation');failure.searchParams.set('next',next);
  const code=request.nextUrl.searchParams.get('code');
  if(code&&code.length<=2048&&!/\s/.test(code)){
    try{
      const client=await createClient();
      const {data,error}=await client.auth.exchangeCodeForSession(code);
      if(!error&&data.user?.id){
        const verified=await client.auth.getUser();
        if(!verified.error&&verified.data.user?.id===data.user.id&&verified.data.user.email_confirmed_at&&!verified.data.user.is_anonymous)return NextResponse.redirect(new URL(next,request.url));
      }
    }catch{/* Return a recoverable confirmation failure without provider details. */}
  }
  return NextResponse.redirect(failure);
}
