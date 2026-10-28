import 'dart:math' as math;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_config.dart';

/// How good the connection is, as shown to the user.
enum NetworkQuality { good, weak, poor }

/// What we send, best first. [CallQualityController] picks one from live
/// stats; WebRTC's own congestion control still adapts within each level.
/// Voice calls only use [high] and below.
enum SendQuality { ultra, high, medium, low, veryLow, minimal }

/// Encoder limits for one [SendQuality]. Resolutions assume a 1080p camera.
class SendSettings {
  const SendSettings({
    required this.audioBitrate,
    this.videoBitrate = 0,
    this.videoScaleDown = 1,
    this.videoFrameRate = 0,
  });

  final int audioBitrate;

  /// 0 stops sending video so the whole link carries voice.
  final int videoBitrate;
  final double videoScaleDown;
  final int videoFrameRate;

  bool get videoActive => videoBitrate > 0;

  static SendSettings of(SendQuality quality) => switch (quality) {
        // 1920x1080
        SendQuality.ultra => const SendSettings(
            audioBitrate: CallConfig.hdAudioBitrate,
            videoBitrate: CallConfig.maxVideoBitrate,
            videoFrameRate: CallConfig.videoFrameRate,
          ),
        // 1280x720
        SendQuality.high => const SendSettings(
            audioBitrate: CallConfig.hdAudioBitrate,
            videoBitrate: 2000000,
            videoScaleDown: 1.5,
            videoFrameRate: CallConfig.videoFrameRate,
          ),
        // 854x480
        SendQuality.medium => const SendSettings(
            audioBitrate: 48000,
            videoBitrate: 900000,
            videoScaleDown: 2.25,
            videoFrameRate: 30,
          ),
        // 640x360
        SendQuality.low => const SendSettings(
            audioBitrate: 36000,
            videoBitrate: 450000,
            videoScaleDown: 3,
            videoFrameRate: 24,
          ),
        // 426x240
        SendQuality.veryLow => const SendSettings(
            audioBitrate: 28000,
            videoBitrate: 180000,
            videoScaleDown: 4.5,
            videoFrameRate: 15,
          ),
        // Voice only; Opus with FEC is still clear at this rate.
        SendQuality.minimal => const SendSettings(audioBitrate: 20000),
      };
}

/// One stats reading, reduced to what quality decisions need.
class LinkSample {
  const LinkSample({
    this.availableBitrate,
    this.outgoingLoss = 0,
    this.incomingLoss = 0,
    this.roundTripTime,
    this.videoBandwidthLimited = false,
  });

  /// WebRTC's estimate of the outgoing bandwidth, bits/s.
  final double? availableBitrate;

  /// Fraction (0..1) of our packets the peer reports lost.
  final double outgoingLoss;

  /// Fraction (0..1) of the peer's packets we lost since the last sample.
  final double incomingLoss;

  /// Seconds.
  final double? roundTripTime;

  /// The video encoder had to cut resolution or frame rate for bandwidth.
  final bool videoBandwidthLimited;
}

/// Turns raw `getStats()` reports into [LinkSample]s. Keeps the previous
/// counters, so use one reader per peer connection.
class LinkStatsReader {
  final Map<String, (num lost, num received)> _inbound = {};

