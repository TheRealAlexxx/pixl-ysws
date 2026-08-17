"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { acknowledgeGuidelines } from "@/app/actions";

interface Page {
  title: string;
  url: string;
}

// First-time reviewer gate: the reviewer must OPEN each guideline page (live
// GitBook, new tab), spend at least `minSeconds` on it, then tick "read". Only
// once every page is ticked does the confirm button (a form calling the server
// action) enable.
export function GuidelinesGate({
  pages,
  minSeconds,
}: {
  pages: Page[];
  minSeconds: number;
}) {
  const [openedAt, setOpenedAt] = useState<(number | null)[]>(() =>
    pages.map(() => null),
  );
  const [read, setRead] = useState<boolean[]>(() => pages.map(() => false));
  // A ticking clock so the per-page countdowns re-render each second.
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 500);
    return () => clearInterval(id);
  }, []);

  const remaining = (i: number) => {
    const at = openedAt[i];
    if (at == null) return minSeconds;
    return Math.max(0, minSeconds - Math.floor((now - at) / 1000));
  };
  const eligible = (i: number) => openedAt[i] != null && remaining(i) === 0;

  function openPage(i: number) {
    window.open(pages[i].url, "_blank", "noopener,noreferrer");
    if (openedAt[i] == null) {
      setOpenedAt((prev) => prev.map((v, j) => (j === i ? Date.now() : v)));
    }
  }

  const readCount = read.filter(Boolean).length;
  const allRead = read.every(Boolean); // [].every === true guards an empty list

  return (
    <div className="mx-auto max-w-3xl space-y-6 py-8">
      <div className="space-y-2">
        <h1 className="text-2xl font-semibold">Before you review</h1>
        <p className="text-muted-foreground text-sm">
          Reviewing decides whether real people get paid, so everyone reads the
          YSWS Project Submission Guidelines once before joining the queue. Open
          each page, spend at least {minSeconds}s on it, then mark it read. This
          only happens the first time (and again if the guidelines change).
        </p>
      </div>

      <div className="text-sm font-medium">
        {readCount} / {pages.length} pages read
      </div>

      <div className="space-y-3">
        {pages.map((p, i) => {
          const rem = remaining(i);
          const ok = eligible(i);
          return (
            <Card key={p.url} className="flex items-center gap-4 p-4">
              <div className="min-w-0 flex-1">
                <div className="truncate font-medium">{p.title}</div>
                <div className="text-muted-foreground text-xs">
                  {openedAt[i] == null
                    ? "Not opened yet"
                    : rem > 0
                      ? `Keep reading… ${rem}s left`
                      : "Minimum time reached"}
                </div>
              </div>
              <Button
                type="button"
                variant={openedAt[i] == null ? "default" : "secondary"}
                onClick={() => openPage(i)}
              >
                {openedAt[i] == null ? "Open page ↗" : "Reopen ↗"}
              </Button>
              <label className="flex items-center gap-2 text-sm select-none">
                <Checkbox
                  checked={read[i]}
                  disabled={!ok}
                  onCheckedChange={(v) =>
                    setRead((prev) =>
                      prev.map((r, j) => (j === i ? v === true : r)),
                    )
                  }
                />
                Read
              </label>
            </Card>
          );
        })}
      </div>

      <form action={acknowledgeGuidelines}>
        <Button type="submit" disabled={!allRead} className="w-full">
          {allRead
            ? "I've read all the guidelines — enter review"
            : "Read every page to continue"}
        </Button>
      </form>
    </div>
  );
}
