import { supabase } from "./db/client.js";
import {
  MAX_LEVEL,
  levelForRe,
  payoutUsdPerHour,
  pxPerHourFor,
  rePerHour,
  reForHours,
  reForProject,
  reForLevel,
} from "./config.generated.js";

// The economy in one line: a project's *tier* (1-4, how ambitious it is) decides
// how much Restoration Energy each hour is worth, RE decides your hourly payout,
// and your level is just a display of RE. Every number lives in
// packages/config/pixl.json - change it there and run `bun run config:sync`.
//
// Note on naming: the database column is `projects.level` and holds the tier
// (1-4). It was named before the player-facing 1-100 level existed. Renaming the
// column is not worth a migration - `tier` is the word everywhere else.
export {
  MAX_LEVEL,
  levelForRe,
  payoutUsdPerHour,
  pxPerHourFor,
  rePerHour,
  reForHours,
  reForProject,
  reForLevel,
};

interface ProjectRow {
  approved_hours: number | null;
  hackatime_seconds: number | null;
  level: number | null;
  sidequest_id: number | null;
}

// approved_hours is set by a reviewer; before that lands, fall back to whatever
// Hackatime tracked. Same precedence the payout path uses.
function hoursOf(p: ProjectRow): number {
  const h =
    p.approved_hours != null
      ? Number(p.approved_hours)
      : (Number(p.hackatime_seconds) || 0) / 3600;
  return Number.isFinite(h) ? h : 0;
}

function reOf(p: ProjectRow): number {
  return reForProject(hoursOf(p), Number(p.level) || 1, p.sidequest_id != null);
}

const round1 = (n: number) => Math.round(n * 10) / 10;

/** Lifetime approved hours - the raw work, before any tier weighting. */
export async function approvedHoursFor(
  userId: string,
  excludeProjectId?: number,
): Promise<number> {
  const rows = await approvedProjectsFor(userId, excludeProjectId);
  return round1(rows.reduce((s, p) => s + hoursOf(p), 0));
}

/**
 * Lifetime Restoration Energy - hours weighted by the tier they were shipped at.
 * This is what drives both the payout rate and the player's level.
 */
export async function lifetimeRe(userId: string, excludeProjectId?: number): Promise<number> {
  const rows = await approvedProjectsFor(userId, excludeProjectId);
  return round1(rows.reduce((s, p) => s + reOf(p), 0));
}

async function approvedProjectsFor(
  userId: string,
  excludeProjectId?: number,
): Promise<ProjectRow[]> {
  let q = supabase
    .from("projects")
    .select("id, approved_hours, hackatime_seconds, level, sidequest_id")
    .eq("user_id", userId)
    .eq("status", "approved")
    .is("banned_at", null);
  if (excludeProjectId) q = q.neq("id", excludeProjectId);
  const { data } = await q;
  return (data ?? []) as ProjectRow[];
}

/** Level from lifetime RE, for a player. */
export async function levelFor(userId: string, excludeProjectId?: number): Promise<number> {
  return levelForRe(await lifetimeRe(userId, excludeProjectId));
}

// Total Restoration Energy pooled by the whole community - every approved
// project's tier-weighted hours, summed. Drives the Core Vault's community goals.
//
// This is tier-weighted now, so it is NOT the same unit as the old
// hours-only total. vault_levels.energy_required was seeded in raw hours and has
// to be rescaled to match (roughly x12.5 on the expected tier mix, but that
// factor moves with the mix - the thresholds were flagged as guesses anyway).
export async function communityEnergy(): Promise<number> {
  const { data } = await supabase
    .from("projects")
    .select("approved_hours, hackatime_seconds, level, sidequest_id")
    .eq("status", "approved")
    .is("banned_at", null);
  return Math.round((data ?? []).reduce((s, p) => s + reOf(p as ProjectRow), 0));
}
