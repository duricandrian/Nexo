import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/crypto.dart';
import '../../core/l10n.dart';
import '../../services/messenger.dart';
import '../widgets/common.dart';

class MyIdScreen extends StatelessWidget {
  const MyIdScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.myId)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: QrImageView(data: Messenger.qrPayload(m.me), size: 240, backgroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: SelectableText(m.me.id, style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 4))),
        if (m.nickname.isNotEmpty) Center(child: Text(m.nickname)),
        const SizedBox(height: 8),
        Text(l.myIdHint, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.fingerprint),
          title: Text(l.keyFingerprint),
          subtitle: Text(Crypto.fingerprint(m.me.publicKey), style: const TextStyle(fontFamily: 'monospace')),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(l.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: m.me.id));
              toast(context, l.copied);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: Text(l.share),
            onPressed: () => SharePlus.instance.share(ShareParams(text: l.shareIdText(m.me.id))),
          ),
        ]),
      ]),
    );
  }
}
