// 날짜별 지표 합계 문서(docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표와 Firestore 컬렉션).
//
// 문서는 비공개 컬렉션 metrics의 `<YYYY-MM-DD>`(보고의 날짜)이고, 보고마다 더하기만 한다(FieldValue.increment).
// 개별 요청은 남기지 않으며, 합계에는 개인을 가리키는 값이 없어 지우는 기한(TTL)을 두지 않는다.
import { FieldValue, type Firestore } from "firebase-admin/firestore";

import { metricsIncrements, type MetricsReport } from "./report.js";

export const METRICS_COLLECTION = "metrics";

export interface MetricsStore {
  /** 보고 하나를 그 날짜의 합계에 더한다. */
  add(report: MetricsReport): Promise<void>;
}

/**
 * 더할 값을 문서 쓰기 꼴로 바꾼다. 숫자는 [increment]로 감싸고, 하위 객체는 같은 꼴로 바꾸며, 비면 뺀다(빈 맵을
 * 합치면 그 필드가 빈 맵으로 바뀔 수 있어서).
 */
export function incrementFields(
  values: object,
  increment: (n: number) => unknown,
): Record<string, unknown> {
  const fields: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(values)) {
    if (typeof value === "number") {
      fields[key] = increment(value);
    } else if (typeof value === "object" && value !== null) {
      const nested = incrementFields(value, increment);
      if (Object.keys(nested).length > 0) fields[key] = nested;
    }
  }
  return fields;
}

/** Firestore의 metrics에 더하는 합계. */
export class FirestoreMetricsStore implements MetricsStore {
  constructor(private readonly db: () => Firestore) {}

  async add(report: MetricsReport): Promise<void> {
    const fields = incrementFields(metricsIncrements(report), (n) =>
      FieldValue.increment(n),
    );
    await this.db()
      .collection(METRICS_COLLECTION)
      .doc(report.date)
      .set(fields, { merge: true });
  }
}
