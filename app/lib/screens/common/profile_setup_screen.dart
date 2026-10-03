import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';

/// First-time profile form. Mazdoors pick trades, experience and availability;
/// everyone can attach their current location for proximity matching.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _location = LocationService();
  final Set<String> _trades = {};
  double _experience = 2;
  bool _available = true;
  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final pos = await _location.currentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final appState = context.read<AppState>();
    final t = appState.t;
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = t('required'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await appState.saveProfile({
        'role': appState.pendingRole,
        'name': _nameCtrl.text.trim(),
        'trades': _trades.toList(),
        'yearsExperience': _experience.round(),
        'isAvailable': _available,
        if (_lat != null && _lng != null)
          'location': {'lat': _lat, 'lng': _lng},
      });
      if (!mounted) return;
      if (appState.profile!.isBuilder) {
        Navigator.pushReplacementNamed(context, '/builder/home');
      } else {
        Navigator.pushReplacementNamed(context, '/mazdoor/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;
    final isMazdoor = appState.pendingRole == 'mazdoor';

    return Scaffold(
      appBar: AppBar(title: Text(t('setupTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: t('nameHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          if (isMazdoor) ...[
            const SizedBox(height: 20),
            Text(t('myTrades'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: AppStrings.trades.map((trade) {
                final en = trade['en']!;
                final selected = _trades.contains(en);
                return FilterChip(
                  label: Text(AppStrings.tradeName(en, appState.locale)),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _trades.add(en);
                    } else {
                      _trades.remove(en);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(t('experience'))),
                Text('${_experience.round()} ${t('yrs')}'),
              ],
            ),
            Slider(
              value: _experience,
              min: 0,
              max: 30,
              divisions: 30,
              label: '${_experience.round()}',
              onChanged: (v) => setState(() => _experience = v),
            ),
            SwitchListTile(
              title: Text(t('available')),
              value: _available,
              onChanged: (v) => setState(() => _available = v),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(_lat == null
                ? t('useMyLocation')
                : '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t('saveProfile')),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
