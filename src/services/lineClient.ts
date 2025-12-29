import axios from "axios";

export async function sendLineMessage(channelAccessToken: string, userId: string, text: string): Promise<void> {
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
}
