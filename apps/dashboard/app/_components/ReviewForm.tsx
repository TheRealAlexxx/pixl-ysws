"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { reviewProject } from "@/app/actions";
import {
  averageUsdPerHourOver,
  config,
  levelForRe,
  pxPerHourOver,
  reForHours,
  rePerHour,
  tierKickerUsd,
} from "@/app/_generated/config";
import { TECHNICAL_FEATURES_MIN } from "@/lib/auditNote";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";

function VerdictButtons({ secondPass }: { secondPass: boolean }) {
  const { pending } = useFormStatus();
  const [clicked, setClicked] = useState("");
  const approveLabel = secondPass ? "Approve & credit pixels" : "Approve";
  return (
    <>
      <Button
        name="verdict"
        value="approved"
        disabled={pending}
        onClick={() => setClicked("approved")}
        className="bg-emerald-600 text-white hover:bg-emerald-700"
      >
        {pending && clicked === "approved" ? "Approving…" : approveLabel}
      </Button>
      <Button
        name="verdict"
        value="needs_changes"
        disabled={pending}
        onClick={() => setClicked("needs_changes")}
        className="bg-red-600 text-white hover:bg-red-700"
      >
        {pending && clicked === "needs_changes" ? "Sending back…" : "Request changes"}
      </Button>
      <Button
        name="verdict"
        value="ban"
        disabled={pending}
        onClick={() => setClicked("ban")}
        variant="outline"
        className="border-red-700 text-red-700 hover:bg-red-50 dark:hover:bg-red-950/30"
      >
        {pending && clicked === "ban"
          ? secondPass
            ? "Banning…"
            : "Proposing…"
          : secondPass
            ? "Ban project"
            : "Propose ban"}
      </Button>
    </>
  );
}

export interface BountyOption {
  id: number;
  name: string;
  reward: number;
  description: string;
}

export interface TrialInfo {
  name: string;
  minHours: number | null;
}

export interface CollaboratorHours {
  id: number;
  name: string;
  claimedHours: number;
}

const TIERS = [
  { value: 1, label: "T1 Spark", blurb: "A simple site, script, or tiny tool" },
  { value: 2, label: "T2 Signal", blurb: "A focused app, CLI, or game with clean polish" },
  { value: 3, label: "T3 Grid", blurb: "Multiple systems together: backend, state, infra" },
  { value: 4, label: "T4 Beacon", blurb: "Deep systems work, serious scope" },
];

/**
 * The tier picker plus every conversion it implies, worked out live so a
 * reviewer never has to do the arithmetic: hours at this tier become RE, that RE
 * moves the player along the payout ramp, and the rate averaged across that move
 * times the hours is the payout. Numbers come from packages/config, and the
 * maths mirrors creditBeneficiary exactly - if these two ever disagree, the
 * reviewer is being shown a number the player won't receive.
 */
