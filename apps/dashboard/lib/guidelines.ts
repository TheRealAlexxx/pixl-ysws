// YSWS Project Submission Guidelines that every reviewer must read once before
// they get into the review queue (see requireGuidelinesAck in guard.ts).
//
// We link out to the LIVE GitBook pages rather than snapshotting them, so the
// text is always Hack Club's current version. The only thing maintained here is
// the ordered list of pages — when Hack Club adds/removes a page, update this
// list. Bumping GUIDELINES_VERSION forces every reviewer to re-read.
//
// Source: https://hackclub.gitbook.io/ysws-project-submission-guidelines
//
// TODO(list): fill in EVERY page from the GitBook left sidebar, in order. The
// nav is rendered client-side so it can't be scraped automatically — copy each
// page's title + URL from the sidebar. The two below are the ones confirmed so
// far; add the rest.
export const GUIDELINES_VERSION = 1;

export const MIN_SECONDS_PER_PAGE = 30;

export interface GuidelinePage {
  title: string;
  url: string;
}

export const GUIDELINE_PAGES: GuidelinePage[] = [
  {
    title: "YSWS Project Submission Guidelines",
    url: "https://hackclub.gitbook.io/ysws-project-submission-guidelines/BLBRN8LIfoCZhFV6oMNR",
  },
  // TODO: add every remaining sidebar page here, e.g. "Project Exceptions", etc.
];
