import axios from "axios";

export async function sendSlackMessage(webhookUrl: string, text: string): Promise<void> {
  const withMention = `<!channel>\n${text}`;

  await axios.post(
    webhookUrl,
    { text: withMention },
    {
      timeout: 5000,
      headers: { "Content-Type": "application/json" },
    }
  );
}