function TierAndPayout({
  hours,
  tier,
  onTier,
  playerReBefore,
}: {
  hours: number;
  tier: number;
  onTier: (t: number) => void;
  playerReBefore: number;
}) {
  const perHour = rePerHour(tier);
  const projectRe = reForHours(hours, tier);
  const reAfter = playerReBefore + projectRe;
  // Averaged across the RE this ship earns, matching creditBeneficiary exactly -
  // the rate climbs as the RE is earned rather than being read off either end.
  const rate = pxPerHourOver(playerReBefore, reAfter);
  const usdRate = averageUsdPerHourOver(playerReBefore, reAfter);
  // Flat tier bonus on the project's first hours - the thing that makes tier
  // visible on a short project, where the RE ramp alone is worth cents.
  const kickerUsd = tierKickerUsd(hours, tier);
  const kickerPx = kickerUsd / config.economy.pixelValueUsd;
  const px = Math.round(hours * rate + kickerPx);
  const usd = px * config.economy.pixelValueUsd;
  const levelBefore = levelForRe(playerReBefore);
  const levelAfter = levelForRe(reAfter);

  return (
    <div className="rounded-md border border-border bg-muted/30 p-3 space-y-2">
      <Label className="flex items-center justify-between gap-2 font-normal text-muted-foreground">
        Tier
        <select
          name="tier"
          value={tier}
          onChange={(e) => onTier(Number(e.target.value))}
          className="rounded-md border border-border bg-background px-2 py-1 text-sm"
        >
          {TIERS.map((t) => (
            <option key={t.value} value={t.value}>
              {t.label} · {rePerHour(t.value)} RE/h
            </option>
          ))}
        </select>
      </Label>
      <div className="text-xs text-muted-foreground">
        {TIERS[Math.min(Math.max(tier, 1), 4) - 1].blurb}
      </div>

      <div className="border-t border-border pt-2 space-y-1 text-sm tabular-nums">
        <div className="flex justify-between">
          <span className="text-muted-foreground">
            This project · {hours}h × {perHour} RE/h
          </span>
          <span className="font-medium">{round1(projectRe).toLocaleString()} RE</span>
        </div>
        <div className="flex justify-between">
          <span className="text-muted-foreground">Their RE before → after</span>
          <span className="font-medium">
            {round1(playerReBefore).toLocaleString()} → {round1(reAfter).toLocaleString()}
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-muted-foreground">Their level before → after</span>
          <span className="font-medium">
            {levelBefore} → {levelAfter}
            {levelAfter > levelBefore && (
              <span className="text-[color:var(--color-hc-green,green)]"> ▲</span>
            )}
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-muted-foreground">Rate (averaged over this ship)</span>
          <span className="font-medium">
            {Math.round(rate)} px/h · ${usdRate.toFixed(2)}/h
          </span>
        </div>
        {kickerPx > 0 && (
          <div className="flex justify-between">
            <span className="text-muted-foreground">
              T{tier} bonus · first {config.economy.tierKickerHours}h
            </span>
            <span className="font-medium">
              +{Math.round(kickerPx).toLocaleString()} px · ${kickerUsd.toFixed(2)}
            </span>
          </div>
        )}
        <div className="flex justify-between border-t border-border pt-1">
          <span className="font-medium">Payout</span>
          <span className="font-bold">
            {px.toLocaleString()} px · ${usd.toFixed(2)}
          </span>
        </div>
      </div>
      <p className="text-[11px] text-muted-foreground leading-snug">
        Changing the tier here saves it with your verdict. Community-goal bonuses and any
        referral boost apply on top and aren&apos;t shown.
      </p>
    </div>
  );
}

const round1 = (n: number) => Math.round(n * 10) / 10;

function CollaboratorHoursInput({ c }: { c: CollaboratorHours }) {
  const [value, setValue] = useState(c.claimedHours);
  return (
    <Label className="flex items-center justify-between gap-2 font-normal text-muted-foreground">
      {c.name}&apos;s hours to credit (decrease only)
      <Input
        name={`collabHours_${c.id}`}
        type="number"
        step="0.1"
        min="0"
        max={c.claimedHours}
        value={value}
        onChange={(e) =>
          setValue(Math.min(c.claimedHours, Math.max(0, Number(e.target.value) || 0)))
        }
        className="w-28 text-sm"
      />
    </Label>
  );
}

