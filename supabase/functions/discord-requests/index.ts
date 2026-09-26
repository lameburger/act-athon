// Rewrites the pinned #part-requests Discord message with the current open requests.
// Called by a database trigger on part_requests; guarded by a shared hook secret.
import { createClient } from "npm:@supabase/supabase-js@2";

const DISCORD = "https://discord.com/api/v10";

Deno.serve(async (req) => {
  if (req.headers.get("x-hook-secret") !== Deno.env.get("HOOK_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await db
    .from("part_requests")
    .select("team,part,qty,notes,created_at")
    .eq("status", "open")
    .order("created_at", { ascending: true });
  if (error) return new Response(error.message, { status: 500 });

  const lines = (data ?? []).map((r) => {
    const t = new Date(r.created_at).toLocaleTimeString("en-US", {
      timeZone: "America/Los_Angeles", hour: "numeric", minute: "2-digit",
    });
    const qty = r.qty ? ` x${r.qty}` : "";
    const notes = r.notes ? ` - _${r.notes}_` : "";
    return `\`${t}\` **${r.team}**: ${r.part}${qty}${notes}`;
  });
  let content = `**open part requests** (${lines.length})\n` +
    (lines.length ? lines.join("\n") : "_none right now._") +
    `\n\nsubmit at <https://act-athon.com/hq/queue/>`;
  if (content.length > 1990) content = content.slice(0, 1960) + "\n_...more on the site_";

  const res = await fetch(
    `${DISCORD}/channels/${Deno.env.get("DISCORD_CHANNEL_ID")}/messages/${Deno.env.get("DISCORD_MESSAGE_ID")}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bot ${Deno.env.get("DISCORD_BOT_TOKEN")}`,
        "Content-Type": "application/json",
        "User-Agent": "DiscordBot (https://act-athon.com, 1.0)",
      },
      body: JSON.stringify({ content }),
    },
  );
  return new Response(res.ok ? "ok" : await res.text(), { status: res.ok ? 200 : 502 });
});
