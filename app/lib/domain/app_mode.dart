// 앱 모드. docs/architecture.md '데모 모드'.
//
// `shared_preferences`의 `app_mode` 키에 enum 이름(`real`/`demo`)으로 둔다.
// `databaseProvider`는 이 값을 보고 폰 DB 파일을 고른다(real은 `app.sqlite`,
// demo는 `app_demo.sqlite`). 두 파일은 서로 읽지 않으므로 데이터가 섞이지 않는다.

/// 실제 계정으로 쓰는 모드([real])와 샘플 학생의 하루로 도는 모드([demo]).
enum AppMode { real, demo }
