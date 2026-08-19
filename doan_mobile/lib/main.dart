import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; 
import 'dart:convert'; 
import 'package:http/http.dart' as http; 

// 🚀 BỔ SUNG THƯ VIỆN BẮT DEEP LINK
import 'dart:async';
import 'package:app_links/app_links.dart';

// 🚀 THÊM THƯ VIỆN SOCKET BẮT LỆNH TỪ ADMIN
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'injection_container.dart' as di;
import 'features/movies/presentation/bloc/movie_bloc.dart'; 
import 'features/movies/presentation/pages/main_page.dart'; 
import 'features/movies/presentation/pages/user_manager.dart';
import 'features/movies/presentation/pages/login_screen.dart'; 
import 'features/movies/presentation/pages/cart_page.dart'; 
import 'features/movies/presentation/pages/post_detail_page.dart'; 

// =======================================================
// 🚀 KHAI BÁO CHÌA KHÓA CHUYỂN TRANG VẠN NĂNG
// =======================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> fetchSystemSettings() async {
  try {
    final response = await http.get(Uri.parse('http://10.173.120.41:3000/api/admin/settings'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      int holdTimeFromAdmin = (data['seatHoldMinutes'] ?? 15) * 60;
      
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
  
  await UserManager.instance.loadUser();
  await fetchSystemSettings();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  
  // 🚀 BIẾN LƯU TRỮ SOCKET ĐỂ LẮNG NGHE BẢO TRÌ
  late IO.Socket socket;
  bool _isMaintenancePopupShowing = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); 
    _initSocket(); // 🚀 Bật máy nghe lén Socket ngay khi mở App
  }

  // ==========================================
  // 🚀 HỆ THỐNG LẮNG NGHE LỆNH TỪ ADMIN (SOCKET CHUẨN MỚI)
  // ==========================================
  void _initSocket() {
    // 1. Khai báo theo chuẩn mới nhất của socket_io_client
    socket = IO.io('http://10.173.120.41:3000', IO.OptionBuilder()
        .setTransports(['websocket']) // Bắt buộc dùng websocket
        .enableAutoConnect() // Tự động kết nối lại nếu rớt mạng
        .build());

    // 2. Ép nó phải cắm cáp kết nối ngay lập tức
    socket.connect();

    // 3. 🟢 MÁY ĐO NHỊP TIM: Báo lên Console nếu kết nối thành công
    socket.onConnect((_) {
      debugPrint('🟢 [SOCKET] BINGO! App đã kết nối thành công với Máy chủ!');
    });

    // 🔴 Báo lên Console nếu rớt mạng / lỗi
    socket.onConnectError((err) {
      debugPrint('🔴 [SOCKET] Lỗi kết nối: $err');
    });

    // 4. LẮNG NGHE LỆNH TỪ ADMIN
    socket.on('system_maintenance', (data) {
      debugPrint('📥 [SOCKET] BẮT ĐƯỢC LỆNH TỪ ADMIN: $data');

      if (data['status'] == 'MAINTENANCE_ON') {
        String msg = data['message'] ?? 'Hệ thống đang bảo trì định kỳ. Vui lòng quay lại sau!';
        if (data['endTime'] != null && data['endTime'].toString().isNotEmpty) {
           msg += '\n\nDự kiến kết thúc: ${data['endTime']}';
        }

        // 🚀 ÉP BUNG POPUP TRÊN LUỒNG CHÍNH (Tránh lỗi đơ UI của Flutter)
        Future.microtask(() {
          final context = navigatorKey.currentState?.overlay?.context ?? navigatorKey.currentContext;

          if (context != null && !_isMaintenancePopupShowing) {
            _isMaintenancePopupShowing = true;
            CartManager.instance.clearCart(); 

            showDialog(
              context: context,
              barrierDismissible: false, // Cấm bấm ra ngoài
              builder: (BuildContext ctx) {
                return WillPopScope(
                  onWillPop: () async => false, // Cấm nút Back điện thoại
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                        SizedBox(width: 10),
                        Text("Hệ thống bảo trì", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    content: Text(msg, style: const TextStyle(fontSize: 15, height: 1.5)),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () {
                          _isMaintenancePopupShowing = false;
                          // Đẩy về trang đăng nhập
                          navigatorKey.currentState?.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const LoginScreen()), 
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            );
          } else {
             debugPrint('🔴 LỖI UI: Không tìm thấy bề mặt Context để bung Popup!');
          }
        });
      } else if (data['status'] == 'MAINTENANCE_OFF') {
        Future.microtask(() {
          final context = navigatorKey.currentState?.overlay?.context ?? navigatorKey.currentContext;
          if (_isMaintenancePopupShowing && context != null) {
            Navigator.of(context).pop();
            _isMaintenancePopupShowing = false;
          }
        });
      }
    });
  }

  // ==========================================
  // HỆ THỐNG DEEP LINK (GIỮ NGUYÊN CỦA SẾP)
  // ==========================================
  void _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleIncomingLink(initialUri);
    } catch (e) {
      debugPrint("Lỗi đọc link ban đầu: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    }, onError: (err) {
      debugPrint("Lỗi stream link: $err");
    });
  }

  void _handleIncomingLink(Uri uri) async {
    debugPrint('🔗 BẮT ĐƯỢC DEEP LINK: $uri');
    
    if (uri.scheme == 'cinematickets' && uri.host == 'post') {
      String postId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      
      if (postId.isNotEmpty) {
        final user = UserManager.instance.currentUser;
        String apiBaseUrl = 'http://10.173.120.41:3000'; 
        
        try {
          final res = await http.get(Uri.parse('$apiBaseUrl/api/group/posts/$postId?user_id=${user?.id ?? 0}'));
          
          if (res.statusCode == 200) {
            var data = jsonDecode(res.body);
            Map<String, dynamic> postData = (data is List && data.isNotEmpty) ? data[0] : (data is Map ? data : {});
            
            if (postData.isNotEmpty) {
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
    socket.dispose(); // Đóng socket khi tắt App
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = Colors.blue.shade800;

    return MultiBlocProvider(
      providers: [
        BlocProvider<MovieBloc>(
          create: (context) => di.sl<MovieBloc>(), 
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, 
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