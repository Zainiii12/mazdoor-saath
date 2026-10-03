import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/speech_service.dart';

/// Round microphone button that transcribes Urdu speech (ur-PK) and hands the
/// text to [onResult]. Used for the job-description field and voice accept.
class UrduMicButton extends StatefulWidget {
  final ValueChanged<String> onResult;
  final String? hint;
  final double size;

  const UrduMicButton({
    super.key,
    required this.onResult,
    this.hint,
    this.size = 48,
  });

  @override
  State<UrduMicButton> createState() => _UrduMicButtonState();
}

class _UrduMicButtonState extends State<UrduMicButton> {
  final SpeechService _speech = SpeechService();
  bool _listening = false;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await _speech.initialize();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AppState>().t('errorGeneric'))),
        );
        return;
      }
      setState(() {
        _busy = false;
        _listening = true;
      });
      await _speech.startListening(
        onResult: (text) {
          if (!mounted) return;
          setState(() => _listening = false);
          if (text.trim().isNotEmpty) widget.onResult(text.trim());
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color:
              _listening ? Colors.red : Theme.of(context).colorScheme.primary,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _busy ? null : _toggle,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _listening ? t('listening') : (widget.hint ?? t('micHint')),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: _listening ? Colors.red : Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
