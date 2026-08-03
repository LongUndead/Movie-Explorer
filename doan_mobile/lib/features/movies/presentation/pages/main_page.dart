import 'package:flutter/material.dart';
import 'dart:ui'; 
import 'dart:async'; // 🚀 IMPORT TIMER ĐỂ LÀM POLLING
import 'dart:convert'; // 🚀 IMPORT JSON
import 'package:http/http.dart' as http; // 🚀 IMPORT HTTP
import 'package:intl/intl.dart'; // 🚀 IMPORT FORMAT NGÀY GIỜ

import 'home_page.dart'; 
import 'cart_page.dart';
import 'profile_page.dart';
import 'cinema_menu_page.dart';
import 'food_booking_page.dart';
import 'group_movie_page.dart';
import 'user_manager.dart';
import 'history_page.dart'; // 🚀 THÊM DÒNG NÀY ĐỂ KẾT NỐI TRANG
import 'notification_service.dart';

final GlobalKey mainCartKey = GlobalKey();

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final GlobalKey<FoodBookingPageState> foodPageKey = GlobalKey<FoodBookingPageState>();
  int _selectedIndex = 0;
  final Color navyBlue = Colors.blue.shade900; 

  double _scrollOffset = 0;

  // ==========================================
  // 🚀 BIẾN LƯU TRỮ THÔNG BÁO TỪ DATABASE
  // ==========================================
  List<dynamic> _notifications = [];
  Timer? _notifTimer;
  final String apiBaseUrl = 'http://192.168.1.7:3000'; // ĐỔI ĐÚNG IP MÁY ÔNG NHA
  
  // ⚠️ Lưu ý: Tạm set cứng ID là 1. Sau này ông nhớ lấy từ SharedPreferences lúc user đăng nhập nhé!
  int currentUserId = 1; 

  late final List<Widget> _pages = [
    const HomePage(), 
    const CinemaMenuPage(), 
    FoodBookingPage(key: foodPageKey),
    const GroupMoviePage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    
    // =======================================================
    // 🚀 THÊM DÒNG NÀY: Khởi tạo & Xin quyền thông báo nổi
    // =======================================================
    NotificationService.initialize();

    // 1. Lấy thông báo lần đầu lúc mới vào app
    _fetchNotifications();
    
    // 2. HẸN GIỜ: Cứ 15 giây âm thầm tải lại thông báo 1 lần (Cảm giác Realtime)
    _notifTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchNotifications());
  }

  @override
  void dispose() {
    _notifTimer?.cancel(); // Hủy hẹn giờ khi thoát trang
    super.dispose();
  }

  // ==========================================
  // 🚀 HÀM LẤY THÔNG BÁO TỪ BACKEND (ĐÃ FIX TỰ NHẬN ID)
  // ==========================================
  Future<void> _fetchNotifications() async {
    // 1. Lấy thông tin user đang đăng nhập hiện tại
    final user = UserManager.instance.currentUser;
    
    // Nếu khách chưa đăng nhập thì nghỉ, không gọi API làm gì cho nặng server
    if (user == null) return; 

    try {
      // 2. Truyền đúng ID thật của khách (user.id) vào link API
      final res = await http.get(Uri.parse('$apiBaseUrl/api/users/${user.id}/notifications'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = json.decode(res.body);
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải thông báo: $e");
    }
  }

  // ==========================================
  // 🚀 HÀM ĐÁNH DẤU ĐÃ ĐỌC (ĐÃ FIX LINK API)
  // ==========================================
  Future<void> _markAsRead(int notifId) async {
    try {
      // ✅ SỬA LẠI THÀNH LINK NÀY (Bỏ chữ /admin/ đi)
      await http.put(Uri.parse('$apiBaseUrl/api/users/notifications/$notifId/read'));
      _fetchNotifications(); // Reload lại danh sách sau khi call API thành công
    } catch (e) {
      debugPrint("Lỗi đánh dấu đã đọc: $e");
    }
  }

  // Đếm số lượng thông báo chưa đọc (IsRead == 0)
  int get unreadCount => _notifications.where((n) => n['IsRead'] == 0).length;

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'CINEMA TICKETS';
      case 1: return 'CHỌN RẠP PHIM';
      case 2: return 'MUA BẮP NƯỚC';
      case 3: return 'NHÓM PHIM';
      case 4: return 'TÀI KHOẢN';
      default: return 'CINEMA TICKETS';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isScrolled = _scrollOffset > 40;

    Color appBarBg = isScrolled ? Colors.white : Colors.transparent;
    Color elementColor = navyBlue;
    Color boxIconsBg = !isScrolled ? Colors.white.withOpacity(0.6) : Colors.grey.shade100;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: const Color(0xFFF5F5F9), 
      appBar: _buildAppBar(appBarBg, elementColor, boxIconsBg, isScrolled), 
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification && 
              scrollNotification.depth == 0 && 
              scrollNotification.metrics.axis == Axis.vertical) {
            setState(() {
              _scrollOffset = scrollNotification.metrics.pixels;
            });
          }
          return false;
        },
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(Color bg, Color itemsColor, Color boxBg, bool isScrolled) {
    final String title = _getAppBarTitle(_selectedIndex);
    bool applyShadow = (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 4) && isScrolled;

    return AppBar(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shadowColor: applyShadow ? Colors.black.withOpacity(0.05) : Colors.transparent,
      elevation: applyShadow ? 2 : 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: itemsColor),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0), 
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: boxBg, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
                  ]
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        _showNotificationBottomSheet();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: _buildIconWithBadge(Icons.notifications_none, unreadCount, itemsColor),
                      ),
                    ),
                    Container(height: 14, width: 1.5, color: itemsColor.withOpacity(0.2)),
                    ListenableBuilder(
                      listenable: CartManager.instance,
                      builder: (context, child) {
                        final cartItemCount = CartManager.instance.totalSeatsCount + CartManager.instance.totalFoodsCount;
                        return InkWell(
                          key: mainCartKey, 
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage(initialIndex: 1)));
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: _buildIconWithBadge(Icons.shopping_cart_outlined, cartItemCount, itemsColor),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconWithBadge(IconData icon, int count, Color iconColor) {
    return SizedBox(
      width: 24, 
      height: 24, 
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center, 
        children: [
          Icon(icon, color: iconColor, size: 22),
          if (count > 0)
            Positioned(
              top: -2, 
              right: -4, 
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red, 
                  shape: BoxShape.circle
                ),
                child: Text(
                  count > 9 ? '9+' : count.toString(), 
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, height: 1)
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 🚀 NÂNG CẤP BOTTOM SHEET ĐỂ HIỂN THỊ DỮ LIỆU THẬT & FULL TYPE
  // ==========================================
  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  Text("Thông báo của bạn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                  const Divider(height: 30),
                  
                  Expanded(
                    child: _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text("Bạn chưa có thông báo nào", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            final isUnread = notif['IsRead'] == 0;
                            
                            // Parse và Format thời gian (Giả sử CreatedAt từ DB trả ra)
                            DateTime createdAt = DateTime.tryParse(notif['CreatedAt'] ?? '')?.toLocal() ?? DateTime.now();
                            String timeString = DateFormat('HH:mm - dd/MM/yyyy').format(createdAt);

                            // 🚀 PHÂN LOẠI ICON VÀ MÀU SẮC THEO TYPE (TỪ BACKEND TRẢ VỀ)
                            IconData iconData = Icons.notifications;
                            Color iconColor = Colors.white;
                            Color bgColor = navyBlue;

                            switch (notif['Type']) {
                              case 'BOOKING': // Mua vé thành công
                                iconData = Icons.confirmation_num_outlined;
                                bgColor = Colors.teal.shade500;
                                break;
                              case 'VOUCHER': // Tặng voucher
                                iconData = Icons.card_giftcard;
                                bgColor = Colors.orange.shade500;
                                break;
                              case 'MOVIE': // Thêm phim mới
                                iconData = Icons.local_movies_outlined;
                                bgColor = Colors.blue.shade500;
                                break;
                              case 'FOOD': // Thêm món mới
                                iconData = Icons.fastfood_outlined;
                                bgColor = Colors.amber.shade600;
                                break;
                              case 'REFUND': // Hoàn vé
                                iconData = Icons.currency_exchange;
                                bgColor = Colors.teal.shade500;
                                break;
                              case 'WARNING': // Cảnh báo, Khóa acc, Phạt bài viết
                              case 'BANNED':
                                iconData = Icons.gavel_rounded; // Búa phán quyết của Admin =))
                                bgColor = Colors.red.shade600;
                                break;
                              default:
                                iconData = Icons.notifications;
                                bgColor = navyBlue;
                            }

                            return GestureDetector(
                              onTap: () {
                                // 1. Đánh dấu đã đọc
                                if (isUnread) {
                                  _markAsRead(notif['NotificationID']);
                                  setModalState(() {
                                    notif['IsRead'] = 1;
                                  });
                                }

                                // 2. ĐÓNG CỬA SỔ THÔNG BÁO LẠI
                                Navigator.pop(context);

                                // 3. BẮT ĐẦU BẺ LÁI (CHUYỂN TRANG)
                                final actionUrl = notif['ActionURL'] ?? '';

                                if (actionUrl.contains('/tickets')) {
                                  // 🚀 BAY THẲNG SANG TRANG LỊCH SỬ GIAO DỊCH
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (_) => const HistoryPage())
                                  );
                                } 
                                else if (actionUrl == '/group') {
                                  // Bay sang tab Nhóm Phim (Index 3)
                                  setState(() {
                                    _selectedIndex = 3;
                                    _scrollOffset = 0;
                                  });
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUnread ? Colors.blue.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isUnread ? Colors.blue.shade100 : Colors.transparent)
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🚀 ÁP DỤNG ĐÚNG MÀU BACKGROUND TƯƠNG ỨNG NẾU CHƯA ĐỌC
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isUnread ? bgColor : Colors.grey.shade300, 
                                        shape: BoxShape.circle
                                      ),
                                      child: Icon(iconData, color: isUnread ? iconColor : Colors.grey.shade600, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(notif['Title'] ?? 'Thông báo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isUnread ? Colors.black87 : Colors.black54)),
                                          const SizedBox(height: 4),
                                          Text(notif['Content'] ?? '', style: TextStyle(color: isUnread ? Colors.black87 : Colors.black54, fontSize: 13, height: 1.4)),
                                          const SizedBox(height: 8),
                                          Text(timeString, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 8, height: 8,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildCustomBottomNavBar() {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.confirmation_num_outlined, Icons.confirmation_num, 'Chọn phim'),
            _buildNavItem(1, Icons.play_arrow_outlined, Icons.play_arrow, 'Chọn rạp'),
            _buildNavItem(2, Icons.fastfood_outlined, Icons.fastfood, 'Bắp nước'),
            _buildNavItem(3, Icons.computer_outlined, Icons.computer, 'Nhóm phim'),
            _buildNavItem(4, Icons.face_outlined, Icons.face, 'Tôi', hasNewBadge: true),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon, String label, {bool hasNewBadge = false}) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _scrollOffset = 0; 
          });
          if (index == 2) { 
            foodPageKey.currentState?.triggerWelcomePopup();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isSelected ? navyBlue : Colors.transparent, width: 3)), 
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isSelected ? solidIcon : outlineIcon, color: isSelected ? navyBlue : Colors.grey, size: 24), 
                  if (hasNewBadge)
                    Positioned(
                      top: -4, right: -12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(10)),
                        child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? navyBlue : Colors.grey, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), 
            ],
          ),
        ),
      ),
    );
  }
}