import { Router } from "express";
import { supabase } from "../db/client.js";

const router = Router();

// Program news, written from the dashboard. Deliberately unauthenticated: every
// player sees the same posts, so there's nothing here worth a session check.
router.get("/api/news", async (_req, res) => {
  const { data, error } = await supabase
    .from("news")
    .select("id, body, link_url, posted_at")
    .eq("active", true)
    .order("posted_at", { ascending: false })
    .limit(20);
  if (error) {
    console.error("[news] list failed", error);
    return res.status(500).json({ ok: false });
  }
  res.json({ ok: true, news: data ?? [] });
});

export default router;
