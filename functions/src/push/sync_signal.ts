// 서버 신호 푸시(docs/architecture.md '앱과 서버 사이 약속 (API)'의 서버 신호 푸시, docs/decisions.md 2026-11-18
// '서버 신호 푸시는 토픽 12개로 나눠 보낸다').
//
// 앱을 백그라운드에서 깨워 LMS 할 일을 받게 하는 무음 푸시다. 서버는 FCM 토큰을 받거나 두지 않는다. 앱이 토픽
// `sync-0`–`sync-11` 가운데 하나를 골라 구독하고, 예약 함수가 15분마다 다음 토픽에 신호를 보낸다. 그래서 폰마다
// 3시간에 한 번 신호가 가고, 폰들이 한꺼번에 LMS를 부르지 않는다. 01:00–06:00(한국 시각)에는 보내지 않는다.
// 메시지는 data만 담고 알림을 띄우지 않는다. 신호를 받은 앱이 LMS를 부를지는 앱의 호출 예산이 정한다.
// 토픽 수·간격·조용한 시간·만료는 모두 임시값이다.
import type { TopicMessage } from "firebase-admin/messaging";
import { logger } from "firebase-functions/logger";

import { describeError } from "../http/request-log.js";

/** 토픽 수. 앱은 0부터 이 값보다 하나 작은 수까지 가운데 하나를 골라 그 토픽만 구독한다. */
export const SYNC_TOPIC_COUNT = 12;

/** 예약 함수가 도는 간격(분). 한 번에 토픽 하나에 보내므로 토픽마다 이 값 × 토픽 수(180분)에 한 번 간다. */
export const SYNC_SIGNAL_INTERVAL_MIN = 15;

/** 예약 함수의 일정(unix-cron). 매시 정각부터 [SYNC_SIGNAL_INTERVAL_MIN]분마다 돈다. */
export const SYNC_SIGNAL_SCHEDULE = `*/${SYNC_SIGNAL_INTERVAL_MIN} * * * *`;

/**
 * 보내지 않는 시간(한국 시각, 자정 기준 분). 01:00 이상 06:00 미만이다. LMS 호출 예산의 조용한 시간 기본값
 * (Remote Config `lms_sync_budget`의 `quietHours`)과 같게 둔다.
 */
export const SYNC_QUIET_START_MIN = 60;
export const SYNC_QUIET_END_MIN = 360;

/** 이 시간(초) 안에 닿지 않은 신호는 버린다. 꺼져 있던 폰에 늦은 신호가 닿지 않게 한다. */
export const SYNC_SIGNAL_TTL_SECONDS = 3600;

/** 메시지의 data. 앱은 모르는 kind를 무시한다. */
export const SYNC_SIGNAL_DATA = { kind: "sync" } as const;

const MINUTES_PER_DAY = 24 * 60;
const KST_OFFSET_MIN = 9 * 60;

/** [bucket]번 토픽의 이름. */
export function syncTopic(bucket: number): string {
  return `sync-${bucket}`;
}

