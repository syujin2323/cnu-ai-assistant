# 결정 기록

팀이 정한 것을 시간 순서로 쌓습니다. 새 결정은 맨 아래에 추가합니다. 이전 결정을 바꿀 때도 지우지 않고 새 항목으로 적습니다.

```markdown
## YYYY-MM-DD 제목

- 결정:
- 이유:
- 다른 후보: (있으면)
```

## 2026-10-03 협업 규칙

- 결정: main, develop, 작업 브랜치로 나눈다. 작업은 PR로 develop에 squash 병합한다. 이때 리뷰어 1명의 승인을 받는 것은 팀 약속이고 GitHub는 강제하지 않는다. develop에서 main으로는 팀원 1명 승인 후(GitHub가 강제) 병합 커밋으로 올린다. 커밋 메시지와 PR 제목은 `종류: 설명` 형식이다. 자세한 규칙은 CLAUDE.md에 있다.
- 이유: 규칙을 사람이 일일이 기억하지 않아도 되게 한다. GitHub에서 막을 수 있는 것은 설정으로 막고, 나머지는 Claude Code가 CLAUDE.md를 읽고 지키게 한다.
- 다른 후보: Claude Code 훅과 `.claude/settings.json`으로 강제(무거워서 뺌), 커밋 종류 `style`·`perf`·`ci`·`build`(`chore`로 묶음), rebase 병합(막음), 브랜치 이름 검사(안내만 함), develop 승인을 GitHub로 강제(약속으로만 둠).
