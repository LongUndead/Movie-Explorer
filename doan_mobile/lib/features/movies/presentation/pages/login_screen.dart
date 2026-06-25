import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_manager.dart';
import 'main_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('http://192.168.1.2:3000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text.trim(),
        })
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        
        // 1. Lưu user vào kho toàn cục
        await UserManager.instance.saveUser(data['user']);
        
        // 2. Nhảy sang trang Chủ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng nhập thành công!'), backgroundColor: Colors.green)
          );
          
          // ✅ ĐÃ SỬA: Lệnh chuyển thẳng sang trang chủ MainPage
          // Dùng pushAndRemoveUntil để xóa sạch lịch sử, khách không thể bấm nút Back quay lại trang Login được nữa!
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const MainPage()),
            (route) => false, 
          );
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sai email hoặc mật khẩu!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("Đăng nhập", style: TextStyle(color: navyBlue)), backgroundColor: Colors.white, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            TextField(controller: _passCtrl, obscureText: true, decoration: InputDecoration(labelText: "Mật khẩu", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Đăng nhập", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}