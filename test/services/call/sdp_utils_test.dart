import 'package:chatspot/services/call/sdp_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const offer = 'v=0\r\n'
      'm=audio 9 UDP/TLS/RTP/SAVPF 111 63 9\r\n'
      'a=rtpmap:111 opus/48000/2\r\n'
      'a=rtcp-fb:111 transport-cc\r\n'
      'a=fmtp:111 minptime=10;useinbandfec=1\r\n'
      'a=rtpmap:63 red/48000/2\r\n'
      'a=fmtp:63 111/111\r\n'
      'a=rtpmap:9 G722/8000\r\n';

  group('SdpUtils.enableHdAudio', () {
    test('adds HD params to the existing Opus fmtp line, keeping others', () {
      final result = SdpUtils.enableHdAudio(offer, maxAverageBitrate: 64000);
      final fmtp =
          result.split('\r\n').firstWhere((l) => l.startsWith('a=fmtp:111 '));

      expect(fmtp, contains('minptime=10'));
      expect(fmtp, contains('useinbandfec=1'));
      expect(fmtp, contains('maxaveragebitrate=64000'));
      expect(fmtp, contains('maxplaybackrate=48000'));
      expect(fmtp, contains('stereo=0'));
      expect('a=fmtp:111 '.allMatches(result).length, 1);
    });

    test('leaves non-Opus codecs untouched', () {
      final result = SdpUtils.enableHdAudio(offer, maxAverageBitrate: 64000);
      expect(result, contains('a=fmtp:63 111/111\r\n'));
      expect(result, contains('a=rtpmap:9 G722/8000\r\n'));
    });

    test('inserts an fmtp line when Opus has none', () {
      const sdp = 'v=0\r\n'
          'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
          'a=rtpmap:111 opus/48000/2\r\n'
          'a=rtcp-fb:111 transport-cc\r\n';
      final lines =
          SdpUtils.enableHdAudio(sdp, maxAverageBitrate: 48000).split('\r\n');
      final rtpMap = lines.indexOf('a=rtpmap:111 opus/48000/2');

      expect(lines[rtpMap + 1], startsWith('a=fmtp:111 '));
      expect(lines[rtpMap + 1], contains('maxaveragebitrate=48000'));
    });

    test('returns the SDP unchanged when there is no Opus', () {
      const sdp = 'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
          'a=rtpmap:96 VP8/90000\r\n';
      expect(SdpUtils.enableHdAudio(sdp, maxAverageBitrate: 64000), sdp);
    });
  });
}
