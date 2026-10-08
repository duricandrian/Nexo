import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../../core/crypto.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../services/connection.dart';
import '../../services/identity.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(Identity) onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nick = TextEditingController();
  final _server = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppConfig.serverUrl().then((v) => _server.text = v);
  }

  Future<void> _saveServer() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('server_url', _server.text.trim());
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _saveServer();
      final keys = Crypto.generateKeyPair();
      final id = await Connection.register(_server.text.trim(), keys.publicKey);
      final identity = Identity(id, keys.publicKey, keys.secretKey);
      await identity.save();
      final p = await SharedPreferences.getInstance();
      await p.setString('nickname', _nick.text.trim());
      await widget.onDone(identity);
    } catch (e) {
      debugPrint('register failed: $e');
      setState(() => _error = context.l.serverUnreachable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final backup = TextEditingController();
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l.restoreBackup),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: backup, maxLines: 4, decoration: InputDecoration(labelText: context.l.backupData)),
          const SizedBox(height: 12),
          TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: context.l.password)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l.restore)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final data = await Crypto.restoreBackup(backup.text, pw.text);
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _busy = false;
        _error = context.l.backupInvalid;
      });
      return;
    }
    final identity = Identity.fromJson(data);
    await identity.save();
    final p = await SharedPreferences.getInstance();
    if (data['nick'] is String) await p.setString('nickname', data['nick'] as String);
    if (data['server'] is String) await p.setString('server_url', data['server'] as String);
    await widget.onDone(identity);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final settings = context.watch<AppSettings>();
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<String?>(
              value: settings.locale?.languageCode,
              underline: const SizedBox(),
              icon: const Icon(Icons.language),
              items: [
                DropdownMenuItem(value: null, child: Text(l.systemDefault)),
                const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'ru', child: Text('Русский')),
              ],
              onChanged: settings.setLocale,
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Image.asset('assets/logo.png', width: 120, height: 120)),
          const SizedBox(height: 16),
          Text(AppConfig.appName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(l.welcomeText, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _feature(Icons.no_cell_outlined, l.featureNoPhone),
          _feature(Icons.lock_outline, l.featureE2E),
          _feature(Icons.call_outlined, l.featureCalls),
          const SizedBox(height: 24),
          TextField(
            controller: _nick,
            maxLength: 32,
            decoration: InputDecoration(labelText: l.nicknameOptional, prefixIcon: const Icon(Icons.person_outline)),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l.advanced),
            children: [
              TextField(controller: _server, decoration: InputDecoration(labelText: l.serverAddress)),
              const SizedBox(height: 8),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _create,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.createId),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : _restore, child: Text(l.restoreBackup)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showAboutDialog(context: context, applicationName: AppConfig.appName, children: [Text(l.privacySummary)]),
            child: Text(l.privacyPolicy),
          ),
        ]),
      ),
    );
  }

  Widget _feature(IconData icon, String text) => ListTile(
        leading: Icon(icon, color: brandColor),
        title: Text(text),
        dense: true,
        contentPadding: EdgeInsets.zero,
      );
}

