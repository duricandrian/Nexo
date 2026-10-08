import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../services/messenger.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'contact_info_screen.dart';

class MemberPicker extends StatefulWidget {
  final String title;
  final Set<String> initial;
  final bool askName;
  const MemberPicker({super.key, required this.title, this.initial = const {}, this.askName = false});
  @override
  State<MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<MemberPicker> {
  late final Set<String> _selected = {...widget.initial};
  final _name = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final l = context.l;
    final contacts = m.contacts.values.where((c) => !c.blocked && (!c.hidden || widget.initial.contains(c.id))).toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        if (widget.askName)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(controller: _name, maxLength: 50, decoration: InputDecoration(labelText: l.groupName)),
          ),
        Expanded(
          child: contacts.isEmpty
              ? Center(child: Text(l.noContacts))
              : ListView(children: [
                  for (final c in contacts)
                    CheckboxListTile(
                      secondary: Avatar(name: c.displayName, seed: c.id),
                      title: Text(c.displayName),
                      subtitle: Text(c.id),
                      value: _selected.contains(c.id),
                      onChanged: (v) => setState(() => v == true ? _selected.add(c.id) : _selected.remove(c.id)),
                    ),
                ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.check),
        label: Text(l.membersCount(_selected.length)),
        onPressed: () {
          if (widget.askName && _name.text.trim().isEmpty) {
            toast(context, l.groupNameRequired);
            return;
          }
          if (_selected.isEmpty) {
            toast(context, l.selectMembers);
            return;
          }
          Navigator.pop(context, (_name.text.trim(), _selected.toList()));
        },
      ),
    );
  }
}

class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.read<Messenger>();
    return _CreateGroupHost(onCreate: (name, members) async {
      final g = await m.createGroup(name, members);
      if (context.mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(chatKey: g.key)));
      }
    });
  }
}

class _CreateGroupHost extends StatefulWidget {
  final Future<void> Function(String, List<String>) onCreate;
  const _CreateGroupHost({required this.onCreate});
  @override
  State<_CreateGroupHost> createState() => _CreateGroupHostState();
}

class _CreateGroupHostState extends State<_CreateGroupHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final r = await Navigator.push<(String, List<String>)>(
          context, MaterialPageRoute(builder: (_) => MemberPicker(title: context.l.newGroup, askName: true)));
      if (!mounted) return;
      if (r == null) {
        Navigator.pop(context);
      } else {
        await widget.onCreate(r.$1, r.$2);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

class GroupInfoScreen extends StatelessWidget {
  final String groupKey;
  const GroupInfoScreen({super.key, required this.groupKey});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Messenger>();
    final l = context.l;
    final g = m.groups[groupKey];
    if (g == null) return Scaffold(appBar: AppBar());
    final isAdmin = g.creator == m.me.id && !g.left;
    return Scaffold(
      appBar: AppBar(title: Text(l.groupInfo)),
      body: ListView(children: [
        const SizedBox(height: 24),
        Center(child: Avatar(name: g.name, seed: g.key, group: true, radius: 48)),
        const SizedBox(height: 12),
        Center(child: Text(g.name, style: Theme.of(context).textTheme.headlineSmall)),
        Center(child: Text(l.createdBy(m.nameOf(g.creator)))),
        const SizedBox(height: 12),
        if (isAdmin)
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.renameGroup),
            onTap: () async {
              final v = await promptText(context, l.renameGroup, initial: g.name, maxLength: 50);
              if (v != null && v.trim().isNotEmpty) m.updateGroup(g, name: v);
            },
          ),
        if (isAdmin)
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: Text(l.editMembers),
            onTap: () async {
              final r = await Navigator.push<(String, List<String>)>(
                context,
                MaterialPageRoute(builder: (_) => MemberPicker(title: l.editMembers, initial: g.members.where((x) => x != m.me.id).toSet())),
              );
              if (r != null) m.updateGroup(g, members: r.$2);
            },
          ),
        const Divider(),
        ListTile(title: Text(l.membersCount(g.members.length)), dense: true),
        for (final id in g.members)
          ListTile(
            leading: Avatar(name: m.nameOf(id), seed: id),
            title: Text(id == m.me.id ? l.you : m.nameOf(id)),
            subtitle: Text(id == g.creator ? '$id · ${l.admin}' : id),
            onTap: id == m.me.id ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactInfoScreen(contactId: id))),
          ),
        const Divider(),
        if (!g.left)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(isAdmin ? l.dissolveGroup : l.leaveGroup, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              if (await confirm(context, isAdmin ? l.dissolveGroup : l.leaveGroup, l.leaveGroupConfirm, danger: true, action: l.ok)) {
                await m.leaveGroup(g);
              }
            },
          ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(l.deleteGroup, style: const TextStyle(color: Colors.red)),
          onTap: () async {
            if (await confirm(context, l.deleteGroup, l.deleteChatConfirm, danger: true, action: l.delete)) {
              await m.deleteGroup(g);
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }
          },
        ),
      ]),
    );
  }
}
