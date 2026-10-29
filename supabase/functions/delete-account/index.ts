// Edge Function entry point (Deno). SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY are provided by the platform; the service key
// never leaves the function.
import { supabaseDeps } from './account.ts';
import { handle } from './handler.ts';

Deno.serve((request) => handle(request, Deno.env, (url, key) => supabaseDeps(url, key)));
