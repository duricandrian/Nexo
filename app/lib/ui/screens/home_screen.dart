import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../data/models.dart';
import '../../services/call_service.dart';
import '../../services/connection.dart';
import '../../services/messenger.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
import 'contact_info_screen.dart';
import 'group_screens.dart';
import 'my_id_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final l = context.l;
    if (m.identityRevoked) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(l.identityRevoked, textAlign: TextAlign.center))));
    }
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(border: InputBorder.none, hintText: l.search, hintStyle: const TextStyle(color: Colors.white70)),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              )
            : Row(children: [
                const Text(AppConfig.appName),
                const SizedBox(width: 8),
                _ConnDot(m.connState),
              ]),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'id') Navigator.push(context, MaterialPageRoute(builder: (_) => const MyIdScreen()));
              if (v == 'settings') Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              if (v == 'group') Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'id', child: Text(l.myId)),
              PopupMenuItem(value: 'group', child: Text(l.newGroup)),
              PopupMenuItem(value: 'settings', child: Text(l.settings)),
            ],
          ),
        ],
      ),
      body: [
        _ChatsTab(query: _query),
        _ContactsTab(query: _query),
        const _CallsTab(),
      ][_tab],
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => _tab == 0 ? const NewChatScreen() : const AddContactScreen())),
              child: Icon(_tab == 0 ? Icons.chat : Icons.person_add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(isLabelVisible: m.totalUnread > 0, label: Text('${m.totalUnread}'), child: const Icon(Icons.chat_bubble_outline)),
            label: l.chats,
          ),
          NavigationDestination(icon: const Icon(Icons.people_outline), label: l.contacts),
          NavigationDestination(icon: const Icon(Icons.call_outlined), label: l.calls),
        ],
      ),
    );
  }
}

class _ConnDot extends StatelessWidget {
  final ConnState s;
  const _ConnDot(this.s);
  @override
  Widget build(BuildContext context) {
    final color = s == ConnState.online ? Colors.lightGreenAccent : (s == ConnState.connecting ? Colors.amber : Colors.redAccent);
    return Tooltip(
      message: s == ConnState.online ? context.l.online : (s == ConnState.connecting ? context.l.connecting : context.l.offline),
      child: Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  final String query;
  const _ChatsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final calls = context.watch<CallService>();
    final l = context.l;
    final chats = m.chats.where((c) => query.isEmpty || m.chatTitle(c.key).toLowerCase().contains(query)).toList();
    if (chats.isEmpty) {
      return _Empty(icon: Icons.forum_outlined, text: l.noChats);
    }
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, i) {
        final c = chats[i];
        final title = m.chatTitle(c.key);
        final typing = m.isTyping(c.key);
        final groupCall = c.isGroup && calls.groupCalls.containsKey(c.key);
        return ListTile(
          leading: Avatar(name: title, seed: c.key, group: c.isGroup),
          title: Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (c.pinned) const Icon(Icons.push_pin, size: 16),
            if (c.muted) const Icon(Icons.notifications_off, size: 16),
          ]),
          subtitle: Text(
            typing ? l.typing : (groupCall ? '📞 ${l.groupCallActive}' : (c.draft != null ? '${l.draft}: ${c.draft}' : (c.lastText ?? ''))),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typing || groupCall ? TextStyle(color: Theme.of(context).colorScheme.primary) : null,
          ),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (c.lastTs > 0) Text(formatTime(context, c.lastTs), style: Theme.of(context).textTheme.bodySmall),
            if (c.unread > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                child: Text('${c.unread}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)),
              ),
          ]),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatKey: c.key))),
          onLongPress: () => _chatMenu(context, m, c),
        );
      },
    );
  }

  void _chatMenu(BuildContext context, Messenger m, Chat c) {
    final l = context.l;
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: Icon(c.pinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(c.pinned ? l.unpin : l.pin),
            onTap: () {
              Navigator.pop(s);
              m.setPinned(c.key, !c.pinned);
            },
          ),
          ListTile(
            leading: Icon(c.muted ? Icons.notifications : Icons.notifications_off),
            title: Text(c.muted ? l.unmute : l.mute),
            onTap: () {
              Navigator.pop(s);
              m.setMuted(c.key, !c.muted);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(l.deleteChat),
            onTap: () async {
              Navigator.pop(s);
              if (await confirm(context, l.deleteChat, l.deleteChatConfirm, danger: true, action: l.delete)) m.deleteChat(c.key);
            },
          ),
        ]),
      ),
    );
  }
}

