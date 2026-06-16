import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

Deno.serve(async () => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { data: existing } = await supabase.storage.getBucket("products");
    if (existing) {
      return new Response(JSON.stringify({ ok: true, existed: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }
    const { error } = await supabase.storage.createBucket("products", {
      public: true,
      fileSizeLimit: 10485760,
    });
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true, created: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
