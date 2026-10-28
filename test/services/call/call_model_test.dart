import 'package:chatspot/services/call/call_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CallModel call(CallStatus status) => CallModel(
        id: 'c1',
        callerId: 'alice',
        callerName: 'Alice',
        calleeId: 'bob',
        calleeName: 'Bob',
        calleePhotoUrl: 'https://example.com/bob.png',
        type: CallType.video,
        status: status,
      );

  test('resolves the other participant from either side', () {
    final c = call(CallStatus.ended);
    expect(c.isOutgoingFor('alice'), isTrue);
    expect(c.otherUserName('alice'), 'Bob');
    expect(c.otherUserPhotoUrl('alice'), 'https://example.com/bob.png');
    expect(c.otherUserId('bob'), 'alice');
    expect(c.otherUserPhotoUrl('bob'), isNull);
  });

  test('missed only applies to the callee', () {
    expect(call(CallStatus.missed).isMissedFor('bob'), isTrue);
    expect(call(CallStatus.cancelled).isMissedFor('bob'), isTrue);
    expect(call(CallStatus.missed).isMissedFor('alice'), isFalse);
    expect(call(CallStatus.ended).isMissedFor('bob'), isFalse);
  });

  test('status parsing and terminal states', () {
    expect(CallStatus.parse('accepted'), CallStatus.accepted);
    expect(CallStatus.parse('garbage'), CallStatus.failed);
    expect(CallStatus.ringing.isTerminal, isFalse);
    expect(CallStatus.accepted.isTerminal, isFalse);
    expect(CallStatus.declined.isTerminal, isTrue);
  });
}