/** [scheduledAt]에 신호를 보낼 토픽 번호. 조용한 시간이면 null이다. 서버의 시간대와 관계없이 한국 시각으로 센다. */
export function syncBucketAt(scheduledAt: Date): number | null {
  const kstMinutes =
    Math.floor(scheduledAt.getTime() / 60_000) + KST_OFFSET_MIN;
  const minuteOfDay =
    ((kstMinutes % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
  if (minuteOfDay >= SYNC_QUIET_START_MIN && minuteOfDay < SYNC_QUIET_END_MIN) {
    return null;
  }
  return Math.floor(minuteOfDay / SYNC_SIGNAL_INTERVAL_MIN) % SYNC_TOPIC_COUNT;
}

/** [topic]에 보낼 메시지. 알림 없이 data만 담고, [sentAt]부터 [SYNC_SIGNAL_TTL_SECONDS] 안에 닿지 않으면 버린다. */
export function syncSignalMessage(topic: string, sentAt: Date): TopicMessage {
  return {
    topic,
    data: { ...SYNC_SIGNAL_DATA },
    android: {
      // 알림을 띄우지 않는 high 메시지는 FCM이 낮출 수 있다. 폰이 Doze 상태면 다음 유지 보수 창에 닿는다.
      priority: "normal",
      ttl: SYNC_SIGNAL_TTL_SECONDS * 1000,
      collapseKey: "sync",
    },
    apns: {
      headers: {
        // 배경 푸시(content-available만 있는 알림)의 우선순위는 5다.
        "apns-push-type": "background",
        "apns-priority": "5",
        "apns-expiration": String(
          Math.floor(sentAt.getTime() / 1000) + SYNC_SIGNAL_TTL_SECONDS,
        ),
      },
      payload: { aps: { contentAvailable: true } },
    },
  };
}

/** 실행마다 남기는 로그 한 줄. 이 밖의 필드는 넣지 않는다. */
export interface SyncSignalLogLine {
  /** 보냈거나 보내려던 토픽. 보내지 않기로 했으면 null이다. */
  topic: string | null;
  /** 보냄 `sent`, 조용한 시간 `quiet`, 꺼 둠 `disabled`, 보내지 못함 `failed`. */
  result: "sent" | "quiet" | "disabled" | "failed";
  /** 보내지 못한 오류의 이름(예: Error). 메시지는 남기지 않는다. */
  errorName?: string;
  /** 그 오류의 Firebase 오류 코드(예: messaging/internal-error). */
  errorCode?: string;
}

export type SyncSignalLogWriter = (line: SyncSignalLogLine) => void;

/** Cloud Logging에 `sync_signal` 한 줄로 쓴다. 보내지 못했으면 error 수준이다. */
export const writeSyncSignalLog: SyncSignalLogWriter = (line) => {
  if (line.result === "failed") {
    logger.error("sync_signal", line);
  } else {
    logger.info("sync_signal", line);
  }
};

export interface SyncSignalDeps {
  /** 메시지를 FCM에 넘긴다. */
  send: (message: TopicMessage) => Promise<unknown>;
  /** false면 보내지 않는다(`SYNC_SIGNAL_ENABLED`). */
  enabled: () => boolean;
  log: SyncSignalLogWriter;
  /** 지금. 만료 시각과, 일정 시각을 읽지 못했을 때 쓴다. */
  now?: () => Date;
}

/** Firebase 오류 코드로 남겨도 되는 꼴. 이 꼴이 아니면 남기지 않는다. */
const SAFE_CODE = /^[a-z0-9/_-]{1,64}$/;

function errorCode(error: unknown): string | undefined {
  if (typeof error !== "object" || error === null || !("code" in error)) {
    return undefined;
  }
  const code = error.code;
  return typeof code === "string" && SAFE_CODE.test(code) ? code : undefined;
}

/**
 * 예약 실행 하나를 처리한다. [scheduleTime]은 Cloud Scheduler의 일정 시각(RFC 3339)이고, 읽지 못하면 지금을 쓴다.
 * 보내지 못해도 던지지 않고 로그만 남긴다. 다시 보내지 않아도 그 토픽에는 3시간 뒤 다음 신호가 간다.
 */
export async function runSyncSignal(
  deps: SyncSignalDeps,
  scheduleTime: string | undefined,
): Promise<void> {
  if (!deps.enabled()) {
    deps.log({ topic: null, result: "disabled" });
    return;
  }
  const now = (deps.now ?? (() => new Date()))();
  const scheduled =
    scheduleTime === undefined ? Number.NaN : Date.parse(scheduleTime);
  const bucket = syncBucketAt(
    Number.isNaN(scheduled) ? now : new Date(scheduled),
  );
  if (bucket === null) {
    deps.log({ topic: null, result: "quiet" });
    return;
  }
  const topic = syncTopic(bucket);
  try {
    await deps.send(syncSignalMessage(topic, now));
    deps.log({ topic, result: "sent" });
  } catch (error) {
    const code = errorCode(error);
    deps.log({
      topic,
      result: "failed",
      errorName: describeError(error).name,
      ...(code === undefined ? {} : { errorCode: code }),
    });
  }
}
