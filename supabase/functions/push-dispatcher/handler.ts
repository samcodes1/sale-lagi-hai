// HTTP handling for the push dispatcher, separate from Deno so it can be
// tested. Called by pg_cron through pg_net with a shared secret
// (verify_jwt = false in config.toml); nobody else can trigger a run.
import { secretsMatch } from '../_shared/secret.ts';
import { dispatch, type DispatchDeps } from './dispatch.ts';

export type Env = { get(name: string): string | undefined };

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

export async function handle(
  request: Request,
  env: Env,
  deps: () => DispatchDeps,
): Promise<Response> {
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' });

  // Fail closed: without a configured secret nothing runs.
  const expected = env.get('DISPATCHER_SECRET') ?? '';
  if (expected.length < 32) return json(500, { error: 'not_configured' });
  if (!secretsMatch(request.headers.get('x-dispatcher-secret'), expected)) {
    return json(401, { error: 'unauthorized' });
  }

  try {
    // Counts only: no tokens, titles or user ids in the response or logs.
    return json(200, await dispatch(deps()));
  } catch (error) {
    console.error('push-dispatcher run failed', error instanceof Error ? error.name : 'error');
    return json(500, { error: 'dispatch_failed' });
  }
}
