// 외부 링크 열기. docs/architecture.md '한눈에 보기'의 패키지 줄(`url_launcher`: 처리방침을 외부
// 브라우저로, 문의 메일).
//
// `canLaunchUrl`은 Android 11 이상에서 매니페스트의 `<queries>`가 없으면 false를 돌려주므로 쓰지 않는다.
// 바로 `launchUrl`(외부 앱)을 부르고, 열지 못하면(false나 플랫폼 오류) 주소를 보이고 복사하게 한다.

import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, PlatformException;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// [uri]를 외부 브라우저(메일 주소면 메일 앱)로 연다. 열지 못하면 주소를 보이는 창을 띄우고
/// '주소 복사'를 둔다. [launcher]는 테스트가 바꾼다.
Future<void> openExternalLink(
  BuildContext context,
  Uri uri, {
  Future<bool> Function(Uri uri)? launcher,
}) async {
  final opened = await (launcher ?? _launchExternally)(uri);
  if (opened || !context.mounted) return;
  final address = uri.toString();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('링크를 열지 못했어요'),
      content: SelectableText(address),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: address));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('주소 복사'),
        ),
      ],
    ),
  );
}

Future<bool> _launchExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}
