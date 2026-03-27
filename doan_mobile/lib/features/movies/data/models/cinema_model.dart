import '../../domain/entities/cinema.dart';

class CinemaModel extends Cinema {
  CinemaModel({required super.id, required super.name, required super.address});

  factory CinemaModel.fromJson(Map<String, dynamic> json) {
    return CinemaModel(
      id: int.parse(json['id'].toString()),
      name: json['name'],
      address: json['address'],
    );
  }
}