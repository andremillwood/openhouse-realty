import { SiteHeader } from '@/components/discovery/site-header';
import { AuthForm } from '@/components/auth/auth-form';
export default async function SignIn({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const params = await searchParams;
  return <><SiteHeader /><main className="account-layout"><AuthForm confirmationError={params.error === 'confirmation'} /></main></>;
}
