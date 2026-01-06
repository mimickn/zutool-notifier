import axios from "axios";

export async function sendLineMessage(channelAccessToken: string, userId: string, text: string): Promise<void> {
  try {
    await axios.post(
      "https://api.line.me/v2/bot/message/push",
      {
        to: userId,
        messages: [
          {
            type: "text",
            text,
          },
        ],
      },
      {
        timeout: 5000,
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${channelAccessToken}`,
        },
      }
    );
  } catch (error: unknown) {
    if (axios.isAxiosError(error)) {
      const status = error.response?.status;
      const statusText = error.response?.statusText;
      const data = error.response?.data;
      const details =
        data !== undefined
          ? typeof data === "string"
            ? data
            : JSON.stringify(data)
          : error.message;
      throw new Error(
        `Failed to send LINE message to user ${userId}: ` +
          `${status ?? "unknown status"}${statusText ? " " + statusText : ""} - ${details}`
      );
    }
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to send LINE message to user ${userId}: ${message}`);
  }
}
