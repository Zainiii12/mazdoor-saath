import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/auth_service.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/section_title.dart';

/// View my profile, switch language, log out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    context.read<AppState>().clear();
    Navigator.pushNamedAndRemoveUntil(context, '/role', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;
    final profile = appState.profile;

    return Scaffold(
      appBar: AppBar(title: Text(t('profile'))),
      body: profile == null
          ? Center(child: Text(t('errorGeneric')))
          : ListView(
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 40,
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.isBuilder ? t('builder') : t('mazdoor'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Center(
                  child: RatingStars(
                    rating: profile.ratingAvg,
                    showCount: true,
                    count: profile.ratingCount,
                  ),
                ),
                SectionTitle(text: t('myTrades')),
                if (profile.trades.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('—'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: profile.trades
                          .map(
                              (tr) => Chip(label: Text(appState.tradeName(tr))))
                          .toList(),
                    ),
                  ),
                SectionTitle(text: t('language')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'ur', label: Text('اردو')),
                    ],
                    selected: {appState.locale},
                    onSelectionChanged: (s) => appState.setLocale(s.first),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout),
                    label: Text(t('logout')),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
