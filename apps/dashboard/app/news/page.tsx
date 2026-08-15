import { requirePagePerm } from "@/lib/guard";
import { listNews } from "@/lib/db";
import { addNews, updateNews, toggleNews, deleteNews } from "@/app/actions";
import { PendingButton } from "@/app/_components/PendingButton";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export const dynamic = "force-dynamic";

// The <input type="datetime-local"> value format, in UTC so it matches how the
// posts are stored and how the players' page renders them.
function localInputValue(iso: string): string {
  const at = new Date(iso);
  if (Number.isNaN(at.getTime())) return "";
  return at.toISOString().slice(0, 16);
}

function dateLabel(iso: string): string {
  const at = new Date(iso);
  if (Number.isNaN(at.getTime())) return "";
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  }).format(at);
}

export default async function NewsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; saved?: string }>;
}) {
  await requirePagePerm(["news"]);
  const { error, saved } = await searchParams;
  const posts = await listNews();

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold text-foreground tracking-tight">News</h1>
        <p className="text-sm text-muted-foreground mt-1 max-w-2xl">
          The news feed on the players&apos; projects page. One short line per post,
          newest first. Hidden posts stay here but drop out of the feed.
        </p>
      </div>

      {saved && (
        <Alert>
          <AlertDescription className="font-medium text-emerald-600 dark:text-emerald-400">
            Saved.
          </AlertDescription>
        </Alert>
      )}
      {error && (
        <Alert variant="destructive">
          <AlertDescription className="font-medium text-destructive">{error}</AlertDescription>
        </Alert>
      )}

      <Card className="p-5 md:p-6 gap-0">
        <div className="text-base font-semibold mb-4">Post news</div>
        <form action={addNews} className="space-y-4">
          <Label className="block font-normal">
            <span className="block text-sm font-medium mb-1.5">Post</span>
            <Textarea
              name="body"
              rows={2}
              required
              maxLength={500}
              placeholder="New items added to the shop!"
              className="w-full text-sm"
            />
          </Label>
          <div className="grid sm:grid-cols-[1fr_auto] gap-4 items-start">
            <Label className="block font-normal">
              <span className="block text-sm font-medium mb-1.5">Link (optional)</span>
              <Input
                name="link_url"
                type="url"
                maxLength={500}
                placeholder="https://pixl.rsvp/shop"
                className="w-full text-sm"
              />
            </Label>
            <Label className="block font-normal">
              <span className="block text-sm font-medium mb-1.5">Date (optional, UTC)</span>
              <Input name="posted_at" type="datetime-local" className="w-full text-sm sm:w-56" />
            </Label>
          </div>
          <PendingButton className="bg-brand text-white border-transparent" pendingText="Posting…">
            Post
          </PendingButton>
        </form>
      </Card>

      <div className="space-y-4">
        {posts.map((p) => (
          <Card key={p.id} className={`p-4 md:p-5 gap-0 ${p.active ? "" : "opacity-60"}`}>
            <form action={updateNews} className="space-y-3">
              <input type="hidden" name="id" value={p.id} />
              <div className="flex items-center gap-2 flex-wrap mb-1">
                <Badge variant="secondary">{dateLabel(p.posted_at)}</Badge>
                {!p.active && <Badge variant="secondary">hidden</Badge>}
                <div className="ml-auto flex items-center gap-2">
                  <PendingButton variant="outline" size="sm" pendingText="Saving…">
                    Save
                  </PendingButton>
                </div>
              </div>
              <Label className="block font-normal">
                <span className="block text-xs font-medium mb-1 text-muted-foreground">Post</span>
                <Textarea
                  name="body"
                  rows={2}
                  defaultValue={p.body}
                  maxLength={500}
                  className="w-full text-sm"
                />
              </Label>
              <div className="grid sm:grid-cols-[1fr_auto] gap-3 items-start">
                <Label className="block font-normal">
                  <span className="block text-xs font-medium mb-1 text-muted-foreground">Link</span>
                  <Input
                    name="link_url"
                    type="url"
                    defaultValue={p.link_url ?? ""}
                    maxLength={500}
                    className="w-full text-sm"
                  />
                </Label>
                <Label className="block font-normal">
                  <span className="block text-xs font-medium mb-1 text-muted-foreground">
                    Date (UTC)
                  </span>
                  <Input
                    name="posted_at"
                    type="datetime-local"
                    defaultValue={localInputValue(p.posted_at)}
                    className="w-full text-sm sm:w-56"
                  />
                </Label>
              </div>
            </form>
            <div className="flex items-center gap-2 mt-3 pt-3 border-t border-border">
              <form action={toggleNews}>
                <input type="hidden" name="id" value={p.id} />
                <input type="hidden" name="active" value={p.active ? "0" : "1"} />
                <PendingButton
                  variant="outline"
                  size="sm"
                  pendingText={p.active ? "Hiding…" : "Showing…"}
                >
                  {p.active ? "Hide" : "Show"}
                </PendingButton>
              </form>
              <form action={deleteNews}>
                <input type="hidden" name="id" value={p.id} />
                <PendingButton
                  variant="outline"
                  size="sm"
                  pendingText="Deleting…"
                  confirm="Delete this post? This can't be undone."
                  className="text-rose-600 border-rose-200 dark:border-rose-500/30 hover:bg-rose-50 dark:hover:bg-rose-500/10 hover:text-rose-600"
                >
                  Delete
                </PendingButton>
              </form>
            </div>
          </Card>
        ))}
        {posts.length === 0 && (
          <Card className="p-8 text-center text-muted-foreground text-sm">
            Nothing posted yet. Write the first one above.
          </Card>
        )}
      </div>
    </div>
  );
}
