import { describe, expect, test } from "bun:test";
import { buildSubmission, organizerPlatformId } from "./joe";

const project = {
  id: 42,
  name: "My Project",
  repo_url: "https://github.com/user/repo",
  demo_url: "https://demo.example.com",
  hackatime_projects: ["my-project"],
  shipped_at: "2026-08-15T12:00:00.000Z",
};

describe("organizerPlatformId", () => {
  test("combines the project id with the ship timestamp", () => {
    expect(organizerPlatformId(42, "2026-08-15T12:00:00.000Z")).toBe("pixl-42-1786795200");
  });

  test("changes when the project is re-shipped", () => {
    const first = organizerPlatformId(42, "2026-08-15T12:00:00.000Z");
    const second = organizerPlatformId(42, "2026-08-16T12:00:00.000Z");
    expect(first).not.toBe(second);
  });

  test("falls back to 0 when the project has never shipped", () => {
    expect(organizerPlatformId(42, null)).toBe("pixl-42-0");
  });
});

describe("buildSubmission", () => {
  test("prefers the slack id as the submitter", () => {
    const result = buildSubmission(project, { slack_id: "U123", email: "a@b.com" });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.submitter).toEqual({ slackId: "U123" });
  });

  test("falls back to email when there is no slack id", () => {
    const result = buildSubmission(project, { slack_id: null, email: "a@b.com" });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.submitter).toEqual({ email: "a@b.com" });
  });

  test("fails when the submitter cannot be identified", () => {
    const result = buildSubmission(project, { slack_id: null, email: null });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toContain("no slack id or email");
  });

  test("fails when there is no code link", () => {
    const result = buildSubmission({ ...project, repo_url: null }, { slack_id: "U123", email: null });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toContain("no code link");
  });

  test("omits demoLink when the project has none", () => {
    const result = buildSubmission({ ...project, demo_url: "" }, { slack_id: "U123", email: null });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.demoLink).toBeUndefined();
  });

  test("carries the hackatime projects and the dedup id", () => {
    const result = buildSubmission(project, { slack_id: "U123", email: null });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.hackatimeProjects).toEqual(["my-project"]);
    expect(result.body.organizerPlatformId).toBe("pixl-42-1786795200");
  });

  test("treats a blank slack id as missing", () => {
    const result = buildSubmission(project, { slack_id: "   ", email: "a@b.com" });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.submitter).toEqual({ email: "a@b.com" });
  });
});
