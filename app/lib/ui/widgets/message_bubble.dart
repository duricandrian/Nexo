import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import 'common.dart';

class MessageBubble extends StatelessWidget {
  final Message msg;
  final bool showSender;
  final String senderName;
  final String Function(String id) nameOf;
  final VoidCallback onLongPress;
  final VoidCallback onDownload;
  final VoidCallback onRetry;
  final void Function(String id)? onReplyTap;
  final bool highlighted;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.showSender,
    required this.senderName,
    required this.nameOf,
    required this.onLongPress,
    required this.onDownload,
    required this.onRetry,
    this.onReplyTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = msg.outgoing ? (dark ? const Color(0xFF1F4D3A) : const Color(0xFFD7F5E4)) : (dark ? const Color(0xFF2A2F2D) : Colors.white);
    final reply = msg.meta['reply'] as Map?;
    final emojiOnly = msg.type == 'text' && !msg.deleted && _isEmojiOnly(msg.body ?? '');

    Widget content;
    if (msg.deleted) {
      content = Text(l.messageDeleted, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    } else {
      switch (msg.type) {
        case 'image':
          content = _image(context);
          break;
        case 'file':
          content = _file(context);
          break;
        case 'audio':
          content = msg.localPath == null ? _downloadTile(context, Icons.mic) : AudioMessage(path: msg.localPath!, durationMs: msg.meta['dur'] as int? ?? 0);
          break;
        case 'location':
          content = InkWell(
            onTap: () => launchUrl(Uri.parse('geo:${msg.meta['lat']},${msg.meta['lon']}?q=${msg.meta['lat']},${msg.meta['lon']}')),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.place, color: Colors.red), const SizedBox(width: 6), Text(l.location)]),
          );
          break;
        default:
          content = Linkify(
            text: msg.body ?? '',
            style: TextStyle(fontSize: emojiOnly ? 40 : 16, color: scheme.onSurface),
            linkStyle: TextStyle(color: scheme.primary),
            onOpen: (link) => launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
          );
      }
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      margin: EdgeInsets.only(left: msg.outgoing ? 48 : 8, right: msg.outgoing ? 8 : 48, top: 2, bottom: msg.reactions.isEmpty ? 2 : 14),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: emojiOnly ? Colors.transparent : (highlighted ? scheme.primaryContainer : bg),
        borderRadius: BorderRadius.circular(14),
        boxShadow: emojiOnly ? null : const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (showSender && !msg.outgoing)
          Text(senderName, style: TextStyle(color: avatarColor(msg.sender), fontWeight: FontWeight.w600, fontSize: 13)),
        if (reply != null && !msg.deleted)
          GestureDetector(
            onTap: () => onReplyTap?.call(reply['id'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4, top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                border: Border(left: BorderSide(color: brandColor, width: 3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nameOf(reply['sender'] as String? ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brandColor)),
                Text(reply['preview'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ),
        content,
        if (msg.body != null && msg.body!.isNotEmpty && msg.type != 'text' && !msg.deleted)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(msg.body!)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (msg.edited && !msg.deleted) Text('${l.edited} · ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(formatTime(context, msg.ts).length > 5 ? _hm(msg.ts) : formatTime(context, msg.ts),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (msg.outgoing) ...[const SizedBox(width: 4), _statusIcon()],
        ]),
      ]),
    );

    return Align(
      alignment: msg.outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: msg.status == MsgStatus.failed ? onRetry : null,
        child: Stack(clipBehavior: Clip.none, children: [
          bubble,
          if (msg.reactions.isNotEmpty)
            Positioned(
              bottom: 0,
              right: msg.outgoing ? 16 : null,
              left: msg.outgoing ? null : 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Text(_reactionSummary(), style: const TextStyle(fontSize: 13)),
              ),
            ),
        ]),
      ),
    );
  }

  String _hm(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _reactionSummary() {
    final counts = <String, int>{};
    for (final e in msg.reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    return counts.entries.map((e) => e.value > 1 ? '${e.key}${e.value}' : e.key).join(' ');
  }

  Widget _statusIcon() {
    switch (msg.status) {
      case MsgStatus.pending:
        return const Icon(Icons.schedule, size: 14, color: Colors.grey);
      case MsgStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.grey);
      case MsgStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case MsgStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.blue);
      default:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
    }
  }

  static bool _isEmojiOnly(String s) {
    final t = s.trim();
    if (t.isEmpty || t.characters.length > 3) return false;
    return !RegExp(r'[A-Za-z0-9А-Яа-яЁёÄÖÜäöüß.,!?]').hasMatch(t);
  }

  Widget _downloadTile(BuildContext context, IconData icon) => InkWell(
        onTap: onDownload,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon),
          const SizedBox(width: 8),
          const Icon(Icons.download),
          const SizedBox(width: 8),
          Text(formatBytes((msg.meta['size'] as num?)?.toInt() ?? 0)),
        ]),
      );

  Widget _image(BuildContext context) {
    if (msg.localPath == null) {
      return SizedBox(width: 200, height: 150, child: Center(child: IconButton.filledTonal(icon: const Icon(Icons.download), onPressed: onDownload)));
    }
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewer(path: msg.localPath!))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(msg.localPath!), width: 240, fit: BoxFit.cover, cacheWidth: 600,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 64)),
      ),
    );
  }

  Widget _file(BuildContext context) {
    final name = msg.meta['name'] as String? ?? 'file';
    return InkWell(
      onTap: msg.localPath == null ? onDownload : () => OpenFilex.open(msg.localPath!),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(child: Icon(msg.localPath == null ? Icons.download : Icons.insert_drive_file)),
        const SizedBox(width: 10),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(formatBytes((msg.meta['size'] as num?)?.toInt() ?? 0), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
      ]),
    );
  }
}

class AudioMessage extends StatefulWidget {
  final String path;
  final int durationMs;
  const AudioMessage({super.key, required this.path, required this.durationMs});
  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage> {
  final _player = AudioPlayer();
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _dur = Duration(milliseconds: widget.durationMs);
    _player.positionStream.listen((p) => mounted ? setState(() => _pos = p) : null);
    _player.durationStream.listen((d) => d != null && mounted ? setState(() => _dur = d) : null);
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (_player.audioSource == null) await _player.setFilePath(widget.path);
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = _dur.inMilliseconds <= 0 ? 1.0 : _dur.inMilliseconds.toDouble();
    return SizedBox(
      width: 220,
      child: Row(children: [
        IconButton(icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle, size: 36), onPressed: _toggle),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Slider(
              value: _pos.inMilliseconds.clamp(0, max.toInt()).toDouble(),
              max: max,
              onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(formatDuration((_playing ? _pos : _dur).inSeconds), style: const TextStyle(fontSize: 11)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class ImageViewer extends StatelessWidget {
  final String path;
  const ImageViewer({super.key, required this.path});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(maxScale: 5, child: Image.file(File(path)))),
      );
}
