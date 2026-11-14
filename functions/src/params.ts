// Functions 설정값과 비밀값(docs/architecture.md '환경 변수').
//
// 설정값의 원본은 여기의 기본값이고, 바꿀 때는 기본값을 고치는 PR로 한다. 다른 값을 잠깐 쓸 때만
// functions/.env(커밋하지 않음)에 적고, 이름과 기본값은 functions/.env.example에 적는다.
// 비밀값은 쓰는 함수의 secrets 옵션에 묶고 `firebase functions:secrets:set <이름>`으로 Secret Manager에 넣는다.
// 값은 핸들러 안에서 .value()로 읽는다. 모듈 최상위에서 읽으면 배포가 실패한다.
import {
  defineBoolean,
  defineInt,
  defineSecret,
} from "firebase-functions/params";

/** 설치당 하루 AI 호출 한도(모든 AI 경로 합계). 넘으면 429 install_limit. */
export const aiDailyLimitPerInstall = defineInt("AI_DAILY_LIMIT_PER_INSTALL", {
  default: 30,
});

/** 서비스 전체 하루 AI 호출 상한. 넘으면 503 service_limit. 월 API 예산에 맞춘 시작값이다. */
export const aiDailyLimitTotal = defineInt("AI_DAILY_LIMIT_TOTAL", {
  default: 400,
});

/** true면 App Check 검증 실패를 401로 거부하고, false면 로그의 appCheck 필드에만 남긴다. */
export const appCheckEnforce = defineBoolean("APP_CHECK_ENFORCE", {
  default: false,
});

/** AI 게이트웨이의 제공사 API 키. 모델을 바꿔도 이름은 그대로 둔다. */
export const llmApiKey = defineSecret("LLM_API_KEY");
