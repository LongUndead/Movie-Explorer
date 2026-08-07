import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; 
import 'dart:convert'; 
import 'package:http/http.dart' as http; 

// 🚀 BỔ SUNG THƯ VIỆN BẮT DEEP LINK
import 'dart:async';
import 'package:app_links/app_links.dart';

import 'injection_container.dart' as di;
import 'features/movies/presentation/bloc/movie_bloc.dart'; 
import 'features/movies/presentation/pages/main_page.dart'; 
import 'features/movies/presentation/pages/user_manager.dart';
import 'features/movies/presentation/pages/login_screen.dart'; 
import 'features/movies/presentation/pages/cart_page.dart'; 

// 🚀 BỔ SUNG TRANG CHI TIẾT BÀI VIẾT ĐỂ NÓ BIẾT ĐƯỜNG MÀ BAY TỚI
import 'features/movies/presentation/pages/post_detail_page.dart'; 

// =======================================================
// 🚀 BƯỚC 3.1: KHAI BÁO CHÌA KHÓA CHUYỂN TRANG VẠN NĂNG
// Giúp app có thể tự chuyển trang mà không cần Context
// =======================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    CartManager.instance.systemHoldSeconds = 900; 
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init(); 
  
  // Lệnh này chạy trước để lôi dữ liệu từ bộ nhớ điện thoại ra
  await UserManager.instance.loadUser();
  
  // Gọi hàm cấu hình trước khi chạy App
  await fetchSystemSettings();
  
  runApp(const MyApp());
}

// =======================================================
// 🚀 BƯỚC 3.2: CHUYỂN MYAPP THÀNH STATEFUL WIDGET 
// Để có thể liên tục lắng nghe Link trong suốt vòng đời App
// =======================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); // 🚀 Bật máy nghe lén khi App vừa khởi động
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1️⃣ Trường hợp App đang TẮT HẲN, người dùng bấm link mở App lên
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleIncomingLink(initialUri);
    } catch (e) {
      debugPrint("Lỗi đọc link ban đầu: $e");
    }

    // 2️⃣ Trường hợp App đang CHẠY NGẦM, người dùng bấm link
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    }, onError: (err) {
      debugPrint("Lỗi stream link: $err");
    });
  }

  // 🚀 HÀM XỬ LÝ KHI BẮT ĐƯỢC LINK
  void _handleIncomingLink(Uri uri) async {
    debugPrint('🔗 BẮT ĐƯỢC DEEP LINK: $uri');
    
    // Kiểm tra xem link có đúng chuẩn: cinematickets://post/123 không
    if (uri.scheme == 'cinematickets' && uri.host == 'post') {
      String postId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      
      if (postId.isNotEmpty) {
        // Lấy ID User đang đăng nhập (để biết họ đã like bài chưa)
        final user = UserManager.instance.currentUser;
        String apiBaseUrl = 'http://192.168.1.7:3000'; 
        
        try {
          // Gọi API tải cục dữ liệu bài viết về
          final res = await http.get(Uri.parse('$apiBaseUrl/api/group/posts/$postId?user_id=${user?.id ?? 0}'));
          
          if (res.statusCode == 200) {
            var data = jsonDecode(res.body);
            Map<String, dynamic> postData = (data is List && data.isNotEmpty) ? data[0] : (data is Map ? data : {});
            
            if (postData.isNotEmpty) {
              // 🚀 PHÉP THUẬT NẰM Ở ĐÂY: Ép App tự động mở màn hình Chi tiết bài viết lên
              navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => PostDetailPage(post: postData))
              );
            }
          }
        } catch (e) {
          debugPrint("Lỗi lấy bài viết từ DeepLink: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

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
        navigatorKey: navigatorKey, // 🚀 BƯỚC 3.3: GẮN CHÌA KHÓA VÀO MATERIAL APP
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
        
        home: const MainPage(),
      ),
    );
  }
}