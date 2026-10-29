// 결과와 오류 타입. docs/architecture.md '앱 코드 규약'의 오류 처리.
//
// 저장소, API 클라이언트, `lms/`는 예외를 던지지 않고 [Result]를 돌려준다.
// 화면은 [Err]를 받으면 기존 데이터를 그대로 두고 상태 문구만 바꾼다.
// 예외는 프로그래밍 오류에만 쓴다.
//
// 오류에는 로그에 남겨도 되는 값만 담는다. 제목, 과목명, 사용자 문장, 쿠키, 학번,
// 요청 주소, 응답 본문, 예외 메시지는 담지 않는다.

/// 성공([Ok])이나 실패([Err]) 가운데 하나.
sealed class Result<T> {
  const Result();
}

/// 성공. 값을 담는다.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// 실패. 오류를 담는다.
final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppError error;

  @override
  bool operator ==(Object other) => other is Err<T> && other.error == error;

  @override
  int get hashCode => Object.hash(Err, error);

  @override
  String toString() => 'Err($error)';
}

/// 앱이 다루는 오류. [ApiError], [LmsOutcome], [StorageError] 셋뿐이다.
sealed class AppError {
  const AppError();
}

/// 앱 서버(Functions) 호출 실패.
///
/// 앱은 [status]로만 동작을 정하고 [code]는 로그에만 쓴다
/// (docs/architecture.md '앱과 서버 사이 약속'의 오류 응답 표).
final class ApiError extends AppError {
  const ApiError(this.status, this.code);

  /// HTTP 상태 코드. 응답을 받지 못했으면(연결 실패, 시간 초과, 취소) null.
  final int? status;

  /// 오류 본문의 `error.code`(예: `install_limit`). 본문에 없으면 null.
  final String? code;

  @override
  bool operator ==(Object other) =>
      other is ApiError && other.status == status && other.code == code;

  @override
  int get hashCode => Object.hash(ApiError, status, code);

  @override
  String toString() => 'ApiError(status: $status, code: $code)';
}

/// 사캠 응답 판별의 일곱 가지. docs/lms.md '응답 판별'.
enum LmsOutcomeKind {
  /// 스키마에 맞는 JSON.
  normal,

  /// 스키마에 맞고 항목이 0개.
  empty,

  /// 로그인 주소로 넘어가거나 로그인 폼이 담긴 HTML.
  reloginRequired,

  /// JSON이지만 인증 오류 표시.
  restoreRequired,

  /// 5xx·429 또는 점검 페이지.
  serverError,

  /// 연결 실패, 시간 초과.
  networkFailure,

  /// 위 어디에도 맞지 않음, 스키마 검증 실패.
  parseFailure,
}

/// 사캠 조회 결과. 판별 종류와 HTTP 상태 코드만 담는다.
///
/// `lms/`는 `FormatException`·`DioException`을 안에서 잡아 이 값으로 바꾸고 밖으로
/// 던지지 않는다. URL, 헤더, 본문, 쿠키는 담지 않는다.
final class LmsOutcome extends AppError {
  const LmsOutcome(this.kind, {this.statusCode});

  final LmsOutcomeKind kind;

  /// HTTP 상태 코드. 응답을 받지 못했으면 null.
  final int? statusCode;

  @override
  bool operator ==(Object other) =>
      other is LmsOutcome &&
      other.kind == kind &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(LmsOutcome, kind, statusCode);

  @override
  String toString() => 'LmsOutcome(${kind.name}, statusCode: $statusCode)';
}

/// 폰 DB나 보안 저장소의 읽기·쓰기 실패.
final class StorageError extends AppError {
  const StorageError(this.operation, {this.causeType});

  /// 실패한 동작의 이름(예: `settings.write`).
  final String operation;

  /// 원인 예외의 타입 이름(예: `SqliteException`). 예외 메시지는 담지 않는다.
  final String? causeType;

  @override
  bool operator ==(Object other) =>
      other is StorageError &&
      other.operation == operation &&
      other.causeType == causeType;

  @override
  int get hashCode => Object.hash(StorageError, operation, causeType);

  @override
  String toString() =>
      'StorageError(operation: $operation, causeType: $causeType)';
}
