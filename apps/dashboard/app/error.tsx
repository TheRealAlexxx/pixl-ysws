"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

// Server Actions are versioned per deploy (a content hash baked into the
// client bundle). This project auto-deploys on every push to main, so any
// reviewer who has a review page open across a deploy is left holding a
// stale action reference - their next click (Approve, Next, claim, etc.)
// throws exactly this Next.js error, and with no error boundary in place it
// used to fail with nothing visible happening: no verdict recorded, no
// navigation, nothing - which reads as "the project vanished". There is no
// way to recover a stale action client-side, so the fix is a fresh page
// load; do that automatically instead of leaving the reviewer stuck.
// See https://nextjs.org/docs/messages/failed-to-find-server-action
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const isStaleDeploy = /failed to find server action/i.test(error.message);

  useEffect(() => {
    if (isStaleDeploy) window.location.reload();
  }, [isStaleDeploy]);

  if (isStaleDeploy) {
    return (
      <div className="flex items-center justify-center min-h-[50vh]">
        <Card className="p-6 text-sm text-muted-foreground">
          A new version just deployed , reloading…
        </Card>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-[50vh]">
      <Card className="p-6 max-w-sm text-center space-y-3">
        <div className="font-semibold">Something went wrong</div>
        <p className="text-sm text-muted-foreground break-words">
          {error.message || "Unknown error."}
        </p>
        <Button onClick={() => reset()}>Try again</Button>
      </Card>
    </div>
  );
}
