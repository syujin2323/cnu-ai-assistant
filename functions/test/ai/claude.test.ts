// Claude 어댑터 테스트. 네트워크 없이 SDK 호출(client.beta.messages.create)을 가짜로 바꾼다.
import Anthropic from "@anthropic-ai/sdk";
import type {
  BetaMessage,
  MessageCreateParamsNonStreaming,
} from "@anthropic-ai/sdk/resources/beta/messages/messages";
import { describe, expect, it } from "vitest";

import {
  buildParseRequest,
  calendarAround,
  ClaudeProvider,
  CLAUDE_MODEL,
  FALLBACK_BETA,
  PARSE_MAX_TOKENS,
} from "../../src/ai/claude.js";
import { toProviderOutput } from "../../src/ai/convert.js";
import { PARSE_SYSTEM_PROMPT } from "../../src/ai/prompts/parse.js";
import { ProviderError } from "../../src/ai/provider.js";
import type { ParseInput } from "../../src/ai/types.js";
import { providerOutputSchema } from "../../src/ai/validate.js";
import { loadSamples, sampleInput } from "../support/samples.js";

const samples = loadSamples();
const once = samples.get("create_event_once")!;

/** 텍스트 블록 하나와 stop_reason, 토큰 사용량을 가진 가짜 응답. */
function message(
  content: unknown[],
  stopReason = "end_turn",
  cacheRead: number | null = 2000,
): BetaMessage {
  return {
    id: "msg_synthetic",
    type: "message",
    role: "assistant",
    model: CLAUDE_MODEL,
    content,
    stop_reason: stopReason,
    stop_sequence: null,
    usage: {
      input_tokens: 500,
      output_tokens: 300,
      cache_read_input_tokens: cacheRead,
      cache_creation_input_tokens: 0,
    },
  } as unknown as BetaMessage;
}

function textBlock(value: unknown): unknown {
  return {
    type: "text",
    text: typeof value === "string" ? value : JSON.stringify(value),
  };
}

function providerReturning(response: BetaMessage | Error) {
  const requests: MessageCreateParamsNonStreaming[] = [];
  const provider = new ClaudeProvider(async (params) => {
    requests.push(params);
    if (response instanceof Error) throw response;
    return response;
  });
  return { provider, requests };
}

async function parseError(
  provider: ClaudeProvider,
  input: ParseInput = sampleInput(),
): Promise<ProviderError> {
  try {
    await provider.parse(input);
  } catch (error) {
    expect(error).toBeInstanceOf(ProviderError);
    return error as ProviderError;
  }
  throw new Error("parse did not fail");
}

describe("calendarAround", () => {
  it("lists every day from a week before to six weeks after today", () => {
    const calendar = calendarAround("2026-10-12");
    const days = Object.keys(calendar);
    expect(days).toHaveLength(50);
    expect(days[0]).toBe("2026-10-05");
    expect(days.at(-1)).toBe("2026-11-23");
    expect(calendar).toMatchObject({
      "2026-10-05": "월",
      "2026-10-12": "월",
      "2026-10-15": "목",
      "2026-10-16": "금",
      "2026-10-18": "일",
      "2026-11-23": "월",
    });
  });

  it("crosses months, years and leap days", () => {
    expect(calendarAround("2026-12-28")).toMatchObject({
      "2026-12-31": "목",
      "2027-01-01": "금",
    });
    expect(calendarAround("2028-02-27")).toMatchObject({
      "2028-02-29": "화",
      "2028-03-01": "수",
    });
  });
});

describe("buildParseRequest", () => {
  it("builds the request the provider rules describe", () => {
    const params = buildParseRequest(sampleInput("내일 3시 회의"));

    expect(params.model).toBe("claude-sonnet-5-5");
    expect(params.max_tokens).toBe(PARSE_MAX_TOKENS);
    expect(params.thinking).toEqual({ type: "between_tools" });
    expect(params.output_config).toEqual({
      effort: "low",
      format: { type: "json_schema", schema: providerOutputSchema },
    });
    expect(params.betas).toEqual([FALLBACK_BETA]);
    expect(params.fallbacks).toBe("default");
    expect(params.system).toEqual([
      {
        type: "text",
        text: PARSE_SYSTEM_PROMPT,
        cache_control: { type: "ephemeral" },
      },
    ]);
    expect(params.messages).toHaveLength(1);
    expect(params.messages[0]!.role).toBe("user");
    const input = sampleInput("내일 3시 회의");
    expect(JSON.parse(params.messages[0]!.content as string)).toEqual({
      ...input,
      calendar: calendarAround(input.today),
    });
  });

  it("sends no sampling parameters, tools, metadata or prefill", () => {
    const params = buildParseRequest(sampleInput()) as unknown as Record<
      string,
      unknown
    >;
    for (const key of [
      "temperature",
      "top_p",
      "top_k",
      "tools",
      "tool_choice",
      "metadata",
      "stop_sequences",
    ]) {
      expect(key in params, key).toBe(false);
    }
  });

  it("passes only the known request fields to the model", () => {
    const input = {
      ...sampleInput(),
      installToken: "should-not-leak",
      courses: [{ name: "데이터구조", professor: "should-not-leak" }],
    } as unknown as ParseInput;
    const content = buildParseRequest(input).messages[0]!.content as string;
    expect(content).not.toContain("should-not-leak");
  });

  it("keeps the system prompt identical between requests for caching", () => {
    const a = buildParseRequest(sampleInput("하나"));
    const b = buildParseRequest({ ...sampleInput("둘"), today: "2026-11-02" });
    expect(a.system).toEqual(b.system);
  });
});

