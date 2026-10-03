import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';

/// Global app state: signed-in profile, role, locale (en/ur), selected job.
class AppState extends ChangeNotifier {
  final ApiClient api;

  AppState({required this.api});

  UserProfile? _profile;
  String _locale = 'en';
  String _pendingRole = 'mazdoor';
  String? _selectedJobId;

  UserProfile? get profile => _profile;
  String get role => _profile?.role ?? _pendingRole;
  String get locale => _locale;
  String get pendingRole => _pendingRole;
  String? get selectedJobId => _selectedJobId;
  bool get isLoggedIn => _profile != null;

  /// Shortcut for localized strings in widgets:
  /// `context.watch<AppState>().t('postJob')`
  String t(String key) => AppStrings.get(key, _locale);

  String tradeName(String tradeEn) => AppStrings.tradeName(tradeEn, _locale);

  String statusLabel(String status) => AppStrings.statusLabel(status, _locale);

  void setPendingRole(String role) {
    _pendingRole = role;
    notifyListeners();
  }

  void setLocale(String locale) {
    if (locale != 'en' && locale != 'ur') return;
    _locale = locale;
    notifyListeners();
  }

  void selectJob(String? jobId) {
    _selectedJobId = jobId;
    notifyListeners();
  }

  /// GET /api/users/me — throws [ApiException] (404) when no profile exists.
  Future<void> loadProfile() async {
    final data = await api.get('/api/users/me');
    _profile = UserProfile.fromJson(_asMap(data));
    notifyListeners();
  }

  /// POST /api/users/profile — create or update the profile.
  /// Translates the setup-form map into the backend contract:
  /// {name, role, trades, yearsExperience, availability, lat, lng}.
  Future<void> saveProfile(Map<String, dynamic> body) async {
    final loc = body['location'];
    final lat = loc is Map ? (loc['lat'] as num?)?.toDouble() : null;
    final lng = loc is Map ? (loc['lng'] as num?)?.toDouble() : null;
    final profileBody = <String, dynamic>{
      'name': body['name'],
      'role': body['role'],
      'trades': body['trades'],
      'yearsExperience': body['yearsExperience'],
      'availability': body['isAvailable'],
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    final data = await api.post('/api/users/profile', profileBody);
    _profile = UserProfile.fromJson(_asMap(data));
    notifyListeners();
  }

  void clear() {
    _profile = null;
    _selectedJobId = null;
    notifyListeners();
  }

  static Map<String, dynamic> _asMap(dynamic data) =>
      Map<String, dynamic>.from(data as Map);
}
