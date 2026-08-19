import { db } from "./db";
import { joeEnabled, submitProject } from "./joe";
import { outcomePatch, type IncomingOutcome } from "./joeOutcome";

// Push a first-passed project to Joe. Never throws and never blocks the
// verdict: a failed submission is stored on the row and the reconcile job
// retries it, so a network blip cannot strand a reviewer mid-verdict.
export async function submitToJoe(projectId: number): Promise<void> {
  if (!joeEnabled()) return;
  const { data: project } = await db
    .from("projects")
    .select("id, name, repo_url, demo_url, hackatime_projects, shipped_at, user_id")
    .eq("id", projectId)
    .maybeSingle();
  if (!project) return;
  const { data: owner } = await db
    .from("users")
    .select("slack_id, email")
    .eq("id", project.user_id as string)
    .maybeSingle();

  const result = await submitProject(
    {
      id: project.id as number,
      name: String(project.name),
      repo_url: (project.repo_url as string | null) ?? null,
      demo_url: (project.demo_url as string | null) ?? null,
      hackatime_projects: (project.hackatime_projects as string[] | null) ?? [],
      shipped_at: (project.shipped_at as string | null) ?? null,
    },
    { slack_id: owner?.slack_id ?? null, email: owner?.email ?? null },
  );

  if (result.ok) {
    await db
      .from("projects")
      .update({
        joe_project_id: result.joeProjectId,
        joe_submitted_at: new Date().toISOString(),
        joe_error: "",
      })
      .eq("id", projectId);
    return;
  }
  console.error("joe submit failed", projectId, result.error);
  await db.from("projects").update({ joe_error: result.error }).eq("id", projectId);
}

// Applies an outcome to one project. Idempotent: the status guard means a
// repeated delivery refreshes the joe_* fields and moves nothing.
export async function applyOutcome(
  projectId: number,
  currentStatus: string,
  outcome: IncomingOutcome,
): Promise<{ applied: boolean; advanced: boolean }> {
  const patch = outcomePatch(currentStatus, outcome);
  if (!patch) return { applied: false, advanced: false };

  const query = db.from("projects").update(patch).eq("id", projectId);
  const { error } = patch.status
    ? await query.eq("status", "fraud_review")
    : await query;
  if (error) {
    console.error("applyOutcome failed", projectId, error.message);
    return { applied: false, advanced: false };
  }
  return { applied: true, advanced: Boolean(patch.status) };
}
