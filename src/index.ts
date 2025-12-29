import { loadConfig } from "./config/env";
import { logger } from "./utils/logger";
import { fetchTodayWeather } from "./services/zutoolClient";
import { decideNotification } from "./domain/pressureNotification";
import { sendSlackMessage } from "./services/slackClient";
import { sendLineMessage } from "./services/lineClient";

async function main(): Promise<void> {
  try {
    const config = loadConfig();

    logger.info("Job started");

    const weather = await fetchTodayWeather(config.zutoolPlaceId);
    logger.info("Fetched zutool data", { place: weather.place_name, entries: weather.today.length });

    const decision = decideNotification(weather.today, config.pressureLevelThreshold);
    const hasAlerts = decision.shouldNotify;

    if (!hasAlerts && !config.alwaysNotify) {
      logger.info("No alert slots for today. Job completed without notification.");
      return;
    }

    const header = "【頭痛ーる予報】本日の頭痛リスク";
    const commonLines = [
      `地点: ${weather.place_name}`,
      `しきい値: level ${config.pressureLevelThreshold} 以上`,
    ];

    let bodyLines: string[];

    if (hasAlerts) {
      const times = decision.alertSlots.map(
        (slot) => `${slot.time}時 (${slot.pressure}hPa, level ${slot.pressureLevel})`,
      );
      bodyLines = [
        ...commonLines,
        "本日中に注意が必要な時間帯:",
        ...times,
      ];
    } else {
      bodyLines = [
        ...commonLines,
        "本日中にしきい値を超える時間帯はありません。大きな気圧変化の心配は少なそうです。",
      ];
    }

    const text = [header, ...bodyLines].join("\n");

    const tasks: Promise<void>[] = [];

    if (config.slackWebhookUrl) {
      tasks.push(sendSlackMessage(config.slackWebhookUrl, text));
    }

    if (config.lineChannelAccessToken && config.lineUserId) {
      tasks.push(sendLineMessage(config.lineChannelAccessToken, config.lineUserId, text));
    }

    await Promise.all(tasks);

    logger.info("Notifications sent", { targets: {
      slack: Boolean(config.slackWebhookUrl),
      line: Boolean(config.lineChannelAccessToken && config.lineUserId),
    }});
  } catch (error) {
    logger.error("Job failed", { error: error instanceof Error ? error.message : String(error) });
    process.exitCode = 1;
  }
}

void main();
