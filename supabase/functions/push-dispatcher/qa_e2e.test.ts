// QA, Phase 2 full-phase gate: the push dispatcher end to end against a
// real database. The planner's SQL output is claimed by the real
// handler → dispatch → FcmClient path; only FCM's HTTP endpoints are fake.
// It talks to Postgres through psql, so it needs a running database:
//   tool/db_test.sh --keep supabase/tests/database/000_setup.test.sql
//   PGHOST=… PGPORT=… PGUSER=postgres PGDATABASE=postgres \
//     node --experimental-strip-types --no-warnings --test supabase/functions/push-dispatcher/qa_e2e.test.ts
// Without PGHOST (the CI edge-functions job) the test is skipped.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';
import { FcmClient } from '../_shared/fcm.ts';
import type { ClaimedPush, DispatchDeps } from './dispatch.ts';
import { handle } from './handler.ts';

const haveDb = Boolean(process.env.PGHOST);

function psql(sql: string): string {
  return execFileSync('psql', ['-X', '-At', '-q', '-v', 'ON_ERROR_STOP=1', '-c', sql], { encoding: 'utf8' }).trim();
}
const lit = (s: string) => `'${s.replace(/'/g, "''")}'`;

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

test('planned pushes go out through the real dispatcher; dead devices are dropped', { skip: !haveDb && 'no PGHOST' }, async () => {
  const user = psql(`select gen_random_uuid()`);
  const live = `qa-e2e-live-${user}`;
  const dead = `qa-e2e-dead-${user}`;
  psql(`insert into auth.users (id) values (${lit(user)});
        insert into public.push_tokens (token, user_id, platform) values (${lit(live)}, ${lit(user)}, 'android'),
                                                                          (${lit(dead)}, ${lit(user)}, 'android');
        insert into private.push_outbox (user_id, local_day, title, body, send_at)
          values (${lit(user)}, current_date, 'Chai Corner: 41% off', 'Karak chai and paratha', now() - interval '1 minute');`);
  try {
    const sent: string[] = [];
    const http = (async (url: string | URL, init?: RequestInit) => {
      if (String(url).includes('oauth2')) {
        return new Response(JSON.stringify({ access_token: 'tok', expires_in: 3600 }), { status: 200 });
      }
      const body = JSON.parse(String(init?.body)) as { message: { token: string; notification: { title: string } } };
      sent.push(body.message.token);
      return body.message.token === dead
        ? new Response(JSON.stringify({ error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }), { status: 404 })
        : new Response('{}', { status: 200 });
    }) as typeof fetch;
    const client = new FcmClient(await account(), http);
    const deps: DispatchDeps = {
      claim: async (batch) =>
        JSON.parse(psql(`select coalesce(json_agg(t), '[]') from private.claim_due_pushes(${batch}) t
                         where t.token like 'qa-e2e-%'`)) as ClaimedPush[],
      markSent: async (ids) => Number(psql(`select private.mark_pushes_sent(array[${ids.join(',')}]::bigint[])`)),
      dropTokens: async (tokens) => Number(psql(`select private.drop_push_tokens(array[${tokens.map(lit).join(',')}])`)),
      send: (push) => client.send(push),
    };
    const secret = 's'.repeat(40);
    const res = await handle(
      new Request('https://x.supabase.co/functions/v1/push-dispatcher', { method: 'POST', headers: { 'x-dispatcher-secret': secret } }),
      { get: (k) => (k === 'DISPATCHER_SECRET' ? secret : undefined) },
      () => deps,
    );
    assert.equal(res.status, 200);
    const summary = await res.json();
    assert.equal(summary.sent, 1, 'the push reached the live device');
    assert.equal(summary.deadTokens, 1);
    assert.deepEqual(sent.sort(), [dead, live].sort(), 'one FCM request per device');
    assert.equal(psql(`select count(*) from private.push_outbox where user_id = ${lit(user)} and sent_at is not null`), '1',
      'the outbox row is marked sent');
    assert.equal(psql(`select string_agg(token, ',') from public.push_tokens where user_id = ${lit(user)}`), live,
      'only the dead token is gone');
    // A second run finds nothing due.
    const again = await (await handle(
      new Request('https://x.supabase.co/functions/v1/push-dispatcher', { method: 'POST', headers: { 'x-dispatcher-secret': secret } }),
      { get: (k) => (k === 'DISPATCHER_SECRET' ? secret : undefined) },
      () => deps,
    )).json();
    assert.equal(again.claimed, 0, 'nothing is sent twice');
  } finally {
    psql(`delete from auth.users where id = ${lit(user)}`);
  }
});
