"use client";

import { useRef, useState } from "react";
import { PendingButton } from "@/app/_components/PendingButton";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const selectCls =
  "w-full h-9 rounded-md border border-input bg-transparent px-3 text-sm shadow-xs";

// One entry per world the client will spawn NPCs into. Keep in sync with
// NPC_WORLDS in app/actions.ts and WORLDS in the server's routes/npcs.ts.
const WORLDS = [
  { id: "village", label: "The Hub village" },
  { id: "open_world", label: "Open world (Dustline)" },
];

// npc.gd resolves its modes as an if/elif chain, so exactly one applies.
const KINDS = [
  { id: "dialogue", label: "Just talks", hint: "Says its dialogue and nothing else." },
  { id: "trial", label: "Hands out a Trial", hint: "Offers a Trial the player can accept." },
  { id: "projects", label: "Opens the Builder Terminal", hint: "Sends the player to /projects." },
  { id: "explore", label: "Opens Explore", hint: "Sends the player to /explore." },
  { id: "project_quest", label: "Asks for any project", hint: "Nudges the player to ship something of their own." },
  { id: "faq", label: "Answers FAQs", hint: "Canned question picker sourced from the docs." },
];

// SkinUtil's nine pre-assembled characters. A custom cv1: composite can still be
// typed in by hand; the server validates either shape.
const PRESET_SKINS = Array.from({ length: 9 }, (_, i) => `cvc:${i + 1}`);

interface Bounds {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface NpcDraft {
  id?: number;
  world: string;
  pos_x: number;
  pos_y: number;
  npc_name: string;
  skin: string;
  dialogue: string;
  kind: string;
  trial_checkin: boolean;
  sidequest_id: number | null;
  quest_offer: string;
  quest_done: string;
  trial_reminder: string;
  wanders: boolean;
}

interface TrialLite {
  id: number;
  name: string;
  active: boolean;
}

interface Marker {
  world: string;
  npc_name: string;
  pos_x: number;
  pos_y: number;
}

function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <Label className="block font-normal">
      <span className="block text-sm font-medium mb-1.5">{label}</span>
      {children}
      {hint && <span className="block text-xs text-muted-foreground mt-1">{hint}</span>}
    </Label>
  );
}

