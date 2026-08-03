import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cart_page.dart';

class UserModel {
  final int id;
  String name;
  final String email;
  String phone;
  String avatar; // 🚀 NÂNG CẤP: Bổ sung trường Avatar

  UserModel({
    required this.id, 
    required this.name, 
    required this.email, 
    required this.phone,
    required this.avatar, // 🚀 NÂNG CẤP
  });
}

class UserManager {
  static final UserManager instance = UserManager._internal();
  UserManager._internal();

  UserModel? currentUser;

  bool get isLoggedIn => currentUser != null;

  // Lưu thông tin khi gọi API Login thành công
  Future<void> saveUser(Map<String, dynamic> userData) async {
    currentUser = UserModel(
      id: userData['UserID'], 
      name: userData['Username'] ?? '',
      email: userData['Email'] ?? '',
      phone: userData['Phone'] ?? '',
      avatar: userData['Avatar'] ?? '', // 🚀 NÂNG CẤP: Bắt link Avatar từ DB
    );
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', currentUser!.id);
    await prefs.setString('userName', currentUser!.name);
    await prefs.setString('userEmail', currentUser!.email);
    await prefs.setString('userPhone', currentUser!.phone);
    await prefs.setString('userAvatar', currentUser!.avatar); // 🚀 NÂNG CẤP: Lưu vào bộ nhớ máy
  }

  // Khôi phục đăng nhập khi mở App
  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    if (id != null) {
      currentUser = UserModel(
        id: id,
        name: prefs.getString('userName') ?? '',
        email: prefs.getString('userEmail') ?? '',
        phone: prefs.getString('userPhone') ?? '',
        avatar: prefs.getString('userAvatar') ?? '', // 🚀 NÂNG CẤP: Tải từ bộ nhớ lên
      );
    }
  }

  // 🚀 HÀM MỚI: DÙNG ĐỂ CẬP NHẬT ẢNH SAU KHI SỬA PROFILE
  Future<void> updateAvatar(String newAvatarUrl) async {
    if (currentUser != null) {
      currentUser!.avatar = newAvatarUrl;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userAvatar', newAvatarUrl);
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    final user = currentUser;

    // ==============================================================
    // 🚀 BƯỚC XỬ LÝ NHẢ GHẾ (CHUẨN APP THỰC TẾ)
    // ==============================================================
    if (user != null && CartManager.instance.tickets.isNotEmpty) {
      for (var ticket in CartManager.instance.tickets) {
        for (var seat in ticket.selectedSeats) {
          try {
            await http.post(
              Uri.parse('http://192.168.1.7:3000/api/seats/release'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'userId': user.id,
                'showtimeId': ticket.showtimeId,
                'seatId': seat['id']
              })
            );
          } catch (e) {
            debugPrint("Lỗi giải phóng ghế khi đăng xuất: $e");
          }
        }
      }
    }
    // ==============================================================

    currentUser = null;
    
    // Dọn sạch giỏ hàng trên RAM điện thoại (tránh việc User 2 vô tình xài lại giỏ User 1)
    CartManager.instance.clearCart(); 
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Xóa sạch dữ liệu đăng nhập
  }
}