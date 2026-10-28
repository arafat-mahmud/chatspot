import 'package:chatspot/services/presence/presence_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 28, 12);
  Presence at(Duration ago, {bool online = false}) =>
      Presence(online: online, lastActive: now.subtract(ago));

  test('online with a fresh heartbeat is active now', () {
    final presence = at(const Duration(minutes: 3), online: true);
    expect(presence.isActiveNow(now), isTrue);
    expect(presence.label(now), 'Active now');
    expect(presence.minutesAway(now), isNull);
  });

  test('online with a stopped heartbeat (app killed) goes stale', () {
    final presence = at(const Duration(minutes: 20), online: true);
    expect(presence.isActiveNow(now), isFalse);
    expect(presence.label(now), 'Active 20m ago');
  });

  test('labels how long ago someone left', () {
    expect(at(const Duration(seconds: 20)).label(now), 'Active just now');
    expect(at(const Duration(minutes: 5)).label(now), 'Active 5m ago');
    expect(at(const Duration(hours: 3)).label(now), 'Active 3h ago');
    expect(at(const Duration(days: 2)).label(now), 'Active 2d ago');
    expect(at(const Duration(days: 9)).label(now), isNull);
    expect(Presence.unknown.label(now), isNull);
  });

  test('the avatar badge counts minutes, for the last hour only', () {
    expect(at(const Duration(seconds: 20)).minutesAway(now), 1);
    expect(at(const Duration(minutes: 42)).minutesAway(now), 42);
    expect(at(const Duration(minutes: 61)).minutesAway(now), isNull);
  });
}
