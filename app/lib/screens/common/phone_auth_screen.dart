import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

/// Two-step phone authentication: number → SMS code → sign in.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _auth = AuthService();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _verificationId;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Normalizes a Pakistani mobile number to E.164.
  String? _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92') && digits.length == 12) {
      return '+$digits';
    }
    if (digits.startsWith('0') && digits.length == 11) {
      return '+92${digits.substring(1)}';
    }
    if (digits.length == 10) {
      return '+92$digits';
    }
    return null;
  }

  Future<void> _sendCode() async {
    final t = context.read<AppState>().t;
    final phone = _normalizePhone(_phoneCtrl.text);
    if (phone == null) {
      setState(() => _error = t('invalidPhone'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _auth.verifyPhone(
      phoneNumber: phone,
      onCodeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _busy = false;
        });
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _error = message;
          _busy = false;
        });
      },
      onAutoVerified: (_) => _afterSignIn(),
    );
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null || _codeCtrl.text.trim().length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signInWithSmsCode(_verificationId!, _codeCtrl.text.trim());
      await _afterSignIn();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.read<AppState>().t('errorGeneric');
        _busy = false;
      });
    }
  }

  /// After sign-in: existing profile → role home, else → profile setup.
  Future<void> _afterSignIn() async {
    final appState = context.read<AppState>();
    try {
      await appState.loadProfile();
    } on ApiException catch (e) {
      if (!e.isNotFound) rethrow;
      // No profile yet — fall through to setup.
    }
    if (!mounted) return;
    if (appState.profile == null) {
      Navigator.pushReplacementNamed(context, '/setup');
    } else if (appState.profile!.isBuilder) {
      Navigator.pushReplacementNamed(context, '/builder/home');
    } else {
      Navigator.pushReplacementNamed(context, '/mazdoor/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return Scaffold(
      appBar: AppBar(title: Text(t('phoneTitle'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_codeSent) ...[
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: t('phoneHint'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _sendCode,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t('sendCode')),
              ),
            ] else ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: t('codeHint'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.sms_outlined),
                ),
                onSubmitted: (_) => _verifyCode(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _verifyCode,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t('verify')),
              ),
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: Text(t('resendCode')),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
