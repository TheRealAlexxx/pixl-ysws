import express from "express";
import { app, receiver } from "../slack/app.js";

// Where shop-change notifications go. Defaults to the #shop-changes channel
// the team asked for; override with SHOP_NOTIFY_CHANNEL if it ever moves.
const SHOP_CHANNEL = process.env.SHOP_NOTIFY_CHANNEL || "C0BA5SAEZQS";

// Supabase Database Webhook payload for a table change.
type ShopRow = {
  id: number;
  name: string;
  description: string;
  price: number;
  image_url: string;
  options: unknown;
  active: boolean;
  position: number;
  created_by: string;
  region?: string | null;
  unlock_xp?: number | null;
};

type WebhookPayload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: ShopRow | null;
  old_record: ShopRow | null;
};

const px = (n: number | null | undefined) => `${n ?? 0}px`;
const region = (r: ShopRow) => r.region || "US";

/** Truncate long text (descriptions) so a message stays readable. */
function short(s: string, max = 140): string {
  const t = (s ?? "").replace(/\s+/g, " ").trim();
  return t.length > max ? t.slice(0, max - 1) + "…" : t;
}

/** Human-readable list of what changed between two rows on an UPDATE. */
function diffLines(oldRow: ShopRow, newRow: ShopRow): string[] {
  const lines: string[] = [];

  if (oldRow.name !== newRow.name) {
    lines.push(`• name: *${oldRow.name}* → *${newRow.name}*`);
  }
  if (oldRow.price !== newRow.price) {
    lines.push(`• price: ${px(oldRow.price)} → ${px(newRow.price)}`);
  }
  if ((oldRow.description ?? "") !== (newRow.description ?? "")) {
    lines.push(`• description:\n> _${short(oldRow.description)}_\n> ↳ ${short(newRow.description)}`);
  }
  if (!!oldRow.active !== !!newRow.active) {
    lines.push(`• ${newRow.active ? "activated ✅ (now visible in shop)" : "deactivated 🚫 (hidden from shop)"}`);
  }
  if ((oldRow.image_url ?? "") !== (newRow.image_url ?? "")) {
    lines.push(`• image updated`);
  }
  if (JSON.stringify(oldRow.options) !== JSON.stringify(newRow.options)) {
    lines.push(`• options changed`);
  }
  if ((oldRow.position ?? 0) !== (newRow.position ?? 0)) {
    lines.push(`• position: ${oldRow.position ?? 0} → ${newRow.position ?? 0}`);
  }

  return lines;
}

async function handleShopChange(payload: WebhookPayload): Promise<void> {
  if (payload.table !== "shop_items") return;

  if (payload.type === "INSERT" && payload.record) {
    const r = payload.record;
    await app.client.chat.postMessage({
      channel: SHOP_CHANNEL,
      text: `🆕 *New shop item* — *${r.name}* · ${px(r.price)} · region \`${region(r)}\`${r.active ? "" : " (inactive)"}`,
    });
    return;
  }

  if (payload.type === "DELETE" && payload.old_record) {
    const r = payload.old_record;
    await app.client.chat.postMessage({
      channel: SHOP_CHANNEL,
      text: `🗑️ *Shop item removed* — *${r.name}* (region \`${region(r)}\`)`,
    });
    return;
  }

  if (payload.type === "UPDATE" && payload.record && payload.old_record) {
    const lines = diffLines(payload.old_record, payload.record);
    if (lines.length === 0) return; // no meaningful field changed
    const r = payload.record;
    await app.client.chat.postMessage({
      channel: SHOP_CHANNEL,
      text: `✏️ *Shop item updated* — *${r.name}* (region \`${region(r)}\`)\n${lines.join("\n")}`,
    });
    return;
  }
}

// Supabase Database Webhooks POST JSON here. Optionally protect with a shared
// secret sent as a custom header (set SHOP_WEBHOOK_SECRET and add the matching
// header in the Supabase webhook config).
receiver.app.post("/webhooks/shop", express.json({ limit: "1mb" }), (req, res) => {
  const secret = process.env.SHOP_WEBHOOK_SECRET;
  if (secret) {
    const provided = req.headers["x-shop-webhook-secret"];
    if (provided !== secret) return res.status(401).send("Invalid secret");
  }
  res.status(200).send("ok");
  handleShopChange(req.body as WebhookPayload).catch((e: any) =>
    console.error("[shop-webhook]", e?.message ?? e),
  );
});
