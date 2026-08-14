import { app } from "../slack/app.js";
import { RIDIT_ID, PIXL_MAIN_CHANNEL, RIDIT_CHANNEL } from "../constants.js";
import { botIdentity } from "../slack/identity.js";
import { welcomeThreads } from "./thread.js";
import { recordMemberJoin } from "./newMembersDigest.js";

// The main channel no longer gets an instant per-join welcome — joins are
// recorded and welcomed together in the end-of-day digest (newMembersDigest.ts).
// Ridit's own channel keeps its instant welcome.
export const RIDIT_CHANNEL_MSGS = [
  ":sho: welcome to <#C0BHLGJ7YBA> !! we all yap here :neocat_hug:",
  "yoooooo we got another yapper!! :yay:",
  "another certified professional yapper has arrived :yay:",
  "grab a seat and start yapping :3",
  "welcome!! we hope you like pings :sob:",
  "the chat just got 0.1% funnier :catjam:",
  "welcome!! the floor is yours :microphone:",
];

// Private welcome DM sent to each new main-channel member (the public welcome is
// the daily digest — see newMembersDigest.ts).
const WELCOME_DM = `hey! welcome to Pixl :yay:

i'm pixo, i answer questions from the Pixl docs. you can:
• ping me in any channel
• DM me right here
• use /pixl-help to see everything i can do!

quick links:
• play: https://pixl.hackclub.com/play
• docs: https://pixl.hackclub.com/docs

stuck on something a helper should see? post in <#C0B6STY9G5N> :hii:
want to hear updates about the ysws? join <#C0B627CFHEY>  :pixl-yay:`;

async function sendWelcomeDM(userId: string): Promise<void> {
  try {
    const im = await app.client.conversations.open({ users: userId });
    const channel = im.channel?.id;
    if (channel) await app.client.chat.postMessage({ channel, text: WELCOME_DM });
  } catch (e: any) {
    console.error("welcome DM error:", e?.message ?? e);
  }
}

app.event("member_joined_channel", async ({ event, client }) => {
  if (event.user === botIdentity.userId) return;

  // Main channel: send the newcomer a private welcome DM and record the join
  // for the daily digest. No instant public message.
  if (event.channel === PIXL_MAIN_CHANNEL) {
    await sendWelcomeDM(event.user);
    await recordMemberJoin(event.user, event.channel);
    return;
  }

  // Ridit's own channel: keep the instant welcome addressed to him.
  if (event.channel !== RIDIT_CHANNEL) return;

  try {
    const msg = RIDIT_CHANNEL_MSGS[Math.floor(Math.random() * RIDIT_CHANNEL_MSGS.length)];

    const posted = await client.chat.postMessage({
      channel: event.channel,
      text: `<@${event.user}> ${msg}`,
    });

    welcomeThreads.add(posted.ts!);

    await client.chat.postMessage({
      channel: event.channel,
      thread_ts: posted.ts,
      text: `cc <@${RIDIT_ID}>`,
    });
  } catch (e: any) {
    console.error("welcome error:", e.message);
  }
});
