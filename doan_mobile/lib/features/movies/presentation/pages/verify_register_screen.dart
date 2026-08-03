import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class VerifyRegisterScreen extends StatefulWidget {
  // Nhận toàn bộ data từ màn hình Đăng ký truyền sang
  final String name;
  final String email;
  final String phone;
  final String password;

  const VerifyRegisterScreen({
    super.key, 
    required this.name, 
    required this.email, 
    required this.phone, 
    required this.password
  });

  @override
  State<VerifyRegisterScreen> createState() => _VerifyRegisterScreenState();
}

class _VerifyRegisterScreenState extends State<VerifyRegisterScreen> {
  final _otpCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  final Color primaryBlue = const Color(0xFF1565C0);

  Timer? _timer;
  int _start = 300; // 5 phút

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

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

  // 🚀 HÀM GỬI LẠI OTP ĐĂNG KÝ
  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      final res = await http.post(
        Uri.parse('http://192.168.1.7:3000/api/send-register-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': widget.email})
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lại mã xác nhận mới!'), backgroundColor: Colors.green));
          startTimer();
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

  // 🚀 HÀM CHỐT ĐĂNG KÝ
  Future<void> _confirmRegister() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập mã OTP!'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Gọi API Đăng ký và ném toàn bộ dữ liệu + OTP lên
      final res = await http.post(
        Uri.parse('http://192.168.1.7:3000/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': widget.name,
          'email': widget.email,
          'phone': widget.phone,
          'password': widget.password,
          'otp': otp
        })
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tạo tài khoản thành công! Vui lòng đăng nhập.'), backgroundColor: Colors.green)
          );
          // Đá về màn hình Login (xóa sạch lịch sử)
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        final data = json.decode(res.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Mã xác nhận sai!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối máy chủ!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text("Xác Thực Email", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 32)),
            const SizedBox(height: 16),
            
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
                children: [
                  const TextSpan(text: "Mã OTP 6 số đã được gửi tới email "),
                  TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  const TextSpan(text: " để hoàn tất đăng ký."),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 6),
                    decoration: InputDecoration(
                      labelText: "Mã OTP",
                      hintText: "Nhập 6 số",
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0),
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 16, letterSpacing: 0),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryBlue, width: 2)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
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
            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: (_isLoading || _start == 0) ? null : _confirmRegister,
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
                          Text("HOÀN TẤT ĐĂNG KÝ", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
}