// Joe (joe.fraud.hackclub.com) is the second review pass: we submit a project
// after its first pass and their fraud team scores it. Every outbound call to
// Joe lives here.

const DEFAULT_BASE = "https://joe.fraud.hackclub.com/api/v1/ysws";

export interface JoeConfig {
  base: string;
  eventId: string;
  apiKey: string;
}

export interface JoeSubmission {
  name: string;
  codeLink: string;
  demoLink?: string;
  submitter: { slackId: string } | { email: string };
  hackatimeProjects: string[];
  organizerPlatformId: string;
}

export interface SubmittableProject {
  id: number;
  name: string;
  repo_url: string | null;
  demo_url: string | null;
  hackatime_projects: string[] | null;
  shipped_at: string | null;
}

export interface SubmittableOwner {
  slack_id: string | null;
  email: string | null;
}

export type BuildResult =
  | { ok: true; body: JoeSubmission }
  | { ok: false; error: string };

// Unset config disables the whole fraud pass: pass 1 goes straight to
// second_review, exactly as it did before Joe existed.
export function joeConfig(): JoeConfig | null {
  const eventId = (process.env.JOE_EVENT_ID ?? "").trim();
  const apiKey = (process.env.JOE_API_KEY ?? "").trim();
  if (!eventId || !apiKey) return null;
  const base = (process.env.JOE_API_BASE ?? "").trim() || DEFAULT_BASE;
  return { base: base.replace(/\/+$/, ""), eventId, apiKey };
}

export function joeEnabled(): boolean {
  return joeConfig() !== null;
}

// shipped_at is refreshed on every ship, so a re-shipped project gets a fresh
// Joe record instead of colliding with its previous one, while a retried POST
// within the same ship deduplicates to Joe's 200 response.
export function organizerPlatformId(projectId: number, shippedAt: string | null): string {
  const ms = shippedAt ? Date.parse(shippedAt) : NaN;
  const seconds = Number.isFinite(ms) ? Math.floor(ms / 1000) : 0;
  return `pixl-${projectId}-${seconds}`;
}

function clean(value: string | null | undefined): string {
  return String(value ?? "").trim();
}

export function buildSubmission(
  project: SubmittableProject,
  owner: SubmittableOwner,
): BuildResult {
  const codeLink = clean(project.repo_url);
  if (!codeLink) return { ok: false, error: "project has no code link" };

  const slackId = clean(owner.slack_id);
  const email = clean(owner.email);
  if (!slackId && !email)
    return { ok: false, error: "submitter has no slack id or email" };

  const demoLink = clean(project.demo_url);
  return {
    ok: true,
    body: {
      name: project.name,
      codeLink,
      ...(demoLink ? { demoLink } : {}),
      submitter: slackId ? { slackId } : { email },
      hackatimeProjects: project.hackatime_projects ?? [],
      organizerPlatformId: organizerPlatformId(project.id, project.shipped_at),
    },
  };
}
