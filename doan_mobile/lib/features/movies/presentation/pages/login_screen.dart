import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_manager.dart';
import 'main_page.dart';
import 'register_screen.dart';
import 'onboarding_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePass = true;

  String _supportEmail = "Đang tải...";
  
  final Color primaryBlue = const Color(0xFF1565C0); 

  @override
  void initState() {
    super.initState();
    _fetchContactInfo();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // 🚀 HÀM KÉO DATA CÓ GẮN MÁY CHỤP X-QUANG (PRINT)
  Future<void> _fetchContactInfo() async {
    try {
      print("🚀 Đang gọi API lấy Email liên hệ...");
      
      final res = await http.get(
        Uri.parse('http://192.168.1.7:3000/api/contact-info')
      ).timeout(const Duration(seconds: 5));

      print("🟢 Kết quả từ Server trả về: ${res.body}"); // In ra kết quả để xem App có nhận được không

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _supportEmail = data['supportEmail'] ?? "hotro@cinematickets.vn";
          });
          print("✅ Đã cập nhật giao diện thành công!");
        }
      }
    } catch (e) {
      print("❌ LỖI RỒI ÔNG ƠI: $e"); // Báo lỗi đỏ chót nếu mất mạng hoặc sai IP
      
      if (mounted) {
        setState(() => _supportEmail = "hotro@cinematickets.vn");
      }
    }
  }
  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ email và mật khẩu!'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('http://192.168.1.7:3000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text.trim(),
        })
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        await UserManager.instance.saveUser(data['user']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng nhập thành công!'), backgroundColor: Colors.green)
          );
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainPage()), (route) => false);
        }
      }
      else if (res.statusCode == 503) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hệ thống đang bảo trì, vui lòng quay lại sau!'), 
            backgroundColor: Colors.orange
          ));
        }
      }
      else {
        final errorData = json.decode(res.body);
        final errorMessage = errorData['error'] ?? 'Đăng nhập thất bại. Vui lòng thử lại!';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối máy chủ!'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () {
             Navigator.pushReplacement(
               context, 
               MaterialPageRoute(builder: (_) => const OnboardingScreen())
             );
          },
        ),
        // 🚀 THÊM NÚT TRANG CHỦ (VÀO THẲNG GUEST MODE) Ở GÓC PHẢI
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded, color: primaryBlue, size: 28),
            onPressed: () {
              // Bấm vào là nhảy thẳng vô MainPage (Trang chủ chính)
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => const MainPage()), 
                (route) => false
              );
            },
          ),
          const SizedBox(width: 8), // Canh lề nhẹ cho đẹp
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text("CINEMATICKETS", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text("Đăng Nhập", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 32)),
              const SizedBox(height: 40),

              _buildTextField(controller: _emailCtrl, label: "Email", hint: "vd: nguyenvana@gmail.com", keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 24),
              
              _buildPasswordField(controller: _passCtrl, label: "Mật khẩu", hint: "••••••••", isObscure: _obscurePass, onToggle: () => setState(() => _obscurePass = !_obscurePass)),
              const SizedBox(height: 16),

              // Nút quên mật khẩu
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())
                    );
                  },
                  child: Text("Quên mật khẩu?", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 40),

              // Nút đăng nhập
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("ĐĂNG NHẬP", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Chân trang chuyển sang đăng ký
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Chưa có tài khoản? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                    },
                    child: Text("ĐĂNG KÝ NGAY", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              
              // 🚀 FOOTER MỚI: Lấp đầy khoảng trống cực kỳ an toàn
              const SizedBox(height: 80),
              Center(
                child: Column(
                  children: [
                    Text("Cần hỗ trợ? Liên hệ CSKH", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 6),
                    // 🚀 SỬ DỤNG BIẾN ĐỘNG Ở ĐÂY
                    Text(_supportEmail, style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 40),
                    Text("Phiên bản 1.0.0", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget Tái sử dụng cho ô nhập liệu
  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 17),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryBlue, width: 2)),
      ),
    );
  }

  // Widget Tái sử dụng cho ô mật khẩu
  Widget _buildPasswordField({required TextEditingController controller, required String label, required String hint, required bool isObscure, required VoidCallback onToggle}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 17),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off, color: primaryBlue, size: 20), 
          onPressed: onToggle
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryBlue, width: 2)),
      ),
    );
  }
}