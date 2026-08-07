import 'package:flutter/material.dart';
import 'user_manager.dart';
import 'login_screen.dart'; // Import đúng đường dẫn file Login của sếp

class GuestGuard {
  /// Hàm kiểm tra: Nếu đã đăng nhập -> Cho đi tiếp. Nếu chưa -> Hiện Popup
  static void check(BuildContext context, VoidCallback onAllowed) {
    final user = UserManager.instance.currentUser;
    
    if (user != null) {
      // Đã đăng nhập, thực thi hành động bình thường
      onAllowed();
    } else {
      // Chưa đăng nhập (Khách tham quan) -> Bật Popup chặn lại
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon ổ khóa xịn xò
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50, 
                    shape: BoxShape.circle
                  ),
                  child: Icon(Icons.lock_person_rounded, size: 45, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 20),
                const Text("Yêu cầu đăng nhập", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                Text(
                  "Bạn cần đăng nhập để sử dụng tính năng này. Tham gia cùng chúng tôi ngay?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 28),
                // 2 Nút bấm (Hủy và Đăng nhập)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context), // Tắt Popup
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text("Không, cảm ơn", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Tắt popup trước
                          // Chuyển tới màn hình đăng nhập
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue.shade900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Đăng nhập", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}