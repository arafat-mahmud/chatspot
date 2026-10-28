import 'package:chatspot/services/call/call_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const good = LinkSample(availableBitrate: 5000000, roundTripTime: 0.08);

/// A congested link: the encoder is starved and reports it.
LinkSample congested(double bitrate, {double loss = 0}) => LinkSample(
      availableBitrate: bitrate,
      outgoingLoss: loss,
      roundTripTime: 0.2,
      videoBandwidthLimited: true,
    );

void feed(CallQualityController controller, LinkSample sample, int times) {
  for (var i = 0; i < times; i++) {
    controller.add(sample);
  }
}

void main() {
  group('CallQualityController (video)', () {
    late CallQualityController controller;
    setUp(() => controller = CallQualityController(video: true));

    /// Fast link long enough for the opening jump to Full HD to count as held.
    void settleAtUltra() => feed(controller, good, 10);

    test('climbs to Full HD within two samples on a fast link', () {
      expect(controller.quality, SendQuality.high);
      feed(controller, good, 2);
      expect(controller.quality, SendQuality.ultra);
      feed(controller, good, 20);
      expect(controller.quality, SendQuality.ultra);
      expect(controller.network, NetworkQuality.good);
    });

    test('ignores a single slightly bad sample', () {
      settleAtUltra();
      controller.add(congested(2000000));
      expect(controller.quality, SendQuality.ultra);
      controller.add(congested(2000000));
      expect(controller.quality, SendQuality.high);
    });

    test('a sudden collapse drops at once to what the link carries', () {
      settleAtUltra();
      controller.add(congested(400000));
      expect(controller.quality, SendQuality.low);
      // One more level is an ordinary step: it waits for confirmation.
      controller.add(congested(150000));
      expect(controller.quality, SendQuality.low);
      controller.add(congested(150000));
      expect(controller.quality, SendQuality.veryLow);
    });

    test('a low estimate alone does not count while the encoder is idle', () {
      // Static scene: the estimate never grows, but nothing is starved.
      feed(controller, const LinkSample(availableBitrate: 400000), 10);
      expect(controller.quality, SendQuality.ultra);
    });

    test('pauses video below the floor and reports a poor network', () {
      settleAtUltra();
      controller.add(const LinkSample(availableBitrate: 60000));
      expect(controller.quality, SendQuality.minimal);
      expect(SendSettings.of(controller.quality).videoActive, isFalse);

      controller.add(const LinkSample(availableBitrate: 60000));
      expect(controller.network, NetworkQuality.poor);
    });

    test('heavy packet loss pauses video', () {
      settleAtUltra();
      controller.add(
        const LinkSample(availableBitrate: 5000000, outgoingLoss: 0.25),
      );
      expect(controller.quality, SendQuality.minimal);
    });

    test('during warm-up only a dead link lowers quality', () {
      feed(controller, congested(300000), 2);
      expect(controller.quality, SendQuality.high);

      final fresh = CallQualityController(video: true);
      fresh.add(const LinkSample(availableBitrate: 50000));
      expect(fresh.quality, SendQuality.high);
      fresh.add(const LinkSample(availableBitrate: 50000));
      expect(fresh.quality, SendQuality.minimal);
    });

    test('resumes video on a quiet link, then jumps back to Full HD', () {
      settleAtUltra();
      controller.add(const LinkSample(availableBitrate: 60000));
      expect(controller.quality, SendQuality.minimal);

      // Voice alone keeps the estimate low, so resuming is time based.
      const quiet = LinkSample(availableBitrate: 70000, roundTripTime: 0.1);
      feed(controller, quiet, 3);
      expect(controller.quality, SendQuality.minimal);
      controller.add(quiet);
      expect(controller.quality, SendQuality.veryLow);

      // Once video flows the estimate proves the link is fast again.
      feed(controller, good, 2);
      expect(controller.quality, SendQuality.ultra);
    });

    test('a failed step up doubles the wait before the next one', () {
      settleAtUltra();
      feed(controller, congested(1500000), 2);
      expect(controller.quality, SendQuality.high);

      const quietAtHigh = LinkSample(availableBitrate: 2000000);
      feed(controller, quietAtHigh, 4);
      expect(controller.quality, SendQuality.ultra);
      // Full HD doesn't hold on this link.
      feed(controller, congested(2000000), 2);
      expect(controller.quality, SendQuality.high);

      feed(controller, quietAtHigh, 7);
      expect(controller.quality, SendQuality.high);
      controller.add(quietAtHigh);
      expect(controller.quality, SendQuality.ultra);
    });

    test('does not step up while the encoder is starved', () {
      settleAtUltra();
      feed(controller, congested(1500000), 32);
      expect(controller.quality, SendQuality.high);
    });

    test('Full HD sends 1080p; lower levels scale it down', () {
      final ultra = SendSettings.of(SendQuality.ultra);
      expect(ultra.videoScaleDown, 1);
      expect(ultra.videoBitrate,
          greaterThan(SendSettings.of(SendQuality.high).videoBitrate));
      expect(SendSettings.of(SendQuality.veryLow).videoScaleDown, 4.5);
    });
  });

  group('CallQualityController (audio)', () {
    late CallQualityController controller;
    setUp(() => controller = CallQualityController(video: false));

    test('never goes above HD voice', () {
      feed(controller, good, 20);
      expect(controller.quality, SendQuality.high);
    });

    test('lowers the voice bitrate as bandwidth shrinks, and recovers', () {
      feed(controller, good, 3);
      feed(controller, const LinkSample(availableBitrate: 80000), 2);
      expect(controller.quality, SendQuality.medium);
      controller.add(const LinkSample(availableBitrate: 30000));
      expect(controller.quality, SendQuality.minimal);
      expect(SendSettings.of(controller.quality).audioBitrate, 20000);

      feed(controller, good, 2);
      expect(controller.quality, SendQuality.high);
    });

    test('packet loss alone does not lower voice quality', () {
      feed(
        controller,
        const LinkSample(availableBitrate: 200000, outgoingLoss: 0.2),
        10,
      );
      expect(controller.quality, SendQuality.high);
    });
  });

  group('network quality', () {
    test('needs two samples in a row to change', () {
      final controller = CallQualityController(video: false);
      feed(controller, good, 3);
      controller
          .add(const LinkSample(availableBitrate: 2000000, incomingLoss: 0.08));
      expect(controller.network, NetworkQuality.good);
      controller
          .add(const LinkSample(availableBitrate: 2000000, incomingLoss: 0.08));
      expect(controller.network, NetworkQuality.weak);

      controller.add(good);
      expect(controller.network, NetworkQuality.weak);
      controller.add(good);
      expect(controller.network, NetworkQuality.good);
    });

    test('high latency counts as a poor connection', () {
      final controller = CallQualityController(video: false);
      feed(controller,
          const LinkSample(availableBitrate: 2000000, roundTripTime: 1.2), 2);
      expect(controller.network, NetworkQuality.poor);
    });
  });

  group('LinkStatsReader', () {
    StatsReport report(String id, String type, Map<String, Object> values) =>
        StatsReport(id, type, 0, values);

    List<StatsReport> stats({required int lost, required int received}) => [
          report('T1', 'transport', {'selectedCandidatePairId': 'CP2'}),
          report('CP1', 'candidate-pair', {
            'state': 'succeeded',
            'nominated': true,
            'availableOutgoingBitrate': 999.0,
          }),
          report('CP2', 'candidate-pair', {
            'state': 'succeeded',
            'availableOutgoingBitrate': 350000.0,
            'currentRoundTripTime': 0.25,
          }),
          report('RIA', 'remote-inbound-rtp',
              {'kind': 'audio', 'fractionLost': 0.02}),
          report('RIV', 'remote-inbound-rtp',
              {'kind': 'video', 'fractionLost': 0.1}),
          report('IA', 'inbound-rtp',
              {'packetsLost': lost, 'packetsReceived': received}),
          report('OV', 'outbound-rtp', {
            'kind': 'video',
            'qualityLimitationReason': 'bandwidth',
          }),
        ];

    test('reads the selected pair, worst outgoing loss and encoder state', () {
      final sample = LinkStatsReader().read(stats(lost: 0, received: 100));
      expect(sample.availableBitrate, 350000);
      expect(sample.roundTripTime, 0.25);
      expect(sample.outgoingLoss, 0.1);
      expect(sample.videoBandwidthLimited, isTrue);
    });

    test('measures incoming loss between samples', () {
      final reader = LinkStatsReader();
      expect(reader.read(stats(lost: 50, received: 1000)).incomingLoss, 0);
      final sample = reader.read(stats(lost: 60, received: 1090));
      expect(sample.incomingLoss, closeTo(0.1, 1e-9));
    });

    test('falls back to the nominated pair without transport stats', () {
      final reports = stats(lost: 0, received: 0)
          .where((r) => r.type != 'transport')
          .toList();
      expect(LinkStatsReader().read(reports).availableBitrate, 999);
    });
  });
}
