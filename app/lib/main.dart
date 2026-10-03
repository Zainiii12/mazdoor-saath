import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';

import 'screens/common/splash_screen.dart';
import 'screens/common/role_select_screen.dart';
import 'screens/common/phone_auth_screen.dart';
import 'screens/common/profile_setup_screen.dart';
import 'screens/common/profile_screen.dart';

import 'screens/builder/builder_home_screen.dart';
import 'screens/builder/post_job_screen.dart';
import 'screens/builder/job_detail_screen.dart';
import 'screens/builder/match_results_screen.dart';
import 'screens/builder/progress_timeline_screen.dart';
import 'screens/builder/ledger_screen.dart';
import 'screens/builder/rate_worker_screen.dart';

import 'screens/mazdoor/mazdoor_home_screen.dart';
import 'screens/mazdoor/job_invite_screen.dart';
import 'screens/mazdoor/active_job_screen.dart';
import 'screens/mazdoor/earnings_screen.dart';
import 'screens/mazdoor/rate_builder_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final api = ApiClient();
  // FCM setup is best-effort at boot; token is (re-)registered after login.
  try {
    await NotificationService(api).initialize();
  } catch (_) {
    // Notifications will be retried once the user signs in.
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(api: api),
      child: const MazdoorSathiApp(),
    ),
  );
}

class MazdoorSathiApp extends StatelessWidget {
  const MazdoorSathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return MaterialApp(
      title: 'Mazdoor Sathi',
      debugShowCheckedModeBanner: false,
      // 'ur' flips the whole app to right-to-left automatically.
      locale: Locale(appState.locale),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C5B)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final args = (settings.arguments as Map<String, dynamic>?) ??
            <String, dynamic>{};
        switch (settings.name) {
          // Common
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/role':
            return MaterialPageRoute(builder: (_) => const RoleSelectScreen());
          case '/auth':
            return MaterialPageRoute(builder: (_) => const PhoneAuthScreen());
          case '/setup':
            return MaterialPageRoute(
                builder: (_) => const ProfileSetupScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());

          // Builder
          case '/builder/home':
            return MaterialPageRoute(builder: (_) => const BuilderHomeScreen());
          case '/builder/post':
            return MaterialPageRoute(builder: (_) => const PostJobScreen());
          case '/builder/job':
            return MaterialPageRoute(
              builder: (_) => JobDetailScreen(jobId: args['jobId'] as String),
            );
          case '/builder/matches':
            return MaterialPageRoute(
              builder: (_) =>
                  MatchResultsScreen(jobId: args['jobId'] as String),
            );
          case '/builder/progress':
            return MaterialPageRoute(
              builder: (_) =>
                  ProgressTimelineScreen(jobId: args['jobId'] as String),
            );
          case '/builder/ledger':
            return MaterialPageRoute(
              builder: (_) => LedgerScreen(jobId: args['jobId'] as String),
            );
          case '/builder/rate':
            return MaterialPageRoute(
              builder: (_) => RateWorkerScreen(
                jobId: args['jobId'] as String,
                workerId: args['workerId'] as String,
                workerName: args['workerName'] as String? ?? '',
              ),
            );

          // Mazdoor
          case '/mazdoor/home':
            return MaterialPageRoute(builder: (_) => const MazdoorHomeScreen());
          case '/mazdoor/invite':
            return MaterialPageRoute(
              builder: (_) => JobInviteScreen(
                  applicationId: args['applicationId'] as String),
            );
          case '/mazdoor/active':
            return MaterialPageRoute(
              builder: (_) => ActiveJobScreen(jobId: args['jobId'] as String),
            );
          case '/mazdoor/earnings':
            return MaterialPageRoute(builder: (_) => const EarningsScreen());
          case '/mazdoor/rate':
            return MaterialPageRoute(
              builder: (_) => RateBuilderScreen(
                jobId: args['jobId'] as String,
                builderId: args['builderId'] as String,
                builderName: args['builderName'] as String? ?? '',
              ),
            );
        }
        return null;
      },
    );
  }
}
