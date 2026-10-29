// HTTP handling for delete-account, separate from Deno so it can be
// tested. The caller's access token is checked by the Auth server itself
// (verify_jwt = false in config.toml: the new asymmetric keys are verified
// here, by asking Auth, not by the gateway).
import { type AccountDeps, deleteAccount } from './account.ts';

export type Env = { get(name: string): string | undefined };

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

export async function handle(
  request: Request,
  env: Env,
  deps: (url: string, serviceKey: string) => AccountDeps,
): Promise<Response> {
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' });

  // Fail closed: without its configuration nothing is deleted.
  const url = env.get('SUPABASE_URL') ?? '';
  const serviceKey = env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!url.startsWith('https://') && !url.startsWith('http://kong')) {
    return json(500, { error: 'not_configured' });
  }
  if (serviceKey.length < 20) return json(500, { error: 'not_configured' });

  const match = /^Bearer ([A-Za-z0-9._-]{20,4096})$/.exec(request.headers.get('authorization') ?? '');
  if (!match) return json(401, { error: 'unauthorized' });

  try {
    const outcome = await deleteAccount(match[1], deps(url, serviceKey));
    switch (outcome.kind) {
      case 'deleted':
        return json(200, { deleted: true });
      case 'unauthorized':
        return json(401, { error: 'unauthorized' });
      case 'reauth-required':
        return json(403, { error: 'reauth_required' });
    }
  } catch (error) {
    // No ids or tokens in logs.
    console.error('delete-account failed', error instanceof Error ? error.message.split(':')[0] : 'error');
    return json(500, { error: 'delete_failed' });
  }
}
