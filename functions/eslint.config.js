// typescript-eslint recommended와 Prettier 기본값(docs/architecture.md '확인과 CI'). 포맷은 Prettier가 맡으므로
// 포맷과 겹치는 ESLint 규칙은 eslint-config-prettier로 끈다. 규칙을 더하거나 끄면 docs/decisions.md에 적는다.
import js from "@eslint/js";
import prettier from "eslint-config-prettier/flat";
import { defineConfig, globalIgnores } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig([
  globalIgnores(["lib/", "coverage/", "src/schema/"]),
  js.configs.recommended,
  tseslint.configs.recommended,
  prettier,
]);
