import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/crypto.dart';
import '../../core/l10n.dart';
import '../../services/messenger.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import 'add_contact_screen.dart';

class ContactInfoScreen extends StatelessWidget {
  final String contactId;
  const ContactInfoScreen({super.key, required this.contactId});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final l = context.l;
    final c = m.contacts[contactId];
    if (c == null) return Scaffold(appBar: AppBar());
    final groups = m.groups.values.where((g) => !g.left && g.members.contains(c.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.contactInfo)),
      body: ListView(children: [
        const SizedBox(height: 24),
        Center(child: Avatar(name: c.displayName, seed: c.id, radius: 48)),
        const SizedBox(height: 12),
        Center(child: Text(c.displayName, style: Theme.of(context).textTheme.headlineSmall)),
        if (c.nick != null && c.nick!.isNotEmpty) Center(child: Text('${l.nickname}: ${c.nick}')),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.badge_outlined), title: Text(l.id), subtitle: SelectableText(c.id)),
        ListTile(
          leading: const Icon(Icons.verified_user_outlined),
          title: Text(l.verificationLevel),
          subtitle: Text(c.verified >= 3 ? l.verifiedQr : l.notVerified),
          trailing: VerificationDots(c.verified),
          onTap: c.verified >= 3
              ? null
              : () async {
                  final data = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
                  if (data == null || !context.mounted) return;
                  try {
                    final v = await m.addContactFromQr(data);
                    if (!context.mounted) return;
                    toast(context, v.id == c.id ? l.contactVerified : l.errorKeyMismatch);
                  } catch (e) {
                    if (context.mounted) toast(context, contactError(context, e));
                  }
                },
        ),
        ListTile(
          leading: const Icon(Icons.fingerprint),
          title: Text(l.keyFingerprint),
          subtitle: Text(Crypto.fingerprint(c.pk), style: const TextStyle(fontFamily: 'monospace')),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(l.editName),
          onTap: () async {
            final v = await promptText(context, l.editName, initial: c.name ?? '', maxLength: 40);
            if (v != null) m.renameContact(c, v);
          },
        ),
        if (groups.isNotEmpty) ...[
          const Divider(),
          ListTile(title: Text(l.commonGroups), dense: true),
          for (final g in groups) ListTile(leading: Avatar(name: g.name, seed: g.key, group: true, radius: 16), title: Text(g.name)),
        ],
        const Divider(),
        SwitchListTile(
          secondary: const Icon(Icons.block),
          title: Text(l.block),
          value: c.blocked,
          onChanged: (v) => m.setBlocked(c, v),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(l.deleteContact, style: const TextStyle(color: Colors.red)),
          onTap: () async {
            if (await confirm(context, l.deleteContact, l.deleteContactConfirm, danger: true, action: l.delete)) {
              await m.deleteContact(c);
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }
          },
        ),
      ]),
    );
  }
}
