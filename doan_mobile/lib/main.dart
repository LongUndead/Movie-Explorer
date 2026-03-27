import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // BẮT BUỘC THÊM: Để xài BlocProvider
import 'injection_container.dart' as di;
import 'features/movies/presentation/bloc/movie_bloc.dart'; // BẮT BUỘC THÊM: Import MovieBloc
import 'features/movies/presentation/pages/main_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tông màu Xanh biển chủ đạo 
    final Color primaryBlue = Colors.blue.shade800;

    // BỌC MULTIBLOCPROVIDER Ở ĐÂY ĐỂ TRỊ TẬN GỐC LỖI MÀN HÌNH ĐỎ
    return MultiBlocProvider(
      providers: [
        BlocProvider<MovieBloc>(
          create: (context) => di.sl<MovieBloc>(), // Khởi tạo MovieBloc dùng chung cho toàn App
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
        // ĐẶT MAIN PAGE LÀM TRANG CHỦ ĐỂ CÓ MENU DƯỚI
        home: const MainPage(),
      ),
    );
  }
}