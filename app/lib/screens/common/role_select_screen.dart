import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';

/// First-run choice: Builder/homeowner or Mazdoor (worker).
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.handyman,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                t('appTitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(t('tagline'), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Text(
                t('iAm'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.business_outlined,
                title: t('builder'),
                subtitle: t('builderDesc'),
                selected: appState.pendingRole == 'builder',
                onTap: () => appState.setPendingRole('builder'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.construction_outlined,
                title: t('mazdoor'),
                subtitle: t('mazdoorDesc'),
                selected: appState.pendingRole == 'mazdoor',
                onTap: () => appState.setPendingRole('mazdoor'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/auth'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(t('continue')),
                ),
              ),
              const SizedBox(height: 16),
              // Quick language switch even before sign-in.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => appState.setLocale('en'),
                    child: Text(
                      'English',
                      style: TextStyle(
                        fontWeight: appState.locale == 'en'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const Text('|'),
                  TextButton(
                    onPressed: () => appState.setLocale('ur'),
                    child: Text(
                      'اردو',
                      style: TextStyle(
                        fontWeight: appState.locale == 'ur'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
