import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/models.dart';
import 'background.dart';
import 'messenger.dart';
import 'notifications.dart';

enum CallPhase { idle, outgoing, incoming, connecting, active }

class CallPeer {
  final String id;
  final RTCPeerConnection pc;
  final RTCVideoRenderer renderer = RTCVideoRenderer();
  final List<RTCIceCandidate> pendingIce = [];
  bool remoteSet = false;
  bool connected = false;
  bool hasVideo = false;
  CallPeer(this.id, this.pc);
}

/// WebRTC calls. 1:1 calls ring the callee; group calls are a full mesh where
/// the participant with the lower ID always creates the offer.
class CallService extends ChangeNotifier {
  final Messenger m;
  CallService(this.m) {
    _sub = m.callSignals.listen((s) => _signals = _signals.then((_) => _onSignal(s)).catchError((e) => debugPrint('call $e')));
  }

  late final StreamSubscription _sub;
  Future<void> _signals = Future.value();

  CallPhase phase = CallPhase.idle;
  String? callId;
  String? chatKey;
  String? groupKey;
  String? remoteId;
  bool video = false;
  bool outgoing = false;
  bool muted = false;
  bool speaker = false;
  bool cameraOff = false;
  DateTime? startedAt;
  MediaStream? localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  bool _localRendererReady = false;
  final Map<String, CallPeer> peers = {};
  Map<String, dynamic>? _incomingOffer;
  Timer? _ringTimer;

  /// Active group calls by group key (for "join" banners): {call, video, from, ts}.
  final Map<String, Map<String, dynamic>> groupCalls = {};

  void Function()? onCallUi;

  bool get isGroup => groupKey != null;
  bool get busy => phase != CallPhase.idle;

  // ------------------------------------------------------------- 1:1 calls

  Future<void> startCall(String contactId, {bool video = false}) async {
    if (busy) return;
    callId = m.newId();
    chatKey = 'c:$contactId';
    remoteId = contactId;
    groupKey = null;
    this.video = video;
    outgoing = true;
    phase = CallPhase.outgoing;
    notifyListeners();
    onCallUi?.call();
    try {
      await _openMedia(video);
      final peer = await _createPeer(contactId);
      final offer = await peer.pc.createOffer();
      await peer.pc.setLocalDescription(offer);
      await m.sendCallSignal(contactId, {'type': 'call-offer', 'call': callId, 'sdp': offer.sdp, 'video': video});
      _ringTimer = Timer(const Duration(seconds: 45), () => hangup(status: 'cancelled'));
    } catch (e) {
      debugPrint('startCall: $e');
      await _finish('cancelled');
    }
  }

  Future<void> accept() async {
    if (phase != CallPhase.incoming) return;
    await Notifications.cancelCall();
    if (groupKey != null && _incomingOffer == null) {
      final gc = groupCalls[groupKey!];
      await joinGroupCall(groupKey!, gc?['call'] as String? ?? callId!, video: video);
      return;
    }
    final offer = _incomingOffer!;
    phase = CallPhase.connecting;
    notifyListeners();
    try {
      await _openMedia(video);
      final peer = await _createPeer(remoteId!);
      await _answer(peer, offer['sdp'] as String);
    } catch (e) {
      debugPrint('accept: $e');
      await hangup();
    }
  }

  Future<void> reject() async {
    await Notifications.cancelCall();
    if (phase != CallPhase.incoming) return;
    if (groupKey == null && remoteId != null) {
      await m.sendCallSignal(remoteId!, {'type': 'call-reject', 'call': callId});
    }
    await _finish('declined');
  }

  Future<void> hangup({String? status}) async {
    for (final id in peers.keys.toList()) {
      await m.sendCallSignal(id, {'type': 'call-end', 'call': callId, if (isGroup) 'gcall': callId});
    }
    if (!isGroup && peers.isEmpty && remoteId != null && outgoing) {
      await m.sendCallSignal(remoteId!, {'type': 'call-end', 'call': callId});
    }
    if (isGroup && peers.isEmpty && groupKey != null && phase != CallPhase.incoming) {
      await m.sendGroupCallSignal(groupKey!, {'type': 'gcall-end', 'call': callId});
    }
    await _finish(status ?? (startedAt != null ? 'answered' : (outgoing ? 'cancelled' : 'missed')));
  }

  // ------------------------------------------------------------- group calls

  Future<void> startGroupCall(String group, {bool video = false}) async {
    if (busy) return;
    final id = m.newId();
    groupCalls[group] = {'call': id, 'video': video, 'from': m.me.id, 'ts': DateTime.now().millisecondsSinceEpoch};
    await m.sendGroupCallSignal(group, {'type': 'gcall-start', 'call': id, 'video': video});
    await joinGroupCall(group, id, video: video, announce: false);
  }

