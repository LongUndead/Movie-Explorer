import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; 
import 'injection_container.dart' as di;
import 'features/movies/presentation/bloc/movie_bloc.dart'; 
import 'features/movies/presentation/pages/main_page.dart'; 
import 'features/movies/presentation/pages/user_manager.dart';

// ✅ BƯỚC 1: NHỚ IMPORT FILE LOGIN SCREEN CỦA BẠN VÀO ĐÂY
import 'features/movies/presentation/pages/login_screen.dart'; // (Sửa lại đường dẫn này cho đúng với file của bạn)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init(); 
  
  // Lệnh này chạy trước để lôi dữ liệu từ bộ nhớ điện thoại ra
  await UserManager.instance.loadUser();
  
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
        
        // ==========================================
        // ✅ BƯỚC 2: SỬA DÒNG NÀY (KIỂM TRA ĐĂNG NHẬP TRƯỚC KHI VÀO)
        // ==========================================
        home: UserManager.instance.isLoggedIn ? const MainPage() : const LoginScreen(),
        
      ),
    );
  }
}