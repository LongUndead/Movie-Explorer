import 'package:flutter/material.dart';
import 'dart:async'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';

import '../../domain/entities/movie.dart';
import '../../../movies/presentation/widgets/scroll_to_top_wrapper.dart';
import '../../domain/entities/cinema.dart';
import '../../domain/repositories/movie_repository.dart';
import '../../../../injection_container.dart';
import 'movie_detail_page.dart';
import 'all_movies_page.dart';
import 'user_manager.dart';
import 'login_screen.dart';
import 'ai_chat_screen.dart'; 
import 'search_page.dart';
import 'guest_guard.dart';

// ✅ IMPORT FILE VOUCHER VỪA TẠO
import 'voucher_list_screen.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<Movie>>? _futureMovies;
  final Color navyBlue = Colors.blue.shade900;

  PageController? _featuredPageController;
  Timer? _featuredTimer;
  int _currentFeaturedPage = 1000; 
  List<Movie> _featuredMoviesList = [];

  Timer? _banCheckTimer;
  bool _isBannedAlertShown = false;

  PageController? _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  final List<String> _bannerImages = [
    'assets/banner-1.png',
    'assets/banner-2.png',
    'assets/banner-3.png',
  ];

  // ==========================================
  // ✅ THÊM BIẾN LƯU TRỮ VOUCHER
  // ==========================================
  List<dynamic> _vouchers = [];
  bool _isLoadingVouchers = true;
  final String apiBaseUrl = 'http://10.173.120.41:3000'; // NHỚ ĐỔI ĐÚNG IP

  @override
  void initState() {
    super.initState();
    
    _checkAccountStatus(); // Quét 1 lần ngay khi vừa mở App
    
    // 🚀 THIẾT LẬP ĐỒNG BỘ REAL-TIME: Cứ 10 giây quét ngầm 1 lần
    _banCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkAccountStatus();
    });

    _loadData();
    _loadVouchers(); 
    _featuredPageController = PageController(viewportFraction: 0.72, initialPage: _currentFeaturedPage);
    _setupAutoScroll();

    _bannerPageController = PageController(initialPage: 0);
    _setupBannerAutoScroll(); 
  }

  // =========================================================
  // 🚀 HÀM QUÉT TRẠNG THÁI KHÓA TÀI KHOẢN (ĐÃ NÂNG CẤP BẮT LỖI)
  // =========================================================
  Future<void> _checkAccountStatus() async {
    if (_isBannedAlertShown) return; 

    final user = UserManager.instance.currentUser;
    if (user == null) return;

    try {
      // 🚀 1. GẮN MẮT THẦN: In ra Console để xem Link gọi API có đúng không
      final String url = '$apiBaseUrl/api/admin/users/${user.id}/check-status';
      // MẸO: Nếu Terminal báo lỗi 404, ông thử đổi chữ 'api/users/' thành 'api/admin/users/' nhé!
      // final String url = '$apiBaseUrl/api/admin/users/${user.id}/check-status';
      
      debugPrint('🔍 [AUTO-BAN] Đang quét trạng thái tại: $url');

      final res = await http.get(Uri.parse(url));
      
      // 🚀 2. IN KẾT QUẢ ĐỂ BẮT BỆNH
      debugPrint('🔍 [AUTO-BAN] Kết quả Server trả về: Mã ${res.statusCode} | Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        
        // 🚀 3. ÉP KIỂU TUYỆT ĐỐI: Bắt trọn mọi thể loại (Boolean, Int, String)
        bool isLocked = data['isLocked'] == true || 
                        data['isLocked'] == 1 || 
                        data['isLocked'] == '1' || 
                        data['isLocked'] == 'true';

        if (isLocked) {
          _isBannedAlertShown = true; 
          _banCheckTimer?.cancel();   

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false, 
              builder: (_) => PopScope(
                canPop: false, 
                child: Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                          child: Icon(Icons.lock_person_rounded, color: Colors.red.shade500, size: 40),
                        ),
                        const SizedBox(height: 20),
                        const Text("Tài khoản bị khóa", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),
                        Text(
                          "Tài khoản của bạn đã bị vô hiệu hóa do lạm dụng tính năng hoàn vé vượt mức quy định.\n\nVui lòng liên hệ CSKH để được hỗ trợ.", 
                          textAlign: TextAlign.center, 
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4)
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              await UserManager.instance.logout();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context, 
                                  MaterialPageRoute(builder: (_) => const LoginScreen()), 
                                  (route) => false
                                );
                              }
                            },
                            child: const Text("Đăng xuất ngay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }
      } else {
        // BÁO LỖI NẾU SAI ĐƯỜNG DẪN API
        debugPrint('❌ [AUTO-BAN] THẤT BẠI: Server trả về lỗi ${res.statusCode}. Khả năng cao sai đường dẫn URL!');
      }
    } catch (e) {
      debugPrint("❌ [AUTO-BAN] Lỗi mạng hoặc Server sập: $e");
    }
  }
  
  void _loadData() {
    _futureMovies = sl<MovieRepository>().getPopularMovies();
  }