  Future<void> joinGroupCall(String group, String id, {bool video = false, bool announce = true}) async {
    callId = id;
    groupKey = group;
    chatKey = group;
    remoteId = null;
    this.video = video;
    outgoing = !announce;
    phase = CallPhase.active;
    startedAt = DateTime.now();
    _incomingOffer = null;
    notifyListeners();
    onCallUi?.call();
    await _openMedia(video);
    await _onActive();
    if (announce) await m.sendGroupCallSignal(group, {'type': 'gcall-join', 'call': id});
  }

  // ------------------------------------------------------------- signaling

  Future<void> _onSignal(CallSignal s) async {
    final p = s.payload;
    final type = p['type'] as String;
    final id = p['call'] as String?;
    final age = DateTime.now().millisecondsSinceEpoch + m.conn.serverTimeOffset - s.ts;

    switch (type) {
      case 'gcall-start':
        final group = p['group'] as String?;
        if (group == null) return;
        groupCalls[group] = {'call': id, 'video': p['video'] == true, 'from': s.from, 'ts': s.ts};
        notifyListeners();
        if (age > 60000 || busy) return;
        callId = id;
        groupKey = group;
        chatKey = group;
        remoteId = s.from;
        video = p['video'] == true;
        outgoing = false;
        _incomingOffer = null;
        phase = CallPhase.incoming;
        notifyListeners();
        _ring(group, s.from);
        _ringTimer = Timer(const Duration(seconds: 40), () {
          if (phase == CallPhase.incoming) _finish('missed');
        });
        return;
      case 'gcall-join':
        final group = p['group'] as String?;
        if (group != null && groupCalls[group] == null) {
          groupCalls[group] = {'call': id, 'video': false, 'from': s.from, 'ts': s.ts};
          notifyListeners();
        }
        if (!isGroup || id != callId || phase != CallPhase.active || age > 60000) return;
        await m.sendCallSignal(s.from, {'type': 'gcall-here', 'call': id, 'gcall': id});
        if (m.me.id.compareTo(s.from) < 0) await _offerTo(s.from);
        return;
      case 'gcall-end':
        final group = p['group'] as String?;
        if (group != null && groupCalls[group]?['call'] == id) {
          groupCalls.remove(group);
          notifyListeners();
        }
        if (isGroup && id == callId && phase == CallPhase.incoming) await _finish('missed');
        return;
      case 'gcall-here':
        if (!isGroup || id != callId) return;
        if (m.me.id.compareTo(s.from) < 0) await _offerTo(s.from);
        return;
      case 'call-offer':
        if (p['gcall'] != null) {
          if (!isGroup || p['gcall'] != callId) return;
          final peer = peers[s.from] ?? await _createPeer(s.from);
          await _answer(peer, p['sdp'] as String);
          return;
        }
        if (age > 45000) {
          await _logMissed(s.from, p['video'] == true, s.ts);
          return;
        }
        if (busy) {
          if (id != callId) {
            await m.sendCallSignal(s.from, {'type': 'call-busy', 'call': id});
            await _logMissed(s.from, p['video'] == true, s.ts);
          }
          return;
        }
        callId = id;
        chatKey = 'c:${s.from}';
        remoteId = s.from;
        groupKey = null;
        video = p['video'] == true;
        outgoing = false;
        _incomingOffer = p;
        phase = CallPhase.incoming;
        notifyListeners();
        _ring(chatKey!, s.from);
        _ringTimer = Timer(const Duration(seconds: 45), () {
          if (phase == CallPhase.incoming) _finish('missed');
        });
        return;
      case 'call-answer':
        if (id != callId) return;
        final peer = peers[s.from];
        if (peer == null) return;
        await peer.pc.setRemoteDescription(RTCSessionDescription(p['sdp'] as String, 'answer'));
        await _flushIce(peer);
        if (phase == CallPhase.outgoing) {
          _ringTimer?.cancel();
          phase = CallPhase.connecting;
          notifyListeners();
        }
        return;
      case 'call-ice':
        if (id != callId) return;
        final peer = peers[s.from];
        final c = p['cand'] as Map?;
        if (peer == null || c == null) return;
        final cand = RTCIceCandidate(c['candidate'] as String?, c['sdpMid'] as String?, (c['sdpMLineIndex'] as num?)?.toInt());
        if (peer.remoteSet) {
          await peer.pc.addCandidate(cand);
        } else {
          peer.pendingIce.add(cand);
        }
        return;
      case 'call-reject':
      case 'call-busy':
      case 'call-end':
        if (id != callId) {
          if (type == 'call-end' && _incomingOffer == null) return;
          return;
        }
        if (isGroup) {
          await _removePeer(s.from);
          notifyListeners();
          return;
        }
        if (s.from != remoteId) return;
        await _finish(type == 'call-reject'
            ? 'declined'
            : type == 'call-busy'
                ? 'busy'
                : (startedAt != null ? 'answered' : (outgoing ? 'cancelled' : 'missed')));
        return;
    }
  }

  void _ring(String chat, String from) {
    final title = chat.startsWith('g:') ? m.chatTitle(chat) : m.nameOf(from);
    Notifications.showIncomingCall(chat: chat, title: title, body: m.nameOf(from));
    HapticFeedback.heavyImpact();
    onCallUi?.call();
  }

