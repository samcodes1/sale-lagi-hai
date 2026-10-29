import assert from 'node:assert/strict';
import { test } from 'node:test';
import { classify, FcmClient, message, signedAssertion } from './fcm.ts';
import { secretsMatch } from './secret.ts';

async function testAccount() {
  const pair = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----\n`;
  return {
    account: { project_id: 'sale-lagi-hai', client_email: 'push@sale-lagi-hai.iam.gserviceaccount.com', private_key: pem },
    publicKey: pair.publicKey,
  };
}

const fromBase64url = (s: string) =>
  Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));

test('secretsMatch compares exactly', () => {
  assert.equal(secretsMatch('a'.repeat(40), 'a'.repeat(40)), true);
  assert.equal(secretsMatch('a'.repeat(39) + 'b', 'a'.repeat(40)), false);
  assert.equal(secretsMatch('a'.repeat(41), 'a'.repeat(40)), false);
  assert.equal(secretsMatch(null, 'a'.repeat(40)), false);
  assert.equal(secretsMatch('', ''), false, 'an empty secret never matches');
});

test('the OAuth assertion is a valid RS256 JWT for the FCM scope', async () => {
  const { account, publicKey } = await testAccount();
  const jwt = await signedAssertion(account, 1_800_000_000);
  const [header, claims, signature] = jwt.split('.');
  assert.deepEqual(JSON.parse(new TextDecoder().decode(fromBase64url(header))), { alg: 'RS256', typ: 'JWT' });
  const body = JSON.parse(new TextDecoder().decode(fromBase64url(claims)));
  assert.equal(body.iss, account.client_email);
  assert.equal(body.scope, 'https://www.googleapis.com/auth/firebase.messaging');
  assert.equal(body.exp - body.iat, 3600);
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', publicKey, fromBase64url(signature),
    new TextEncoder().encode(`${header}.${claims}`),
  );
  assert.equal(ok, true, 'the signature verifies with the public key');
});

test('messages carry title, body and deal id only, collapsed per deal', () => {
  const m = message({ token: 't'.repeat(30), title: 'Khaadi: 40% off', body: 'Winter sale', dealId: 'd1' });
  assert.deepEqual(m.message.notification, { title: 'Khaadi: 40% off', body: 'Winter sale' });
  assert.deepEqual(m.message.data, { type: 'deal', deal_id: 'd1' });
  assert.equal(m.message.android.collapse_key, 'd1');
  assert.equal(m.message.android.notification.channel_id, 'deal_alerts');
  assert.deepEqual(Object.keys(m.message).sort(), ['android', 'data', 'notification', 'token']);
});

test('FCM responses are classified', () => {
  assert.deepEqual(classify(200, {}), { kind: 'sent' });
  assert.deepEqual(classify(404, { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }), { kind: 'dead-token' });
  assert.deepEqual(
    classify(400, { error: { status: 'INVALID_ARGUMENT', message: 'The registration token is not a valid FCM registration token' } }),
    { kind: 'dead-token' },
  );
  assert.deepEqual(
    classify(400, { error: { status: 'INVALID_ARGUMENT', details: [{ fieldViolations: [{ field: 'message.token' }] }] } }),
    { kind: 'dead-token' },
  );
  // A bad payload field is our bug, not the token's.
  assert.deepEqual(classify(400, { error: { status: 'INVALID_ARGUMENT' } }), { kind: 'failed', status: 400 });
  assert.deepEqual(classify(429, null), { kind: 'retry' });
  assert.deepEqual(classify(503, null), { kind: 'retry' });
  assert.deepEqual(classify(403, { error: { status: 'PERMISSION_DENIED' } }), { kind: 'failed', status: 403 });
});

test('the access token is fetched once and reused until near expiry', async () => {
  const { account } = await testAccount();
  let now = 1_800_000_000_000;
  const calls: string[] = [];
  const http = (async (url: string | URL) => {
    calls.push(String(url));
    if (String(url).includes('oauth2')) {
      return new Response(JSON.stringify({ access_token: 'tok', expires_in: 3600 }), { status: 200 });
    }
    return new Response('{}', { status: 200 });
  }) as typeof fetch;
  const client = new FcmClient(account, http, () => now);
  await client.send({ token: 'x'.repeat(30), title: 't', body: null, dealId: null });
  await client.send({ token: 'y'.repeat(30), title: 't', body: null, dealId: null });
  assert.equal(calls.filter((u) => u.includes('oauth2')).length, 1);
  now += 3_550_000; // within the last minute of validity
  await client.send({ token: 'z'.repeat(30), title: 't', body: null, dealId: null });
  assert.equal(calls.filter((u) => u.includes('oauth2')).length, 2);
  assert.ok(calls.some((u) => u.endsWith('/v1/projects/sale-lagi-hai/messages:send')));
});

test('network errors are retried later, not dropped', async () => {
  const { account } = await testAccount();
  const http = (async (url: string | URL) => {
    if (String(url).includes('oauth2')) {
      return new Response(JSON.stringify({ access_token: 'tok', expires_in: 3600 }), { status: 200 });
    }
    throw new TypeError('network down');
  }) as typeof fetch;
  const result = await new FcmClient(account, http).send({ token: 'x'.repeat(30), title: 't', body: null, dealId: null });
  assert.deepEqual(result, { kind: 'retry' });
});
