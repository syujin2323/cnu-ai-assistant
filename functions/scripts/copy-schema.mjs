// 레포 루트 schema/의 *.schema.json(앱·서버의 응답 약속)을 functions/src/schema/로 복사한다.
// build·lint·test·eval 앞에 돈다. 복사본은 .gitignore에 있어 커밋하지 않는다(docs/architecture.md '폴더 구조').
import { copyFileSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { URL } from "node:url";

const from = new URL("../../schema/", import.meta.url);
const to = new URL("../src/schema/", import.meta.url);

rmSync(to, { recursive: true, force: true });
mkdirSync(to, { recursive: true });
for (const name of readdirSync(from)) {
  if (name.endsWith(".schema.json")) {
    copyFileSync(new URL(name, from), new URL(name, to));
  }
}
