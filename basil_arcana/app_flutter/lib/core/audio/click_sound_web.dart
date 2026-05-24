import 'dart:async';
import 'dart:web_audio' as web_audio;

web_audio.AudioContext? _audioContext;
DateTime? _lastPlayedAt;

void playClickSound() {
  final nowWallClock = DateTime.now();
  final lastPlayedAt = _lastPlayedAt;
  if (lastPlayedAt != null &&
      nowWallClock.difference(lastPlayedAt).inMilliseconds < 45) {
    return;
  }
  _lastPlayedAt = nowWallClock;

  try {
    if (!web_audio.AudioContext.supported) {
      return;
    }
    final context = _audioContext ??= web_audio.AudioContext();
    if (context.state == 'suspended') {
      unawaited(context.resume());
    }

    final oscillator = context.createOscillator();
    final gain = context.createGain();
    final currentTime = context.currentTime ?? 0;
    final destination = context.destination;
    if (destination == null) {
      return;
    }

    oscillator.type = 'sine';
    oscillator.frequency?.setValueAtTime(760, currentTime);
    oscillator.frequency?.exponentialRampToValueAtTime(520, currentTime + 0.05);

    gain.gain?.setValueAtTime(0.0001, currentTime);
    gain.gain?.exponentialRampToValueAtTime(0.025, currentTime + 0.004);
    gain.gain?.exponentialRampToValueAtTime(0.0001, currentTime + 0.055);

    oscillator.connectNode(gain);
    gain.connectNode(destination);
    oscillator.start2(currentTime);
    oscillator.stop(currentTime + 0.06);
  } catch (_) {
    // Audio is decorative. Ignore browser autoplay or WebAudio edge-case errors.
  }
}
