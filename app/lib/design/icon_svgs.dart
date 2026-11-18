// 아이콘 SVG 원본(캔버스 '최종 프로토타입'의 아이콘). docs/architecture.md '앱 코드 규약'(아이콘).
//
// 에셋 파일이 아니라 Dart 문자열로 둔다. 에셋은 Shorebird 패치로 바꿀 수 없어 새 아이콘마다 새 release가 필요하기
// 때문이다(docs/decisions.md 2026-11-19 '아이콘 SVG는 Dart 문자열로 둔다'). 모두 24 viewBox이고 선은
// `currentColor`, 끝은 둥글며, 색은 [AppIcon](`design/icons.dart`)이 `colorFilter`로 입힌다. 새 아이콘은 여기에
// 문자열 하나와 `AppIconName`에 한 줄을 더한다.

/// 아이콘 이름마다의 SVG 문자열.
abstract final class IconSvgs {
  static const today =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2.8v2M12 19.2v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2.8 12h2M19.2 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>''';

  static const calendar =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="5" width="17" height="15.5" rx="3.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/></svg>''';

  static const tasks =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><path d="m8 12.3 2.7 2.7 5.3-5.5"/></svg>''';

  static const me =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8.5" r="3.6"/><path d="M5 20c1.3-3.6 4-5.2 7-5.2s5.7 1.6 7 5.2"/></svg>''';

  static const assistant =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5.2 17.6 4 21l3.9-1.6c1.2.5 2.6.8 4.1.8 4.7 0 8.5-3.4 8.5-7.6S16.7 5 12 5 3.5 8.4 3.5 12.6c0 1.9.6 3.6 1.7 5Z"/><path d="M8.5 11.6h7M8.5 14.6h4.5"/></svg>''';

  static const bell =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9.5a6 6 0 1 1 12 0c0 4.4 1.5 6.1 2 6.9H4c.5-.8 2-2.5 2-6.9Z"/><path d="M10 19.6a2.2 2.2 0 0 0 4 0"/></svg>''';

  static const refresh =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M19.5 8.5A8 8 0 0 0 5 7.4M4.5 15.5A8 8 0 0 0 19 16.6"/><path d="M19.8 4.6v4h-4M4.2 19.4v-4h4"/></svg>''';

  /// 할 일 탭과 같은 그림.
  static const checkSquare = tasks;

  static const check =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>''';

  static const clock =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>''';

  static const freeTime =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 10h11v3.5a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5Z"/><path d="M16 11.5h1.5a2 2 0 0 1 0 4H16M8.5 4.5c0 1.5 1.5 1.5 1.5 3M12 4.5c0 1.5 1.5 1.5 1.5 3"/></svg>''';

  static const chevronRight =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>''';

  static const hourglass =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 3.5h10M7 20.5h10M8 3.5c0 4.5 4 5.5 4 8.5s-4 4-4 8.5M16 3.5c0 4.5-4 5.5-4 8.5s4 4 4 8.5"/></svg>''';

  static const chevronUp =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="m6 15 6-6 6 6"/></svg>''';

  static const plus =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>''';

  static const bus =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="3.5" width="14" height="14" rx="3"/><path d="M5 11h14M8 20.5v-3M16 20.5v-3M8.5 14.5h.1M15.5 14.5h.1"/></svg>''';

  static const meal =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 3v8M5 3v4.5a2 2 0 0 0 4 0V3M7 11v10M16.5 21V3c-2 1.2-3 3.5-3 6.5V13h3"/></svg>''';

  /// 나 탭과 같은 그림.
  static const person = me;

  static const exercise =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 8v8M17.5 8v8M4 10v4M20 10v4M6.5 12h11"/></svg>''';

  static const pencil =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5.5 18.5 9.5M4 20l1-4.4L15.6 5a2 2 0 0 1 2.9 0l.5.5a2 2 0 0 1 0 2.9L8.4 19Z"/></svg>''';

  static const flag =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5.5 21V4M5.5 4.5h11l-2 4 2 4h-11"/></svg>''';

  static const info =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8v.1"/></svg>''';

