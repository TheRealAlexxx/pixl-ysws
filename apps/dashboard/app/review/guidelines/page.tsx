import { requirePagePerm } from "@/lib/guard";
import { GUIDELINE_PAGES, MIN_SECONDS_PER_PAGE } from "@/lib/guidelines";
import { GuidelinesGate } from "@/app/_components/GuidelinesGate";

export const dynamic = "force-dynamic";

// The first-time guidelines gate. Reviewer-only, but deliberately does NOT call
// requireGuidelinesAck (that's what redirects here) — otherwise it would loop.
export default async function ReviewGuidelinesPage() {
  await requirePagePerm(["review"]);
  return (
    <GuidelinesGate pages={GUIDELINE_PAGES} minSeconds={MIN_SECONDS_PER_PAGE} />
  );
}