export function NpcForm({
  action,
  bounds,
  trials,
  others,
  initial,
  submitLabel,
  pendingLabel,
}: {
  action: (formData: FormData) => void | Promise<void>;
  bounds: Record<string, Bounds>;
  trials: TrialLite[];
  others: Marker[];
  initial?: NpcDraft;
  submitLabel: string;
  pendingLabel: string;
}) {
  const [world, setWorld] = useState(initial?.world ?? "village");
  const [pos, setPos] = useState({
    x: initial?.pos_x ?? 0,
    y: initial?.pos_y ?? 0,
  });
  const [kind, setKind] = useState(initial?.kind ?? "dialogue");
  const [skin, setSkin] = useState(initial?.skin ?? "cvc:1");
  const imgRef = useRef<HTMLImageElement>(null);

  const b = bounds[world];

  // A click anywhere on the baked map becomes a world coordinate. The image is
  // the whole world rect, so the fraction across it maps linearly onto the
  // world's bounds - which keeps this correct at any rendered size.
  function place(e: React.MouseEvent<HTMLImageElement>) {
    const img = imgRef.current;
    if (!img || !b) return;
    const rect = img.getBoundingClientRect();
    const fx = (e.clientX - rect.left) / rect.width;
    const fy = (e.clientY - rect.top) / rect.height;
    setPos({
      x: Math.round(b.x + fx * b.w),
      y: Math.round(b.y + fy * b.h),
    });
  }

  const frac = b
    ? { left: ((pos.x - b.x) / b.w) * 100, top: ((pos.y - b.y) / b.h) * 100 }
    : { left: 50, top: 50 };
  const inFrame =
    frac.left >= 0 && frac.left <= 100 && frac.top >= 0 && frac.top <= 100;

  return (
    <form action={action} className="space-y-4">
      {initial?.id && <input type="hidden" name="id" value={initial.id} />}
      <input type="hidden" name="world" value={world} />
      <input type="hidden" name="posX" value={pos.x} />
      <input type="hidden" name="posY" value={pos.y} />
      <input type="hidden" name="kind" value={kind} />
      <input type="hidden" name="skin" value={skin} />

      <div className="grid sm:grid-cols-2 gap-4">
        <Field label="World">
          <select
            className={selectCls}
            value={world}
            onChange={(e) => setWorld(e.target.value)}
          >
            {WORLDS.map((w) => (
              <option key={w.id} value={w.id}>
                {w.label}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Name" hint="Has to be unique within its world.">
          <Input
            name="npcName"
            required
            maxLength={40}
            defaultValue={initial?.npc_name ?? ""}
            className="w-full text-sm"
          />
        </Field>
      </div>

      <div>
        <span className="block text-sm font-medium mb-1.5">
          Spot {inFrame ? "" : "(outside the map, drag it back in)"}
        </span>
        <div className="relative inline-block max-w-full overflow-x-auto rounded-md border">
          <img
            ref={imgRef}
            src={`/map/${world}.png`}
            alt={`${world} map`}
            onClick={place}
            className="block max-w-full cursor-crosshair select-none"
            style={{ imageRendering: "pixelated" }}
            draggable={false}
          />
          {others
            .filter((o) => o.world === world && o.npc_name !== initial?.npc_name && b)
            .map((o) => (
              <span
                key={o.npc_name}
                title={o.npc_name}
                className="absolute -translate-x-1/2 -translate-y-1/2 rounded-full bg-muted-foreground/70 ring-1 ring-background"
                style={{
                  left: `${((o.pos_x - b.x) / b.w) * 100}%`,
                  top: `${((o.pos_y - b.y) / b.h) * 100}%`,
                  width: 8,
                  height: 8,
                }}
              />
            ))}
          {inFrame && (
            <span
              className="absolute -translate-x-1/2 -translate-y-1/2 rounded-full bg-brand ring-2 ring-background"
              style={{ left: `${frac.left}%`, top: `${frac.top}%`, width: 12, height: 12 }}
            />
          )}
        </div>
        <div className="flex items-center gap-3 mt-2">
          <Label className="font-normal text-sm flex items-center gap-1.5">
            x
            <Input
              type="number"
              value={pos.x}
              onChange={(e) => setPos((p) => ({ ...p, x: Number(e.target.value) }))}
              className="w-24 text-sm"
            />
          </Label>
          <Label className="font-normal text-sm flex items-center gap-1.5">
            y
            <Input
              type="number"
              value={pos.y}
              onChange={(e) => setPos((p) => ({ ...p, y: Number(e.target.value) }))}
              className="w-24 text-sm"
            />
          </Label>
          <span className="text-xs text-muted-foreground">
            Click the map, or type exact coordinates.
          </span>
        </div>
      </div>

      <div className="grid sm:grid-cols-2 gap-4">
        <Field label="Skin">
          <div className="flex items-center gap-2">
            <select
              className={selectCls}
              value={PRESET_SKINS.includes(skin) ? skin : "custom"}
              onChange={(e) => setSkin(e.target.value === "custom" ? "cv1:b1h1t1o1" : e.target.value)}
            >
              {PRESET_SKINS.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
              <option value="custom">custom…</option>
            </select>
            {!PRESET_SKINS.includes(skin) && (
              <Input
                value={skin}
                onChange={(e) => setSkin(e.target.value)}
                className="w-48 text-sm font-mono"
              />
            )}
          </div>
        </Field>
        <Field label="What it does">
          <select
            className={selectCls}
            value={kind}
            onChange={(e) => setKind(e.target.value)}
          >
            {KINDS.map((k) => (
              <option key={k.id} value={k.id}>
                {k.label}
              </option>
            ))}
          </select>
          <span className="block text-xs text-muted-foreground mt-1">
            {KINDS.find((k) => k.id === kind)?.hint}
          </span>
        </Field>
      </div>

      <Field label="Dialogue" hint="One line per Dialogue box. Shown when the NPC has nothing more specific to say.">
        <Textarea
          name="dialogue"
          maxLength={1000}
          rows={2}
          defaultValue={initial?.dialogue ?? ""}
          className="w-full text-sm"
        />
      </Field>

      {kind === "trial" && (
        <div className="space-y-4 rounded-md border p-4">
          <Field
            label="Trial it hands out"
            hint="Only active Trials can actually be offered , the NPC falls back to its dialogue otherwise."
          >
            <select
              className={selectCls}
              name="sidequestId"
              defaultValue={initial?.sidequest_id ?? ""}
            >
              <option value="">, pick a Trial ,</option>
              {trials.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                  {t.active ? "" : " (hidden)"}
                </option>
              ))}
            </select>
          </Field>
          <Label className="flex items-center gap-2 font-normal text-sm">
            <input
              type="checkbox"
              name="trialCheckin"
              value="1"
              defaultChecked={initial?.trial_checkin ?? false}
              className="size-4"
            />
            Check-in copy
            <span className="text-xs text-muted-foreground">
              Hidden until the player accepts this Trial, then appears to nudge them along.
            </span>
          </Label>
          <Field label="Offer" hint="The pitch, shown before the player accepts.">
            <Textarea
              name="questOffer"
              maxLength={1500}
              rows={3}
              defaultValue={initial?.quest_offer ?? ""}
              className="w-full text-sm"
            />
          </Field>
          <div className="grid sm:grid-cols-2 gap-4">
            <Field label="Reminder" hint="Shown while the Trial is in progress.">
              <Textarea
                name="trialReminder"
                maxLength={1000}
                rows={3}
                defaultValue={initial?.trial_reminder ?? ""}
                className="w-full text-sm"
              />
            </Field>
            <Field label="On completion" hint="Shown once the Trial is finished.">
              <Textarea
                name="questDone"
                maxLength={1000}
                rows={3}
                defaultValue={initial?.quest_done ?? ""}
                className="w-full text-sm"
              />
            </Field>
          </div>
        </div>
      )}

      <Label className="flex items-center gap-2 font-normal text-sm">
        <input
          type="checkbox"
          name="wanders"
          value="1"
          defaultChecked={initial?.wanders ?? true}
          className="size-4"
        />
        Wanders around
        <span className="text-xs text-muted-foreground">
          Off pins it to the exact spot above.
        </span>
      </Label>

      <PendingButton
        className="bg-brand text-white border-transparent"
        pendingText={pendingLabel}
      >
        {submitLabel}
      </PendingButton>
    </form>
  );
}
