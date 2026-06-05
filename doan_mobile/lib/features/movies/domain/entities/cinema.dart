class Cinema {
  final int id;
  final String brand;
  final String name;
  final String address;
  final double rating;
  final double latitude;
  final double longitude;

  Cinema({
    required this.id,
    required this.brand,
    required this.name,
    required this.address,
    required this.rating,
    required this.latitude,
    required this.longitude,
    
  });

  // Ánh xạ dữ liệu từ API/Database sang Object
  factory Cinema.fromJson(Map<String, dynamic> json) {
    return Cinema(
      id: json['id'] ?? 0,
      brand: json['brand'] ?? 'BHD',
      name: json['name'] ?? 'Đang cập nhật',
      address: json['address'] ?? 'Đang cập nhật',
      rating: double.tryParse(json['rating'].toString()) ?? 0.0,
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}