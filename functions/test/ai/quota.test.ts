// 호출 한도 테스트. Firestore는 트랜잭션의 읽기·쓰기만 흉내 내는 가짜로 바꾼다.
import type { Firestore } from "firebase-admin/firestore";
import { describe, expect, it } from "vitest";

import {
  decideQuota,
  FirestoreQuotaStore,
  seoulDate,
  usageExpireAt,
  USAGE_COLLECTION,
} from "../../src/ai/quota.js";

/** 문서 id → 데이터. 트랜잭션은 순서대로 하나씩 돈다. */
class FakeFirestore {
  readonly docs = new Map<string, Record<string, unknown>>();
  transactions = 0;

  collection(name: string) {
    return { doc: (id: string) => ({ path: `${name}/${id}` }) };
  }

  async runTransaction<T>(
    fn: (tx: {
      getAll: (...refs: { path: string }[]) => Promise<{ data(): unknown }[]>;
      set: (ref: { path: string }, data: Record<string, unknown>) => void;
    }) => Promise<T>,
  ): Promise<T> {
    this.transactions++;
    const writes: [string, Record<string, unknown>][] = [];
    const result = await fn({
      getAll: async (...refs) =>
        refs.map((ref) => ({ data: () => this.docs.get(ref.path) })),
      set: (ref, data) => {
        writes.push([ref.path, data]);
      },
    });
    for (const [path, data] of writes) this.docs.set(path, data);
    return result;
  }
}

function storeWith(db: FakeFirestore) {
  return new FirestoreQuotaStore(() => db as unknown as Firestore);
}

const TOKEN_A = "A".repeat(43);
const TOKEN_B = "B".repeat(43);
const NOW = new Date("2026-10-12T01:30:00Z"); // 2026-10-12 10:30 KST
const LIMITS = { perInstall: 3, total: 5 };

function countOf(db: FakeFirestore, id: string): unknown {
  return db.docs.get(`${USAGE_COLLECTION}/${id}`)?.count;
}

describe("seoulDate", () => {
  it("uses the Asia/Seoul calendar date", () => {
    expect(seoulDate(new Date("2026-10-12T14:59:59Z"))).toBe("2026-10-12");
    expect(seoulDate(new Date("2026-10-12T15:00:00Z"))).toBe("2026-10-13");
    expect(seoulDate(new Date("2026-12-31T15:00:00Z"))).toBe("2027-01-01");
  });
});

describe("usageExpireAt", () => {
  it("is two days after 00:00 KST of that date", () => {
    expect(usageExpireAt("2026-10-12").toISOString()).toBe(
      "2026-10-13T15:00:00.000Z",
    );
  });
});

describe("decideQuota", () => {
  it("checks the install limit first, then the service limit", () => {
    expect(decideQuota(2, 4, LIMITS)).toBe("ok");
    expect(decideQuota(3, 0, LIMITS)).toBe("install_limit");
    expect(decideQuota(3, 5, LIMITS)).toBe("install_limit");
    expect(decideQuota(0, 5, LIMITS)).toBe("service_limit");
  });
});

describe("FirestoreQuotaStore", () => {
  it("counts a call on the day's total and on the install, with expireAt", async () => {
    const db = new FakeFirestore();

    expect(await storeWith(db).take(TOKEN_A, NOW, LIMITS)).toBe("ok");

    const expireAt = usageExpireAt("2026-10-12").getTime();
    for (const id of ["2026-10-12", `2026-10-12_${TOKEN_A}`]) {
      const doc = db.docs.get(`${USAGE_COLLECTION}/${id}`);
      expect(doc?.count, id).toBe(1);
      expect((doc?.expireAt as { toMillis(): number }).toMillis(), id).toBe(
        expireAt,
      );
    }
    expect(db.transactions).toBe(1);
  });

  it("stops at the install limit without counting", async () => {
    const db = new FakeFirestore();
    const store = storeWith(db);
    for (let i = 0; i < LIMITS.perInstall; i++) {
      expect(await store.take(TOKEN_A, NOW, LIMITS)).toBe("ok");
    }

    expect(await store.take(TOKEN_A, NOW, LIMITS)).toBe("install_limit");
    expect(countOf(db, `2026-10-12_${TOKEN_A}`)).toBe(3);
    expect(countOf(db, "2026-10-12")).toBe(3);
    // 다른 설치는 아직 쓸 수 있다.
    expect(await store.take(TOKEN_B, NOW, LIMITS)).toBe("ok");
  });

  it("stops at the service limit across installs without counting", async () => {
    const db = new FakeFirestore();
    const store = storeWith(db);
    for (const token of [TOKEN_A, TOKEN_A, TOKEN_A, TOKEN_B, TOKEN_B]) {
      expect(await store.take(token, NOW, LIMITS)).toBe("ok");
    }

    expect(await store.take(TOKEN_B, NOW, LIMITS)).toBe("service_limit");
    expect(countOf(db, "2026-10-12")).toBe(5);
    expect(countOf(db, `2026-10-12_${TOKEN_B}`)).toBe(2);
  });

  it("starts over on the next Seoul day", async () => {
    const db = new FakeFirestore();
    const store = storeWith(db);
    for (let i = 0; i < LIMITS.perInstall; i++) {
      await store.take(TOKEN_A, NOW, LIMITS);
    }

    const nextDay = new Date("2026-10-12T15:00:00Z"); // 10-13 00:00 KST
    expect(await store.take(TOKEN_A, nextDay, LIMITS)).toBe("ok");
    expect(countOf(db, `2026-10-13_${TOKEN_A}`)).toBe(1);
  });

  it("treats a count that is not a number as zero", async () => {
    const db = new FakeFirestore();
    db.docs.set(`${USAGE_COLLECTION}/2026-10-12`, { count: "many" });

    expect(await storeWith(db).take(TOKEN_A, NOW, LIMITS)).toBe("ok");
    expect(countOf(db, "2026-10-12")).toBe(1);
  });
});