class _ContactsTab extends StatelessWidget {
  final String query;
  const _ContactsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final l = context.l;
    final contacts = m.visibleContacts
        .where((c) => query.isEmpty || c.displayName.toLowerCase().contains(query) || c.id.toLowerCase().contains(query))
        .toList();
    final groups = m.groups.values.where((g) => !g.left && (query.isEmpty || g.name.toLowerCase().contains(query))).toList();
    return ListView(children: [
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.group_add)),
        title: Text(l.newGroup),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
      ),
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.qr_code)),
        title: Text(l.myId),
        subtitle: Text(m.me.id),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyIdScreen())),
      ),
      if (groups.isNotEmpty) _Header(l.groups),
      for (final g in groups)
        ListTile(
          leading: Avatar(name: g.name, seed: g.key, group: true),
          title: Text(g.name),
          subtitle: Text(l.membersCount(g.members.length)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatKey: g.key))),
        ),
      _Header(l.contacts),
      if (contacts.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noContacts, textAlign: TextAlign.center)),
      for (final c in contacts)
        ListTile(
          leading: Avatar(name: c.displayName, seed: c.id),
          title: Text(c.displayName),
          subtitle: Text(c.id),
          trailing: c.blocked ? const Icon(Icons.block, color: Colors.red) : VerificationDots(c.verified),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatKey: Chat.forContact(c.id)))),
          onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactInfoScreen(contactId: c.id))),
        ),
    ]);
  }
}

class _CallsTab extends StatelessWidget {
  const _CallsTab();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final calls = context.read<CallService>();
    final l = context.l;
    return FutureBuilder<List<CallRecord>>(
      future: m.callHistory(),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty) return _Empty(icon: Icons.call_outlined, text: l.noCalls);
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i];
            final group = r.chat.startsWith('g:');
            final title = m.chatTitle(r.chat);
            final missed = r.status == 'missed';
            final icon = r.outgoing ? Icons.call_made : (missed ? Icons.call_missed : Icons.call_received);
            return ListTile(
              leading: Avatar(name: title, seed: r.chat, group: group),
              title: Text(title, style: missed ? const TextStyle(color: Colors.red) : null),
              subtitle: Row(children: [
                Icon(icon, size: 16, color: missed ? Colors.red : Colors.green),
                const SizedBox(width: 4),
                Text(formatTime(context, r.ts)),
                if (r.duration > 0) Text(' · ${formatDuration(r.duration)}'),
              ]),
              trailing: IconButton(
                icon: Icon(r.video ? Icons.videocam_outlined : Icons.call_outlined),
                onPressed: () => group ? calls.startGroupCall(r.chat, video: r.video) : calls.startCall(r.peer, video: r.video),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatKey: r.chat))),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ]),
        ),
      );
}

class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.newChat)),
      body: ListView(children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_add)),
          title: Text(l.addContact),
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddContactScreen())),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.group_add)),
          title: Text(l.newGroup),
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
        ),
        const Divider(),
        for (final c in m.visibleContacts.where((c) => !c.blocked))
          ListTile(
            leading: Avatar(name: c.displayName, seed: c.id),
            title: Text(c.displayName),
            subtitle: Text(c.id),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(chatKey: Chat.forContact(c.id)))),
          ),
      ]),
    );
  }
}
