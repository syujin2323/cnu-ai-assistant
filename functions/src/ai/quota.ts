// AI 호출 한도(docs/architecture.md '제공사 호출 규칙'의 호출 한도).
//
// 모든 AI 경로의 합계이고 하루는 Asia/Seoul 달력 날짜다. 요청 검증과 인증을 통과한 뒤, 제공사를 부르기 전에
// Firestore 트랜잭션 하나로 센다. 설치별 count가 한도 이상이면 install_limit, 전체 count가 상한 이상이면
// service_limit이고 늘리지 않는다. 그 밖에는 둘 다 1 늘린다. 문서는 비공개 컬렉션 ai_usage의
// `<YYYY-MM-DD>`(전체)와 `<YYYY-MM-DD>_<설치 토큰>`(설치별)이고, 필드는 count와 expireAt(그 날짜 00:00 KST + 2일,
// TTL로 지움)이다.
import { Timestamp, type Firestore } from "firebase-admin/firestore";

export type QuotaDecision = "ok" | "install_limit" | "service_limit";

export interface QuotaLimits {
  perInstall: number;
  total: number;
}

export interface QuotaStore {
  /** 이 설치의 호출 하나를 센다. 한도에 걸리면 세지 않고 그 이유를 돌려준다. */
  take(
    installToken: string,
    now: Date,
    limits: QuotaLimits,
  ): Promise<QuotaDecision>;
}

export const USAGE_COLLECTION = "ai_usage";

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** [now]의 Asia/Seoul 달력 날짜(YYYY-MM-DD). 한국은 서머타임이 없어 9시간을 더해 읽는다. */
export function seoulDate(now: Date): string {
  return new Date(now.getTime() + KST_OFFSET_MS).toISOString().slice(0, 10);
}

/** [day](YYYY-MM-DD) 00:00 KST에서 이틀 뒤의 순간. 이때가 지나면 TTL이 그 날짜의 문서를 지운다. */
export function usageExpireAt(day: string): Date {
  return new Date(Date.parse(`${day}T00:00:00Z`) - KST_OFFSET_MS + 2 * DAY_MS);
}

/** 이미 센 수와 한도로 이번 호출을 받을지 정한다. 설치별 한도를 먼저 본다. */
export function decideQuota(
  installCount: number,
  totalCount: number,
  limits: QuotaLimits,
): QuotaDecision {
  if (installCount >= limits.perInstall) return "install_limit";
  if (totalCount >= limits.total) return "service_limit";
  return "ok";
}

/** 문서의 count. 없거나 숫자가 아니면 0으로 본다. */
function countOf(data: unknown): number {
  if (typeof data !== "object" || data === null || !("count" in data)) {
    return 0;
  }
  const count = (data as { count: unknown }).count;
  return typeof count === "number" && Number.isFinite(count) ? count : 0;
}

/** Firestore의 ai_usage로 세는 한도. */
export class FirestoreQuotaStore implements QuotaStore {
  constructor(private readonly db: () => Firestore) {}

  async take(
    installToken: string,
    now: Date,
    limits: QuotaLimits,
  ): Promise<QuotaDecision> {
    const db = this.db();
    const day = seoulDate(now);
    const expireAt = Timestamp.fromDate(usageExpireAt(day));
    const usage = db.collection(USAGE_COLLECTION);
    const totalRef = usage.doc(day);
    const installRef = usage.doc(`${day}_${installToken}`);
    return db.runTransaction(async (tx) => {
      const [total, install] = await tx.getAll(totalRef, installRef);
      const totalCount = countOf(total?.data());
      const installCount = countOf(install?.data());
      const decision = decideQuota(installCount, totalCount, limits);
      if (decision === "ok") {
        tx.set(totalRef, { count: totalCount + 1, expireAt });
        tx.set(installRef, { count: installCount + 1, expireAt });
      }
      return decision;
    });
  }
}
