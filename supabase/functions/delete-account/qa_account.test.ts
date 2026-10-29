// QA (sub-phase 4.2 gate): delete-account. Independent checks of who can
// be deleted, failing closed, ordering under partial failure, and log
// hygiene. "QA BUG" tests fail until the bug in docs/qa/4.2.md is fixed.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { type AccountDeps, deleteAccount, supabaseDeps } from './account.ts';
import { handle } from './handler.ts';

const NOW = Date.parse('2026-10-29T12:00:00Z');
const USER = '7a1c2f3e-0000-4000-8000-00000000beef';
const PHONE = '923001234567';

const b64url = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
/** An access token shaped like Supabase Auth's (the signature is not checked here). */
function jwt(claims: Record<string, unknown>): string {
  return `${b64url({ alg: 'ES256', typ: 'JWT' })}.${b64url(claims)}.c2lnbmF0dXJlLXNpZ25hdHVyZQ`;
}

function recordingDeps(overrides: Partial<AccountDeps> = {}) {
  const calls: string[] = [];
  const deps: AccountDeps = {
    verifyUser: async () => ({ id: USER }),
    listPrivateFiles: async () => [],
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

const env = (values: Record<string, string>) => ({ get: (k: string) => values[k] });
const configured = env({ SUPABASE_URL: 'https://p.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_' + 'q'.repeat(30) });
const TOKEN = jwt({ sub: USER, role: 'authenticated', amr: [{ method: 'otp', timestamp: NOW / 1000 - 30 }] });

// ---------------------------------------------------------------------------
// QA BUG 4.2-A1 (S2): the fresh-sign-in rule reads users.last_sign_in_at,
// which Supabase Auth also bumps on every refresh-token grant
// (internal/models/refresh_token.go createRefreshToken →
// user.UpdateLastSignInAt; used by GrantRefreshTokenSwap). The app
// refreshes its session on launch and hourly, so a session that signed in
// days ago (or a stolen refresh token) passes the 5-minute check. The
// session's real authentication time is in the access token's `amr`
// timestamps, which refreshes do not change.
// ---------------------------------------------------------------------------
test('QA BUG 4.2-A1: a session refreshed just now, but signed in two hours ago, must sign in again', async () => {
  const twoHoursAgo = NOW / 1000 - 2 * 60 * 60;
  const refreshedToken = jwt({
    sub: USER,
    role: 'authenticated',
    iat: NOW / 1000 - 10, // just refreshed
    amr: [{ method: 'otp', timestamp: twoHoursAgo }], // the real sign-in
  });
  // What /auth/v1/user returns right after a refresh: last_sign_in_at = now.
  const { deps, calls } = recordingDeps({
    verifyUser: async () => ({ id: USER, lastSignInAt: new Date(NOW - 10_000).toISOString() }),
  });
  assert.deepEqual(await deleteAccount(refreshedToken, deps), { kind: 'reauth-required' });
  assert.deepEqual(calls, [], 'nothing is deleted');
});

// ---------------------------------------------------------------------------
// Who gets deleted: only the token's user, whatever the request says.
// ---------------------------------------------------------------------------
test('the request body and query cannot name another user', async () => {
  const { deps, calls } = recordingDeps();
  const request = new Request('https://p.supabase.co/functions/v1/delete-account?user_id=victim', {
    method: 'POST',
    headers: { authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ user_id: 'victim', target: 'victim', id: 'victim' }),
  });
  const response = await handle(request, configured, () => deps);
  assert.equal(response.status, 200);
  assert.deepEqual(calls, [`delete ${USER}`]);
});

test('the token is checked by the Auth server with the token itself, never trusted from its payload', async () => {
  const seen: { url: string; auth: string | null }[] = [];
  const http = (async (input: string | URL, init: RequestInit = {}) => {
    seen.push({ url: String(input), auth: new Headers(init.headers).get('authorization') });
    return new Response('{"msg":"bad_jwt"}', { status: 403 });
  }) as typeof fetch;
  // A forged token claiming to be USER: Auth rejects it, nothing else runs.
  const forged = jwt({ sub: USER, role: 'service_role' });
  const outcome = await deleteAccount(forged, supabaseDeps('https://p.supabase.co', 'k'.repeat(40), http));
  assert.deepEqual(outcome, { kind: 'unauthorized' });
  assert.equal(seen.length, 1);
  assert.ok(seen[0].url.endsWith('/auth/v1/user'));
  assert.equal(seen[0].auth, `Bearer ${forged}`);
});

test('an Auth answer without a string id deletes nothing', async () => {
  for (const body of [{}, { id: 42 }, { id: null }, []]) {
    const http = (async () => new Response(JSON.stringify(body), { status: 200 })) as typeof fetch;
    assert.equal(await supabaseDeps('https://p', 'k'.repeat(40), http).verifyUser(TOKEN), null, JSON.stringify(body));
  }
});

// ---------------------------------------------------------------------------
// Failing closed.
// ---------------------------------------------------------------------------
test('fails closed on bad configuration and malformed authorization', async () => {
  const never = () => {
    throw new Error('must not run');
  };
  const post = (headers: Record<string, string>) =>
    new Request('https://p.supabase.co/functions/v1/delete-account', { method: 'POST', headers });
  const auth = { authorization: `Bearer ${TOKEN}` };
  for (const values of [
    { SUPABASE_URL: 'http://p.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'k'.repeat(40) }, // cleartext
    { SUPABASE_URL: 'https://p.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'short' },
    { SUPABASE_URL: 'https://p.supabase.co' },
    { SUPABASE_SERVICE_ROLE_KEY: 'k'.repeat(40) },
  ]) {
    assert.equal((await handle(post(auth), env(values), never)).status, 500, JSON.stringify(Object.keys(values)));
  }
  for (const authorization of [
    `bearer ${TOKEN}`,
    `Bearer  ${TOKEN}`,
    `Bearer ${TOKEN} extra`,
    `Basic ${TOKEN}`,
    `Bearer ${'a'.repeat(5000)}`,
  ]) {
    assert.equal((await handle(post({ authorization }), configured, never)).status, 401, authorization.slice(0, 12));
  }
  for (const method of ['GET', 'PUT', 'DELETE', 'OPTIONS']) {
    const request = new Request('https://p.supabase.co/functions/v1/delete-account', { method, headers: auth });
    assert.equal((await handle(request, configured, never)).status, 405, method);
  }
});

test('a malformed file list from the database deletes nothing', async () => {
  for (const bad of [{ error: 'x' }, null, 42]) {
    const { deps, calls } = recordingDeps({ listPrivateFiles: async () => bad as never });
    await assert.rejects(deleteAccount(TOKEN, deps));
    assert.deepEqual(calls, [], JSON.stringify(bad));
  }
});

// ---------------------------------------------------------------------------
// Ordering and partial failure.
// ---------------------------------------------------------------------------
test('batches are per bucket, and every file goes before the user', async () => {
  const files = [
    ...Array.from({ length: 101 }, (_, i) => ({ bucket_id: 'avatars', name: `${USER}/${i}.jpg` })),
    ...Array.from({ length: 100 }, (_, i) => ({ bucket_id: 'submission-photos', name: `${USER}/${i}.jpg` })),
  ];
  const { deps, calls } = recordingDeps({ listPrivateFiles: async () => files });
  assert.deepEqual(await deleteAccount(TOKEN, deps), { kind: 'deleted', files: 201 });
  assert.deepEqual(calls, [
    'remove avatars 100',
    'remove avatars 1',
    'remove submission-photos 100',
    `delete ${USER}`,
  ]);
});

test('a failure in a later batch stops before the user is deleted; a retry finishes the job', async () => {
  let stored = Array.from({ length: 150 }, (_, i) => ({ bucket_id: 'avatars', name: `${USER}/${i}.jpg` }));
  let batch = 0;
  const calls: string[] = [];
  const deps: AccountDeps = {
    verifyUser: async () => ({ id: USER, lastSignInAt: new Date(NOW).toISOString() }),
    listPrivateFiles: async () => stored,
    removeFiles: async (_bucket, names) => {
      if (++batch === 2) throw new Error('storage delete failed: 503');
      stored = stored.filter((f) => !names.includes(f.name));
      calls.push(`remove ${names.length}`);
    },
    deleteUser: async (id) => {
      calls.push(`delete ${id}`);
    },
    now: () => NOW,
  };
  await assert.rejects(deleteAccount(TOKEN, deps));
  assert.deepEqual(calls, ['remove 100'], 'the user survives a half-done file clean-up');
  assert.deepEqual(await deleteAccount(TOKEN, deps), { kind: 'deleted', files: 50 });
  assert.deepEqual(calls, ['remove 100', 'remove 50', `delete ${USER}`]);
});

test('the user is deleted with the service key, not the caller token', async () => {
  const headers: Record<string, string>[] = [];
  const http = (async (_input: string | URL, init: RequestInit = {}) => {
    headers.push(Object.fromEntries(new Headers(init.headers).entries()));
    return new Response('{}', { status: 200 });
  }) as typeof fetch;
  const key = 'sb_secret_' + 'z'.repeat(30);
  await supabaseDeps('https://p.supabase.co', key, http).deleteUser(USER);
  assert.equal(headers[0].authorization, `Bearer ${key}`);
});

// ---------------------------------------------------------------------------
// Log hygiene: no token, user id or phone number reaches the logs.
// ---------------------------------------------------------------------------
test('failure logs hold no token, user id or phone number', async () => {
  const logged: string[] = [];
  const original = console.error;
  console.error = (...args: unknown[]) => {
    logged.push(args.map(String).join(' '));
  };
  try {
    const failures: (() => never)[] = [
      () => {
        throw new Error(`auth delete failed: 500 ${USER}`);
      },
      () => {
        throw new TypeError(`error sending request for url (https://p.supabase.co/auth/v1/admin/users/${USER})`);
      },
      () => {
        throw new SyntaxError(`Unexpected token 'x', "{"id":"${USER}","phone":"${PHONE}"" is not valid JSON`);
      },
      () => {
        throw `raw string ${TOKEN}`;
      },
      () => {
        throw { message: `${USER} ${PHONE}` };
      },
    ];
    for (const fail of failures) {
      const response = await handle(
        new Request('https://p.supabase.co/functions/v1/delete-account', {
          method: 'POST',
          headers: { authorization: `Bearer ${TOKEN}` },
        }),
        configured,
        () => recordingDeps({ deleteUser: async () => fail() }).deps,
      );
      assert.equal(response.status, 500);
      assert.deepEqual(await response.json(), { error: 'delete_failed' });
    }
  } finally {
    console.error = original;
  }
  assert.equal(logged.length, 5);
  for (const line of logged) {
    assert.ok(!line.includes(USER), line);
    assert.ok(!line.includes(PHONE), line);
    assert.ok(!line.includes(TOKEN.split('.')[1]), line);
  }
});

// ---------------------------------------------------------------------------
// Round 2 (b280677): the amr-based freshness check.
// ---------------------------------------------------------------------------
const tokenWith = (amr: unknown) => jwt({ sub: USER, role: 'authenticated', amr });
const ago = (seconds: number) => NOW / 1000 - seconds;

test('R2: Google (oauth, as Supabase records signInWithIdToken) and phone codes both count', async () => {
  for (const method of ['otp', 'oauth']) {
    const { deps, calls } = recordingDeps();
    assert.deepEqual(await deleteAccount(tokenWith([{ method, timestamp: ago(60) }]), deps), { kind: 'deleted', files: 0 }, method);
    assert.deepEqual(calls, [`delete ${USER}`]);
  }
});

test('R2: refreshes, anonymous sessions, MFA steps and recovery links are not a sign-in', async () => {
  for (const method of ['token_refresh', 'anonymous', 'totp', 'mfa/phone', 'recovery', 'invite', 'email_change', 'OTP', '']) {
    const { deps, calls } = recordingDeps();
    assert.deepEqual(await deleteAccount(tokenWith([{ method, timestamp: ago(10) }]), deps), { kind: 'reauth-required' }, method);
    assert.deepEqual(calls, []);
  }
});

test('R2: the newest real sign-in wins; the 5-minute edge holds', async () => {
  const run = async (amr: unknown) => (await deleteAccount(tokenWith(amr), recordingDeps().deps)).kind;
  assert.equal(await run([{ method: 'otp', timestamp: ago(7200) }, { method: 'oauth', timestamp: ago(30) }]), 'deleted');
  assert.equal(await run([{ method: 'oauth', timestamp: ago(30) }, { method: 'otp', timestamp: ago(7200) }]), 'deleted');
  // A fresh refresh entry next to an old sign-in changes nothing.
  assert.equal(await run([{ method: 'otp', timestamp: ago(7200) }, { method: 'token_refresh', timestamp: ago(5) }]), 'reauth-required');
  assert.equal(await run([{ method: 'otp', timestamp: ago(299) }]), 'deleted');
  assert.equal(await run([{ method: 'otp', timestamp: ago(301) }]), 'reauth-required');
});

test('R2: a missing or garbled amr claim is stale, never an error or a pass', async () => {
  const garbled = [
    'no-dots-at-all-but-long-enough',
    'header..signature',
    `${b64url({ alg: 'ES256' })}.%%%not-base64%%%.sig`,
    `${b64url({ alg: 'ES256' })}.${Buffer.from('not json').toString('base64url')}.sig`,
    `${b64url({ alg: 'ES256' })}.${Buffer.from('null').toString('base64url')}.sig`,
    jwt({ sub: USER }),
    tokenWith('otp'),
    tokenWith({ method: 'otp', timestamp: ago(10) }),
    tokenWith([null, 42, 'otp']),
    tokenWith([{ method: 'otp', timestamp: String(ago(10)) }]),
    tokenWith([{ method: 'otp', timestamp: null }]),
    tokenWith([{ method: 'otp' }]),
    tokenWith([{ method: 'otp', timestamp: Number.NaN }]),
  ];
  for (const token of garbled) {
    const { deps, calls } = recordingDeps();
    assert.deepEqual(await deleteAccount(token, deps), { kind: 'reauth-required' }, token.slice(0, 40));
    assert.deepEqual(calls, []);
  }
});

test('R2: the token is still checked by Auth first; a forged fresh amr on a rejected token deletes nothing', async () => {
  const { deps, calls } = recordingDeps({ verifyUser: async () => null });
  assert.deepEqual(await deleteAccount(tokenWith([{ method: 'otp', timestamp: ago(1) }]), deps), { kind: 'unauthorized' });
  assert.deepEqual(calls, []);
});

test('R2: through the HTTP handler, a refreshed old session gets 403 reauth_required', async () => {
  const token = jwt({ sub: USER, role: 'authenticated', iat: ago(5), amr: [{ method: 'otp', timestamp: ago(86_400) }] });
  const response = await handle(
    new Request('https://p.supabase.co/functions/v1/delete-account', { method: 'POST', headers: { authorization: `Bearer ${token}` } }),
    configured,
    () => recordingDeps().deps,
  );
  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { error: 'reauth_required' });
});