describe("ClaudeProvider.parse", () => {
  it("returns the converted result and the token usage", async () => {
    const { provider, requests } = providerReturning(
      message([textBlock(toProviderOutput(once))]),
    );

    const outcome = await provider.parse(sampleInput());

    expect(outcome.result).toEqual(once);
    expect(outcome.usage).toEqual({
      inputTokens: 500,
      outputTokens: 300,
      cacheReadTokens: 2000,
    });
    expect(requests).toHaveLength(1);
  });

  it("reads the text block among thinking and fallback blocks", async () => {
    const { provider } = providerReturning(
      message([
        { type: "thinking", thinking: "", signature: "x" },
        {
          type: "fallback",
          from: { model: CLAUDE_MODEL },
          to: { model: "claude-sonnet-5" },
        },
        textBlock(toProviderOutput(once)),
      ]),
    );
    expect((await provider.parse(sampleInput())).result).toEqual(once);
  });

  it("counts missing cache reads as zero", async () => {
    const { provider } = providerReturning(
      message([textBlock(toProviderOutput(once))], "end_turn", null),
    );
    expect((await provider.parse(sampleInput())).usage.cacheReadTokens).toBe(0);
  });

  it("drops a course the request did not list", async () => {
    const output = toProviderOutput(samples.get("create_task_course")!);
    output.items[0]!.course = "자구";
    const { provider } = providerReturning(message([textBlock(output)]));
    expect(
      (await provider.parse(sampleInput())).result.items[0]!.course,
    ).toBeNull();
  });

  it("fails with refusal when the model declines", async () => {
    const { provider } = providerReturning(message([textBlock("")], "refusal"));
    const error = await parseError(provider);
    expect(error.code).toBe("refusal");
    expect(error.usage?.outputTokens).toBe(300);
  });

  it("fails with invalid_output when the output stopped early", async () => {
    // 잘린 글자도, 우연히 끝까지 읽히는 글자도 끝나지 않은 응답이면 받지 않는다.
    for (const text of [
      '{"intent": "crea',
      JSON.stringify(toProviderOutput(once)),
    ]) {
      const { provider } = providerReturning(
        message([textBlock(text)], "max_tokens"),
      );
      expect((await parseError(provider)).code).toBe("invalid_output");
    }
  });

  it("fails with invalid_output without exactly one text block", async () => {
    for (const content of [
      [],
      [textBlock(toProviderOutput(once)), textBlock("{}")],
    ]) {
      const { provider } = providerReturning(message(content));
      expect((await parseError(provider)).code).toBe("invalid_output");
    }
  });

  it("fails with invalid_output on text that is not JSON", async () => {
    const { provider } = providerReturning(message([textBlock("{not json")]));
    const error = await parseError(provider);
    expect(error.code).toBe("invalid_output");
    expect(error.cause).toBeInstanceOf(SyntaxError);
  });

  it("fails with invalid_output when the output breaks the provider schema", async () => {
    const missingKey = toProviderOutput(once) as unknown as Record<
      string,
      unknown
    >;
    delete missingKey.queryFrom;
    // 숫자 칸을 숫자로 보내면 null로 바꾼 뒤에는 약속을 따르지만, 제공사용 스키마(숫자 문자열)는 어긴다.
    const numberNotText = toProviderOutput(once);
    (
      numberNotText.items[0] as unknown as Record<string, unknown>
    ).estimatedMinutes = 90;
    for (const output of [missingKey, numberNotText]) {
      const { provider } = providerReturning(message([textBlock(output)]));
      expect((await parseError(provider)).code).toBe("invalid_output");
    }
  });

  it("fails with invalid_output on a date that is not on the calendar", async () => {
    // 제공사용 스키마의 패턴은 통과하지만 앱·서버 약속의 date 형식(달력)은 통과하지 못한다.
    const output = toProviderOutput(once);
    output.items[0]!.date = "2026-02-30";
    const { provider } = providerReturning(message([textBlock(output)]));
    expect((await parseError(provider)).code).toBe("invalid_output");
  });

  it("fails with provider_error and keeps the SDK error as the cause", async () => {
    const overloaded = Anthropic.APIError.generate(
      529,
      { type: "error", error: { type: "overloaded_error", message: "x" } },
      "overloaded",
      new Headers(),
    );
    const { provider } = providerReturning(overloaded);
    const error = await parseError(provider);
    expect(error.code).toBe("provider_error");
    expect(error.cause).toBe(overloaded);
  });
});
