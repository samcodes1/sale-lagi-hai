// Account deletion (sub-phase 4.2, a Play requirement). The steps, in the
// order Supabase needs them:
// 1. who is asking (their access token, checked by the Auth server);
// 2. that they signed in recently (a fresh OTP or Google sign-in), so a
//    stolen or left-open session can't delete the account;
// 3. their private files (avatars, submission photos), removed through
//    the Storage API: Supabase refuses to delete a user who owns objects;
// 4. the auth user. `on delete cascade` removes every row of theirs.

/** A sign-in older than this needs repeating before deletion. */
export const REAUTH_WINDOW_MS = 5 * 60 * 1000;

export type AuthUser = { id: string; lastSignInAt: string | null };
export type StoredFile = { bucket_id: string; name: string };

export type AccountDeps = {
  /** The user the token belongs to, or null for a bad or expired token. */
  verifyUser: (accessToken: string) => Promise<AuthUser | null>;
  listPrivateFiles: (userId: string) => Promise<StoredFile[]>;
  removeFiles: (bucket: string, names: string[]) => Promise<void>;
  deleteUser: (userId: string) => Promise<void>;
  now: () => number;
};

export type DeleteOutcome =
  | { kind: 'deleted'; files: number }
  | { kind: 'unauthorized' }
  | { kind: 'reauth-required' };

/** Storage deletes take at most this many names per call. */
const BATCH = 100;

export async function deleteAccount(accessToken: string, deps: AccountDeps): Promise<DeleteOutcome> {
  const user = await deps.verifyUser(accessToken);
  if (!user) return { kind: 'unauthorized' };

  const signedIn = user.lastSignInAt ? Date.parse(user.lastSignInAt) : NaN;
  if (!Number.isFinite(signedIn) || deps.now() - signedIn > REAUTH_WINDOW_MS) {
    return { kind: 'reauth-required' };
  }

  const files = await deps.listPrivateFiles(user.id);
  const byBucket = new Map<string, string[]>();
  for (const f of files) byBucket.set(f.bucket_id, [...(byBucket.get(f.bucket_id) ?? []), f.name]);
  for (const [bucket, names] of byBucket) {
    for (let i = 0; i < names.length; i += BATCH) {
      await deps.removeFiles(bucket, names.slice(i, i + BATCH));
    }
  }

  await deps.deleteUser(user.id);
  return { kind: 'deleted', files: files.length };
}

type Fetch = typeof fetch;

/** [AccountDeps] over the Auth, PostgREST and Storage HTTP APIs. */
export function supabaseDeps(url: string, serviceKey: string, http: Fetch = fetch): AccountDeps {
  const admin = { apikey: serviceKey, authorization: `Bearer ${serviceKey}` };
  async function ok(response: Response, what: string): Promise<Response> {
    if (!response.ok) throw new Error(`${what} failed: ${response.status}`);
    return response;
  }
  return {
    async verifyUser(accessToken) {
      const response = await http(`${url}/auth/v1/user`, {
        headers: { apikey: serviceKey, authorization: `Bearer ${accessToken}` },
      });
      if (response.status === 401 || response.status === 403) return null;
      const body = (await (await ok(response, 'auth user')).json()) as {
        id?: unknown;
        last_sign_in_at?: unknown;
      };
      if (typeof body.id !== 'string') return null;
      return {
        id: body.id,
        lastSignInAt: typeof body.last_sign_in_at === 'string' ? body.last_sign_in_at : null,
      };
    },
    async listPrivateFiles(userId) {
      const response = await http(`${url}/rest/v1/rpc/prepare_account_deletion`, {
        method: 'POST',
        headers: { ...admin, 'content-type': 'application/json' },
        body: JSON.stringify({ target: userId }),
      });
      return (await (await ok(response, 'prepare_account_deletion')).json()) as StoredFile[];
    },
    async removeFiles(bucket, names) {
      await ok(
        await http(`${url}/storage/v1/object/${encodeURIComponent(bucket)}`, {
          method: 'DELETE',
          headers: { ...admin, 'content-type': 'application/json' },
          body: JSON.stringify({ prefixes: names }),
        }),
        'storage delete',
      );
    },
    async deleteUser(userId) {
      await ok(
        await http(`${url}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
          method: 'DELETE',
          headers: admin,
        }),
        'auth delete',
      );
    },
    now: () => Date.now(),
  };
}
