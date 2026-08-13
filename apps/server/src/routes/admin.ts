import { Router, type Request } from "express";
import { timingSafeEqual } from "crypto";
import { listOnlinePlayers, kickPlayer } from "../ws/gameServer.js";

const router = Router();

// Dashboard-to-server admin API, guarded by a shared secret.
function authorized(req: Request): boolean {
  const key = process.env.ADMIN_API_KEY;
  const given = req.header("x-admin-key") ?? "";
  if (!key || !given) return false;
  const a = Buffer.from(given);
  const b = Buffer.from(key);
  return a.length === b.length && timingSafeEqual(a, b);
}

router.get("/api/admin/online", (req, res) => {
  if (!authorized(req)) return res.status(401).json({ ok: false });
  res.json({ ok: true, players: listOnlinePlayers() });
});

router.post("/api/admin/kick", (req, res) => {
  if (!authorized(req)) return res.status(401).json({ ok: false });
  const userId = String(req.body?.userId ?? "");
  const reason = String(req.body?.reason ?? "").slice(0, 100);
  if (!userId) return res.status(400).json({ ok: false, error: "userId required" });
  const kicked = kickPlayer(
    userId,
    reason ? `Kicked by a moderator: ${reason}` : "",
  );
  res.json({ ok: true, kicked });
});

export default router;
