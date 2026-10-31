// 한국 음력 표(app/lib/domain/text/lunar_data.dart)를 만든다.
// ICU의 dangi(단기) 달력을 Node Intl로 읽어 음력 각 달이 시작하는 양력 날짜를 모은다.
// full ICU가 들어간 Node가 필요하다. 실행: node tool/gen_lunar_data.js (app/ 폴더에서)
//
// 값 하나는 `기준일부터 지난 날 수 * 32 + 달 * 2 + 윤달 여부`다. 마지막 값은 표가 끝나는
// 자리를 알리는 다음 달의 시작이다.

'use strict';

const fs = require('fs');
const path = require('path');

// 이 범위의 날은 반드시 표 안에 들어간다. 앞뒤로 그 날이 든 음력 달 전체가 함께 들어간다.
const FROM = Date.UTC(2000, 0, 1);
const TO = Date.UTC(2050, 11, 31);
const DAY = 86400000;

const fmt = new Intl.DateTimeFormat('ko-KR-u-ca-dangi', {
  timeZone: 'UTC',
  month: 'numeric',
  day: 'numeric',
});

// ICU는 윤달을 '윤6'처럼 달 숫자 앞에 '윤'을 붙여 적는다.
function lunarOf(ms) {
  const parts = fmt.formatToParts(new Date(ms));
  const raw = parts.find((p) => p.type === 'month').value;
  const day = Number(parts.find((p) => p.type === 'day').value);
  const m = /^(윤)?(\d{1,2})$/.exec(raw);
  if (!m) throw new Error(`알 수 없는 달 표기: ${raw}`);
  return { month: Number(m[2]), leap: m[1] !== undefined, day };
}

function iso(ms) {
  return new Date(ms).toISOString().slice(0, 10);
}

// FROM이 든 달의 첫날까지 거슬러 간다.
let start = FROM;
while (lunarOf(start).day !== 1) start -= DAY;

const starts = [];
let prev = null;
for (let ms = start; ; ms += DAY) {
  const l = lunarOf(ms);
  if (prev && l.day !== prev.day + 1 && l.day !== 1) {
    throw new Error(`날이 이어지지 않음: ${iso(ms)}`);
  }
  if (l.day === 1) {
    starts.push({ ms, month: l.month, leap: l.leap });
    // TO가 든 달의 다음 달 시작까지 넣고 멈춘다.
    if (ms > TO) break;
  }
  prev = l;
}

for (let i = 1; i < starts.length; i++) {
  const len = (starts[i].ms - starts[i - 1].ms) / DAY;
  if (len !== 29 && len !== 30) {
    throw new Error(`달 길이 이상: ${iso(starts[i - 1].ms)} ${len}일`);
  }
}

const base = starts[0].ms;
const values = starts.map(
  (s) => ((s.ms - base) / DAY) * 32 + s.month * 2 + (s.leap ? 1 : 0),
);
const baseDate = new Date(base);
const last = iso(starts[starts.length - 1].ms - DAY);

const lines = [];
for (let i = 0; i < values.length; i += 10) {
  lines.push('  ' + values.slice(i, i + 10).join(', ') + ',');
}

const out = `// 생성된 파일이다. 직접 고치지 않고 app/tool/gen_lunar_data.js를 다시 돌린다.
// 출처: ICU dangi 달력(Node ${process.version} Intl, ICU ${process.versions.icu}).
// 범위: 양력 ${iso(base)}–${last} (음력 달 ${values.length - 1}개).
//
// 값 하나는 음력 한 달의 시작이다. \`[lunarBase]부터 지난 날 수 * 32 + 달 * 2 + 윤달이면 1\`.
// 마지막 값은 표가 끝나는 자리(그다음 달의 시작)다.

/// 표의 첫 값이 가리키는 양력 날짜(UTC 자정).
final lunarBase = DateTime.utc(${baseDate.getUTCFullYear()}, ${baseDate.getUTCMonth() + 1}, ${baseDate.getUTCDate()});

// 한 줄에 값 하나씩 늘어서지 않게 포맷을 끈다.
// dart format off
/// 음력 각 달의 시작. 오름차순이다.
const lunarMonthStarts = <int>[
${lines.join('\n')}
];
// dart format on
`;

const target = path.join(__dirname, '..', 'lib', 'domain', 'text', 'lunar_data.dart');
fs.writeFileSync(target, out);
console.log(`${target}: ${iso(base)}–${last}, ${values.length}개 값`);