// ✅ HÀM LẤY VOUCHER TỪ BACKEND (100% DỮ LIỆU THẬT + BẢO VỆ 503)
  Future<void> _loadVouchers() async {
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/vouchers'));

      // =========================================================
      // 🚀 1. KIỂM TRA LỖI 503 BẢO TRÌ VÀ ĐÁ VĂNG NGAY LẬP TỨC
      // =========================================================
      if (res.statusCode == 503) {
         await UserManager.instance.logout(); // Xóa sạch phiên đăng nhập
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hệ thống đang bảo trì. Bạn đã bị đăng xuất!'), backgroundColor: Colors.red)
           );
           // Đá văng ra màn Login và xóa sạch lịch sử trang
           Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => const LoginScreen()), 
              (route) => false
           );
         }
         return; // 🛑 Dừng lại ngay, không chạy xuống dưới nữa!
      }

      // =========================================================
      // 2. NẾU BÌNH THƯỜNG THÌ CHẠY TIẾP CODE CŨ
      // =========================================================
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _vouchers = json.decode(res.body);
            _isLoadingVouchers = false;
          });
        }
      } else {
        throw Exception('Lỗi Server: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint("Lỗi tải Voucher: $e");
      if (mounted) {
        setState(() {
          // XÓA DỮ LIỆU GIẢ. Nếu lỗi thì cho danh sách rỗng để ẩn Box Voucher đi.
          _vouchers = []; 
          _isLoadingVouchers = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadData(); 
      _loadVouchers(); 
    });
    await _futureMovies; 
  }

  void _setupAutoScroll() {
    _featuredTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_featuredPageController != null && _featuredPageController!.hasClients && _featuredMoviesList.isNotEmpty) {
        _featuredPageController!.nextPage(
          duration: const Duration(milliseconds: 600), 
          curve: Curves.easeInOut, 
        );
      }
    });
  }

  void _setupBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bannerPageController != null && _bannerPageController!.hasClients) {
        int nextPage = _currentBannerIndex + 1;
        if (nextPage >= _bannerImages.length) {
          _bannerPageController!.jumpToPage(0);
        } else {
          _bannerPageController!.jumpToPage(nextPage);
        }
      }
    });
  }

  @override
  void dispose() {
    _banCheckTimer?.cancel(); // 🚀 Hủy vòng lặp khi thoát trang để tiết kiệm RAM
    _featuredTimer?.cancel();
    _featuredPageController?.dispose();
    _bannerTimer?.cancel();
    _bannerPageController?.dispose();
    super.dispose();
  }

  // 🚀 BỌC THÉP VÀ LỌC RÁC TỪ DATABASE (CHẶN SỐ -1 HOẶC CHỮ NULL)
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == '-1' || dateStr.toLowerCase() == 'null') {
      return null; 
    }

    try {
      // 🚀 ĐÃ FIX TẬN GỐC: ÉP CỨNG MÚI GIỜ VIỆT NAM (GMT+7)
      // Dùng .toUtc() rồi cộng 7 tiếng. Kệ xác máy ảo điện thoại của sếp đang xài giờ Mỹ hay giờ Châu Phi!
      return DateTime.parse(dateStr).toUtc().add(const Duration(hours: 7));
    } catch (_) {
      try {
        // Backup: Cắt rác trường hợp lỗi định dạng
        String cleanDate = dateStr.split(' ')[0].split('T')[0].trim();
        if (cleanDate.contains('/')) {
          final parts = cleanDate.split('/');
          if (parts.length == 3) {
            return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } else {
          return DateTime.parse(cleanDate).toUtc().add(const Duration(hours: 7));
        }
      } catch (e) {
        return null;
      }
      return null;
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_futureMovies == null) {
      return Center(child: CircularProgressIndicator(color: navyBlue));
    }

    return FutureBuilder<List<Movie>>(
      future: _futureMovies!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: navyBlue));
        if (snapshot.hasError) return const Center(child: Text("Lỗi tải dữ liệu."));
        
        final List<Movie> allMovies = snapshot.data ?? [];
        if (allMovies.isEmpty) return const Center(child: Text("Không có phim"));

        final DateTime now = DateTime.now();

        List<Movie> topFeatured = allMovies.where((m) {
          final date = _parseDate(m.releaseDate);
          if (date == null) return false;
          return date.year >= 2024 && (date.isBefore(now) || date.isAtSameMomentAs(now));
        }).toList();
        topFeatured.sort((a, b) => (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0));
        _featuredMoviesList = topFeatured.take(5).toList();

        List<Movie> nowShowing = allMovies.where((m) {
          final date = _parseDate(m.releaseDate);
          if (date == null) return true; 
          return date.isBefore(now) || date.isAtSameMomentAs(now);
        }).toList();
        
        nowShowing.sort((a, b) {
          final dateA = _parseDate(a.releaseDate) ?? DateTime(1970);
          final dateB = _parseDate(b.releaseDate) ?? DateTime(1970);
          return dateB.compareTo(dateA); 
        });

        List<Movie> vietnameseMovies = allMovies.where((m) {
          final lang = m.language?.toLowerCase() ?? '';
          // 🚀 ĐÃ FIX: Có chữ 'việt' nhưng PHẢI LOẠI TRỪ phim 'phụ đề' hoặc 'lồng tiếng'
          bool isVietnamese = (lang.contains('việt') || lang.contains('vn') || lang.contains('viet')) 
                           && !lang.contains('phụ đề') && !lang.contains('lồng tiếng');
          
          final date = _parseDate(m.releaseDate);
          // Điều kiện Đang chiếu: Không có ngày hoặc ngày phát hành <= ngày hiện tại
          bool isNowShowing = date == null || date.isBefore(now) || date.isAtSameMomentAs(now);
          
          // Trả về true nếu VỪA là phim Việt Nam VÀ VỪA đang chiếu
          return isVietnamese && isNowShowing;
        }).toList();
        
        // Sắp xếp phim Việt Nam mới nhất lên đầu giống như mục Đang chiếu
        vietnameseMovies.sort((a, b) {
          final dateA = _parseDate(a.releaseDate) ?? DateTime(1970);
          final dateB = _parseDate(b.releaseDate) ?? DateTime(1970);
          return dateB.compareTo(dateA); 
        });

        List<Movie> upcoming = allMovies.where((m) {
          final date = _parseDate(m.releaseDate);
          if (date == null) return false;
          
          // 🔥 Bỏ chặn Phim Việt Nam. Chỉ cần ngày chiếu LỚN HƠN ngày hiện tại là lọt vào mục Sắp chiếu!
          return date.isAfter(now); 
        }).toList();
        
        upcoming.sort((a, b) {
          final dateA = _parseDate(a.releaseDate) ?? DateTime(2100);
          final dateB = _parseDate(b.releaseDate) ?? DateTime(2100);
          return dateA.compareTo(dateB); 
        });

        return RefreshIndicator(
          color: navyBlue, 
          backgroundColor: Colors.white, 
          onRefresh: _onRefresh, 
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            // 🚀 BỌC SCROLL TO TOP WRAPPER VÀO ĐÂY
            child: ScrollToTopWrapper(
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController, // 🚀 GẮN CONTROLLER TỪ WRAPPER VÀO ĐÂY
                  physics: const AlwaysScrollableScrollPhysics(), 
                  child: Stack(
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.3, 
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF64B5F6), 
                              Color(0xFFF5F5F9), 
                            ],
                          ),
                        ),
                      ),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 105), 
                          
                          _buildSearchBar(allMovies),
                          
                          _buildPromoBanner(),
                          
                          _buildSectionTitle("Phim nổi bật", hasSeeAll: false),
                          _buildFeaturedMovies(_featuredMoviesList),
                          
                          _buildSectionTitle(
                            "Phim hay đang chiếu", 
                            hasSeeAll: true,
                            onSeeAllTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AllMoviesPage(
                                pageTitle: "Phim đang chiếu", 
                                movies: allMovies, 
                                initialIndex: 0,
                              )));
                            },
                          ),
                          _buildNowShowingMovies(nowShowing.take(5).toList()), 
                          
                          if (vietnameseMovies.isNotEmpty) ...[
                            _buildSectionTitle(
                              "Phim Việt Nam", 
                              hasSeeAll: true,
                              onSeeAllTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => AllMoviesPage(
                                  pageTitle: "Phim Việt Nam", 
                                  movies: allMovies, 
                                  initialIndex: 2, 
                                )));
                              },
                            ),
                            _buildVietnameseMovies(vietnameseMovies.take(5).toList()),
                          ],

                          // ========================================================
                          // ✅ CHÈN BOX VOUCHER TRƯỢT NGANG TẠI ĐÂY
                          // ========================================================
                          if (!_isLoadingVouchers && _vouchers.isNotEmpty) ...[
                            _buildSectionTitle(
                              "Ưu đãi dành cho bạn", 
                              hasSeeAll: true,
                              onSeeAllTap: () {
                                // 🚀 BỌC GUEST GUARD CHO KHÁCH VÃNG LAI
                                GuestGuard.check(context, () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => VoucherListScreen()
                                  ));
                                });
                              },
                            ),
                            _buildHorizontalVoucherList(),
                          ],

                          _buildSectionTitle(
                            "Phim sắp chiếu", 
                            hasSeeAll: true,
                            onSeeAllTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AllMoviesPage(
                                pageTitle: "Phim sắp chiếu", 
                                movies: allMovies, 
                                initialIndex: 1,
                              )));
                            },
                          ),
                          _buildUpcomingMovies(upcoming.take(5).toList()), 
                          
                          const SizedBox(height: 30),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
  // ========================================================
  // ✅ GIAO DIỆN BOX VOUCHER NẰM NGANG NGOÀI TRANG CHỦ (ĐỒNG BỘ 100%)
  // ========================================================
  Widget _buildHorizontalVoucherList() {
    return SizedBox(
      height: 125, // 🚀 Nâng nhẹ chiều cao để chứa bóng đổ 3D lơ lửng
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _vouchers.length,
        itemBuilder: (context, index) {
          final voucher = _vouchers[index];
          String code = voucher['Code']?.toString() ?? 'Khuyến mãi';
          int percent = int.tryParse(voucher['DiscountPercent']?.toString() ?? '0') ?? 0;
          
          int discountAmount = int.tryParse(voucher['DiscountAmount']?.toString() ?? '0') ?? 0;
          int minOrderValue = int.tryParse(voucher['MinOrderValue']?.toString() ?? '0') ?? 0;
          int maxDiscountAmount = int.tryParse(voucher['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
          
          bool isPointVoucher = code.startsWith('P') && code.contains('_');

          // ========================================================
          // 🚀 HIỂN THỊ CHỮ "GIẢM XX" SIÊU TO KHỔNG LỒ
          // ========================================================
          bool isFixed = percent == 100;
          String titleText = "";
          String leftBlockText = "";
          
          if (isFixed) {
            int realAmount = discountAmount > 0 ? discountAmount : maxDiscountAmount;
            leftBlockText = _formatCompactMoney(realAmount);
            titleText = "Giảm $leftBlockText";
          } else {
            leftBlockText = "$percent%";
            titleText = "Giảm $leftBlockText";
          }

          Color activeColor = navyBlue;
          LinearGradient bgGradient = LinearGradient(colors: [activeColor, Colors.blue.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight);

          // 🚀 ĐÃ NÂNG CẤP: Bấm vào cái Box này sẽ bật lên bảng thông tin chi tiết của Voucher
          return GestureDetector(
            onTap: () {
              GuestGuard.check(context, () {
                _showVoucherDetail(context, voucher);
              });
            },
            child: Stack(
              children: [
                Container(
                  width: 270, 
                  margin: const EdgeInsets.only(right: 12, bottom: 12), // Chừa margin dưới để hắt bóng đổ
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    // 🚀 BÓNG ĐỔ 3D GIÚP VÉ NỔI LÊN TRÊN NỀN
                    boxShadow: [BoxShadow(color: activeColor.withOpacity(0.20), blurRadius: 8, spreadRadius: 0, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                    children: [
                      // 1. CỘT TRÁI ĐỒNG BỘ: MÀU NAVY, CHỮ "GIẢM", RĂNG CƯA TRÒN
                      Stack(
                        children: [
                          Container(
                            width: 90,
                            decoration: BoxDecoration(gradient: bgGradient),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("GIẢM", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 2),
                                Text(leftBlockText, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                if (isPointVoucher)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text("VIP TICKET", style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                          // 🚀 ĐỤC LỖ RĂNG CƯA TRÒN VÀO MÉP TRÁI VÉ
                          Positioned(
                            left: -4, top: 0, bottom: 0, 
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                              children: List.generate(10, (index) => Container(
                                width: 8, height: 8, 
                                decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle)
                              ))
                            )
                          ),
                        ],
                      ),

                      // 2. RÃNH XÉ VÉ (DOTTED LINE)
                      Container(
                        width: 12,
                        color: Colors.white,
                        child: Stack(
                          children: [
                            Center(
                              child: DottedLine(
                                direction: Axis.vertical,
                                lineThickness: 1.5,
                                dashLength: 4,
                                dashColor: Colors.grey.shade300,
                              ),
                            ),
                            Positioned(top: -6, left: 0, right: 0, child: Container(height: 12, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle))),
                            Positioned(bottom: -6, left: 0, right: 0, child: Container(height: 12, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle))),
                          ],
                        ),
                      ),

                      // 3. CỘT PHẢI (THÔNG TIN CHI TIẾT)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200, width: 0.5),
                                ),
                                child: Text(
                                  isPointVoucher ? "VIP: $code" : "Mã: $code",
                                  style: TextStyle(color: Colors.blue.shade800, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              
                              Text(
                                titleText, 
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),

                              if (!isFixed && maxDiscountAmount < 999999)
                                Text("Tối đa ${_formatCompactMoney(maxDiscountAmount)}", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),

                              if (minOrderValue > 0)
                                Text("Đơn tối thiểu ${_formatCompactMoney(minOrderValue)}", style: TextStyle(fontSize: 10, color: Colors.grey.shade600))
                              else
                                Text("Mọi đơn hàng", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSearchBar(List<Movie> allMovies) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final currentCinemasFromDB = await sl<MovieRepository>().getCinemasByBrand('');

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchPage(
                      allMovies: allMovies,
                      allCinemas: currentCinemasFromDB,
                    ),
                  ),
                );
              },
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: Colors.grey.shade500, size: 22),
                    const SizedBox(width: 10),
                    Text("Tìm tên phim hoặc rạp", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // =========================================================
          // 🚀 [TƯƠNG LAI] NÚT CHAT AI ĐƯỢC TẠM ẨN ĐỂ UPDATE BẢN SAU
          // =========================================================
          /*
          InkWell(
            onTap: () {
              GuestGuard.check(context, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AiChatScreen()));
              });
            },
            borderRadius: BorderRadius.circular(23),
            child: Container(
              height: 46,
              padding: const EdgeInsets.only(left: 6, right: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: navyBlue, width: 1.5), 
                borderRadius: BorderRadius.circular(23),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    child: Image.asset('assets/bot.gif', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text("🤖", style: TextStyle(fontSize: 16)))),
                  ),
                  const SizedBox(width: 6),
                  Text('Trợ lý', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
          */

          // =========================================================
          // ✅ NÚT BỘ LỌC PHIM (THAY THẾ CHỖ CỦA AI CHAT)
          // =========================================================
          InkWell(
            onTap: () {
              // Gọi thẳng cái BottomSheet Bộ lọc đã viết sẵn ở bên dưới
              _showFilterBottomSheet(context, allMovies);
            },
            borderRadius: BorderRadius.circular(23),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16), // Padding gọn gàng
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: navyBlue, width: 1.5), 
                borderRadius: BorderRadius.circular(23),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: navyBlue, size: 20), // Icon Bộ lọc nhìn xịn xò
                  const SizedBox(width: 6),
                  Text(
                    'Bộ lọc', 
                    style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
  void _showFilterBottomSheet(BuildContext context, List<Movie> allMovies) {
    final Color primaryBlue = Colors.blue.shade800;
    String selectedStatus = 'Đang chiếu';
    String selectedAge = 'Tất cả';
    List<String> selectedGenres = [];

    final List<String> statuses = _buildStatusOptions(allMovies);
    final List<String> ages = _buildAgeOptions(allMovies);
    final List<String> genres = _buildGenreOptions(allMovies);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.7,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        const Text(
                          'Bộ Lọc Phim',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close_rounded, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterSectionTitle('Trạng thái'),
                          _buildSingleChoiceChips(statuses, selectedStatus, (val) {
                            setModalState(() => selectedStatus = val);
                          }, primaryBlue),
                          const SizedBox(height: 20),
                          _buildFilterSectionTitle('Độ tuổi'),
                          _buildSingleChoiceChips(ages, selectedAge, (val) {
                            setModalState(() => selectedAge = val);
                          }, primaryBlue),
                          const SizedBox(height: 20),
                          _buildFilterSectionTitle('Thể loại (Có thể chọn nhiều)'),
                          _buildMultiChoiceChips(genres, selectedGenres, (val, isSelected) {
                            setModalState(() {
                              if (isSelected) {
                                selectedGenres.add(val);
                              } else {
                                selectedGenres.remove(val);
                              }
                            });
                          }, primaryBlue),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedStatus = 'Tất cả';
                                selectedAge = 'Tất cả';
                                selectedGenres.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Đặt lại', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final filteredMovies = _filterMovies(
                                allMovies,
                                status: selectedStatus,
                                age: selectedAge,
                                genres: selectedGenres,
                              );

                              Navigator.pop(context);
                              Navigator.push(
                                this.context,
                                MaterialPageRoute(
                                  builder: (context) => AllMoviesPage(
                                    pageTitle: 'Danh Sách Phim',
                                    movies: filteredMovies,
                                    initialIndex: _getInitialIndexForStatus(selectedStatus),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Áp dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _buildStatusOptions(List<Movie> movies) {
    final now = DateTime.now();
    final options = <String>{'Tất cả'};

    for (final movie in movies) {
      final releaseDate = _parseDate(movie.releaseDate);
      final language = movie.language?.toLowerCase() ?? '';

      if (releaseDate != null && (releaseDate.isBefore(now) || releaseDate.isAtSameMomentAs(now))) {
        options.add('Đang chiếu');
      }

      if (releaseDate != null && releaseDate.isAfter(now)) {
        options.add('Sắp chiếu');
      }

      if ((language.contains('việt') || language.contains('vn') || language.contains('viet')) 
          && !language.contains('phụ đề') && !language.contains('lồng tiếng')) {
        options.add('Việt Nam');
      }

      if ((movie.voteAverage ?? 0) > 8.0) {
        options.add('Suất chiếu sớm');
      }
    }

    return options.toList();
  }

  List<String> _buildAgeOptions(List<Movie> movies) {
    final options = <String>{'Tất cả'};

    for (final movie in movies) {
      final ageRating = movie.ageRating?.trim();
      if (ageRating != null && ageRating.isNotEmpty) {
        options.add(ageRating);
      }
    }

    if (options.length == 1) {
      options.addAll(['P', 'C13', 'C16', 'C18']);
    }

    return options.toList();
  }

  List<String> _buildGenreOptions(List<Movie> movies) {
    final options = <String>{};

    for (final movie in movies) {
      final rawGenres = movie.genres ?? '';
      for (final genre in rawGenres.split(',')) {
        final trimmed = genre.trim();
        if (trimmed.isNotEmpty) {
          options.add(trimmed);
        }
      }
    }

    if (options.isEmpty) {
      options.addAll(['Hành động', 'Kinh dị', 'Hài hước', 'Anime', 'Tình cảm', 'Viễn tưởng']);
    }

    return options.toList();
  }

  List<Movie> _filterMovies(
    List<Movie> movies, {
    required String status,
    required String age,
    required List<String> genres,
  }) {
    final now = DateTime.now();

    return movies.where((movie) {
      final releaseDate = _parseDate(movie.releaseDate);
      final language = movie.language?.toLowerCase() ?? '';
      final movieAge = movie.ageRating?.trim() ?? '';
      final movieGenres = (movie.genres ?? '')
          .split(',')
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toList();

      final matchesStatus = switch (status) {
        'Tất cả' => true,
        'Đang chiếu' => releaseDate == null || releaseDate.isBefore(now) || releaseDate.isAtSameMomentAs(now),
        'Sắp chiếu' => releaseDate != null && releaseDate.isAfter(now),
        'Việt Nam' => (language.contains('việt') || language.contains('vn') || language.contains('viet')) && !language.contains('phụ đề') && !language.contains('lồng tiếng'),
        'Suất chiếu sớm' => (movie.voteAverage ?? 0) > 8.0,
        _ => true,
      };

      final matchesAge = age == 'Tất cả' || movieAge == age;
      final matchesGenre = genres.isEmpty || movieGenres.any(genres.contains);

      return matchesStatus && matchesAge && matchesGenre;
    }).toList();
  }

  int _getInitialIndexForStatus(String status) {
    switch (status) {
      case 'Sắp chiếu':
        return 1;
      case 'Việt Nam':
        return 2;
      case 'Suất chiếu sớm':
        return 3;
      case 'Đang chiếu':
      case 'Tất cả':
      default:
        return 0;
    }
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSingleChoiceChips(List<String> items, String selectedValue, Function(String) onSelect, Color primaryColor) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = item == selectedValue;
        return ChoiceChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (_) => onSelect(item),
          selectedColor: primaryColor.withValues(alpha: 0.1),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? primaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildMultiChoiceChips(List<String> items, List<String> selectedValues, Function(String, bool) onSelect, Color primaryColor) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = selectedValues.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (selected) => onSelect(item, selected),
          selectedColor: primaryColor.withValues(alpha: 0.1),
          backgroundColor: Colors.white,
          checkmarkColor: primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? primaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: 155,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PageView.builder(
                controller: _bannerPageController,
                onPageChanged: (index) {
                  setState(() => _currentBannerIndex = index);
                },
                itemCount: _bannerImages.length,
                itemBuilder: (context, index) {
                  return Image.asset(
                    _bannerImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.blue.shade50,
                      child: Center(
                        child: Text('Banner Khuyến Mãi ${index + 1}', style: TextStyle(color: navyBlue))
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentBannerIndex + 1}/${_bannerImages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required bool hasSeeAll, VoidCallback? onSeeAllTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (hasSeeAll)
            GestureDetector(
              onTap: onSeeAllTap, 
              child: Row(
                children: [
                  Text('Xem tất cả ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navyBlue)),
                  Icon(Icons.arrow_forward_ios, size: 12, color: navyBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedMovies(List<Movie> movies) {
    if(movies.isEmpty) return const SizedBox();
    return SizedBox(
      height: 420, 
      child: PageView.builder(
        controller: _featuredPageController,
        onPageChanged: (index) {
          if (mounted) setState(() => _currentFeaturedPage = index);
        },
        itemBuilder: (context, index) {
          final int movieIndex = index % movies.length;
          final movie = movies[movieIndex];
          
          double scale = (index == _currentFeaturedPage) ? 1.0 : 0.85;

          return AnimatedScale(
            scale: scale, 
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: GestureDetector(
              onTap: () async {
  // 1. Chờ người dùng sang trang chi tiết xem/đánh giá chán chê
  await Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)));
  
  // 2. Khi họ bấm Back quay lại trang chủ -> Tự động gọi API tải lại dữ liệu mới nhất!
  _onRefresh(); 
},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10), 
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Stack(
                      clipBehavior: Clip.none, 
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            _getImage(movie.posterPath), 
                            height: 330, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => Container(height: 330, width: double.infinity, color: Colors.grey[300]),
                          ),
                        ),
                        Positioned(top: 10, left: 10, child: _buildBlueBadge("SNEAKSHOW")),
                        Positioned(top: 10, right: 10, child: _buildAgeBadgeBadge(movie.ageRating ?? "16+")),
                        Positioned(
                          bottom: -15, left: 10,
                          child: Text(
                            '${movieIndex + 1}',
                            style: TextStyle(
                              fontSize: 80, fontWeight: FontWeight.bold,
                              foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(movie.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(movie.genres ?? "Đang cập nhật", textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNowShowingMovies(List<Movie> movies) {
    if(movies.isEmpty) return const SizedBox();
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () async {
            // 1. Chờ người dùng sang trang chi tiết xem/đánh giá chán chê
            await Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)));
            
            // 2. Khi họ bấm Back quay lại trang chủ -> Tự động gọi API tải lại dữ liệu mới nhất!
            _onRefresh(); 
          },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12), 
                        child: Image.network(
                          _getImage(movie.posterPath), 
                          height: 200, width: 140, fit: BoxFit.cover, 
                          errorBuilder: (context, error, stackTrace) {
                          // 🚀 Gắn máy nghe lén: Báo lỗi đỏ rực trên Terminal để ta biết bệnh
                          debugPrint('❌ LỖI TẢI ẢNH: ${_getImage(movie.posterPath)}');
                          debugPrint('🔍 CHI TIẾT LỖI: $error');
                          return Container(height: 200, width: 140, color: Colors.grey[200]);
                        }
                        )
                      ),
                      Positioned(top: 8, left: 8, child: _buildAgeBadgeBadge(movie.ageRating ?? "P")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.star, color: Colors.deepOrange, size: 14),
                    const SizedBox(width: 4),
                    Text('${(movie.voteAverage ?? 0.0).toStringAsFixed(1)}/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 4),
                  ]),
                  const SizedBox(height: 4),
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(movie.genres ?? "Đang cập nhật", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVietnameseMovies(List<Movie> movies) {
    return _buildNowShowingMovies(movies);
  }

  Widget _buildUpcomingMovies(List<Movie> movies) {
    if(movies.isEmpty) return const SizedBox();
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () async {
  // 1. Chờ người dùng sang trang chi tiết xem/đánh giá chán chê
  await Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)));
  
  // 2. Khi họ bấm Back quay lại trang chủ -> Tự động gọi API tải lại dữ liệu mới nhất!
  _onRefresh(); 
},
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none, 
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12), 
                        child: Image.network(
                          _getImage(movie.posterPath), 
                          height: 200, width: 140, fit: BoxFit.cover, 
                         errorBuilder: (context, error, stackTrace) {
                          // 🚀 Gắn máy nghe lén: Báo lỗi đỏ rực trên Terminal để ta biết bệnh
                          debugPrint('❌ LỖI TẢI ẢNH: ${_getImage(movie.posterPath)}');
                          debugPrint('🔍 CHI TIẾT LỖI: $error');
                          return Container(height: 200, width: 140, color: Colors.grey[200]);
                        }
                        )
                      ),
                      Positioned(top: 8, right: 8, child: _buildAgeBadgeBadge(movie.ageRating ?? "18+")),
                      Positioned(
                        top: 8, left: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.access_time_filled, color: Colors.white, size: 10), 
                              SizedBox(width: 4),
                              Text("COMING SOON", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_formatDateShort(movie.releaseDate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyBlue)), 
                  const SizedBox(height: 2),
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(movie.genres ?? "Đang cập nhật", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

 // 🚀 HÀM BỌC THÉP TỐI THƯỢNG (CHÉM BAY CÁI TMDB BỊ GẮN OAN)
  String _getImage(String? path) {
    if (path == null || path.trim().isEmpty || path == 'null') {
      return 'https://via.placeholder.com/300x450?text=No+Poster';
    }
    
    String cleanPath = path.trim();

    // 🛑 BƯỚC 1: CHÉM BỎ TMDB NẾU BỊ MODEL GẮN NHẦM VÀO ẢNH LOCAL
    // Nếu trong link vừa có chữ tmdb.org, lại vừa có chữ uploads -> 100% bị gài nhầm!
    if (cleanPath.contains('image.tmdb.org') && (cleanPath.contains('uploads') || cleanPath.contains('avatars'))) {
      // Tách lấy đúng khúc 'uploads/...' ở phía sau, vứt bỏ toàn bộ chữ TMDB phía trước
      int cutIndex = cleanPath.indexOf('uploads');
      if (cutIndex == -1) cutIndex = cleanPath.indexOf('avatars');
      cleanPath = cleanPath.substring(cutIndex); 
    }

    String finalUrl = '';
    
    // 2. Nhận diện ảnh của máy chủ mình (chứa chữ uploads hoặc avatars)
    if (cleanPath.contains('uploads') || cleanPath.contains('avatars')) {
      // Đảm bảo luôn có 1 dấu '/' ở đầu
      if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
      
      // Xóa chữ /public nếu lỡ DB có lưu
      cleanPath = cleanPath.replaceFirst('/public', '');
      
      finalUrl = '$apiBaseUrl$cleanPath';
    } 
    // 3. Nếu là Link web ngoài hoàn chỉnh (http://...)
    else if (cleanPath.startsWith('http')) {
      finalUrl = cleanPath;
    } 
    // 4. Cuối cùng: Ảnh từ TheMovieDB thật sự (chỉ có /abc.jpg)
    else {
      if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
      finalUrl = 'https://image.tmdb.org/t/p/w500$cleanPath';
    }
    
    // debugPrint('🎬 [LINK CHUẨN CỦA APP]: $finalUrl');
    return finalUrl;
  }
  // 🚀 ĐÃ FIX DỨT ĐIỂM LỖI NGÀY -1 VÀ LỖI LÙI MÚI GIỜ
  String _formatDateShort(String? date) {
    if (date == null || date.trim().isEmpty || date == '-1' || date.toLowerCase() == 'null') {
      return "Sắp chiếu"; 
    }

    try {
      // ÉP LẠI MÚI GIỜ VIỆT NAM MỘT LẦN NỮA NGAY TẠI LÚC RENDER CHỮ ĐỂ CHẮC CÚ 100%
      DateTime dt = DateTime.parse(date).toUtc().add(const Duration(hours: 7));
      
      // Định dạng lại thành: 25 Thg 08 (Chuẩn UI)
      String day = dt.day.toString().padLeft(2, '0');
      String month = dt.month.toString().padLeft(2, '0');
      
      return "$day Thg $month";
    } catch (_) {
      // Nếu không parse được thì in lại chuỗi gốc
      return date;
    }
  }
  String _formatCompactMoney(int amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}tr';
  }

  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
  }

  return '${amount}đ';
}

  Widget _buildAgeBadgeBadge(String age) {
    Color bgColor = Colors.green;
    if (age.contains('13')) bgColor = Colors.orange.shade300;
    if (age.contains('16')) bgColor = Colors.orange; 
    if (age.contains('18')) bgColor = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1), 
      ),
      child: Text(age, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBlueBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: navyBlue, 
        borderRadius: BorderRadius.circular(4)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  // ====================================================================
  // 🚀 HÀM HIỂN THỊ CHI TIẾT VOUCHER (KÈM CHỨC NĂNG LƯU VÀO VÍ)
  // ====================================================================
  void _showVoucherDetail(BuildContext context, dynamic voucher) {
    String code = voucher['Code']?.toString() ?? 'Khuyến mãi';
    int percent = int.tryParse(voucher['DiscountPercent']?.toString() ?? '0') ?? 0;
    int maxDiscount = int.tryParse(voucher['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
    int minOrderValue = int.tryParse(voucher['MinOrderValue']?.toString() ?? '0') ?? 0;
    
    // Ép múi giờ VN (GMT+7) để xem ngày cho chính xác
    DateTime expiredAt;
    try {
      expiredAt = DateTime.parse(voucher['ExpiredAt']).toLocal();
    } catch (_) {
      expiredAt = DateTime.now();
    }
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(expiredAt);
    
    bool isPointVoucher = code.startsWith('P') && code.contains('_');

    // Setup Text hiển thị
    bool isFixed = percent == 100;
    String titleText = "";
    if (isFixed) {
      int realAmount = (voucher['DiscountAmount'] != null && voucher['DiscountAmount'] > 0) ? voucher['DiscountAmount'] : maxDiscount;
      titleText = "Giảm giá ${_formatCompactMoney(realAmount)}";
    } else {
      titleText = "Giảm $percent%";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              
              Text(titleText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              
              if (isPointVoucher)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade200)),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 28),
                      const SizedBox(width: 8),
                      const Expanded(child: Text("Vé Khách Hàng VIP (Đổi bằng Điểm tích lũy)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Mã Voucher:", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                      Text(code, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navyBlue, letterSpacing: 1.2)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Điều kiện áp dụng:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text("• Áp dụng cho đơn hàng từ ${_formatCompactMoney(minOrderValue)}", style: TextStyle(color: Colors.grey.shade700)),
                        if (!isFixed && maxDiscount < 999999) 
                          Text("• Mức giảm tối đa không vượt quá ${_formatCompactMoney(maxDiscount)}", style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Text("Hạn sử dụng: ", style: TextStyle(color: Colors.grey.shade700)),
                  Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPointVoucher ? Colors.amber.shade600 : navyBlue, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                    elevation: 0
                  ),
                  onPressed: () {
                    // Đóng Bottom Sheet hiện tại
                    Navigator.pop(context); 
                    
                    GuestGuard.check(context, () {
                      // 🚀 ĐÃ NÂNG CẤP: Truyền lệnh 'initialStoreMode' sang để App biết phải mở Kho hay Cửa hàng VIP
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => VoucherListScreen(initialStoreMode: isPointVoucher)
                      )).then((_) {
                        _loadVouchers(); 
                      });
                    });
                  },
                  child: Text(
                    isPointVoucher ? "Đi đến Cửa Hàng Đổi Điểm" : "Vào kho lưu Voucher", 
                    style: TextStyle(
                      color: isPointVoucher ? Colors.black87 : Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 16
                    )
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      }
    );
  }
}