import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const privacyPolicyUrl = 'https://hanulbear.online/privacy';

class PrivacyPolicyButton extends StatelessWidget {
  const PrivacyPolicyButton({this.launch, super.key});

  final Future<bool> Function(Uri uri)? launch;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.privacy_tip_outlined),
      label: const Text('개인정보처리방침'),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(privacyPolicyUrl);
    var didLaunch = false;
    try {
      didLaunch =
          await (launch?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } on Object {
      didLaunch = false;
    }
    if (didLaunch || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('개인정보처리방침 페이지를 열지 못했습니다.')));
  }
}