  LinkSample read(List<StatsReport> reports) {
    String? selectedPairId;
    final pairs = <String, Map<dynamic, dynamic>>{};
    var outgoingLoss = 0.0;
    num lost = 0;
    num received = 0;
    var videoBandwidthLimited = false;

    for (final report in reports) {
      final values = report.values;
      switch (report.type) {
        case 'transport':
          selectedPairId ??= values['selectedCandidatePairId'] as String?;
        case 'candidate-pair':
          pairs[report.id] = values;
        case 'remote-inbound-rtp':
          final fraction = values['fractionLost'];
          if (fraction is num) {
            outgoingLoss = math.max(outgoingLoss, fraction.toDouble());
          }
        case 'inbound-rtp':
          final totalLost = values['packetsLost'] as num? ?? 0;
          final totalReceived = values['packetsReceived'] as num? ?? 0;
          final previous = _inbound[report.id];
          _inbound[report.id] = (totalLost, totalReceived);
          if (previous != null) {
            lost += math.max(0, totalLost - previous.$1);
            received += math.max(0, totalReceived - previous.$2);
          }
        case 'outbound-rtp':
          if (values['kind'] == 'video' &&
              values['qualityLimitationReason'] == 'bandwidth') {
            videoBandwidthLimited = true;
          }
      }
    }

    final pair = pairs[selectedPairId] ??
        pairs.values
            .where((p) => p['nominated'] == true && p['state'] == 'succeeded')
            .firstOrNull;
    return LinkSample(
      availableBitrate: (pair?['availableOutgoingBitrate'] as num?)?.toDouble(),
      roundTripTime: (pair?['currentRoundTripTime'] as num?)?.toDouble(),
      outgoingLoss: outgoingLoss,
      incomingLoss: lost + received == 0 ? 0 : lost / (lost + received),
      videoBandwidthLimited: videoBandwidthLimited,
    );
  }
}

/// Picks what to send from a stream of [LinkSample]s.
///
/// Steps down as soon as the link can't carry the current level, so voice
/// keeps flowing, and climbs back as the link recovers: straight to the
/// level the bandwidth estimate proves, otherwise one level at a time after
/// a quiet stretch. A step up that fails right away doubles the wait before
/// the next try, so a borderline link doesn't flap between levels.
class CallQualityController {
  CallQualityController({required this.video})
      : _quality = SendQuality.high,
        _top = video ? SendQuality.ultra : SendQuality.high;

  final bool video;

  /// Best level for this call type.
  final SendQuality _top;

  SendQuality _quality;
  SendQuality get quality => _quality;

  NetworkQuality _network = NetworkQuality.good;
  NetworkQuality get network => _network;

  /// Minimum available bandwidth (bits/s) and maximum outgoing packet loss
  /// each level needs.
  static const Map<SendQuality, (int, double)> _videoNeeds = {
    SendQuality.ultra: (2800000, 0.03),
    SendQuality.high: (1200000, 0.05),
    SendQuality.medium: (550000, 0.06),
    SendQuality.low: (280000, 0.08),
    SendQuality.veryLow: (110000, 0.15),
  };

  /// Opus FEC handles random loss; only bandwidth matters for voice.
  static const Map<SendQuality, (int, double)> _audioNeeds = {
    SendQuality.high: (100000, 1),
    SendQuality.medium: (75000, 1),
    SendQuality.low: (60000, 1),
    SendQuality.veryLow: (45000, 1),
  };

  /// Below this, video only starves the voice, whatever the encoder says.
  static const int _videoFloor = 80000;

  /// Bandwidth estimates are still ramping up right after connecting.
  static const int _warmupSamples = 2;
  static const int _downgradeAfter = 2;
  static const int _provenUpgradeAfter = 2;
  static const int _baseUpgradeAfter = 4;
  static const int _maxUpgradeAfter = 30;

  /// A step up that falls back within this many samples failed.
  static const int _probeWindow = 6;

  int _samples = 0;
  int _downStreak = 0;
  int _upStreak = 0;
  int _provenStreak = 0;
  int _upgradeAfter = _baseUpgradeAfter;
  int? _upgradedAt;
  NetworkQuality? _pendingNetwork;

  Map<SendQuality, (int, double)> get _needs =>
      video ? _videoNeeds : _audioNeeds;

  /// Feeds one sample; returns true if [quality] or [network] changed.
  bool add(LinkSample sample) {
    _samples++;
    final before = (_quality, _network);
    _updateQuality(sample);
    _updateNetwork(sample);
    return (_quality, _network) != before;
  }

