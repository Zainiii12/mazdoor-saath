import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mazdoor_sathi/l10n/strings.dart';
import 'package:mazdoor_sathi/models/job.dart';
import 'package:mazdoor_sathi/providers/app_state.dart';
import 'package:mazdoor_sathi/screens/common/role_select_screen.dart';
import 'package:mazdoor_sathi/services/api_client.dart';

void main() {
  test('localization returns strings for English and Urdu', () {
    expect(AppStrings.get('appTitle', 'en'), 'Mazdoor Sathi');
    expect(AppStrings.get('appTitle', 'ur'), isNotEmpty);
    expect(AppStrings.get('builder', 'en'), 'Builder');
    expect(AppStrings.get('mazdoor', 'ur'), isNotEmpty);
    expect(AppStrings.tradeName('mason', 'en'), isNotEmpty);
    expect(AppStrings.tradeName('mason', 'ur'), isNotEmpty);
  });

  test('Job parses from the backend API JSON shape', () {
    final job = Job.fromJson({
      'id': 'job-1',
      'builderId': 'builder-1',
      'title': 'Ghar ki tameer',
      'description': '2 kamray',
      'city': 'Gujrat',
      'siteLocation': {'lat': 32.5731, 'lng': 74.1005},
      'tradesRequired': [
        {'trade': 'mason', 'count': 2, 'wageOffer': 1500},
        {'trade': 'electrician', 'count': 1, 'wageOffer': 1800},
      ],
      'status': 'open',
    });

    expect(job.id, 'job-1');
    expect(job.builderId, 'builder-1');
    expect(job.title, 'Ghar ki tameer');
    expect(job.city, 'Gujrat');
    expect(job.siteLat, closeTo(32.5731, 0.0001));
    expect(job.trades, hasLength(2));
    expect(job.trades.first.trade, 'mason');
    expect(job.trades.first.count, 2);
    expect(job.status, 'open');
  });

  test('trade requirement round-trips through toJson', () {
    const req = TradeRequirement(trade: 'plumber', count: 1, dailyWage: 2000);
    final json = req.toJson();
    final back = TradeRequirement.fromJson(json);
    expect(back.trade, 'plumber');
    expect(back.count, 1);
    expect(back.dailyWage, 2000);
  });

  testWidgets('role select screen renders both roles', (tester) async {
    final api = ApiClient();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(api: api),
        child: const MaterialApp(home: RoleSelectScreen()),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.get('appTitle', 'en')), findsOneWidget);
    expect(find.text(AppStrings.get('builder', 'en')), findsOneWidget);
    expect(find.text(AppStrings.get('mazdoor', 'en')), findsOneWidget);
  });
}
