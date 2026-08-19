import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'verify_register_screen.dart'; // 🚀 Import màn hình xác thực sắp tạo

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false; 

  final Color primaryBlue = const Color(0xFF1565C0); 

  bool _isStrongPassword(String pass) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$');
    return regex.hasMatch(pass);
  }

  // 🚀 ĐÃ SỬA HÀM NÀY: Chỉ gọi API gửi OTP, chưa tạo tài khoản vội!
  Future<void> _register() async {
    String name = _nameCtrl.text.trim();
    String email = _emailCtrl.text.trim();
    String phone = _phoneCtrl.text.trim();
    String pass = _passCtrl.text.trim();
    String confirmPass = _confirmPassCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirmPass.isEmpty) {
      _showError('Vui lòng điền đầy đủ thông tin bắt buộc (*)');
      return;
    }
    if (pass != confirmPass) {
      _showError('Mật khẩu xác nhận không trùng khớp!');
      return;
    }
    if (!_isStrongPassword(pass)) {
      _showError('Mật khẩu yếu! Cần từ 8 ký tự, gồm chữ Hoa, thường, số và ký tự đặc biệt.');
      return;
    }
    if (!_agreedToTerms) {
      _showError('Vui lòng đồng ý với Điều khoản & Chính sách bảo mật!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 Gọi API gửi mã xác thực
      final res = await http.post(
        Uri.parse('http://10.173.120.41:3000/api/send-register-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email})
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi mã xác nhận đến Email!'), backgroundColor: Colors.green));
          
          // 🚀 Chuyển sang màn hình nhập OTP, mang theo toàn bộ thông tin khách vừa điền
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyRegisterScreen(
                name: name,
                email: email,
                phone: phone,
                password: pass,
              ),
            ),
          );
        }
      } else {
        final data = json.decode(res.body);
        _showError(data['error'] ?? 'Email không hợp lệ hoặc đã tồn tại!');
      }
    } catch (e) {
      _showError('Lỗi kết nối máy chủ!');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ... (TOÀN BỘ PHẦN giao diện Widget build Ở DƯỚI ÔNG GIỮ NGUYÊN Y CHANG FILE CŨ, KHÔNG THAY ĐỔI GÌ CẢ NHÉ!)
  // Do giới hạn ký tự nên tui không chép lại khúc giao diện ở đây, ông cứ giữ lại khúc dưới là ok!
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text("CINEMATICKETS", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text("Đăng Ký", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 32)),
            const SizedBox(height: 32),

            _buildTextField(controller: _nameCtrl, label: "Họ và tên", hint: "vd: Nguyễn Văn A"),
            const SizedBox(height: 20),
            
            _buildTextField(controller: _emailCtrl, label: "Email", hint: "vd: nguyenvana@gmail.com", keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),

            _buildTextField(controller: _phoneCtrl, label: "Số điện thoại (Tùy chọn)", hint: "vd: 0901234567", keyboardType: TextInputType.phone),
            const SizedBox(height: 20),

            _buildPasswordField(controller: _passCtrl, label: "Mật khẩu", hint: "••••••••", isObscure: _obscurePass, onToggle: () => setState(() => _obscurePass = !_obscurePass)),
            const SizedBox(height: 20),

            _buildPasswordField(controller: _confirmPassCtrl, label: "Xác nhận mật khẩu", hint: "••••••••", isObscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 24),

            // Checkbox điều khoản
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToTerms,
                    activeColor: primaryBlue,
                    onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text("Tôi đồng ý với các Điều khoản Dịch vụ và Chính sách Bảo mật.", style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Nút bấm
            SizedBox(
              width: double.infinity, 
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
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
                          Text("ĐĂNG KÝ TÀI KHOẢN", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Chân trang
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Đã có tài khoản? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text("ĐĂNG NHẬP", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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