// QA (sub-phase 2.5): FCM error handling and dispatcher auth, written by
// QA. Tests named "QA BUG" state the expected behaviour and FAIL until the
// bug in docs/qa/2.5.md is fixed; `todo` tests are S4 findings.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { type ClaimedPush, dispatch, type DispatchDeps } from '../push-dispatcher/dispatch.ts';
import { handle } from '../push-dispatcher/handler.ts';
import { classify, FcmClient } from './fcm.ts';

async function account() {
  const pair = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----\n`;
  return { project_id: 'sale-lagi-hai', client_email: 'push@example.iam.gserviceaccount.com', private_key: pem };
}

const push = { token: 't'.repeat(30), title: 'Khaadi: 40% off', body: 'Winter sale', dealId: 'd1' };

// ---------------------------------------------------------------------------
// QA BUG 2.5-F1 (S3): any 404 counts as a dead token. A wrong project id
// (or a moved endpoint) answers 404 NOT_FOUND for every request, so one
// misconfigured deploy deletes every user's device token. Only the
// UNREGISTERED error code means the token is gone.
// ---------------------------------------------------------------------------
test('QA BUG 2.5-F1: a 404 without UNREGISTERED does not drop the token', () => {
  const wrongProject = { error: { code: 404, status: 'NOT_FOUND', message: 'Requested entity was not found.' } };
  assert.notEqual(classify(404, wrongProject).kind, 'dead-token');
  assert.notEqual(classify(404, null).kind, 'dead-token', 'an HTML 404 page is not about the token either');
});

// ---------------------------------------------------------------------------
// QA BUG 2.5-F2 (S3): INVALID_ARGUMENT about the message (not the token)
// also drops the token. A payload bug in one release would wipe every
// token. Only drop when FCM says the registration token is invalid.
// ---------------------------------------------------------------------------
test('QA BUG 2.5-F2: INVALID_ARGUMENT about a message field keeps the token', () => {
  const badField = {
    error: {
      code: 400,
      status: 'INVALID_ARGUMENT',
      message: 'Invalid value at \'message.android.notification.tag\'',
      details: [{
        '@type': 'type.googleapis.com/google.rpc.BadRequest',
        fieldViolations: [{ field: 'message.android.notification.tag', description: 'Invalid value' }],
      }],
    },
  };
  assert.notEqual(classify(400, badField).kind, 'dead-token');
});

// ---------------------------------------------------------------------------
// QA BUG 2.5-F3 (S3): 401 (our OAuth token rejected, e.g. revoked or clock
// skew) is "failed", so the push is closed and never retried, and the bad
// token stays cached for up to an hour: every push in that hour is lost.
// ---------------------------------------------------------------------------
test('QA BUG 2.5-F3: a 401 from FCM is retried, not dropped', () => {
  assert.equal(classify(401, { error: { status: 'UNAUTHENTICATED' } }).kind, 'retry');
});

test('QA BUG 2.5-F3: after a 401 the cached access token is replaced', async () => {
  let oauthCalls = 0;
  let sends = 0;
  const http = (async (url: string | URL) => {
    if (String(url).includes('oauth2')) {
      oauthCalls++;
      return new Response(JSON.stringify({ access_token: `tok${oauthCalls}`, expires_in: 3600 }), { status: 200 });
    }
    sends++;
    return sends === 1
      ? new Response(JSON.stringify({ error: { status: 'UNAUTHENTICATED' } }), { status: 401 })
      : new Response('{}', { status: 200 });
  }) as typeof fetch;
  const client = new FcmClient(await account(), http);
  await client.send(push);
  await client.send(push);
  assert.equal(oauthCalls, 2, 'a fresh token is fetched after FCM rejects the cached one');
});

// Things that held up.
test('a failing OAuth exchange is retried, never thrown into the run', async () => {
  const http = (async () => new Response('nope', { status: 500 })) as typeof fetch;
  assert.deepEqual(await new FcmClient(await account(), http).send(push), { kind: 'retry' });
});

test('a secret that differs only in a multi-byte character is rejected', async () => {
  const secret = `${'a'.repeat(40)}é`;
  const env = { get: (k: string) => (k === 'DISPATCHER_SECRET' ? secret : undefined) };
  const req = new Request('https://x.supabase.co/functions/v1/push-dispatcher', {
    method: 'POST',
    headers: { 'x-dispatcher-secret': `${'a'.repeat(40)}e` },
  });
  let ran = false;
  const res = await handle(req, env, () => { ran = true; throw new Error('must not run'); });
  assert.equal(res.status, 401);
  assert.equal(ran, false);
});

test('the run summary carries counts only (no tokens, titles or ids)', async () => {
  const rows: ClaimedPush[] = [
    { outbox_id: 7, token: 'secret-device-token-123456', platform: 'android', title: 'Khaadi: 40% off', body: 'x', deal_id: 'deal-1' },
  ];
  const deps: DispatchDeps = {
    claim: async () => rows,
    markSent: async (ids) => ids.length,
    dropTokens: async (t) => t.length,
    send: async () => ({ kind: 'dead-token' }),
  };
  const text = JSON.stringify(await dispatch(deps));
  for (const leak of ['secret-device-token', 'Khaadi', 'deal-1']) assert.ok(!text.includes(leak), leak);
});

// ---------------------------------------------------------------------------
// S4 findings (todo).
// ---------------------------------------------------------------------------
test('QA 2.5-F4 (S4): 20 concurrent first sends share one OAuth exchange', async () => {
  let oauthCalls = 0;
  const http = (async (url: string | URL) => {
    if (String(url).includes('oauth2')) {
      oauthCalls++;
      await new Promise((r) => setTimeout(r, 5));
      return new Response(JSON.stringify({ access_token: 'tok', expires_in: 3600 }), { status: 200 });
    }
    return new Response('{}', { status: 200 });
  }) as typeof fetch;
  const client = new FcmClient(await account(), http);
  await Promise.all(Array.from({ length: 20 }, () => client.send(push)));
  assert.equal(oauthCalls, 1);
});

test('QA 2.5-F5 (S4): SENDER_ID_MISMATCH (token of another Firebase project) drops the token', () => {
  const body = { error: { status: 'PERMISSION_DENIED', details: [{ errorCode: 'SENDER_ID_MISMATCH' }] } };
  assert.equal(classify(403, body).kind, 'dead-token');
});

// ---------------------------------------------------------------------------
// Round 2 (commit 50a4ac6).
// ---------------------------------------------------------------------------

// QA BUG 2.5-F6 (S3): SENDER_ID_MISMATCH now drops the token (F5, which
// QA suggested in round 1). If the deployed FCM_SERVICE_ACCOUNT belongs to
// another Firebase project (a staging key on prod: one project per
// flavor), every token answers SENDER_ID_MISMATCH and one run deletes
// every user's devices. Expected: a run where (nearly) every send comes
// back dead drops nothing and fails loudly, because that signals our
// configuration, not the devices.
test('QA BUG 2.5-F6: a run where every send is a dead token drops nothing', async () => {
  const rows: ClaimedPush[] = Array.from({ length: 50 }, (_, i) => ({
    outbox_id: i, token: `device-token-${i}-xxxxxxxxxxxx`, platform: 'android', title: 't', body: null, deal_id: null,
  }));
  const dropped: string[] = [];
  const deps: DispatchDeps = {
    claim: async () => rows,
    markSent: async (ids) => ids.length,
    dropTokens: async (tokens) => { dropped.push(...tokens); return tokens.length; },
    send: async () => classify(403, { error: { status: 'PERMISSION_DENIED', details: [{ errorCode: 'SENDER_ID_MISMATCH' }] } }),
  };
  try {
    await dispatch(deps);
  } catch {
    // Failing the run loudly is fine too.
  }
  assert.equal(dropped.length, 0, `dropped ${dropped.length} of 50 tokens in one run`);
});

// Checked in round 2: a burst of concurrent 401s shares one token refresh.
test('a burst of 401s refreshes the access token once', async () => {
  let oauthCalls = 0;
  let rejected = 0;
  const http = (async (url: string | URL) => {
    if (String(url).includes('oauth2')) {
      oauthCalls++;
      await new Promise((r) => setTimeout(r, 2));
      return new Response(JSON.stringify({ access_token: `tok${oauthCalls}`, expires_in: 3600 }), { status: 200 });
    }
    await new Promise((r) => setTimeout(r, 2));
    if (rejected < 10) {
      rejected++;
      return new Response(JSON.stringify({ error: { status: 'UNAUTHENTICATED' } }), { status: 401 });
    }
    return new Response('{}', { status: 200 });
  }) as typeof fetch;
  const client = new FcmClient(await account(), http);
  await client.send(push); // warm the cache
  oauthCalls = 0;
  await Promise.all(Array.from({ length: 10 }, () => client.send(push)));
  assert.equal(oauthCalls, 1);
});

// ---------------------------------------------------------------------------
// Round 3 (commit 9746349).
// ---------------------------------------------------------------------------

// QA BUG 2.5-F6b (S3): the breaker needs at least 10 sends in one run. At
// launch volume a run often has fewer, and then a wrong-project service
// account still drops every token it touches: each user loses their device
// on their next push, and a day of alerts wipes the active user base.
// Expected: SENDER_ID_MISMATCH for every send in a run is never enough
// evidence to drop a token, whatever the run size.
test('QA BUG 2.5-F6b: a small run where every send is SENDER_ID_MISMATCH drops nothing', async () => {
  const rows: ClaimedPush[] = Array.from({ length: 9 }, (_, i) => ({
    outbox_id: i, token: `device-token-${i}-xxxxxxxxxxxx`, platform: 'android', title: 't', body: null, deal_id: null,
  }));
  const dropped: string[] = [];
  const deps: DispatchDeps = {
    claim: async () => rows,
    markSent: async (ids) => ids.length,
    dropTokens: async (tokens) => { dropped.push(...tokens); return tokens.length; },
    send: async () => classify(403, { error: { status: 'PERMISSION_DENIED', details: [{ errorCode: 'SENDER_ID_MISMATCH' }] } }),
  };
  await dispatch(deps);
  assert.equal(dropped.length, 0, `dropped ${dropped.length} of 9 tokens in one run`);
});

// Checked in round 3: UNREGISTERED tokens in a run with a few failures are
// still dropped (the breaker doesn't stop normal cleanup).
test('a run with 2 of 20 tokens unregistered drops exactly those 2', async () => {
  const rows: ClaimedPush[] = Array.from({ length: 20 }, (_, i) => ({
    outbox_id: i, token: `device-token-${i}-xxxxxxxxxxxx`, platform: 'android', title: 't', body: null, deal_id: null,
  }));
  const dropped: string[] = [];
  const deps: DispatchDeps = {
    claim: async () => rows,
    markSent: async (ids) => ids.length,
    dropTokens: async (tokens) => { dropped.push(...tokens); return tokens.length; },
    send: async (p) => (p.token.startsWith('device-token-1-') || p.token.startsWith('device-token-2-')
      ? classify(404, { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } })
      : { kind: 'sent' }),
  };
  const summary = await dispatch(deps);
  assert.equal(summary.breakerTripped, false);
  assert.deepEqual(dropped.sort(), ['device-token-1-xxxxxxxxxxxx', 'device-token-2-xxxxxxxxxxxx']);
});
