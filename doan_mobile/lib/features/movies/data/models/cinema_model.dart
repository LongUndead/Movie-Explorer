import '../../domain/entities/cinema.dart';

class CinemaModel extends Cinema {
  CinemaModel({required super.id, required super.name, required super.address});

  factory CinemaModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['cinema_id'];
    final rawName = json['name'] ?? json['cinema_name'] ?? json['cinemaName'];
    final rawAddress = json['address'] ?? json['cinema_address'] ?? json['cinemaAddress'];

    return CinemaModel(
      id: int.parse(rawId.toString()),
      name: rawName?.toString() ?? '',
      address: rawAddress?.toString() ?? '',
    );
  }
}