  /// The best level this sample shows the link can hold.
  SendQuality supportedBy(LinkSample sample) {
    final bandwidth = sample.availableBitrate;
    if (video && bandwidth != null && bandwidth < _videoFloor) {
      return SendQuality.minimal;
    }
    // An idle encoder (static scene) never pushes the estimate up, so for
    // video a low estimate only counts when the encoder is actually short.
    final bandwidthBound = !video || sample.videoBandwidthLimited;
    for (final MapEntry(key: quality, value: (minBitrate, maxLoss))
        in _needs.entries) {
      if (quality.index < _top.index) continue;
      if (sample.outgoingLoss > maxLoss) continue;
      if (bandwidthBound && bandwidth != null && bandwidth < minBitrate) {
        continue;
      }
      return quality;
    }
    return SendQuality.minimal;
  }

  /// The best level the bandwidth estimate alone proves, if any.
  SendQuality? _provenBy(LinkSample sample) {
    final bandwidth = sample.availableBitrate;
    if (bandwidth == null) return null;
    for (final MapEntry(key: quality, value: (minBitrate, _))
        in _needs.entries) {
      if (quality.index >= _top.index && bandwidth >= minBitrate) {
        return quality;
      }
    }
    return null;
  }

  void _updateQuality(LinkSample sample) {
    final supported = supportedBy(sample);

    if (supported.index > _quality.index) {
      _upStreak = 0;
      _provenStreak = 0;
      final warmingUp = _samples <= _warmupSamples;
      if (warmingUp && supported != SendQuality.minimal) return;
      // A sudden collapse (two or more levels at once) can't wait.
      final sudden = supported.index - _quality.index >= 2 && !warmingUp;
      if (++_downStreak < (sudden ? 1 : _downgradeAfter)) return;
      final upgradedAt = _upgradedAt;
      if (upgradedAt != null && _samples - upgradedAt <= _probeWindow) {
        _upgradeAfter = math.min(_upgradeAfter * 2, _maxUpgradeAfter);
      }
      _upgradedAt = null;
      _downStreak = 0;
      _quality = supported;
      return;
    }

    _downStreak = 0;
    final upgradedAt = _upgradedAt;
    if (upgradedAt != null && _samples - upgradedAt > _probeWindow) {
      // The last step up held.
      _upgradeAfter = _baseUpgradeAfter;
      _upgradedAt = null;
    }

    final calm =
        sample.outgoingLoss < 0.03 && (sample.roundTripTime ?? 0) < 0.6;
    if (_quality == _top || !calm) {
      _upStreak = 0;
      _provenStreak = 0;
      return;
    }

    // The estimate shows room for better: go straight there.
    final proven = _provenBy(sample);
    if (proven != null && proven.index < _quality.index) {
      if (++_provenStreak < _provenUpgradeAfter) return;
      _stepUpTo(proven);
      return;
    }
    _provenStreak = 0;

    // The estimate can't show headroom above what we already send (e.g.
    // with video paused), so step up on a quiet link and let the next
    // samples judge.
    if (video && sample.videoBandwidthLimited) {
      _upStreak = 0;
      return;
    }
    if (++_upStreak < _upgradeAfter) return;
    _stepUpTo(SendQuality.values[_quality.index - 1]);
  }

  void _stepUpTo(SendQuality quality) {
    _upStreak = 0;
    _provenStreak = 0;
    _upgradedAt = _samples;
    _quality = quality;
  }

  void _updateNetwork(LinkSample sample) {
    final rtt = sample.roundTripTime ?? 0;
    final NetworkQuality current;
    if (_quality == SendQuality.minimal ||
        sample.incomingLoss >= 0.15 ||
        rtt >= 1.0) {
      current = NetworkQuality.poor;
    } else if (_quality == SendQuality.veryLow ||
        sample.incomingLoss >= 0.05 ||
        rtt >= 0.5) {
      current = NetworkQuality.weak;
    } else {
      current = NetworkQuality.good;
    }

    // Two samples in a row, so a single lost burst doesn't flash a warning.
    if (current == _network) {
      _pendingNetwork = null;
    } else if (current == _pendingNetwork) {
      _network = current;
      _pendingNetwork = null;
    } else {
      _pendingNetwork = current;
    }
  }
}
