// /v1/parse의 스키마 검증(ajv). 요청 본문(서버만 씀), 제공사용 응답, 앱·서버 약속의 응답을 본다.
// 앱·서버 약속의 스키마는 레포 루트 schema/에서 복사한 src/schema/를 읽는다(scripts/copy-schema.mjs).
import { Ajv, type ValidateFunction } from "ajv";
import addFormatsModule from "ajv-formats";

import parseResultSchema from "../schema/parse_result.schema.json" with { type: "json" };
import parseOutputSchema from "./parse_output.schema.json" with { type: "json" };
import parseRequestSchema from "./parse_request.schema.json" with { type: "json" };
import type { ProviderOutput } from "./convert.js";
import type { ParseResult } from "./types.js";

// ajv-formats는 CommonJS 모듈이라 ES 모듈의 기본 가져오기는 module.exports이고, 플러그인 함수는 그
// default에도 있다(타입도 그쪽에 붙어 있음).
const addFormats = addFormatsModule.default;

const ajv = new Ajv({ strict: true, allErrors: false });
addFormats(ajv, ["date"]);

/** 제공사 구조화 출력에 넣는 응답 스키마(src/ai/parse_output.schema.json). */
export const providerOutputSchema: Record<string, unknown> = parseOutputSchema;

const validateRequest = ajv.compile(parseRequestSchema);
const validateProviderOutput = ajv.compile(parseOutputSchema);
const validateResult: ValidateFunction = ajv.compile(parseResultSchema);

/** 요청 본문이 요청 스키마를 따르는지. 모르는 필드는 따지지 않는다. */
export function isParseRequest(body: unknown): boolean {
  return validateRequest(body);
}

/** 제공사 응답이 제공사용 스키마를 따르는지. */
export function isProviderOutput(value: unknown): value is ProviderOutput {
  return validateProviderOutput(value);
}

/** 응답이 앱·서버 약속의 스키마를 따르는지(날짜는 달력에 있는 날짜인지도 본다). */
export function isParseResult(value: unknown): value is ParseResult {
  return validateResult(value);
}
