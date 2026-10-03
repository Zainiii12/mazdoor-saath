import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/job.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';
import '../../widgets/section_title.dart';
import '../../widgets/urdu_mic_button.dart';

class _TradeRow {
  String trade = 'Mason';
  int count = 2;
  double wage = 1500;
}

/// Builder posts a job: title, description (with Urdu voice input), site
/// location on an OpenStreetMap picker, dates, and per-trade team rows.
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _mapController = MapController();
  final _location = LocationService();

  final List<_TradeRow> _rows = [_TradeRow()];
  LatLng? _siteLatLng;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prefill the city from the builder's profile when available.
    _cityCtrl.text = context.read<AppState>().profile?.city ?? '';
    _centerOnMe();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _siteCtrl.dispose();
    _cityCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _centerOnMe() async {
    try {
      final pos = await _location.currentPosition();
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _siteLatLng = ll);
      _mapController.move(ll, 14);
    } catch (_) {
      // Keep the default (Lahore) center.
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final t = appState.t;
    if (_titleCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _siteLatLng == null ||
        _rows.isEmpty) {
      setState(() => _error = t('required'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // expectedDays defaults to the chosen date range, or 7 days.
      int expectedDays = 7;
      if (_startDate != null && _endDate != null) {
        final diff = _endDate!.difference(_startDate!).inDays;
        expectedDays = diff > 0 ? diff : 7;
      }
      final job = Job(
        id: '',
        builderId: appState.profile?.id ?? '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        siteLat: _siteLatLng!.latitude,
        siteLng: _siteLatLng!.longitude,
        trades: _rows
            .map((r) => TradeRequirement(
                trade: r.trade, count: r.count, dailyWage: r.wage))
            .toList(),
        startDate: _startDate,
        expectedDays: expectedDays,
      );
      final data = await appState.api.post('/api/jobs', job.toJson());
      final created = Job.fromJson(Map<String, dynamic>.from(data as Map));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('jobPosted'))));
      Navigator.pushReplacementNamed(
        context,
        '/builder/job',
        arguments: {'jobId': created.id},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;
    final dateFmt = DateFormat.yMMMd(appState.locale == 'ur' ? 'ur' : 'en');

    return Scaffold(
      appBar: AppBar(title: Text(t('postJob'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: t('jobTitle'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: t('jobDesc'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              UrduMicButton(
                hint: t('micHint'),
                onResult: (text) {
                  final cur = _descCtrl.text;
                  _descCtrl.text = cur.isEmpty ? text : '$cur $text';
                },
              ),
            ],
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t('speakDescription'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _siteCtrl,
            decoration: InputDecoration(
              labelText: t('siteName'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityCtrl,
            decoration: InputDecoration(
              labelText: t('city'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(t('tapToSetLocation'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _siteLatLng ?? const LatLng(31.5204, 74.3587),
                  initialZoom: 13,
                  onTap: (_, latlng) => setState(() => _siteLatLng = latlng),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.mazdoor_sathi',
                  ),
                  if (_siteLatLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _siteLatLng!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_startDate == null
                      ? t('startDate')
                      : dateFmt.format(_startDate!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_endDate == null
                      ? t('endDate')
                      : dateFmt.format(_endDate!)),
                ),
              ),
            ],
          ),
          SectionTitle(text: t('requiredTeam')),
          ..._rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: row.trade,
                            decoration: InputDecoration(
                              labelText: t('myTrades'),
                              border: const OutlineInputBorder(),
                            ),
                            items: AppStrings.trades
                                .map((tr) => DropdownMenuItem(
                                      value: tr['en'],
                                      child: Text(AppStrings.tradeName(
                                          tr['en']!, appState.locale)),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => row.trade = v ?? row.trade),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _rows.length > 1
                              ? () => setState(() => _rows.removeAt(i))
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text('${t('workers')}: ${row.count}'),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: row.count > 1
                                    ? () => setState(() => row.count--)
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => setState(() => row.count++),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: row.wage.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: t('dailyWage'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) =>
                                row.wage = double.tryParse(v) ?? row.wage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _rows.add(_TradeRow())),
            icon: const Icon(Icons.add),
            label: Text(t('addTrade')),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t('submitJob')),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
