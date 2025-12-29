import dotenv from "dotenv";

dotenv.config();

export type AppConfig = {
  zutoolPlaceId: string;
  pressureLevelThreshold: number;
  alwaysNotify: boolean;
  slackWebhookUrl?: string;
  lineUserId?: string;
  lineChannelAccessToken?: string;
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Environment variable ${name} is required`);
  }
  return value;
}

export function loadConfig(): AppConfig {
  const zutoolPlaceId = requireEnv("ZUTOOL_PLACE_ID");

  const thresholdRaw = process.env["PRESSURE_LEVEL_THRESHOLD"] ?? "3";
  const pressureLevelThreshold = Number(thresholdRaw);
  if (!Number.isInteger(pressureLevelThreshold) || pressureLevelThreshold < 0 || pressureLevelThreshold > 4) {
    throw new Error("PRESSURE_LEVEL_THRESHOLD must be an integer between 0 and 4");
  }

  const alwaysNotifyRaw = process.env["ALWAYS_NOTIFY"] ?? "false";
  const alwaysNotify = ["1", "true", "TRUE", "yes", "YES"].includes(alwaysNotifyRaw);

  const slackWebhookUrl = process.env["SLACK_WEBHOOK_URL"];
  const lineUserId = process.env["LINE_USER_ID"];
  const lineChannelAccessToken = process.env["LINE_CHANNEL_ACCESS_TOKEN"];

  if (!slackWebhookUrl && (!lineUserId || !lineChannelAccessToken)) {
    throw new Error("At least one notification target must be configured (Slack or LINE)");
  }

  return {
    zutoolPlaceId,
    pressureLevelThreshold,
    alwaysNotify,
    slackWebhookUrl,
    lineUserId,
    lineChannelAccessToken,
  };
}
