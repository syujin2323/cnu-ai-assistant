// 제공사용 응답 스키마(src/ai/parse_output.schema.json)가 Claude 구조화 출력이 받는 꼴인지, 앱·서버 약속의
// 스키마(schema/parse_result.schema.json)와 키가 같은지 본다(docs/architecture.md '폴더 구조'의 schema/ 문단).
import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

type Json = Record<string, unknown>;

const provider = JSON.parse(
  readFileSync(
    new URL("../../src/ai/parse_output.schema.json", import.meta.url),
    "utf8",
  ),
) as Json;
const contract = JSON.parse(
  readFileSync(
    new URL("../../../schema/parse_result.schema.json", import.meta.url),
    "utf8",
  ),
) as Json;

/** 구조화 출력이 받지 않거나 쓰지 않기로 한 키워드. */
const UNSUPPORTED = [
  "minimum",
  "maximum",
  "exclusiveMinimum",
  "exclusiveMaximum",
  "multipleOf",
  "minLength",
  "maxLength",
  "maxItems",
  "uniqueItems",
  "patternProperties",
  "propertyNames",
  "dependencies",
  "if",
  "not",
  "oneOf",
  "$schema",
  "$id",
];

function visit(
  node: unknown,
  path: string,
  fn: (obj: Json, path: string) => void,
) {
  if (Array.isArray(node)) {
    node.forEach((child, i) => visit(child, `${path}/${i}`, fn));
  } else if (typeof node === "object" && node !== null) {
    fn(node as Json, path);
    for (const [key, child] of Object.entries(node)) {
      visit(child, `${path}/${key}`, fn);
    }
  }
}

/** object 스키마의 경로 → 키 목록. $ref는 definitions로 따라간다. */
function objectKeys(schema: Json): Map<string, string[]> {
  const definitions = (schema.definitions ?? {}) as Record<string, Json>;
  const keys = new Map<string, string[]>();
  const walk = (node: Json, path: string) => {
    const ref = node.$ref;
    if (typeof ref === "string") {
      walk(definitions[ref.replace("#/definitions/", "")]!, path);
      return;
    }
    const properties = node.properties as Record<string, Json> | undefined;
    if (properties !== undefined) {
      keys.set(path, Object.keys(properties));
      for (const [key, child] of Object.entries(properties)) {
        walk(child, `${path}.${key}`);
      }
    }
    const items = node.items as Json | undefined;
    if (items !== undefined) walk(items, `${path}[]`);
  };
  walk(schema, "$");
  return keys;
}

describe("provider output schema", () => {
  it("uses no union types, so it stays within the 16 union-typed parameters", () => {
    let unions = 0;
    visit(provider, "#", (node) => {
      if (Array.isArray(node.type) || "anyOf" in node || "allOf" in node)
        unions++;
    });
    expect(unions).toBe(0);
  });

  it("requires every key and allows no others, so it has no optional parameters", () => {
    let objects = 0;
    visit(provider, "#", (node, path) => {
      if (node.type !== "object") return;
      objects++;
      expect(node.additionalProperties, path).toBe(false);
      expect(new Set(node.required as string[]), path).toEqual(
        new Set(Object.keys(node.properties as Json)),
      );
    });
    expect(objects).toBe(5);
  });

  it("uses only keywords that structured outputs accept", () => {
    visit(provider, "#", (node, path) => {
      for (const keyword of UNSUPPORTED) {
        expect(keyword in node, `${path} ${keyword}`).toBe(false);
      }
      if ("minItems" in node) {
        expect([0, 1], path).toContain(node.minItems);
      }
      if (typeof node.$ref === "string") {
        expect(node.$ref, path).toMatch(/^#\/definitions\//);
      }
    });
  });

  it("has the same keys as the app–server contract at every level", () => {
    expect(objectKeys(provider)).toEqual(objectKeys(contract));
  });
});
