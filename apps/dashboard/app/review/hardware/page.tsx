import { redirect } from "next/navigation";

// The hardware review queue is the /review page filtered to kind=hardware. This
// gives it a clean, bookmarkable URL of its own.
export default function HardwareReviewPage() {
  redirect("/review?kind=hardware");
}
