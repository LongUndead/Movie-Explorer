import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; 
import 'dart:convert'; // ✅ Bổ sung thư viện để parse JSON
import 'package:http/http.dart' as http; // ✅ Bổ sung thư viện gọi API

import 'injection_container.dart' as di;
import 'features/movies/presentation/bloc/movie_bloc.dart'; 
import 'features/movies/presentation/pages/main_page.dart'; 
import 'features/movies/presentation/pages/user_manager.dart';
import 'features/movies/presentation/pages/login_screen.dart'; 

// ✅ BƯỚC 1: IMPORT CART MANAGER VÀO ĐỂ GÁN CẤU HÌNH
import 'features/movies/presentation/pages/cart_page.dart'; // Sửa lại đường dẫn này nếu cần

Future<void> fetchSystemSettings() async {
  try {
    final response = await http.get(Uri.parse('http://192.168.1.7:3000/api/admin/settings'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      int holdTimeFromAdmin = (data['seatHoldMinutes'] ?? 15) * 60;
      
      // Gán vào CartManager để toàn bộ App xài chung
      CartManager.instance.systemHoldSeconds = holdTimeFromAdmin;

      CartManager.instance.holdSeconds = holdTimeFromAdmin;
      
      debugPrint("✅ Đã đồng bộ cấu hình từ Web Admin: $holdTimeFromAdmin giây");
    }
  } catch (e) {
    debugPrint("❌ Không lấy được cấu hình. Chạy chế độ offline: Mặc định 15 phút.");
    // ✅ SỬA Ở ĐÂY: Phải là systemHoldSeconds chứ không phải holdSeconds
    CartManager.instance.systemHoldSeconds = 900; 
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init(); 
  
  // Lệnh này chạy trước để lôi dữ liệu từ bộ nhớ điện thoại ra
  await UserManager.instance.loadUser();
  
  // ==========================================
  // ✅ BƯỚC 3: GỌI HÀM CẤU HÌNH TRƯỚC KHI CHẠY APP
  // ==========================================
  await fetchSystemSettings();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tông màu Xanh biển chủ đạo 
    final Color primaryBlue = Colors.blue.shade800;

    return MultiBlocProvider(
      providers: [
        BlocProvider<MovieBloc>(
          create: (context) => di.sl<MovieBloc>(), 
        ),
      ],
      child: MaterialApp(
        title: 'Movie Explorer',
        debugShowCheckedModeBanner: false, 
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryBlue,
            primary: primaryBlue,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
        ),
        
        home: UserManager.instance.isLoggedIn ? const MainPage() : const LoginScreen(),
        
      ),
    );
  }
}