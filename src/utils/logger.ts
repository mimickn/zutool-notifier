type LogLevel = "info" | "warn" | "error" | "debug";

function log(level: LogLevel, message: string, meta?: unknown): void {
  const timestamp = new Date().toISOString();
  const payload = meta ? { message, meta } : { message };
  console.log(JSON.stringify({ timestamp, level, ...payload }));
}

export const logger = {
  info(message: string, meta?: unknown) {
    log("info", message, meta);
  },
  warn(message: string, meta?: unknown) {
    log("warn", message, meta);
  },
  error(message: string, meta?: unknown) {
    log("error", message, meta);
  },
  debug(message: string, meta?: unknown) {
    log("debug", message, meta);
  },
};
