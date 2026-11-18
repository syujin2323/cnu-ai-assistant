// 처리방침·이용약관을 앱 안에서 보이는 전체 화면(덮개). docs/screens.md '개인정보 처리 안내 시트'·'10 나',
// docs/decisions.md 2026-11-18 '처리방침·이용약관은 별도 공개 레포의 GitHub Pages에 두고 앱 안에서도 보인다'.
//
// 외부 브라우저로 넘기지 않고, 앱에 넣어 둔 글(`design/legal_texts.dart`. 공개 레포에서 `make legal-sync`로 받음)을
// 앱의 글꼴·색으로 그린다. 표는 좁은 화면에서 읽기 쉽게 줄마다 카드로 그린다. 글 안의 링크는 두 문서 사이
// (`privacy`·`terms`)면 앱 안에서 그 문서를 열고, 그 밖의 주소(공개 레포의 바뀐 기록 등)는 외부 브라우저로 연다.

import 'package:cnu_ai_assistant/design/legal_texts.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/layer_route.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/external_link.dart';
import 'package:cnu_ai_assistant/domain/text/markdown_lite.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:material_ui/material_ui.dart';

/// 앱 안에서 보이는 문서.
enum LegalDocument {
  privacy('개인정보 처리방침', privacyPolicyMarkdown, 'privacy'),
  terms('이용약관', termsMarkdown, 'terms');

  const LegalDocument(this.title, this.markdown, this.path);

  /// 화면 위 제목.
  final String title;

  /// 공개 레포에서 받은 글.
  final String markdown;

  /// 공개 레포에서의 이름. 글 안의 링크가 이 이름이면 앱 안에서 연다.
  final String path;

  static LegalDocument? forLink(String href) {
    for (final document in values) {
      if (href == document.path || href == '${document.path}.md') {
        return document;
      }
    }
    return null;
  }
}

/// [document]를 지금 화면 위에 덮개로 연다(`layer` 모션). 시트 위에서 열어도 시트를 닫지 않는다.
Future<void> showLegalDocument(
  BuildContext context,
  LegalDocument document, {
  Future<bool> Function(Uri uri)? launcher,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    layerRoute<void>(
      motion: MotionScope.of(context),
      builder: (context) =>
          LegalDocumentPage(document: document, launcher: launcher),
    ),
  );
}

/// 처리방침·이용약관 화면.
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document, this.launcher});

  final LegalDocument document;

  /// 외부 주소를 여는 함수. null이면 외부 브라우저로 연다. 테스트가 바꾼다.
  final Future<bool> Function(Uri uri)? launcher;

  void _openLink(BuildContext context, String href) {
    if (LegalDocument.forLink(href) case final other?) {
      showLegalDocument(context, other, launcher: launcher);
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return;
    }
    openExternalLink(context, uri, launcher: launcher);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownLite(document.markdown);
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.s8,
            AppSpace.screen,
            AppSpace.s32,
          ),
          children: [
            // 맨 위 제목(`#`)은 화면 제목과 겹치므로 그리지 않는다.
            for (final block in blocks)
              if (block is! MdHeading || block.level > 1)
                _LegalBlock(
                  block: block,
                  onLink: (href) => _openLink(context, href),
                ),
          ],
        ),
      ),
    );
  }
}

/// 덩어리 하나.
class _LegalBlock extends StatelessWidget {
  const _LegalBlock({required this.block, required this.onLink});

  final MdBlock block;
  final void Function(String href) onLink;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final body = AppText.body.copyWith(color: colors.ink2);
    return switch (block) {
      MdHeading(:final level, :final spans) => Padding(
        padding: EdgeInsets.only(top: level <= 2 ? AppSpace.s32 : AppSpace.s20),
        child: Semantics(
          header: true,
          child: _RichSpans(
            spans: spans,
            style: (level <= 2 ? AppText.title : AppText.bodyLarge).copyWith(
              color: colors.ink,
              fontWeight: AppText.semibold,
            ),
            onLink: onLink,
          ),
        ),
      ),
      MdParagraph(:final spans) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.s12),
        child: _RichSpans(spans: spans, style: body, onLink: onLink),
      ),
      MdList(:final ordered, :final items) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(ordered ? '${index + 1}.' : '•', style: body),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: _RichSpans(
                        spans: items[index],
                        style: body,
                        onLink: onLink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      MdTable(:final header, :final rows) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpace.s8),
                child: _TableRowCard(
                  header: header,
                  row: rows[index],
                  onLink: onLink,
                ),
              ),
          ],
        ),
      ),
    };
  }
}

/// 표의 한 줄. 첫 칸을 카드 제목으로, 나머지 칸은 머리 칸 이름 아래에 적는다.
class _TableRowCard extends StatelessWidget {
  const _TableRowCard({
    required this.header,
    required this.row,
    required this.onLink,
  });

  final List<List<MdSpan>> header;
  final List<List<MdSpan>> row;
  final void Function(String href) onLink;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.edge),
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RichSpans(
              spans: row.first,
              style: AppText.body.copyWith(
                color: colors.ink,
                fontWeight: AppText.semibold,
              ),
              onLink: onLink,
            ),
            for (var column = 1; column < row.length; column++)
              if (row[column].isNotEmpty) ...[
                const SizedBox(height: AppSpace.s12),
                Text(
                  plainText(header[column]),
                  style: AppText.small.copyWith(color: colors.muted),
                ),
                const SizedBox(height: AppSpace.s4),
                _RichSpans(
                  spans: row[column],
                  style: AppText.body.copyWith(color: colors.ink2),
                  onLink: onLink,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// 굵게와 링크가 섞인 글. 링크는 `accent` 색에 밑줄이고 누르면 [onLink]를 부른다.
class _RichSpans extends StatefulWidget {
  const _RichSpans({
    required this.spans,
    required this.style,
    required this.onLink,
  });

  final List<MdSpan> spans;
  final TextStyle style;
  final void Function(String href) onLink;

  @override
  State<_RichSpans> createState() => _RichSpansState();
}

class _RichSpansState extends State<_RichSpans> {
  final _recognizers = <String, TapGestureRecognizer>{};

  TapGestureRecognizer _recognizer(String href) => _recognizers.putIfAbsent(
    href,
    () => TapGestureRecognizer()..onTap = () => widget.onLink(href),
  );

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final span in widget.spans)
            if (span.link case final href?)
              TextSpan(
                text: span.text,
                style: TextStyle(
                  color: colors.accent,
                  decoration: TextDecoration.underline,
                  fontWeight: span.bold ? AppText.semibold : null,
                ),
                recognizer: _recognizer(href),
              )
            else
              TextSpan(
                text: span.text,
                style: span.bold
                    ? const TextStyle(fontWeight: AppText.semibold)
                    : null,
              ),
        ],
      ),
    );
  }
}
