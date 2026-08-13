import { app } from "../slack/app.js";
import { streamedAICall } from "../ai/client.js";
import { checkAiRateLimit, AI_RATE_LIMIT_MESSAGE } from "../ai/rateLimit.js";

app.command("/pixl-ask", async ({ command, ack, client }) => {
  await ack();
  if (!checkAiRateLimit(command.user_id)) {
    await client.chat.postEphemeral({
      channel: command.channel_id,
      user: command.user_id,
      text: AI_RATE_LIMIT_MESSAGE,
    });
    return;
  }
  const question = command.text?.trim();
  if (!question) {
    await client.chat.postEphemeral({
      channel: command.channel_id,
      user: command.user_id,
      text: "Usage: `/pixl-ask what is the meaning of life`",
    });
    return;
  }
  try {
    const stream = await streamedAICall(
      client,
      { channel: command.channel_id },
      {
        messages: [
          {
            role: "system",
            content: "You are Pixorpheus, a sarcastic Slack bot. Answer in 1-2 sentences max, lowercase, gen Z energy.",
          },
          { role: "user", content: question },
        ],
        max_tokens: 150,
      },
      { format: (t) => `<@${command.user_id}> asked: _${question}_\n> ${t}` },
    );
    const reply = stream.rawContent.trim() || "idk tbh";
    await stream.finalize(`<@${command.user_id}> asked: _${question}_\n> ${reply}`);
  } catch (e) {
    await client.chat.postEphemeral({
      channel: command.channel_id,
      user: command.user_id,
      text: "failed lol",
    });
  }
});
