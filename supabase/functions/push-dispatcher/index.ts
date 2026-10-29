// Edge Function entry point (Deno). Wires the handler to the database and
// FCM. Secrets (function settings): DISPATCHER_SECRET (also in Vault as
// dispatcher_secret, for pg_cron), FCM_SERVICE_ACCOUNT (JSON key).
// SUPABASE_DB_URL is provided by the platform; the private dispatcher
// functions are reached over it, so they never need exposing.
import postgres from 'npm:postgres@3.4.7';
import { FcmClient, type ServiceAccount } from '../_shared/fcm.ts';
import type { ClaimedPush, DispatchDeps } from './dispatch.ts';
import { handle } from './handler.ts';

const sql = postgres(Deno.env.get('SUPABASE_DB_URL') ?? '', { max: 2, prepare: false });
let fcm: FcmClient | null = null;

function deps(): DispatchDeps {
  fcm ??= new FcmClient(JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}') as ServiceAccount);
  const client = fcm;
  return {
    claim: async (batch) =>
      (await sql`select * from private.claim_due_pushes(${batch})`) as unknown as ClaimedPush[],
    markSent: async (ids) =>
      (await sql`select private.mark_pushes_sent(${ids}::bigint[]) as n`)[0].n as number,
    dropTokens: async (tokens) =>
      (await sql`select private.drop_push_tokens(${tokens}::text[]) as n`)[0].n as number,
    send: (push) => client.send(push),
  };
}

Deno.serve((request) => handle(request, Deno.env, deps));
