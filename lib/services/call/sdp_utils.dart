/// SDP tweaks applied to every local offer/answer before it is sent.
///
/// The fmtp parameters in *our* SDP tell the *remote* Opus encoder how to
/// encode the audio it sends us, so both peers munge their own description.
class SdpUtils {
  static final RegExp _opusRtpMap =
      RegExp(r'^a=rtpmap:(\d+) opus/48000', caseSensitive: false);

  /// Upgrades Opus to fullband "HD voice": 48 kHz playback, a higher average
  /// bitrate, and in-band FEC so short packet-loss bursts are concealed.
  static String enableHdAudio(String sdp, {required int maxAverageBitrate}) {
    final lines = sdp.split('\r\n');

    String? opusPayload;
    for (final line in lines) {
      final match = _opusRtpMap.firstMatch(line);
      if (match != null) {
        opusPayload = match.group(1);
        break;
      }
    }
    if (opusPayload == null) return sdp;

    final overrides = <String, String>{
      'useinbandfec': '1',
      'stereo': '0',
      'sprop-stereo': '0',
      'maxplaybackrate': '48000',
      'sprop-maxcapturerate': '48000',
      'maxaveragebitrate': '$maxAverageBitrate',
    };

    final fmtpPrefix = 'a=fmtp:$opusPayload ';
    final fmtpIndex = lines.indexWhere((l) => l.startsWith(fmtpPrefix));

    if (fmtpIndex == -1) {
      // No fmtp line yet: add one right after the rtpmap line.
      final rtpMapIndex =
          lines.indexWhere((l) => l.startsWith('a=rtpmap:$opusPayload '));
      lines.insert(rtpMapIndex + 1, '$fmtpPrefix${_encode(overrides)}');
      return lines.join('\r\n');
    }

    final params = <String, String>{};
    for (final pair in lines[fmtpIndex].substring(fmtpPrefix.length).split(';')) {
      final kv = pair.trim().split('=');
      if (kv.length == 2) params[kv[0].trim()] = kv[1].trim();
    }
    params.addAll(overrides);
    lines[fmtpIndex] = '$fmtpPrefix${_encode(params)}';
    return lines.join('\r\n');
  }

  static String _encode(Map<String, String> params) =>
      params.entries.map((e) => '${e.key}=${e.value}').join(';');
}