export function ReviewForm({
  projectId,
  repoUrl,
  demoUrl,
  claimedHours,
  defaultHours,
  secondPass = false,
  bounties = [],
  trial,
  hackatimeProjects = [],
  hackatimeSeconds = 0,
  ageFlag = false,
  collaborators = [],
  tier = 1,
  playerReBefore = 0,
}: {
  projectId: number;
  repoUrl: string | null;
  demoUrl: string | null;
  claimedHours: number;
  defaultHours?: number;
  secondPass?: boolean;
  bounties?: BountyOption[];
  trial?: TrialInfo | null;
  hackatimeProjects?: string[];
  hackatimeSeconds?: number;
  ageFlag?: boolean;
  collaborators?: CollaboratorHours[];
  /** The project's current tier (1-4). Submitted with the verdict. */
  tier?: number;
  /** The player's lifetime RE excluding this project - what sets their rate. */
  playerReBefore?: number;
}) {
  const repoOpened = useRef<HTMLInputElement>(null);
  const demoOpened = useRef<HTMLInputElement>(null);
  const repoSeconds = useRef<HTMLInputElement>(null);
  const demoSeconds = useRef<HTMLInputElement>(null);
  const totalSeconds = useRef<HTMLInputElement>(null);
  const away = useRef<{ kind: "repo" | "demo"; at: number } | null>(null);
  const openedAt = useRef(Date.now());

  const baseHours = defaultHours ?? claimedHours;
  const [hours, setHours] = useState(baseHours);
  const [tierState, setTierState] = useState(tier);
  const deflated = hours < claimedHours;

  const hackatimeDefault = useMemo(() => {
    if (hackatimeSeconds <= 0) return "";
    const h = Math.round((hackatimeSeconds / 3600) * 10) / 10;
    const names = hackatimeProjects.length ? hackatimeProjects.join(", ") : "(unnamed)";
    return `${names} , ${h}h tracked (see the Hackatime tab for the date range).`;
  }, [hackatimeProjects, hackatimeSeconds]);

  const [featuresLen, setFeaturesLen] = useState(0);

  useEffect(() => {
    openedAt.current = Date.now();
    const settle = () => {
      const a = away.current;
      if (!a || document.visibilityState !== "visible") return;
      away.current = null;
      const el = a.kind === "repo" ? repoSeconds.current : demoSeconds.current;
      if (el)
        el.value = String(
          Math.round(Number(el.value || 0) + (Date.now() - a.at) / 1000),
        );
    };
    window.addEventListener("focus", settle);
    document.addEventListener("visibilitychange", settle);
    return () => {
      window.removeEventListener("focus", settle);
      document.removeEventListener("visibilitychange", settle);
    };
  }, []);

  const markOpen = (kind: "repo" | "demo") => {
    const el = kind === "repo" ? repoOpened.current : demoOpened.current;
    if (el) el.value = "1";
    away.current = { kind, at: Date.now() };
  };

  return (
    <form
      action={reviewProject}
      onSubmit={() => {
        if (totalSeconds.current)
          totalSeconds.current.value = String(
            Math.round((Date.now() - openedAt.current) / 1000),
          );
      }}
      className="mt-4 flex flex-col gap-4"
    >
      <input type="hidden" name="projectId" value={projectId} />
      <input type="hidden" name="repoOpened" defaultValue="0" ref={repoOpened} />
      <input type="hidden" name="demoOpened" defaultValue="0" ref={demoOpened} />
      <input type="hidden" name="repoSeconds" defaultValue="0" ref={repoSeconds} />
      <input type="hidden" name="demoSeconds" defaultValue="0" ref={demoSeconds} />
      <input type="hidden" name="totalSeconds" defaultValue="0" ref={totalSeconds} />
      <div className="flex flex-wrap gap-2 items-center text-sm font-bold">
        {repoUrl && (
          <Button asChild variant="secondary">
            <a
              href={repoUrl}
              target="_blank"
              rel="noreferrer"
              onClick={() => markOpen("repo")}
            >
              Repo
            </a>
          </Button>
        )}
        {demoUrl && (
          <Button asChild variant="secondary">
            <a
              href={demoUrl}
              target="_blank"
              rel="noreferrer"
              onClick={() => markOpen("demo")}
            >
              Demo
            </a>
          </Button>
        )}
      </div>
      <Label className="flex items-center justify-between gap-2 font-normal text-muted-foreground">
        Hours to credit (decrease only)
        <Input
          name="approvedHours"
          type="number"
          step="0.1"
          min="0"
          max={claimedHours}
          value={hours}
          onChange={(e) => setHours(Math.min(claimedHours, Math.max(0, Number(e.target.value) || 0)))}
          className="w-28 text-sm"
        />
      </Label>
      {collaborators.map((c) => (
        <CollaboratorHoursInput key={c.id} c={c} />
      ))}
      <TierAndPayout
        hours={hours}
        tier={tierState}
        onTier={setTierState}
        playerReBefore={playerReBefore}
      />
      {trial?.minHours != null && (
        <div
          className={`text-xs font-medium ${
            hours < trial.minHours
              ? "text-red-600 dark:text-red-400"
              : "text-muted-foreground"
          }`}
        >
          Trial &quot;{trial.name}&quot; needs {trial.minHours}h minimum to approve
          {hours < trial.minHours ? " , credited hours are below that, so Approve will be blocked." : "."}
        </div>
      )}
      {bounties.length > 0 && (
        <div className="rounded-lg border border-amber-200 dark:border-amber-500/30 bg-amber-50/60 dark:bg-amber-500/[0.06] p-3">
          <div className="text-xs font-bold uppercase tracking-wide text-amber-700 dark:text-amber-300 mb-1.5">
            Bounty board , tick what this project meets (paid on final approval)
          </div>
          {bounties.map((b) => (
            <Label key={b.id} className="flex items-start gap-2 text-sm py-0.5 font-normal">
              <Checkbox name="bountyIds" value={String(b.id)} className="mt-0.5" />
              <span>
                {b.name} <span className="font-semibold">+{b.reward} px</span>
                {b.description && <span className="text-muted-foreground"> , {b.description}</span>}
              </span>
            </Label>
          ))}
        </div>
      )}
      <div className="rounded-lg border p-4 flex flex-col gap-4">
        <div className="text-xs font-bold uppercase tracking-wide text-muted-foreground leading-relaxed">
          Internal audit note , never shown to the player. Should let someone who
          wasn&apos;t involved reach the same conclusion you did.
        </div>
        <div>
          <Label className="text-xs font-normal text-muted-foreground mb-1.5 block leading-relaxed">
            Technical features , concrete accomplishments, not generic (&quot;OAuth
            auth, REST API, self-hosted Postgres&quot;, not &quot;React&quot;)
          </Label>
          <div className="relative">
            <Textarea
              name="technicalFeatures"
              required
              minLength={TECHNICAL_FEATURES_MIN}
              onChange={(e) => setFeaturesLen(e.target.value.trim().length)}
              placeholder="What did you actually check in the repo/demo?"
              className="w-full text-sm pb-5"
              rows={3}
            />
            <span
              className={`pointer-events-none absolute bottom-1.5 right-2 text-[10px] tabular-nums ${
                featuresLen >= TECHNICAL_FEATURES_MIN ? "text-emerald-500" : "text-muted-foreground"
              }`}
            >
              {featuresLen}/{TECHNICAL_FEATURES_MIN}
            </span>
          </div>
        </div>
        {hackatimeSeconds > 0 && (
          <div>
            <Label className="text-xs font-normal text-muted-foreground mb-1.5 block">
              Hackatime evidence
            </Label>
            <Textarea
              name="hackatimeEvidence"
              defaultValue={hackatimeDefault}
              className="w-full text-sm"
              rows={3}
            />
          </div>
        )}
        {deflated && (
          <div>
            <Label className="text-xs font-normal text-muted-foreground mb-1.5 block">
              Why lower the hours? ({claimedHours}h claimed → {hours}h credited)
            </Label>
            <Textarea
              name="deflationReason"
              required
              placeholder="Mismatched experience/features, missing commits, etc."
              className="w-full text-sm"
              rows={3}
            />
          </div>
        )}
        {ageFlag && (
          <div>
            <Label className="text-xs font-normal text-muted-foreground mb-1.5 block leading-relaxed">
              Age justification , this submitter turns 19 between shipping and this
              review
            </Label>
            <Textarea
              name="ageJustification"
              required
              placeholder="Document the submitter's age at shipping vs. now."
              className="w-full text-sm"
              rows={3}
            />
          </div>
        )}
        <div>
          <Label className="text-xs font-normal text-muted-foreground mb-1.5 block">
            Additional notes
          </Label>
          <Textarea
            name="notes"
            required
            placeholder="Anything else , suspicious commits, AI usage, experience mismatch…"
            className="w-full text-sm"
            rows={3}
          />
        </div>
      </div>
      <div className="flex flex-col gap-2">
        <Textarea
          name="note"
          required
          placeholder="Feedback for the player (required)"
          className="w-full text-sm"
          rows={3}
        />
        <div className="flex flex-wrap gap-2">
          <VerdictButtons secondPass={secondPass} />
        </div>
      </div>
    </form>
  );
}
