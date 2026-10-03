import 'package:speech_to_text/speech_to_text.dart';

/// Urdu speech-to-text wrapper used for the mic buttons in the post-job and
/// invite-accept flows. Defaults to the `ur-PK` device locale when available.
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  /// Initializes the recognizer. Returns false when unavailable/denied.
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize();
    return _initialized;
  }

  /// Whether the device offers an Urdu (Pakistan) recognition locale.
  Future<bool> hasUrduLocale() async {
    final ok = await initialize();
    if (!ok) return false;
    final locales = await _speech.locales();
    return locales.any((l) => l.localeId.toLowerCase().startsWith('ur'));
  }

  /// Starts listening; [onResult] receives the final recognized words.
  /// Falls back to the device default locale when `ur-PK` is missing.
  Future<void> startListening({
    required void Function(String text) onResult,
    String localeId = 'ur-PK',
  }) async {
    final ok = await initialize();
    if (!ok) throw StateError('Speech recognition is not available');
    final locales = await _speech.locales();
    final wanted = locales.any((l) => l.localeId == localeId)
        ? localeId
        : null; // null => device default
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: wanted,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
