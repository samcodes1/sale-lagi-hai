import assert from 'node:assert/strict';
import { test } from 'node:test';
import { type AccountDeps, deleteAccount, REAUTH_WINDOW_MS, supabaseDeps } from './account.ts';
import { handle } from './handler.ts';

const NOW = Date.parse('2026-10-29T12:00:00Z');
const TOKEN = 'header.payload-xxxxxxxxxxxxxxxx.signature';

function fakeDeps(overrides: Partial<AccountDeps> = {}) {
  const calls: string[] = [];
  const deps: AccountDeps = {
    verifyUser: async () => ({ id: 'u1', lastSignInAt: new Date(NOW - 60_000).toISOString() }),
    listPrivateFiles: async () => [
      { bucket_id: 'avatars', name: 'u1/me.jpg' },
      { bucket_id: 'submission-photos', name: 'u1/a.jpg' },
    ],
    removeFiles: async (bucket, names) => {
      calls.push(`remove ${bucket} ${names.length}`);
    },
    deleteUser: async (id) => {
      calls.push(`delete ${id}`);
    },
    now: () => NOW,
    ...overrides,
  };
  return { deps, calls };
}

test('deletes the files first, then the user', async () => {
  const { deps, calls } = fakeDeps();
  assert.deepEqual(await deleteAccount(TOKEN, deps), { kind: 'deleted', files: 2 });
  assert.deepEqual(calls, ['remove avatars 1', 'remove submission-photos 1', 'delete u1']);
});

test('a bad token deletes nothing', async () => {
  const { deps, calls } = fakeDeps({ verifyUser: async () => null });
  assert.deepEqual(await deleteAccount(TOKEN, deps), { kind: 'unauthorized' });
  assert.deepEqual(calls, []);
});

test('an old sign-in must be repeated first', async () => {
  for (const lastSignInAt of [new Date(NOW - REAUTH_WINDOW_MS - 1).toISOString(), null, 'garbage']) {
    const { deps, calls } = fakeDeps({ verifyUser: async () => ({ id: 'u1', lastSignInAt }) });
    assert.deepEqual(await deleteAccount(TOKEN, deps), { kind: 'reauth-required' }, String(lastSignInAt));
    assert.deepEqual(calls, []);
  }
});

test('many files go in batches of 100', async () => {
  const files = Array.from({ length: 250 }, (_, i) => ({ bucket_id: 'avatars', name: `u1/${i}.jpg` }));
  const { deps, calls } = fakeDeps({ listPrivateFiles: async () => files });
  await deleteAccount(TOKEN, deps);
  assert.deepEqual(calls, ['remove avatars 100', 'remove avatars 100', 'remove avatars 50', 'delete u1']);
});

test('if removing files fails, the user is not deleted', async () => {
  const { deps, calls } = fakeDeps({
    removeFiles: async () => {
      throw new Error('storage delete failed: 500');
    },
  });
  await assert.rejects(deleteAccount(TOKEN, deps));
  assert.deepEqual(calls, []);
});

// --- HTTP API layer -------------------------------------------------------

test('supabaseDeps speaks the Auth, PostgREST and Storage APIs', async () => {
  const seen: { url: string; method: string; headers: Record<string, string>; body?: string }[] = [];
  const http = (async (input: string | URL, init: RequestInit = {}) => {
    const url = String(input);
    seen.push({
      url,
      method: init.method ?? 'GET',
      headers: Object.fromEntries(new Headers(init.headers).entries()),
      body: init.body as string | undefined,
    });
    if (url.endsWith('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'u1', last_sign_in_at: '2026-10-29T11:59:00Z' }), { status: 200 });
    }
    if (url.includes('/rpc/')) return new Response(JSON.stringify([{ bucket_id: 'avatars', name: 'u1/me.jpg' }]), { status: 200 });
    return new Response('{}', { status: 200 });
  }) as typeof fetch;
  const deps = supabaseDeps('https://p.supabase.co', 'sb_secret_xxxxxxxxxxxxxxxx', http);

  assert.deepEqual(await deps.verifyUser(TOKEN), { id: 'u1', lastSignInAt: '2026-10-29T11:59:00Z' });
  assert.equal(seen[0].headers.authorization, `Bearer ${TOKEN}`, 'the user is checked with their own token');
  assert.deepEqual(await deps.listPrivateFiles('u1'), [{ bucket_id: 'avatars', name: 'u1/me.jpg' }]);
  assert.equal(JSON.parse(seen[1].body!).target, 'u1');
  await deps.removeFiles('avatars', ['u1/me.jpg']);
  assert.equal(seen[2].method, 'DELETE');
  assert.deepEqual(JSON.parse(seen[2].body!), { prefixes: ['u1/me.jpg'] });
  await deps.deleteUser('u1');
  assert.equal(seen[3].url, 'https://p.supabase.co/auth/v1/admin/users/u1');
  assert.equal(seen[3].headers.apikey, 'sb_secret_xxxxxxxxxxxxxxxx');
});

test('supabaseDeps: a rejected token is null; other failures throw', async () => {
  const status = (code: number) => (async () => new Response('{}', { status: code })) as typeof fetch;
  assert.equal(await supabaseDeps('https://p', 'k'.repeat(20), status(401)).verifyUser(TOKEN), null);
  await assert.rejects(supabaseDeps('https://p', 'k'.repeat(20), status(500)).verifyUser(TOKEN));
  await assert.rejects(supabaseDeps('https://p', 'k'.repeat(20), status(400)).deleteUser('u1'));
});

// --- handler ------------------------------------------------------------

const env = (values: Record<string, string>) => ({ get: (k: string) => values[k] });
const configured = env({ SUPABASE_URL: 'https://p.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_xxxxxxxxxxxxxxxx' });
const post = (headers: Record<string, string> = {}) =>
  new Request('https://p.supabase.co/functions/v1/delete-account', { method: 'POST', headers });

test('handler: POST with a bearer token only; fails closed without config', async () => {
  const never = () => {
    throw new Error('must not run');
  };
  assert.equal((await handle(new Request('https://x', { method: 'GET' }), configured, never)).status, 405);
  assert.equal((await handle(post(), configured, never)).status, 401);
  assert.equal((await handle(post({ authorization: 'Bearer short' }), configured, never)).status, 401);
  assert.equal((await handle(post({ authorization: `Bearer ${TOKEN}` }), env({}), never)).status, 500);
});

test('handler: maps outcomes to 200, 401 and 403, and failures to a generic 500', async () => {
  const auth = { authorization: `Bearer ${TOKEN}` };
  const ok = await handle(post(auth), configured, () => fakeDeps().deps);
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), { deleted: true });
  assert.equal((await handle(post(auth), configured, () => fakeDeps({ verifyUser: async () => null }).deps)).status, 401);
  const stale = await handle(post(auth), configured, () =>
    fakeDeps({ verifyUser: async () => ({ id: 'u1', lastSignInAt: null }) }).deps);
  assert.equal(stale.status, 403);
  assert.deepEqual(await stale.json(), { error: 'reauth_required' });
  const broken = await handle(post(auth), configured, () =>
    fakeDeps({ deleteUser: async () => { throw new Error('auth delete failed: 500 u1'); } }).deps);
  assert.equal(broken.status, 500);
  assert.deepEqual(await broken.json(), { error: 'delete_failed' });
});
