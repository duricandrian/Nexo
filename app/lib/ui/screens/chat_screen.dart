import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../data/models.dart';
import '../../services/call_service.dart';
import '../../services/messenger.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/message_bubble.dart';
import 'contact_info_screen.dart';
import 'group_screens.dart';

const quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class ChatScreen extends StatefulWidget {
  final String chatKey;
  const ChatScreen({super.key, required this.chatKey});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final Messenger m;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  StreamSubscription? _sub;
  List<Message> _messages = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _showEmoji = false;
  Message? _replyTo;
  Message? _editing;
  String? _highlight;

  final _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recStart;
  Timer? _recTimer;

  bool get _isGroup => widget.chatKey.startsWith('g:');

  @override
  void initState() {
    super.initState();
    m = context.read<Messenger>();
    _text.text = m.chatFor(widget.chatKey).draft ?? '';
    _sub = m.chatChanges.where((k) => k == widget.chatKey).listen((_) => _reload());
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _focus.addListener(() {
      if (_focus.hasFocus && _showEmoji) setState(() => _showEmoji = false);
    });
    m.openChat(widget.chatKey);
    _reload();
  }

  @override
  void dispose() {
    m.closeChat(widget.chatKey);
    if (_editing == null) m.setDraft(widget.chatKey, _text.text);
    _sub?.cancel();
    _recTimer?.cancel();
    _recorder.dispose();
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final count = _messages.length < 60 ? 60 : _messages.length;
    final list = await m.loadMessages(widget.chatKey, limit: count);
    if (!mounted) return;
    setState(() => _messages = list);
    if (m.inForeground) m.markRead(widget.chatKey);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    _loadingMore = true;
    final more = await m.loadMessages(widget.chatKey, beforeTs: _messages.last.ts);
    if (mounted) {
      setState(() {
        _messages.addAll(more);
        _hasMore = more.isNotEmpty;
      });
    }
    _loadingMore = false;
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    if (_editing != null) {
      final e = _editing!;
      setState(() => _editing = null);
      await m.editMessage(e, text);
      return;
    }
    final reply = _replyTo;
    setState(() => _replyTo = null);
    await m.sendText(widget.chatKey, text, replyTo: reply);
    m.setDraft(widget.chatKey, '');
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 2560, maxHeight: 2560, imageQuality: 85);
    if (x == null) return;
    final caption = await _askCaption();
    if (caption == null) return;
    await m.sendMedia(widget.chatKey, File(x.path), 'image', caption: caption.isEmpty ? null : caption, replyTo: _takeReply());
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final picked = files.single;
    final path = picked.path;
    if (path == null) return;
    final f = File(path);
    if (await f.length() > 100 * 1024 * 1024) {
      if (mounted) toast(context, context.l.fileTooLarge);
      return;
    }
    await m.sendMedia(widget.chatKey, f, 'file', name: picked.name, replyTo: _takeReply());
  }

  Message? _takeReply() {
    final r = _replyTo;
    if (r != null) setState(() => _replyTo = null);
    return r;
  }

  Future<String?> _askCaption() => showDialog<String>(
        context: context,
        builder: (c) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: Text(context.l.sendImage),
            content: TextField(controller: ctrl, decoration: InputDecoration(hintText: context.l.captionOptional)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(context.l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(context.l.send)),
            ],
          );
        },
      );

  Future<void> _startRecording() async {
    if (!await Permission.microphone.request().isGranted) {
      if (mounted) toast(context, context.l.micPermission);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100), path: path);
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = true;
      _recStart = DateTime.now();
    });
    _recTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_recording) return;
    _recTimer?.cancel();
    final path = await _recorder.stop();
    final dur = DateTime.now().difference(_recStart!).inMilliseconds;
    setState(() => _recording = false);
    if (path == null) return;
    if (cancel || dur < 800) {
      File(path).delete().ignore();
      return;
    }
    await m.sendMedia(widget.chatKey, File(path), 'audio', name: 'voice.m4a', extra: {'dur': dur}, replyTo: _takeReply());
    File(path).delete().ignore();
  }

  void _attachMenu() {
    final l = context.l;
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_library), title: Text(l.gallery), onTap: () {
            Navigator.pop(s);
            _pickImage(ImageSource.gallery);
          }),
          ListTile(leading: const Icon(Icons.photo_camera), title: Text(l.camera), onTap: () {
            Navigator.pop(s);
            _pickImage(ImageSource.camera);
          }),
          ListTile(leading: const Icon(Icons.attach_file), title: Text(l.file), onTap: () {
            Navigator.pop(s);
            _pickFile();
          }),
        ]),
      ),
    );
  }

  void _messageMenu(Message msg) {
    final l = context.l;
    final canEdit = msg.outgoing && msg.type == 'text' && !msg.deleted &&
        DateTime.now().millisecondsSinceEpoch - msg.ts < 6 * 3600 * 1000;
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!msg.deleted && msg.type != 'system')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final e in quickReactions)
                  InkWell(
                    onTap: () {
                      Navigator.pop(s);
                      m.react(msg, msg.reactions[m.me.id] == e ? '' : e);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: msg.reactions[m.me.id] == e
                          ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle)
                          : null,
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
              ]),
            ),
          if (!msg.deleted)
            ListTile(leading: const Icon(Icons.reply), title: Text(l.reply), onTap: () {
              Navigator.pop(s);
              setState(() {
                _replyTo = msg;
                _editing = null;
              });
              _focus.requestFocus();
            }),
          if (msg.type == 'text' && !msg.deleted)
            ListTile(leading: const Icon(Icons.copy), title: Text(l.copy), onTap: () {
              Navigator.pop(s);
              Clipboard.setData(ClipboardData(text: msg.body ?? ''));
              toast(context, l.copied);
            }),
          if (canEdit)
            ListTile(leading: const Icon(Icons.edit), title: Text(l.edit), onTap: () {
              Navigator.pop(s);
              setState(() {
                _editing = msg;
                _replyTo = null;
                _text.text = msg.body ?? '';
              });
              _focus.requestFocus();
            }),
          if (msg.status == MsgStatus.failed)
            ListTile(leading: const Icon(Icons.refresh), title: Text(l.retry), onTap: () {
              Navigator.pop(s);
              m.retry(msg);
            }),
          ListTile(leading: const Icon(Icons.info_outline), title: Text(l.messageInfo), onTap: () {
            Navigator.pop(s);
            _showInfo(msg);
          }),
          ListTile(leading: const Icon(Icons.delete_outline), title: Text(l.deleteForMe), onTap: () {
            Navigator.pop(s);
            m.deleteForMe(msg);
          }),
          if (msg.outgoing && !msg.deleted && msg.status != MsgStatus.pending && msg.status != MsgStatus.failed)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(l.deleteForEveryone, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(s);
                m.deleteForEveryone(msg);
              },
            ),
        ]),
      ),
    );
  }

  void _showInfo(Message msg) {
    final l = context.l;
    final statusNames = {
      MsgStatus.pending: l.statusPending,
      MsgStatus.sent: l.statusSent,
      MsgStatus.delivered: l.statusDelivered,
      MsgStatus.read: l.statusRead,
      MsgStatus.failed: l.statusFailed,
      MsgStatus.received: l.statusReceived,
    };
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.messageInfo),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l.sender}: ${m.nameOf(msg.sender)}'),
          Text('${l.time}: ${DateTime.fromMillisecondsSinceEpoch(msg.ts).toLocal().toString().substring(0, 19)}'),
          Text('${l.status}: ${statusNames[msg.status] ?? msg.status}'),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.lock, size: 16, color: Colors.green), const SizedBox(width: 6), Expanded(child: Text(l.e2eNotice))]),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l.ok))],
      ),
    );
  }

  void _jumpTo(String id) {
    final idx = _messages.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    setState(() => _highlight = id);
    _scroll.animateTo(idx * 72.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    Future.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _highlight = null) : null);
  }

  Future<void> _download(Message msg) async {
    final r = await m.downloadMedia(msg);
    if (r == null && mounted) toast(context, context.l.downloadFailed);
  }

  Widget _systemLine(Message msg) {
    final l = context.l;
    final by = m.nameOf(msg.meta['by'] as String? ?? '');
    final member = m.nameOf(msg.meta['id'] as String? ?? '');
    String text;
    switch (msg.body) {
      case 'group_created':
        text = l.sysGroupCreated(by);
        break;
      case 'member_added':
        text = l.sysMemberAdded(by, member);
        break;
      case 'member_removed':
        text = l.sysMemberRemoved(by, member);
        break;
      case 'member_left':
        text = l.sysMemberLeft(member);
        break;
      case 'group_renamed':
        text = l.sysRenamed(by, msg.meta['name'] as String? ?? '');
        break;
      case 'added_to_group':
        text = l.sysAddedToGroup(by);
        break;
      case 'you_left':
        text = l.sysYouLeft;
        break;
      case 'you_were_removed':
        text = l.sysYouWereRemoved;
        break;
      case 'key_changed':
        text = l.sysKeyChanged(member);
        break;
      default:
        text = msg.body ?? '';
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.watch<Messenger>();
    final calls = context.watch<CallService>();
    final settings = context.watch<AppSettings>();
    final l = context.l;
    final title = mm.chatTitle(widget.chatKey);
    final chat = mm.chatFor(widget.chatKey);
    final group = _isGroup ? mm.groups[widget.chatKey] : null;
    final contact = _isGroup ? null : mm.contacts[chat.contactId];
    final canWrite = _isGroup ? (group != null && !group.left) : (contact != null && !contact.blocked);
    final typing = mm.isTyping(widget.chatKey);
    final groupCallActive = _isGroup && calls.groupCalls.containsKey(widget.chatKey);

    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => _isGroup ? GroupInfoScreen(groupKey: widget.chatKey) : ContactInfoScreen(contactId: chat.contactId))),
            child: Row(children: [
              Avatar(name: title, seed: widget.chatKey, group: _isGroup, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    typing
                        ? l.typing
                        : (_isGroup ? l.membersCount(group?.members.length ?? 0) : chat.contactId),
                    style: const TextStyle(fontSize: 12),
                  ),
                ]),
              ),
              if (contact != null) Padding(padding: const EdgeInsets.only(right: 4), child: VerificationDots(contact.verified)),
            ]),
          ),
          actions: [
            if (canWrite) ...[
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: calls.busy
                    ? null
                    : () => _isGroup ? calls.startGroupCall(widget.chatKey) : calls.startCall(chat.contactId),
              ),
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: calls.busy
                    ? null
                    : () => _isGroup ? calls.startGroupCall(widget.chatKey, video: true) : calls.startCall(chat.contactId, video: true),
              ),
            ],
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'mute') mm.setMuted(widget.chatKey, !chat.muted);
                if (v == 'clear' && await confirm(context, l.clearChat, l.clearChatConfirm, danger: true, action: l.delete)) {
                  mm.clearChat(widget.chatKey);
                }
                if (v == 'search' && context.mounted) {
                  showSearch(context: context, delegate: _MessageSearch(mm, widget.chatKey, _jumpTo));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'search', child: Text(l.search)),
                PopupMenuItem(value: 'mute', child: Text(chat.muted ? l.unmute : l.mute)),
                PopupMenuItem(value: 'clear', child: Text(l.clearChat)),
              ],
            ),
          ],
        ),
        body: Column(children: [
          if (groupCallActive && !calls.busy)
            MaterialBanner(
              content: Text(l.groupCallActive),
              leading: const Icon(Icons.call, color: Colors.green),
              actions: [
                TextButton(
                  onPressed: () {
                    final info = calls.groupCalls[widget.chatKey]!;
                    calls.joinGroupCall(widget.chatKey, info['id'] as String, video: info['video'] == true);
                  },
                  child: Text(l.join),
                ),
              ],
            ),
          if (contact != null && contact.hidden)
            MaterialBanner(
              content: Text(l.unknownContact),
              actions: [
                TextButton(onPressed: () => mm.addContactById(contact.id), child: Text(l.add)),
                TextButton(onPressed: () => mm.setBlocked(contact, true), child: Text(l.block)),
              ],
            ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.lock, size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Flexible(child: Text(l.e2eNotice, textAlign: TextAlign.center)),
                        ]),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final older = i + 1 < _messages.length ? _messages[i + 1] : null;
                        final newDay = older == null ||
                            DateTime.fromMillisecondsSinceEpoch(older.ts).day != DateTime.fromMillisecondsSinceEpoch(msg.ts).day;
                        final item = msg.type == 'system'
                            ? _systemLine(msg)
                            : MessageBubble(
                                key: ValueKey(msg.id),
                                msg: msg,
                                showSender: _isGroup && (older == null || older.sender != msg.sender || newDay),
                                senderName: mm.nameOf(msg.sender),
                                nameOf: mm.nameOf,
                                highlighted: _highlight == msg.id,
                                onLongPress: () => _messageMenu(msg),
                                onDownload: () => _download(msg),
                                onRetry: () => m.retry(msg),
                                onReplyTap: _jumpTo,
                              );
                        final swipe = msg.type == 'system' || msg.deleted
                            ? item
                            : Dismissible(
                                key: ValueKey('d${msg.id}'),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) async {
                                  setState(() => _replyTo = msg);
                                  _focus.requestFocus();
                                  return false;
                                },
                                background: const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(padding: EdgeInsets.only(left: 20), child: Icon(Icons.reply)),
                                ),
                                child: item,
                              );
                        if (!newDay) return swipe;
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Chip(label: Text(formatDay(context, msg.ts), style: const TextStyle(fontSize: 12))),
                          ),
                          swipe,
                        ]);
                      },
                    ),
            ),
          ),
          if (canWrite) _composer(settings) else _readOnlyBar(group, contact),
          if (_showEmoji && canWrite)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _text,
                onEmojiSelected: (_, _) => setState(() {}),
                config: Config(
                  height: 280,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(backgroundColor: Theme.of(context).colorScheme.surface),
                  bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    iconColorSelected: Theme.of(context).colorScheme.primary,
                  ),
                  searchViewConfig: SearchViewConfig(backgroundColor: Theme.of(context).colorScheme.surface),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _readOnlyBar(dynamic group, Contact? contact) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            contact?.blocked == true ? context.l.contactBlocked : context.l.notGroupMember,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );

  Widget _composer(AppSettings settings) {
    final l = context.l;
    final hasText = _text.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_replyTo != null || _editing != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(children: [
              Icon(_editing != null ? Icons.edit : Icons.reply, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_editing != null ? l.editMessage : m.nameOf(_replyTo!.sender),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  Text(Messenger.previewOf(_editing ?? _replyTo!), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  if (_editing != null) _text.clear();
                  _replyTo = null;
                  _editing = null;
                }),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (_recording) ...[
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _stopRecording(cancel: true)),
              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text('${l.recording}  ${formatDuration(DateTime.now().difference(_recStart!).inSeconds)}')),
            ] else ...[
              IconButton(
                icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined),
                onPressed: () {
                  if (_showEmoji) {
                    _focus.requestFocus();
                  } else {
                    FocusScope.of(context).unfocus();
                  }
                  setState(() => _showEmoji = !_showEmoji);
                },
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  textInputAction: settings.enterSends ? TextInputAction.send : TextInputAction.newline,
                  onSubmitted: settings.enterSends ? (_) => _send() : null,
                  onChanged: (_) {
                    setState(() {});
                    m.sendTyping(widget.chatKey);
                  },
                  decoration: InputDecoration(
                    hintText: l.messageHint,
                    filled: true,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (_editing == null) IconButton(icon: const Icon(Icons.attach_file), onPressed: _attachMenu),
            ],
            const SizedBox(width: 2),
            if (hasText || _editing != null)
              IconButton.filled(icon: Icon(_editing != null ? Icons.check : Icons.send), onPressed: _send)
            else if (_recording)
              IconButton.filled(icon: const Icon(Icons.send), onPressed: () => _stopRecording())
            else
              IconButton.filledTonal(icon: const Icon(Icons.mic), tooltip: l.voiceMessage, onPressed: _startRecording),
          ]),
        ),
      ]),
    );
  }
}

class _MessageSearch extends SearchDelegate<void> {
  final Messenger m;
  final String chat;
  final void Function(String) onPick;
  _MessageSearch(this.m, this.chat, this.onPick);

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => const BackButton();

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length < 2) return const SizedBox();
    return FutureBuilder<List<Message>>(
      future: m.searchMessages(chat, query.trim()),
      builder: (context, snap) {
        final list = snap.data ?? [];
        return ListView(children: [
          for (final msg in list)
            ListTile(
              title: Text(msg.body ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${m.nameOf(msg.sender)} · ${formatTime(context, msg.ts)}'),
              onTap: () {
                close(context, null);
                onPick(msg.id);
              },
            ),
        ]);
      },
    );
  }
}
