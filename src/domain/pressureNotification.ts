import { ZutoolTimeEntry } from "../services/zutoolClient";

export type AlertSlot = {
  time: string;
  pressure: number;
  pressureLevel: number;
};

export type NotificationDecision = {
  shouldNotify: boolean;
  alertSlots: AlertSlot[];
};

export function decideNotification(entries: ZutoolTimeEntry[], threshold: number): NotificationDecision {
  const alertSlots: AlertSlot[] = entries
    .filter((entry) => entry.pressure_level >= threshold)
    .map((entry) => ({
      time: entry.time,
      pressure: entry.pressure,
      pressureLevel: entry.pressure_level,
    }));

  return {
    shouldNotify: alertSlots.length > 0,
    alertSlots,
  };
}
