import { describe, expect, it } from "vitest";

import { describeError } from "../../src/http/request-log.js";

describe("describeError", () => {
  it("keeps the name of an Error and drops its message", () => {
    expect(describeError(new TypeError("private text"))).toEqual({
      name: "TypeError",
    });
  });

  it("keeps an integer status", () => {
    const error = Object.assign(new Error("x"), { status: 529 });
    error.name = "APIError";
    expect(describeError(error)).toEqual({ name: "APIError", status: 529 });
  });

  it("drops a status that is not an integer", () => {
    expect(
      describeError(Object.assign(new Error("x"), { status: "529" })),
    ).toEqual({ name: "Error" });
    expect(
      describeError(Object.assign(new Error("x"), { status: 1.5 })),
    ).toEqual({ name: "Error" });
  });

  it("logs a name that is not name-shaped as Error", () => {
    const error = new Error("x");
    error.name = "Error: 학번 1234 for user";
    expect(describeError(error)).toEqual({ name: "Error" });
  });

  it("logs values that are not Errors as Error", () => {
    expect(describeError("text thrown as a string")).toEqual({ name: "Error" });
    expect(describeError(undefined)).toEqual({ name: "Error" });
    expect(describeError({ status: 400 })).toEqual({
      name: "Error",
      status: 400,
    });
  });
});
