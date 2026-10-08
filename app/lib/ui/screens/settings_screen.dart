import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../services/messenger.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final s = context.watch<AppSettings>();
    final l = context.l;
    final langNames = {null: l.systemDefault, 'de': 'Deutsch', 'en': 'English', 'ru': 'Русский'};
    final themeNames = {ThemeMode.system: l.systemDefault, ThemeMode.light: l.themeLight, ThemeMode.dark: l.themeDark};
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(children: [
        _section(context, l.profile),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(l.nickname),
          subtitle: Text(m.nickname.isEmpty ? '-' : m.nickname),
          onTap: () async {
            final v = await promptText(context, l.nickname, initial: m.nickname, maxLength: 32);
            if (v != null) m.setNickname(v);
          },
        ),
        ListTile(leading: const Icon(Icons.badge_outlined), title: Text(l.id), subtitle: Text(m.me.id)),
        _section(context, l.appearance),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l.language),
          subtitle: Text(langNames[s.locale?.languageCode] ?? l.systemDefault),
          onTap: () async {
            final v = await showDialog<String>(
              context: context,
              builder: (c) => SimpleDialog(title: Text(l.language), children: [
                for (final e in langNames.entries)
                  SimpleDialogOption(onPressed: () => Navigator.pop(c, e.key ?? ''), child: Text(e.value)),
              ]),
            );
            if (v != null) s.setLocale(v.isEmpty ? null : v);
          },
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(l.theme),
          subtitle: Text(themeNames[s.themeMode]!),
          onTap: () async {
            final v = await showDialog<ThemeMode>(
              context: context,
              builder: (c) => SimpleDialog(title: Text(l.theme), children: [
                for (final e in themeNames.entries) SimpleDialogOption(onPressed: () => Navigator.pop(c, e.key), child: Text(e.value)),
              ]),
            );
            if (v != null) s.setTheme(v);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.keyboard_return),
          title: Text(l.enterSends),
          value: s.enterSends,
          onChanged: s.setEnterSends,
        ),
        _section(context, l.privacy),
        SwitchListTile(
          secondary: const Icon(Icons.done_all),
          title: Text(l.readReceipts),
          subtitle: Text(l.readReceiptsHint),
          value: m.readReceipts,
          onChanged: m.setReadReceipts,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.keyboard_outlined),
          title: Text(l.typingIndicators),
          value: m.typingIndicators,
          onChanged: m.setTypingIndicators,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: Text(l.appLock),
          subtitle: Text(l.appLockHint),
          value: s.appLock,
          onChanged: (v) async {
            if (v) {
              final auth = LocalAuthentication();
              if (!await auth.isDeviceSupported()) {
                if (context.mounted) toast(context, l.appLockUnavailable);
                return;
              }
              if (!context.mounted) return;
              final ok = await auth.authenticate(localizedReason: l.unlockReason);
              if (!ok) return;
            }
            s.setAppLock(v);
          },
        ),
        _section(context, l.security),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(l.backupId),
          subtitle: Text(l.backupIdHint),
          onTap: () => _backup(context, m),
        ),
        ListTile(leading: const Icon(Icons.dns_outlined), title: Text(l.serverAddress), subtitle: Text(m.serverUrl)),
        _section(context, l.about),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (c, snap) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppConfig.appName),
            subtitle: Text('${l.version} ${snap.data?.version ?? ''} (${snap.data?.buildNumber ?? ''})'),
            onTap: () => showLicensePage(context: context, applicationName: AppConfig.appName),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(l.privacyPolicy),
          onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl), mode: LaunchMode.externalApplication),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: Text(l.deleteId, style: const TextStyle(color: Colors.red)),
          subtitle: Text(l.deleteIdHint),
          onTap: () async {
            if (!await confirm(context, l.deleteId, l.deleteIdConfirm, danger: true, action: l.delete)) return;
            await m.deleteIdentity();
            SystemNavigator.pop();
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _section(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );

  Future<void> _backup(BuildContext context, Messenger m) async {
    final l = context.l;
    final pw = TextEditingController();
    final pw2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.backupId),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.backupPasswordHint),
          const SizedBox(height: 12),
          TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: l.password)),
          const SizedBox(height: 8),
          TextField(controller: pw2, obscureText: true, decoration: InputDecoration(labelText: l.repeatPassword)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.create)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (pw.text.length < 8 || pw.text != pw2.text) {
      toast(context, l.passwordRules);
      return;
    }
    final backup = await m.exportBackup(pw.text);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.backupId),
        content: SelectableText(backup, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: backup));
              toast(context, l.copied);
            },
            child: Text(l.copy),
          ),
          TextButton(onPressed: () => SharePlus.instance.share(ShareParams(text: backup)), child: Text(l.share)),
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.ok)),
        ],
      ),
    );
  }
}
