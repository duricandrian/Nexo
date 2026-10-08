import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../services/call_service.dart';
import '../../services/messenger.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _tick;
  late CallService _calls;

  @override
  void initState() {
    super.initState();
    _calls = context.read<CallService>();
    _calls.addListener(_onChange);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _onChange() {
    if (!_calls.busy && mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _calls.removeListener(_onChange);
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CallService>();
    final m = context.read<Messenger>();
    final l = context.l;
    final title = c.chatKey == null ? '' : m.chatTitle(c.chatKey!);
    String status;
    switch (c.phase) {
      case CallPhase.outgoing:
        status = l.ringing;
        break;
      case CallPhase.incoming:
        status = c.isGroup ? l.incomingGroupCall(m.nameOf(c.remoteId ?? '')) : (c.video ? l.incomingVideoCall : l.incomingCall);
        break;
      case CallPhase.connecting:
        status = l.connecting;
        break;
      case CallPhase.active:
        status = c.startedAt == null ? '' : formatDuration(DateTime.now().difference(c.startedAt!).inSeconds);
        break;
      case CallPhase.idle:
        status = l.callEnded;
    }
    final videoPeers = c.peers.values.where((p) => p.hasVideo).toList();
    final showVideo = c.video && c.phase == CallPhase.active || (c.video && c.phase == CallPhase.connecting);

    return PopScope(
      canPop: !c.busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF102820),
        body: Stack(children: [
          if (showVideo && videoPeers.isNotEmpty)
            Positioned.fill(
              child: GridView.count(
                crossAxisCount: videoPeers.length <= 1 ? 1 : 2,
                childAspectRatio: videoPeers.length <= 1 ? MediaQuery.of(context).size.aspectRatio : 0.75,
                children: [
                  for (final p in videoPeers)
                    RTCVideoView(p.renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ],
              ),
            )
          else
            Positioned.fill(
              child: SafeArea(
                child: Column(children: [
                  const SizedBox(height: 64),
                  Avatar(name: title, seed: c.chatKey ?? '', radius: 56, group: c.isGroup),
                  const SizedBox(height: 20),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  if (c.isGroup && c.phase == CallPhase.active) ...[
                    const SizedBox(height: 24),
                    Text(l.participants(c.peers.length + 1), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                      for (final p in c.peers.values)
                        Chip(
                          avatar: Avatar(name: m.nameOf(p.id), seed: p.id, radius: 12),
                          label: Text(m.nameOf(p.id)),
                        ),
                    ]),
                    // Keep audio renderers mounted so remote audio plays.
                    for (final p in c.peers.values) SizedBox(width: 1, height: 1, child: RTCVideoView(p.renderer)),
                  ],
                ]),
              ),
            ),
          if (showVideo && videoPeers.isNotEmpty)
            Positioned(
              top: 40,
              left: 16,
              child: Text('$title  $status', style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
            ),
          if (c.video && c.localStream != null && !c.cameraOff)
            Positioned(
              top: 40,
              right: 16,
              width: 110,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(c.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: SafeArea(child: c.phase == CallPhase.incoming ? _incomingControls(c, l) : _activeControls(c)),
          ),
        ]),
      ),
    );
  }

  Widget _incomingControls(CallService c, dynamic l) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RoundButton(icon: Icons.call_end, color: Colors.red, label: context.l.decline, onTap: c.reject),
        _RoundButton(icon: c.video ? Icons.videocam : Icons.call, color: Colors.green, label: context.l.accept, onTap: c.accept),
      ]);

  Widget _activeControls(CallService c) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RoundButton(icon: c.muted ? Icons.mic_off : Icons.mic, color: c.muted ? Colors.white : Colors.white24, iconColor: c.muted ? Colors.black : Colors.white, onTap: c.toggleMute),
        _RoundButton(icon: c.speaker ? Icons.volume_up : Icons.hearing, color: c.speaker ? Colors.white : Colors.white24, iconColor: c.speaker ? Colors.black : Colors.white, onTap: c.toggleSpeaker),
        if (c.video) _RoundButton(icon: c.cameraOff ? Icons.videocam_off : Icons.videocam, color: Colors.white24, onTap: c.toggleCamera),
        if (c.video) _RoundButton(icon: Icons.cameraswitch, color: Colors.white24, onTap: c.switchCamera),
        _RoundButton(icon: Icons.call_end, color: Colors.red, onTap: () => c.hangup()),
      ]);
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String? label;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.color, required this.onTap, this.label, this.iconColor = Colors.white});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(18), child: Icon(icon, color: iconColor, size: 30)),
          ),
        ),
        if (label != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(label!, style: const TextStyle(color: Colors.white))),
      ]);
}
