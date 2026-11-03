# Supabase Edge Functions for the self-hosted stack on Railway. Build from
# the repository root: the functions come from supabase/functions.
FROM supabase/edge-runtime:v1.77.9
COPY supabase/functions /home/deno/functions
COPY deploy/edge-runtime/main /home/deno/functions/main
EXPOSE 9000
# Railway's private network is IPv6.
CMD ["start", "--main-service", "/home/deno/functions/main", "--ip", "::", "--port", "9000"]
