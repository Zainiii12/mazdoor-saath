import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';

/// Boot screen: decides where to send the user (role select / setup / home).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final appState = context.read<AppState>();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/role');
      return;
    }

    try {
      await appState.loadProfile();
      // (Re-)register the FCM token now that we are authenticated.
      await NotificationService(appState.api).registerToken();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNotFound) {
        Navigator.pushReplacementNamed(context, '/setup');
      } else {
        _showErrorAndRetry(e.message);
      }
      return;
    } catch (e) {
      if (!mounted) return;
      _showErrorAndRetry(e.toString());
      return;
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

  void _showErrorAndRetry(String message) {
    final t = context.read<AppState>().t;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(t('errorGeneric')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _boot();
            },
            child: Text(t('retry')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handyman,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              t('appTitle'),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(t('tagline')),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
