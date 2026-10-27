class WasteBank {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String openingHours;
  final List<String> acceptedMaterials;
  final String? phoneNumber;
  final double rating;
  final int totalReviews;

  const WasteBank({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.acceptedMaterials,
    this.phoneNumber,
    this.rating = 4.8,
    this.totalReviews = 42,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'opening_hours': openingHours,
      'accepted_materials': acceptedMaterials.join(','),
      'phone_number': phoneNumber,
      'rating': rating,
      'total_reviews': totalReviews,
    };
  }

  factory WasteBank.fromMap(Map<String, dynamic> map) {
    final rawMaterials = map['accepted_materials'];
    List<String> materials = [];
    if (rawMaterials is List) {
      materials = rawMaterials.map((e) => e.toString()).toList();
    } else if (rawMaterials is String) {
      materials = rawMaterials.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return WasteBank(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Bank Sampah',
      address: map['address']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      openingHours: map['opening_hours']?.toString() ?? '08:00 - 16:00',
      acceptedMaterials: materials.isNotEmpty ? materials : ['Plastik', 'Kertas', 'Kardus'],
      phoneNumber: map['phone_number']?.toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 4.7,
      totalReviews: (map['total_reviews'] as num?)?.toInt() ?? 25,
    );
  }
}
