// The edge runtime's main service on Railway: routes /<function> to that
// function as a user worker. Only the functions listed here can run, and
// each checks its own caller (a shared secret or the user's token), as on
// hosted Supabase with verify_jwt = false.
const FUNCTIONS = new Set(['ingest', 'ingest-batch', 'push-dispatcher', 'delete-account']);

// Variables the functions read; nothing else from this service reaches them.
const PASSED = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SUPABASE_DB_URL',
  'DISPATCHER_SECRET',
  'INGEST_BATCH_SECRET',
  'FCM_SERVICE_ACCOUNT',
];

declare const EdgeRuntime: {
  userWorkers: {
    create(options: {
      servicePath: string;
      memoryLimitMb: number;
      workerTimeoutMs: number;
      noModuleCache: boolean;
      envVars: [string, string][];
      forceCreate: boolean;
    }): Promise<{ fetch(request: Request): Promise<Response> }>;
  };
};

Deno.serve(async (request) => {
  const name = new URL(request.url).pathname.split('/').filter(Boolean)[0] ?? '';
  if (name === '_health') return new Response('ok');
  if (!FUNCTIONS.has(name)) {
    return new Response(JSON.stringify({ error: 'not_found' }), { status: 404, headers: { 'content-type': 'application/json' } });
  }
  const envVars = PASSED.flatMap((k): [string, string][] => {
    const v = Deno.env.get(k);
    return v === undefined ? [] : [[k, v]];
  });
  try {
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: `/home/deno/functions/${name}`,
      memoryLimitMb: 256,
      // ingest runs for up to 2 minutes.
      workerTimeoutMs: 150_000,
      noModuleCache: false,
      envVars,
      forceCreate: false,
    });
    return await worker.fetch(request);
  } catch (error) {
    console.error('worker failed', name, error instanceof Error ? error.name : 'error');
    return new Response(JSON.stringify({ error: 'worker_failed' }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
