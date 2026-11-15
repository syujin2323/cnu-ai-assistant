// 지표 합계 저장 테스트. Firestore는 쓰기만 기록하는 가짜로 바꾼다.
import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { describe, expect, it } from "vitest";

import {
  FirestoreMetricsStore,
  incrementFields,
  METRICS_COLLECTION,
} from "../../src/metrics/store.js";
import { sampleReport } from "../support/metrics.js";

describe("incrementFields", () => {
  it("wraps numbers, keeps nesting, and drops empty maps", () => {
    const fields = incrementFields(
      { reports: 1, zero: 0, sync: { open: 2 }, empty: {}, deep: { a: {} } },
      (n) => ({ inc: n }),
    );

    expect(fields).toEqual({
      reports: { inc: 1 },
      zero: { inc: 0 },
      sync: { open: { inc: 2 } },
    });
  });
});

class FakeFirestore {
  readonly writes: {
    path: string;
    data: Record<string, unknown>;
    options: unknown;
  }[] = [];

  collection(name: string) {
    return {
      doc: (id: string) => ({
        set: async (data: Record<string, unknown>, options: unknown) => {
          this.writes.push({ path: `${name}/${id}`, data, options });
        },
      }),
    };
  }
}

describe("FirestoreMetricsStore", () => {
  it("merges increments into the report's date document", async () => {
    const db = new FakeFirestore();
    const store = new FirestoreMetricsStore(() => db as unknown as Firestore);

    await store.add(sampleReport({ confirmSeconds: null }));

    expect(db.writes).toHaveLength(1);
    const [write] = db.writes;
    // 문서에 적은 컬렉션 이름 그대로다(docs/architecture.md의 Firestore 컬렉션).
    expect(write?.path).toBe("metrics/2026-11-19");
    expect(METRICS_COLLECTION).toBe("metrics");
    expect(write?.options).toEqual({ merge: true });
    expect(Object.keys(write?.data ?? {}).sort()).toEqual([
      "briefingOpened",
      "daysSinceLmsLogin",
      "editsBeforeConfirm",
      "installAge",
      "missedDeadlines",
      "planConfirmed",
      "reports",
      "syncAttempts",
      "syncSuccesses",
      "todaySuggested",
    ]);
    const reports = write?.data.reports as FieldValue;
    expect(reports.isEqual(FieldValue.increment(1))).toBe(true);
    const open = (write?.data.syncAttempts as Record<string, FieldValue>).open;
    expect(open?.isEqual(FieldValue.increment(3))).toBe(true);
    const age = (write?.data.installAge as Record<string, FieldValue>)["7"];
    expect(age?.isEqual(FieldValue.increment(1))).toBe(true);
  });
});
