// 서버 신호 푸시 테스트. FCM은 보낸 메시지만 기록하는 가짜로 바꾼다.
import type { TopicMessage } from "firebase-admin/messaging";
import { logger } from "firebase-functions/logger";
import { afterEach, describe, expect, it, vi } from "vitest";

import {
  runSyncSignal,
  SYNC_SIGNAL_SCHEDULE,
  SYNC_TOPIC_COUNT,
  syncBucketAt,
  syncSignalMessage,
  type SyncSignalDeps,
  type SyncSignalLogLine,
  syncTopic,
  writeSyncSignalLog,
} from "../../src/push/sync_signal.js";

/** 2026-11-18 한국 시각 [hhmm]:[seconds]의 순간. */
function kst(hhmm: string, seconds = 0): Date {
  const ss = String(seconds).padStart(2, "0");
  return new Date(`2026-11-18T${hhmm}:${ss}+09:00`);
}

function range(n: number): number[] {
  return Array.from({ length: n }, (_, i) => i);
}

describe("syncTopic", () => {
  it("names twelve topics that fit the FCM topic name pattern", () => {
    const topics = range(SYNC_TOPIC_COUNT).map(syncTopic);

    expect(topics).toHaveLength(12);
    expect(topics[0]).toBe("sync-0");
    expect(topics[11]).toBe("sync-11");
    for (const topic of topics) {
      expect(topic).toMatch(/^[a-zA-Z0-9-_.~%]{1,900}$/);
    }
  });
});

describe("syncBucketAt", () => {
  it("moves to the next topic every 15 minutes from midnight in Korea", () => {
    expect(syncBucketAt(kst("00:00"))).toBe(0);
    expect(syncBucketAt(kst("00:15"))).toBe(1);
    expect(syncBucketAt(kst("00:59", 59))).toBe(3);
    expect(syncBucketAt(kst("06:00"))).toBe(0);
    expect(syncBucketAt(kst("08:45"))).toBe(11);
    expect(syncBucketAt(kst("09:00"))).toBe(0);
    expect(syncBucketAt(kst("10:15"))).toBe(5);
    expect(syncBucketAt(kst("23:45"))).toBe(11);
  });

  it("sends nothing from 01:00 up to 06:00 in Korea", () => {
    expect(syncBucketAt(kst("01:00"))).toBeNull();
    expect(syncBucketAt(kst("03:30"))).toBeNull();
    expect(syncBucketAt(kst("05:59", 59))).toBeNull();
  });

  it("keeps the topic of the 15-minute slot when the run starts late", () => {
    expect(syncBucketAt(kst("10:29", 59))).toBe(5);
  });

  it("counts in Korean time whatever the server time zone is", () => {
    expect(syncBucketAt(new Date("2026-11-17T15:00:00Z"))).toBe(0);
    expect(syncBucketAt(new Date("2026-11-17T16:00:00Z"))).toBeNull();
    expect(syncBucketAt(new Date("2026-11-18T14:45:00Z"))).toBe(11);
  });

  it("reaches every topic once every three hours, also across midnight", () => {
    const sentAt = new Map<number, number[]>();
    const start = kst("00:00").getTime();
    for (let slot = 0; slot < 2 * 96; slot++) {
      const bucket = syncBucketAt(new Date(start + slot * 15 * 60_000));
      if (bucket === null) continue;
      sentAt.set(bucket, [...(sentAt.get(bucket) ?? []), slot * 15]);
    }

    expect([...sentAt.keys()].sort((a, b) => a - b)).toEqual(range(12));
    // 하루 96칸 가운데 조용한 시간 20칸을 뺀 76번 보낸다.
    const sends = [...sentAt.values()].reduce((n, at) => n + at.length, 0);
    expect(sends).toBe(2 * 76);
    for (const minutes of sentAt.values()) {
      const gaps = minutes.slice(1).map((m, i) => m - minutes[i]!);
      expect(Math.min(...gaps)).toBe(180);
      // 조용한 시간을 건너뛰면 3시간의 배수만큼 벌어진다.
      for (const gap of gaps) expect(gap % 180).toBe(0);
    }
  });
});

describe("syncSignalMessage", () => {
  it("is a silent data-only push that expires after an hour", () => {
    const sentAt = new Date("2026-11-18T01:15:07Z");

    expect(syncSignalMessage("sync-5", sentAt)).toEqual({
      topic: "sync-5",
      data: { kind: "sync" },
      android: { priority: "normal", ttl: 3_600_000, collapseKey: "sync" },
      apns: {
        headers: {
          "apns-push-type": "background",
          "apns-priority": "5",
          "apns-expiration": String(Math.floor(sentAt.getTime() / 1000) + 3600),
        },
        payload: { aps: { contentAvailable: true } },
      },
    });
  });
});

