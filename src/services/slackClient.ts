import axios from "axios";

export async function sendSlackMessage(webhookUrl: string, text: string): Promise<void> {
  const withMention = `<!channel>\n${text}`;

  try {
    await axios.post(
      webhookUrl,
      { text: withMention },
      {
        timeout: 5000,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    if (axios.isAxiosError(error)) {
      const status = error.response?.status;
      const statusText = error.response?.statusText;
      const data = error.response?.data;
      console.error(
        `Failed to send Slack message via webhook ${webhookUrl}.` +
          (status ? ` Status: ${status} ${statusText ?? ""}.` : " No HTTP response received."),
        data ?? error.message
      );
    } else {
      console.error(`Failed to send Slack message via webhook ${webhookUrl}.`, error);
    }
    throw error;
  }
}
