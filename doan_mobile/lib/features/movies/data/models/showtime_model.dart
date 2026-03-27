import '../../domain/entities/showtime.dart';

class ShowtimeModel extends Showtime {
  ShowtimeModel({
    required int id,
    required DateTime startTime,
    required double price,
    required String roomName,
    required String cinemaName,
  }) : super(
          id: id,
          startTime: startTime,
          price: price,
          roomName: roomName,
          cinemaName: cinemaName,
        );

  factory ShowtimeModel.fromJson(Map<String, dynamic> json) {
    return ShowtimeModel(
      id: json['id'],
      // Chuyển chuỗi thời gian từ MySQL thành object DateTime trong Flutter
      startTime: DateTime.parse(json['start_time']), 
      // Ép kiểu an toàn cho giá tiền (vì MySQL có thể trả về string hoặc int)
      price: double.parse(json['price'].toString()),
      roomName: json['room_name'],
      cinemaName: json['cinema_name'],
    );
  }
}