// Firebase Cloud Messaging HTTP v1 client. Runs on Deno (Edge Functions)
// and Node (tests): it uses only fetch and WebCrypto.
//
// Auth: a Google service account (FCM_SERVICE_ACCOUNT, the JSON key, kept
// in function secrets) signs a JWT, exchanged for an OAuth access token
// that is cached until a minute before it expires.

export type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

export type Push = {
  token: string;
  title: string;
  body: string | null;
  dealId: string | null;
};

/** What to do after sending one push. */
export type SendResult =
  | { kind: 'sent' }
  | { kind: 'dead-token' } // remove the token
  | { kind: 'retry' } // try again later (rate limited, server error, network)
  | { kind: 'failed'; status: number }; // our request was wrong; don't retry

type Fetch = typeof fetch;

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

function base64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes;
  let s = '';
  for (const b of raw) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** A signed RS256 JWT asking for the FCM scope. */
export async function signedAssertion(account: ServiceAccount, nowSeconds: number): Promise<string> {
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(JSON.stringify({
    iss: account.client_email,
    scope: SCOPE,
    aud: TOKEN_URL,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64url(new Uint8Array(signature))}`;
}

/** The FCM message for one push. No personal data: title, body, deal id. */
export function message(push: Push) {
  return {
    message: {
      token: push.token,
      notification: { title: push.title, ...(push.body ? { body: push.body } : {}) },
      data: { type: 'deal', ...(push.dealId ? { deal_id: push.dealId } : {}) },
      android: {
        priority: 'high',
        // One notification per deal on the device, replacing older ones.
        ...(push.dealId ? { collapse_key: push.dealId } : {}),
        notification: {
          channel_id: 'deal_alerts',
          ...(push.dealId ? { tag: push.dealId } : {}),
        },
      },
    },
  };
}

type FcmError = {
  status?: string;
  message?: string;
  details?: { errorCode?: string; fieldViolations?: { field?: string }[] }[];
};

/**
 * Maps an FCM v1 response to what the dispatcher should do. A token is
 * dropped only when FCM says that token is the problem: a wrong project
 * id (404 NOT_FOUND) or a bad payload field (INVALID_ARGUMENT) affects
 * every request, and must not wipe every user's devices.
 */
export function classify(status: number, body: unknown): SendResult {
  if (status >= 200 && status < 300) return { kind: 'sent' };
  // 401: our access token was rejected (revoked, clock skew); send() has
  // already fetched a fresh one once, so try again on the next run.
  if (status === 401 || status === 429 || status >= 500) return { kind: 'retry' };
  const error = (body as { error?: FcmError } | null)?.error;
  const details = error?.details ?? [];
  const codes = details.map((d) => d.errorCode);
  if (codes.includes('UNREGISTERED') || codes.includes('SENDER_ID_MISMATCH')) {
    return { kind: 'dead-token' };
  }
  const aboutToken =
    details.some((d) => (d.fieldViolations ?? []).some((v) => v.field === 'message.token')) ||
    /registration token/i.test(error?.message ?? '');
  if ((error?.status === 'INVALID_ARGUMENT' || codes.includes('INVALID_ARGUMENT')) && aboutToken) {
    return { kind: 'dead-token' };
  }
  return { kind: 'failed', status };
}

export class FcmClient {
  private token: { value: string; expiresAt: number } | null = null;
  // Concurrent first sends share one OAuth exchange.
  private pending: Promise<string> | null = null;
  private readonly account: ServiceAccount;
  private readonly http: Fetch;
  private readonly now: () => number;

  // Plain fields, not parameter properties: Node's type stripping (used by
  // the tests) only accepts erasable TypeScript.
  constructor(account: ServiceAccount, http: Fetch = fetch, now: () => number = () => Date.now()) {
    this.account = account;
    this.http = http;
    this.now = now;
  }

  async accessToken(): Promise<string> {
    if (this.token && this.token.expiresAt - 60_000 > this.now()) return this.token.value;
    this.pending ??= this.fetchAccessToken().finally(() => {
      this.pending = null;
    });
    return this.pending;
  }

  private async fetchAccessToken(): Promise<string> {
    const assertion = await signedAssertion(this.account, Math.floor(this.now() / 1000));
    const response = await this.http(TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    });
    if (!response.ok) throw new Error(`oauth token request failed: ${response.status}`);
    const json = (await response.json()) as { access_token: string; expires_in: number };
    this.token = { value: json.access_token, expiresAt: this.now() + json.expires_in * 1000 };
    return json.access_token;
  }

  async send(push: Push): Promise<SendResult> {
    const first = await this.sendOnce(push);
    if (first.kind !== 'unauthorized') return first.result;
    // FCM rejected the cached access token: forget it and try once more.
    this.token = null;
    return (await this.sendOnce(push)).result;
  }

  private async sendOnce(push: Push): Promise<{ kind: 'done' | 'unauthorized'; result: SendResult }> {
    try {
      const response = await this.http(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(this.account.project_id)}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${await this.accessToken()}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify(message(push)),
        },
      );
      let body: unknown = null;
      try {
        body = await response.json();
      } catch {
        // Non-JSON error page.
      }
      const result = classify(response.status, body);
      return { kind: response.status === 401 ? 'unauthorized' : 'done', result };
    } catch {
      return { kind: 'done', result: { kind: 'retry' } };
    }
  }
}