  Future<void> _offerTo(String peerId) async {
    if (peers.containsKey(peerId)) return;
    final peer = await _createPeer(peerId);
    final offer = await peer.pc.createOffer();
    await peer.pc.setLocalDescription(offer);
    await m.sendCallSignal(peerId, {'type': 'call-offer', 'call': callId, 'gcall': callId, 'sdp': offer.sdp, 'video': video});
  }

  Future<void> _answer(CallPeer peer, String sdp) async {
    await peer.pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    await _flushIce(peer);
    final answer = await peer.pc.createAnswer();
    await peer.pc.setLocalDescription(answer);
    await m.sendCallSignal(peer.id, {'type': 'call-answer', 'call': callId, if (isGroup) 'gcall': callId, 'sdp': answer.sdp});
  }

  Future<void> _flushIce(CallPeer peer) async {
    peer.remoteSet = true;
    for (final c in peer.pendingIce) {
      await peer.pc.addCandidate(c);
    }
    peer.pendingIce.clear();
  }

  // ------------------------------------------------------------- media

  Future<void> _openMedia(bool withVideo) async {
    if (localStream != null) return;
    if (!_localRendererReady) {
      await localRenderer.initialize();
      _localRendererReady = true;
    }
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
      'video': withVideo ? {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 24} : false,
    });
    localRenderer.srcObject = localStream;
    speaker = withVideo;
    await Helper.setSpeakerphoneOn(speaker);
    notifyListeners();
  }

  Future<CallPeer> _createPeer(String peerId) async {
    final pc = await createPeerConnection({
      'iceServers': m.conn.iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
    });
    final peer = CallPeer(peerId, pc);
    await peer.renderer.initialize();
    peers[peerId] = peer;
    for (final t in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await pc.addTrack(t, localStream!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      m.sendCallSignal(peerId, {'type': 'call-ice', 'call': callId, 'cand': c.toMap()}, ephemeral: false);
    };
    pc.onTrack = (e) {
      if (e.streams.isEmpty) return;
      peer.renderer.srcObject = e.streams.first;
      if (e.track.kind == 'video') peer.hasVideo = true;
      notifyListeners();
    };
    pc.onConnectionState = (state) async {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        peer.connected = true;
        if (phase != CallPhase.active) {
          phase = CallPhase.active;
          startedAt ??= DateTime.now();
          await _onActive();
        }
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (isGroup) {
          await _removePeer(peerId);
          notifyListeners();
        } else if (phase != CallPhase.idle) {
          await hangup();
        }
      }
    };
    return peer;
  }

  Future<void> _onActive() async {
    _ringTimer?.cancel();
    await WakelockPlus.enable();
    try {
      await BackgroundService.start(microphone: true);
    } catch (_) {}
  }

  Future<void> _removePeer(String id) async {
    final peer = peers.remove(id);
    if (peer == null) return;
    await peer.pc.close();
    peer.renderer.srcObject = null;
    await peer.renderer.dispose();
  }

  Future<void> toggleMute() async {
    muted = !muted;
    for (final t in localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    speaker = !speaker;
    await Helper.setSpeakerphoneOn(speaker);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    cameraOff = !cameraOff;
    for (final t in localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !cameraOff;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = localStream?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  // ------------------------------------------------------------- teardown

  Future<void> _logMissed(String from, bool video, int ts) => m.addCallRecord(CallRecord(
      id: m.newId(), chat: 'c:$from', peer: from, outgoing: false, video: video, status: 'missed', ts: ts));

  Future<void> _finish(String status) async {
    if (phase == CallPhase.idle) return;
    _ringTimer?.cancel();
    await Notifications.cancelCall();
    final duration = startedAt == null ? 0 : DateTime.now().difference(startedAt!).inSeconds;
    if (chatKey != null) {
      await m.addCallRecord(CallRecord(
        id: callId ?? m.newId(),
        chat: chatKey!,
        peer: remoteId ?? (groupKey ?? ''),
        outgoing: outgoing,
        video: video,
        status: status,
        ts: DateTime.now().millisecondsSinceEpoch,
        duration: duration,
      ));
      if (status == 'missed' && !m.inForeground) {
        Notifications.showMessage(chat: chatKey!, title: m.chatTitle(chatKey!), body: '📞 ${await tr('incomingCall')}');
      }
    }
    for (final id in peers.keys.toList()) {
      await _removePeer(id);
    }
    for (final t in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await t.stop();
    }
    await localStream?.dispose();
    localStream = null;
    if (_localRendererReady) localRenderer.srcObject = null;
    if (groupKey != null && peers.isEmpty && outgoing) groupCalls.remove(groupKey);
    phase = CallPhase.idle;
    callId = null;
    chatKey = null;
    groupKey = null;
    remoteId = null;
    startedAt = null;
    muted = false;
    cameraOff = false;
    _incomingOffer = null;
    notifyListeners();
    await WakelockPlus.disable();
    try {
      await BackgroundService.start();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
