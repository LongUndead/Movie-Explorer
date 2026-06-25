import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final int id;
  String name;
  final String email;
  String phone;

  UserModel({required this.id, required this.name, required this.email, required this.phone});
}

class UserManager {
  static final UserManager instance = UserManager._internal();
  UserManager._internal();

  UserModel? currentUser;

  bool get isLoggedIn => currentUser != null;

  // Lưu thông tin khi gọi API Login thành công
  Future<void> saveUser(Map<String, dynamic> userData) async {
    currentUser = UserModel(
      id: userData['UserID'], // Tên cột phải khớp chính xác với kết quả SQL trả về
      name: userData['Username'] ?? '',
      email: userData['Email'] ?? '',
      phone: userData['Phone'] ?? '',
    );
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', currentUser!.id);
    await prefs.setString('userName', currentUser!.name);
    await prefs.setString('userEmail', currentUser!.email);
    await prefs.setString('userPhone', currentUser!.phone);
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
      );
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Xóa sạch dữ liệu
  }
}