import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // 🚀 Thêm thư viện để chạy đồng hồ đếm ngược

class ResetPasswordScreen extends StatefulWidget {
  final String email; 
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  final Color primaryBlue = const Color(0xFF1565C0);

  // 🚀 BIẾN CHO ĐỒNG HỒ ĐẾM NGƯỢC
  Timer? _timer;
  int _start = 300; // 300 giây = 5 phút

  @override
  void initState() {
    super.initState();
    startTimer(); // Vừa vào màn hình là kích hoạt đồng hồ luôn
  }

  @override
  void dispose() {
    _timer?.cancel(); // Hủy đồng hồ khi thoát màn hình để chống tràn RAM
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // 🚀 HÀM ĐẾM NGƯỢC
  void startTimer() {
    setState(() => _start = 300);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() { timer.cancel(); });
      } else {
        setState(() { _start--; });
      }
    });
  }

  // 🚀 HÀM GỬI LẠI MÃ OTP
  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      final res = await http.post(
        Uri.parse('http://192.168.1.7:3000/api/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': widget.email})
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lại mã OTP mới!'), backgroundColor: Colors.green));
          startTimer(); // Reset lại đồng hồ về 5 phút
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gửi lại mã, thử lại sau!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối máy chủ!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // HÀM XÁC NHẬN ĐỔI MẬT KHẨU
  Future<void> _resetPassword() async {
    final otp = _otpCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (otp.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin!'), backgroundColor: Colors.orange));
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu xác nhận không khớp!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('http://192.168.1.7:3000/api/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email, 
          'otp': otp,
          'newPassword': newPass
        })
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: Colors.green)
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        final data = json.decode(res.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Lỗi không xác định!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối máy chủ!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ép kiểu hiển thị phút:giây (VD: 04:59)
    String minutesStr = (_start ~/ 60).toString().padLeft(2, '0');
    String secondsStr = (_start % 60).toString().padLeft(2, '0');

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
            const SizedBox(height: 10),
            Text("CINEMATICKETS", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text("Tạo Mật Khẩu Mới", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 32)),
            const SizedBox(height: 16),
            
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
                children: [
                  const TextSpan(text: "Mã OTP 6 số đã được gửi tới email "),
                  TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 🚀 KHU VỰC NHẬP OTP VÀ ĐỒNG HỒ ĐẾM NGƯỢC
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildTextField(controller: _otpCtrl, label: "Mã OTP", hint: "Nhập 6 số", keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 16),
                
                // Đồng hồ đếm ngược hoặc Nút gửi lại
                _start > 0 
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text("$minutesStr:$secondsStr", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
                    )
                  : _isResending 
                      ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator())
                      : TextButton(
                          onPressed: _resendOtp,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Gửi lại mã", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                        ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildPasswordField(controller: _newPassCtrl, label: "Mật khẩu mới", hint: "••••••••", isObscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 24),

            _buildPasswordField(controller: _confirmPassCtrl, label: "Xác nhận mật khẩu", hint: "••••••••", isObscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                // Khóa nút nếu hết giờ OTP
                onPressed: (_isLoading || _start == 0) ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("CẬP NHẬT MẬT KHẨU", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          SizedBox(width: 8),
                          Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 6), // Style to bự cho OTP
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 16, letterSpacing: 0),
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