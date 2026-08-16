import type { ArchiveMatch } from "./archive.js";

export interface ImportProvenance {
  imported_ysws_entry_id: string | null;
  imported_from_ysws: string | null;
  imported_ysws_hours: number | null;
  imported_ysws_approved_at: string | null;
}

export interface DoubleDipInput {
  project: { name: string } & ImportProvenance;
  matched: ArchiveMatch | null;
  otherYsws: boolean;
  trackedSeconds: number;
}

export interface DoubleDipResult {
  systemNote: string;
  flagDetail?: string;
}

function hoursOf(seconds: number): number {
  return Math.round((seconds / 3600) * 10) / 10;
}

function suggestedCap(claimed: number, prior: number): string {
  return `suggest crediting at most ${Math.max(0, Math.round((claimed - prior) * 10) / 10)}h unless the new work is clearly separate.`;
}

export function buildDoubleDip(input: DoubleDipInput): DoubleDipResult {
  const { project, matched, otherYsws, trackedSeconds } = input;
  const claimedHours = hoursOf(trackedSeconds);

  if (matched) {
    const when = matched.approvedAt
      ? new Date(matched.approvedAt * 1000).toISOString().slice(0, 10)
      : "unknown date";
    const overlap = `It got ${matched.hours}h there (approved ${when}); the player claims ${claimedHours}h here, ${suggestedCap(claimedHours, matched.hours)}`;
    if (project.imported_ysws_entry_id) {
      return {
        systemNote: `SYSTEM: Imported from "${matched.ysws}" (${matched.url}) through the YSWS importer, so the prior ship was declared up front. ${overlap}`,
      };
    }
    if (otherYsws) {
      return {
        systemNote: `SYSTEM: Player disclosed this was submitted to "${matched.ysws}" (${matched.url}). ${overlap}`,
      };
    }
    return {
      systemNote: `SYSTEM: ${matched.url} already appears in the Hack Club YSWS archive under "${matched.ysws}" but the player did NOT disclose it. Possible double dip. ${overlap}`,
      flagDetail: `"${project.name}" shipped without disclosure: ${matched.url} found in the YSWS archive (${matched.ysws}, ${matched.hours}h)`,
    };
  }

  if (project.imported_ysws_entry_id) {
    const priorHours = Number(project.imported_ysws_hours) || 0;
    const when = project.imported_ysws_approved_at
      ? String(project.imported_ysws_approved_at).slice(0, 10)
      : "unknown date";
    return {
      systemNote: `SYSTEM: Imported from "${project.imported_from_ysws}" through the YSWS importer, but its links no longer match the archive (edited since import). It got ${priorHours}h there (approved ${when}); the player claims ${claimedHours}h here, ${suggestedCap(claimedHours, priorHours)}`,
    };
  }

  return { systemNote: "" };
}