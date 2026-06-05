import '../../domain/entities/cinema.dart';

class CinemaModel extends Cinema {
  CinemaModel({
    required super.id, 
    required super.brand, 
    required super.name, 
    required super.address,
    required super.rating,
    required super.latitude,
    required super.longitude,
  });

  factory CinemaModel.fromJson(Map<String, dynamic> json) {
    // =========================================================
    // ✅ 1. BẮT ĐÚNG CỘT brand_id MÀ BẠN ĐÃ SỬA TRONG MYSQL
    // =========================================================
    final rawBrand = json['brand_id'] ?? json['BrandID'] ?? json['brand']; 
    
    // =========================================================
    // ✅ 2. CHỐNG LỖI VIẾT HOA / VIẾT THƯỜNG (Name vs name)
    // =========================================================
    final rawId = json['id'] ?? json['ID'] ?? json['CinemaID'] ?? json['cinema_id'];
    final rawName = json['name'] ?? json['Name'] ?? json['cinema_name'];
    final rawAddress = json['address'] ?? json['Address'] ?? json['cinema_address'];
    final rawRating = json['rating'] ?? json['Rating']; 
    final rawLatitude = json['latitude'] ?? json['Latitude'];
    final rawLongitude = json['longitude'] ?? json['Longitude'];

    return CinemaModel(
      // Dùng ?.toString() ?? '' để chống lỗi truyền null vào hàm tryParse
      id: int.tryParse(rawId?.toString() ?? '') ?? 0, 
      
      // Nếu không có brand_id, mặc định lấy rạp số 1 (CGV)
      brand: rawBrand?.toString() ?? '1', 
      
      // ✅ Đổi chữ mặc định thành "Tên rạp lỗi" để bạn dễ phát hiện nếu CSDL bị sai cột
      name: rawName?.toString() ?? 'Tên rạp bị lỗi',
      address: rawAddress?.toString() ?? 'Địa chỉ bị lỗi',
      
      rating: double.tryParse(rawRating?.toString() ?? '') ?? 0.0,
      latitude: double.tryParse(rawLatitude?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(rawLongitude?.toString() ?? '') ?? 0.0,
    );
  }
}