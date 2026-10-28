import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/services/call/call_quality.dart';
import 'package:chatspot/services/call/call_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Full-screen UI for a single call, from ringing to hang-up.
///
/// The screen owns the video renderers; [CallSession] owns the media and the
/// connection. When the call ends the screen shows the reason briefly and
/// closes itself.
class CallScreen extends StatefulWidget {
  final CallSession session;

  const CallScreen({super.key, required this.session});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  bool _closing = false;
  Timer? _ticker;
  Offset? _pipOffset;

  CallSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
    _initRenderers();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && session.connectedAt != null) setState(() {});
    });
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;
    _renderersReady = true;
    _onSessionChanged();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_renderersReady) {
      if (_localRenderer.srcObject != session.localStream) {
        _localRenderer.srcObject = session.localStream;
      }
      // Attached for audio calls too: on web, remote audio only plays
      // through a renderer.
      if (_remoteRenderer.srcObject != session.remoteStream) {
        _remoteRenderer.srcObject = session.remoteStream;
      }
    }
    if (session.phase == CallPhase.ended && !_closing) {
      _closing = true;
      _ticker?.cancel();
      Future.delayed(const Duration(milliseconds: 1500), _close);
    }
    setState(() {});
  }

  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    session.removeListener(_onSessionChanged);
    if (session.phase != CallPhase.ended) session.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  bool get _showRemoteVideo =>
      session.isVideo &&
      _renderersReady &&
      session.remoteStream != null &&
      !session.remoteCameraOff &&
      // Otherwise the last frame would sit there frozen.
      !session.remoteVideoPaused &&
      (session.phase == CallPhase.connected ||
          session.phase == CallPhase.reconnecting);

  bool get _showLocalVideo =>
      session.isVideo &&
      _renderersReady &&
      session.localStream != null &&
      !session.cameraOff &&
      session.phase != CallPhase.ended;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back must not silently drop a live call.
      canPop: session.phase == CallPhase.ended,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(),
              if (_showLocalVideo && _showRemoteVideo)
                _buildPictureInPicture(constraints.biggest),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const Spacer(),
                    _buildControls(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (_showRemoteVideo) {
      return RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    // Before the remote video arrives, show our own camera full-screen.
    if (_showLocalVideo && session.phase != CallPhase.ended) {
      return Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(
            _localRenderer,
            mirror: session.frontCamera,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
          Container(color: Colors.black.withValues(alpha: 0.35)),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F2C34), Color(0xFF0B141A)],
        ),
      ),
    );
  }

  Widget _buildPictureInPicture(Size area) {
    const width = 110.0;
    const height = 160.0;
    final padding = MediaQuery.of(context).padding;
    const minX = 16.0;
    final minY = padding.top + 16;
    // Keep clear of the control row; max() guards very short (landscape) screens.
    final maxX = math.max(minX, area.width - width - 16);
    final maxY = math.max(minY, area.height - height - padding.bottom - 140);
    Offset clampToArea(Offset o) =>
        Offset(o.dx.clamp(minX, maxX), o.dy.clamp(minY, maxY));
    final offset = clampToArea(_pipOffset ?? Offset(maxX, minY));

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          _pipOffset = clampToArea(offset + details.delta);
        }),
        onTap: session.switchCamera,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: width,
            height: height,
            child: RTCVideoView(
              _localRenderer,
              mirror: session.frontCamera,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final compact = _showRemoteVideo;
    return Column(
      children: [
        if (!compact) ...[
          _PulsingAvatar(
            name: session.peerName,
            photoUrl: session.peerPhotoUrl,
            pulsing: session.phase == CallPhase.outgoing ||
                session.phase == CallPhase.incoming,
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            session.peerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 20 : 28,
              fontWeight: FontWeight.w600,
              shadows: compact
                  ? const [Shadow(blurRadius: 8, color: Colors.black54)]
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session.phase == CallPhase.connected &&
                session.qualityBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  session.qualityBadge!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _statusText(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
          ],
        ),
        if (session.remoteMicMuted && session.phase == CallPhase.connected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Chip(
              icon: Icons.mic_off,
              label: '${session.peerName} muted',
            ),
          ),
        if (session.isVideo &&
            session.remoteCameraOff &&
            session.phase == CallPhase.connected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Chip(icon: Icons.videocam_off, label: 'Camera off'),
          ),
        if (session.phase == CallPhase.connected)
          for (final chip in _connectionChips())
            Padding(padding: const EdgeInsets.only(top: 8), child: chip),
      ],
    );
  }

  /// Explains choppy or frozen media: our own connection first, then the
  /// peer's.
  List<Widget> _connectionChips() {
    final own = session.networkQuality;
    final peer = session.remoteNetworkQuality;
    return [
      if (own != NetworkQuality.good)
        _Chip(
          icon: _networkIcon(own),
          label: own == NetworkQuality.poor
              ? 'Poor connection'
              : 'Weak connection',
        )
      else if (peer != NetworkQuality.good)
        _Chip(
          icon: _networkIcon(peer),
          label: "${session.peerName}'s connection is "
              '${peer == NetworkQuality.poor ? 'poor' : 'weak'}',
        ),
      if (session.remoteVideoPaused && !session.remoteCameraOff)
        _Chip(
          icon: Icons.videocam_off,
          label: "${session.peerName}'s video paused (weak connection)",
        )
      else if (session.videoPaused && !session.cameraOff)
        const _Chip(
          icon: Icons.videocam_off,
          label: 'Your video is paused to keep audio clear',
        ),
    ];
  }

  static IconData _networkIcon(NetworkQuality quality) =>
      quality == NetworkQuality.poor
          ? Icons.signal_cellular_alt_1_bar
          : Icons.signal_cellular_alt_2_bar;

  String _statusText() {
    switch (session.phase) {
      case CallPhase.outgoing:
        return 'Calling…';
      case CallPhase.incoming:
        return session.isVideo ? 'Incoming video call' : 'Incoming voice call';
      case CallPhase.connecting:
        return 'Connecting…';
      case CallPhase.reconnecting:
        return 'Reconnecting…';
      case CallPhase.connected:
        return _formatDuration(DateTime.now().difference(session.connectedAt!));
      case CallPhase.ended:
        return session.endMessage ?? 'Call ended';
    }
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _buildControls() {
    if (session.phase == CallPhase.ended) {
      return const SizedBox(height: 88);
    }

    if (session.phase == CallPhase.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            icon: Icons.call_end,
            label: 'Decline',
            background: Colors.red,
            onPressed: session.decline,
          ),
          _CallButton(
            icon: session.isVideo ? Icons.videocam : Icons.call,
            label: 'Accept',
            background: Colors.green,
            onPressed: session.accept,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (session.isVideo) ...[
            _CallButton(
              icon: Icons.cameraswitch,
              label: 'Flip',
              onPressed: session.cameraOff ? null : session.switchCamera,
            ),
            _CallButton(
              icon: session.cameraOff ? Icons.videocam_off : Icons.videocam,
              label: 'Camera',
              active: session.cameraOff,
              onPressed: session.toggleCamera,
            ),
          ] else
            _CallButton(
              icon: session.speakerOn ? Icons.volume_up : Icons.volume_down,
              label: 'Speaker',
              active: session.speakerOn,
              onPressed: session.toggleSpeaker,
            ),
          _CallButton(
            icon: session.micMuted ? Icons.mic_off : Icons.mic,
            label: session.micMuted ? 'Unmute' : 'Mute',
            active: session.micMuted,
            onPressed: session.toggleMic,
          ),
          _CallButton(
            icon: Icons.call_end,
            label: 'End',
            background: Colors.red,
            onPressed: session.hangUp,
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? background;
  final bool active;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.background,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = background ??
        (active ? Colors.white : Colors.white.withValues(alpha: 0.18));
    final iconColor =
        background != null ? Colors.white : (active ? Colors.black87 : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(
                icon,
                size: 28,
                color: onPressed == null
                    ? iconColor.withValues(alpha: 0.4)
                    : iconColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingAvatar extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final bool pulsing;

  const _PulsingAvatar({
    required this.name,
    required this.photoUrl,
    required this.pulsing,
  });

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulsingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 64.0;
    final photoUrl = widget.photoUrl;

    return SizedBox(
      width: radius * 3,
      height: radius * 3,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              Container(
                width: radius * 2 * (1 + _controller.value * 0.45),
                height: radius * 2 * (1 + _controller.value * 0.45),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: 0.18 * (1 - _controller.value)),
                ),
              ),
            child!,
          ],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Colors.blueGrey.shade700,
          backgroundImage:
              photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 48, color: Colors.white),
                )
              : null,
        ),
      ),
    );
  }
}