  static const undo =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M9 7 4.5 11.5 9 16"/><path d="M4.5 11.5H15a4.5 4.5 0 0 1 0 9h-2"/></svg>''';

  static const warning =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4.2 2.9 19.5h18.2L12 4.2Z"/><path d="M12 10v4.2M12 17.1v.1"/></svg>''';

  static const close =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/></svg>''';

  static const send =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V5M6 11l6-6 6 6"/></svg>''';

  static const key =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="8" cy="15" r="4"/><path d="m11 12 8.5-8.5M16.5 6.5l2 2M14.5 8.5l1.5 1.5"/></svg>''';

  static const demo =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="3"/><path d="m10 9.2 5 2.8-5 2.8Z"/></svg>''';

  static const trash =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 7h15M10 3.8h4M6.5 7l.8 12.2a1.8 1.8 0 0 0 1.8 1.6h5.8a1.8 1.8 0 0 0 1.8-1.6L17.5 7M10 11v6M14 11v6"/></svg>''';

  static const shield =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.2 5 6v5.3c0 4.4 3 7.9 7 9.5 4-1.6 7-5.1 7-9.5V6l-7-2.8Z"/><path d="m9 12.2 2.2 2.2L15.2 10"/></svg>''';

  static const doc =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 3h7l4.5 4.5V19a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z"/><path d="M14 3v4.5h4.5M8.5 12.5h7M8.5 16h5"/></svg>''';

  static const list =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M9 7h11M9 12h11M9 17h11M4.5 7h.1M4.5 12h.1M4.5 17h.1"/></svg>''';

  static const mail =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/><path d="m4.5 7.5 7.5 5.5 7.5-5.5"/></svg>''';

  static const school =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5 12 5l9 4.5-9 4.5Z"/><path d="M7 11.5v4.5c1.4 1.3 3 2 5 2s3.6-.7 5-2v-4.5M21 9.5v5"/></svg>''';

  static const moon =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M19.5 14.6A7.6 7.6 0 0 1 9.4 4.5a7.6 7.6 0 1 0 10.1 10.1Z"/></svg>''';

  /// 오늘 탭과 같은 그림.
  static const sun = today;

  static const eye =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M2.8 12S6.2 5.5 12 5.5 21.2 12 21.2 12 17.8 18.5 12 18.5 2.8 12 2.8 12Z"/><circle cx="12" cy="12" r="2.8"/></svg>''';

  static const work =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M3 9.5h18M7 15h4"/></svg>''';

  static const place =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s6.5-5.6 6.5-11a6.5 6.5 0 0 0-13 0c0 5.4 6.5 11 6.5 11Z"/><circle cx="12" cy="10" r="2.3"/></svg>''';

  // 03 할 일 줄 머리의 할 일 종류(캔버스 03 할 일). 과제·자료는 [doc], 시험은 [flag], 개인은 [person]이다.

  /// 영상(재생 화면). 데모 모드 아이콘과 같은 그림이다.
  static const video = demo;

  static const quiz =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.6a2.5 2.5 0 1 1 3.4 2.3c-.6.3-1 .8-1 1.5v.6M12 16.8v.1"/></svg>''';

  static const team =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="9" r="3.2"/><path d="M3.5 19c.9-3 3-4.5 5.5-4.5s4.6 1.5 5.5 4.5"/><circle cx="16.8" cy="9.6" r="2.6"/><path d="M16.5 14.3c2 .2 3.4 1.5 4 4"/></svg>''';

  static const discussion =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h8A2.5 2.5 0 0 1 17 6.5v5a2.5 2.5 0 0 1-2.5 2.5H9l-4 3v-3.3a2.5 2.5 0 0 1-1-2Z"/><path d="M17 9h.5A2.5 2.5 0 0 1 20 11.5v4.3a2.5 2.5 0 0 1-1 2V21l-3-2.4h-4.5a2.5 2.5 0 0 1-2.4-1.9"/></svg>''';

  /// 내 규칙(조절 막대). 03 할 일 '얼마나 걸렸어요?'의 저장할 규칙 줄.
  static const rule =
      r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2.2"/><circle cx="9" cy="17" r="2.2"/></svg>''';
}
