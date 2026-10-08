import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../data/models.dart';
import '../../services/messenger.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

String contactError(BuildContext context, Object e) {
  final l = context.l;
  if (e is ContactException) {
    switch (e.code) {
      case 'self':
        return l.errorSelf;
      case 'not_found':
        return l.errorNotFound;
      case 'key_mismatch':
        return l.errorKeyMismatch;
      case 'offline':
        return l.offline;
      default:
        return l.errorInvalidId;
    }
  }
  return l.offline;
}

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});
  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _id = TextEditingController();
  bool _busy = false;

  Future<void> _add(Future<Contact> Function() f) async {
    setState(() => _busy = true);
    try {
      final c = await f();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(chatKey: Chat.forContact(c.id))));
    } catch (e) {
      if (mounted) toast(context, contactError(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.read<Messenger>();
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.addContact)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(l.scanQr),
          onPressed: _busy
              ? null
              : () async {
                  final data = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
                  if (data != null) await _add(() => m.addContactFromQr(data));
                },
        ),
        const SizedBox(height: 8),
        Text(l.scanQrHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 32),
        TextField(
          controller: _id,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          decoration: InputDecoration(labelText: l.enterId, prefixIcon: const Icon(Icons.badge_outlined)),
        ),
        FilledButton.tonal(
          onPressed: _busy ? null : () => _add(() => m.addContactById(_id.text)),
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.add),
        ),
      ]),
    );
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l.scanQr)),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final v = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
          if (v != null && v.startsWith('arcana:')) {
            _done = true;
            Navigator.pop(context, v);
          }
        },
      ),
    );
  }
}
