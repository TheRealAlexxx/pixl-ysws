// Slack mrkdwn treats &, <, > as syntax (mentions, channel refs, links).
// Any user-controlled string headed into a text/mrkdwn field must go through
// this first, or it can spoof mentions (<@U123|fake>), mass-ping (<!channel>),
// or render clickable links under the bot's identity.
export function escapeMrkdwn(text: string): string {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
