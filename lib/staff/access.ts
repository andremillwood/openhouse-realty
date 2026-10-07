import 'server-only';
import { createClient } from '@/lib/supabase/server';
export async function catalogAccess(roles: string[] = ['admin','realtor']) {
  const client = await createClient();
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user?.email_confirmed_at) return { client, user: null, membership: null };
  const { data: membership } = await client.from('staff_accounts').select('organization_id,role').eq('user_id', user.id).single();
  return { client, user, membership: membership?.organization_id && roles.includes(membership.role) ? membership : null };
}
