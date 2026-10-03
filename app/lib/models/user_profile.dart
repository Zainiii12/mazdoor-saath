import '../utils/dates.dart';

/// User profile — a builder/homeowner or a mazdoor (worker).
class UserProfile {
  final String id;
  final String phone;
  final String role; // 'builder' | 'mazdoor'
  final String name;
  final List<String> trades;
  final double ratingAvg;
  final int ratingCount;
  final double? lat;
  final double? lng;
  final bool isAvailable;
  final int yearsExperience;
  final String? city;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.phone,
    required this.role,
    required this.name,
    this.trades = const [],
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.lat,
    this.lng,
    this.isAvailable = true,
    this.yearsExperience = 0,
    this.city,
    this.createdAt,
  });

  bool get isBuilder => role == 'builder';
  bool get isMazdoor => role == 'mazdoor';
  bool get hasLocation => lat != null && lng != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    double? lat;
    double? lng;
    if (loc is Map) {
      final m = Map<String, dynamic>.from(loc);
      lat = (m['lat'] as num?)?.toDouble();
      lng = (m['lng'] as num?)?.toDouble();
    }
    return UserProfile(
      id: (json['id'] ?? json['uid'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? 'mazdoor').toString(),
      name: (json['name'] ?? '').toString(),
      trades: (json['trades'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      lat: lat,
      lng: lng,
      isAvailable:
          (json['isAvailable'] ?? json['availability']) as bool? ?? true,
      yearsExperience: (json['yearsExperience'] as num?)?.toInt() ?? 0,
      city: json['city']?.toString(),
      createdAt: json['createdAt'] != null
          ? parseApiDateTime(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'role': role,
        'name': name,
        'trades': trades,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        if (hasLocation) 'location': {'lat': lat, 'lng': lng},
        'isAvailable': isAvailable,
        'yearsExperience': yearsExperience,
        if (city != null) 'city': city,
      };
}