describe("SYNC_SIGNAL_SCHEDULE", () => {
  it("runs every 15 minutes on the quarter hour", () => {
    expect(SYNC_SIGNAL_SCHEDULE).toBe("*/15 * * * *");
  });
});

/** 보낸 메시지와 로그만 기록하는 의존성. 지금은 한국 시각 10:15:02다. */
function fakeDeps(overrides: Partial<SyncSignalDeps> = {}) {
  const sent: TopicMessage[] = [];
  const logs: SyncSignalLogLine[] = [];
  const now = new Date("2026-11-18T01:15:02Z");
  const deps: SyncSignalDeps = {
    send: async (message) => {
      sent.push(message);
      return "projects/demo/messages/1";
    },
    enabled: () => true,
    log: (line) => logs.push(line),
    now: () => now,
    ...overrides,
  };
  return { deps, sent, logs, now };
}

describe("runSyncSignal", () => {
  it("sends to the topic of the scheduled time and logs it", async () => {
    const { deps, sent, logs, now } = fakeDeps();

    // 한국 시각 10:30 → 42번째 칸 → 6번 토픽(지금 10:15의 5번이 아님).
    await runSyncSignal(deps, "2026-11-18T01:30:00Z");

    expect(sent).toEqual([syncSignalMessage("sync-6", now)]);
    expect(logs).toEqual([{ topic: "sync-6", result: "sent" }]);
  });

  it("falls back to now when the scheduled time is missing or broken", async () => {
    for (const scheduleTime of [undefined, "not a time"]) {
      const { deps, sent, logs, now } = fakeDeps();

      await runSyncSignal(deps, scheduleTime);

      expect(sent).toEqual([syncSignalMessage("sync-5", now)]);
      expect(logs).toEqual([{ topic: "sync-5", result: "sent" }]);
    }
  });

  it("sends nothing in the quiet hours", async () => {
    const { deps, sent, logs } = fakeDeps();

    await runSyncSignal(deps, "2026-11-17T17:00:00Z");

    expect(sent).toEqual([]);
    expect(logs).toEqual([{ topic: null, result: "quiet" }]);
  });

  it("sends nothing when switched off", async () => {
    const { deps, sent, logs } = fakeDeps({ enabled: () => false });

    await runSyncSignal(deps, "2026-11-18T01:30:00Z");

    expect(sent).toEqual([]);
    expect(logs).toEqual([{ topic: null, result: "disabled" }]);
  });

  it("logs only the error name and a safe code when sending fails", async () => {
    const failing = Object.assign(new Error("detail sync-6 abc"), {
      code: "messaging/internal-error",
    });
    const { deps, logs } = fakeDeps({ send: () => Promise.reject(failing) });

    await expect(
      runSyncSignal(deps, "2026-11-18T01:30:00Z"),
    ).resolves.toBeUndefined();

    expect(logs).toEqual([
      {
        topic: "sync-6",
        result: "failed",
        errorName: "Error",
        errorCode: "messaging/internal-error",
      },
    ]);
    expect(JSON.stringify(logs)).not.toContain("detail");
  });

  it("drops codes that are not plain Firebase codes", async () => {
    for (const thrown of [
      Object.assign(new TypeError("x"), { code: "Not A Code" }),
      Object.assign(new Error("x"), { code: 503 }),
      "plain string",
    ]) {
      const { deps, logs } = fakeDeps({ send: () => Promise.reject(thrown) });

      await runSyncSignal(deps, "2026-11-18T01:30:00Z");

      expect(logs).toEqual([
        {
          topic: "sync-6",
          result: "failed",
          errorName: thrown instanceof TypeError ? "TypeError" : "Error",
        },
      ]);
    }
  });
});

describe("writeSyncSignalLog", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("writes one sync_signal line, at error level only for failures", () => {
    const info = vi.spyOn(logger, "info").mockImplementation(() => {});
    const error = vi.spyOn(logger, "error").mockImplementation(() => {});
    const sentLine: SyncSignalLogLine = { topic: "sync-1", result: "sent" };
    const failedLine: SyncSignalLogLine = {
      topic: "sync-1",
      result: "failed",
      errorName: "Error",
    };

    writeSyncSignalLog(sentLine);
    writeSyncSignalLog(failedLine);

    expect(info).toHaveBeenCalledExactlyOnceWith("sync_signal", sentLine);
    expect(error).toHaveBeenCalledExactlyOnceWith("sync_signal", failedLine);
  });
});
