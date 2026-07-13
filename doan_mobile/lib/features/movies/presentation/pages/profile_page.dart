import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart'; 

import '../../domain/entities/movie.dart'; 
import 'user_manager.dart';
import 'login_screen.dart'; 
import 'history_page.dart';
import 'edit_profile_page.dart';
import '../../data/models/movie_model.dart';
import 'movie_detail_page.dart';
import 'promotion_details_page.dart'; 
import 'cinema_showtimes_page.dart';
import 'review_detail_page.dart';

// ⚠️ Điền địa chỉ thư mục chứa ảnh trên Backend Node.js
const String baseUrl = "http://192.168.1.2:3000/"; 

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final PageController _pageController = PageController(viewportFraction: 1.0);
  double _currentPage = 0.0; 

  double totalSpent = 0.0; 
  bool _isLoadingMoney = true;

  int _voucherCount = 0;
  int _watchedCount = 0;
  int _reviewCount = 0;

  final List<Map<String, dynamic>> _tiers = [
    {
      'name': 'Hạng Tập Sự',
      'bgImage': 'assets/tapsu.png',
      'min': 0.0,
      'max': 300000.0,
      'milestones': [{'value': 100000.0, 'icon': Icons.star_border_purple500}],
    },
    {
      'name': 'Hạng Mọt Phim',
      'bgImage': 'assets/motphim.png',
      'min': 300000.0,
      'max': 1000000.0,
      'milestones': [
        {'value': 500000.0, 'icon': Icons.workspace_premium}, 
        {'value': 750000.0, 'icon': Icons.stars}, 
      ],
    },
    {
      'name': 'Hạng Cuồng Phim',
      'bgImage': 'assets/cuongphim.png',
      'min': 1000000.0,
      'max': 5000000.0, 
      'milestones': [{'value': 2500000.0, 'icon': Icons.diamond_outlined}],
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page != null) {
        setState(() => _currentPage = _pageController.page!);
      }
    });
    
    // Lần đầu mở tab sẽ load data
    _fetchTotalSpent();
    _fetchUserStats(); 
  }

  // ✅ ĐÃ THÊM: Hàm gom chung 2 API để làm mới lại toàn bộ trang
  Future<void> _refreshData() async {
    setState(() {
      _isLoadingMoney = true;
    });
    // Gọi song song 2 API cùng lúc cho lẹ
    await Future.wait([
      _fetchTotalSpent(),
      _fetchUserStats(),
    ]);
  }

  Future<void> _fetchTotalSpent() async {
    final user = UserManager.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingMoney = false);
      return;
    }
    try {
      final url = Uri.parse('http://192.168.1.2:3000/api/user/total-spent/${user.id}'); 
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            totalSpent = double.tryParse(data['totalSpent'].toString()) ?? 0.0;
            _isLoadingMoney = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMoney = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMoney = false);
    }
  }

  Future<void> _fetchUserStats() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final url = Uri.parse('http://192.168.1.2:3000/api/user/stats/${user.id}'); 
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 👉 Gắn mắt thần: Xem Node.js đang trả về số mấy
        debugPrint("=== KẾT QUẢ ĐẾM THỐNG KÊ ===");
        debugPrint(data.toString());

        if (mounted) {
          setState(() {
            // ✅ ĐÃ SỬA: Ép kiểu an toàn tuyệt đối bằng int.tryParse
            _voucherCount = int.tryParse(data['vouchers']?.toString() ?? '0') ?? 0;
            _watchedCount = int.tryParse(data['watchedMovies']?.toString() ?? '0') ?? 0;
            _reviewCount  = int.tryParse(data['reviews']?.toString() ?? '0') ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi lấy thông số user: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleLogout(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Đăng xuất"),
        content: const Text("Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Đăng xuất", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      await UserManager.instance.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserManager.instance.currentUser;
    final String userName = user?.name ?? "Khách";
    final Color navyBlue = Colors.blue.shade900;
    
    final double appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true, 
        child: Stack(
          children: [
            // ========================================================
            // 0. BACKGROUND GRADIENT (1/4 MÀN HÌNH TỪ XANH XUỐNG TRẮNG)
            // ========================================================
            Container(
              height: MediaQuery.of(context).size.height * 0.35, 
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF64B5F6), Color(0xFFF5F5F9)], 
                ),
              ),
            ),
            
            // ✅ ĐÃ THÊM: Tính năng vuốt xuống để tải lại (Pull to Refresh)
            RefreshIndicator(
              onRefresh: _refreshData,
              color: Colors.orange, // Màu vòng xoay
              backgroundColor: Colors.white,
              displacement: appBarHeight + 10, // Canh cục xoay hiện ra ngay dưới AppBar
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Bắt buộc AlwaysScrollable để vuốt được cả khi nội dung ngắn
                child: Column(
                  children: [
                    SizedBox(height: appBarHeight - 15),

                    // ========================================================
                    // 1. CAROUSEL BANNER THẺ THÀNH VIÊN
                    // ========================================================
                    SizedBox(
                      height: 220, 
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: _tiers.length,
                            itemBuilder: (context, index) {
                              final tier = _tiers[index];
                              bool isUnlocked = totalSpent >= tier['min'];
                              
                              String currentActualTier = "Hạng Tập Sự";
                              if (totalSpent >= 1000000) currentActualTier = "Hạng Cuồng Phim";
                              else if (totalSpent >= 500000) currentActualTier = "Hạng Mọt Chuyên Gia";
                              else if (totalSpent >= 300000) currentActualTier = "Hạng Mọt Phim";

                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20), 
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                                  image: DecorationImage(image: AssetImage(tier['bgImage']), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20), 
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 48, 
                                                height: 48, 
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle, 
                                                  border: Border.all(color: Colors.white, width: 2), 
                                                  color: Colors.grey.shade400, 
                                                  image: DecorationImage(
                                                    // 🚀 NÂNG CẤP: Lấy ảnh thật của User từ Server
                                                    image: (user?.avatar != null && user!.avatar.isNotEmpty)
                                                        ? NetworkImage(
                                                            user.avatar.startsWith('http') 
                                                                ? user.avatar 
                                                                : 'http://192.168.1.2:3000${user.avatar.startsWith('/') ? '' : '/'}${user.avatar}'
                                                          ) as ImageProvider
                                                        : const AssetImage('assets/avatar_placeholder.png'),
                                                    fit: BoxFit.cover,
                                                  )
                                                )
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                                    const SizedBox(height: 4),
                                                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.5))), child: Text(currentActualTier, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(), 
                                          if (_isLoadingMoney)
                                            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          else if (isUnlocked)
                                            Text("Đã tích được: ${formatter.format(totalSpent)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))
                                          else
                                            const Text("Chưa chinh phục", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          
                                          const SizedBox(height: 20),
                                          _buildCustomProgressBar(tier, isUnlocked ? totalSpent : tier['min'], isUnlocked),
                                          const Spacer(), 
                                        ],
                                      ),
                                      Positioned(
                                        top: 0, right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withOpacity(0.8), width: 1)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.stars, color: Colors.amber, size: 12),
                                              const SizedBox(width: 4),
                                              Text(tier['name'].toUpperCase(), style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0, left: 0, right: 0, 
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Expanded(
                                              child: Text("Hạng càng cao, ưu đãi càng xịn", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PromotionDetailsPage())),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                                                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.info_outline, color: Colors.white, size: 14), SizedBox(width: 4), Text("Xem chi tiết", style: TextStyle(color: Colors.white, fontSize: 12))]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            bottom: 12, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_tiers.length, (idx) {
                                double difference = (_currentPage - idx).abs();
                                double factor = 1.0 - difference.clamp(0.0, 1.0); 
                                return Container(margin: const EdgeInsets.symmetric(horizontal: 3), height: 5, width: 6 + (14 * factor), decoration: BoxDecoration(color: Color.lerp(Colors.white.withOpacity(0.4), Colors.white, factor), borderRadius: BorderRadius.circular(4)));
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ========================================================
                    // 2. DẢI LỐI TẮT NHANH (QUICK STATS)
                    // ========================================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        children: [
                          _buildQuickStatCard(Icons.local_activity_outlined, "Ví Voucher", _voucherCount.toString(), Colors.orange, () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => const UserVoucherPage())
                            ).then((_) {
                              // ✅ QUAN TRỌNG: Gọi tải lại dữ liệu khi quay về
                              _refreshData(); 
                            });
                          }),
                          const SizedBox(width: 12),
                          _buildQuickStatCard(Icons.movie_filter_outlined, "Phim đã xem", _watchedCount.toString(), Colors.blue, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchedMoviesPage()));
                          }),
                          const SizedBox(width: 12),
                          _buildQuickStatCard(Icons.star_border_rounded, "Đánh giá", _reviewCount.toString(), Colors.purple, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const UserReviewsPage()));
                          }),
                        ],
                      ),
                    ),

                    // ========================================================
                    // 3. QUẢNG CÁO GÓI HỘI VIÊN / BẮP NƯỚC
                    // ========================================================
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.orange.shade200, blurRadius: 4)]), child: const Icon(Icons.fastfood, color: Colors.orange, size: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Gói Combo Tiết Kiệm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                Text("Nhận bắp nước thả ga, giá chỉ nửa", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)),
                            onPressed: () {},
                            child: const Text("Mua ngay", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          )
                        ],
                      ),
                    ),

                    // ========================================================
                    // 4. MENU CHỨC NĂNG (GOM THEO NHÓM)
                    // ========================================================
                    const SizedBox(height: 20),
                    
                    _buildMenuGroup("Hoạt động của tôi", [
                      _buildMenuItem(Icons.receipt_long, "Lịch sử giao dịch", navyBlue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()))),
                      _buildMenuItem(Icons.favorite_border, "Phim yêu thích", Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteMoviesPage()))),
                      _buildMenuItem(Icons.storefront_outlined, "Rạp yêu thích", Colors.amber.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteCinemasPage()))),
                    ]),

                    _buildMenuGroup("Tài khoản & Hỗ trợ", [
                      _buildMenuItem(Icons.settings_outlined, "Cài đặt tài khoản", Colors.blueGrey, onTap: () async {
                        // Đợi người dùng sửa ảnh bên trang EditProfile xong và quay lại...
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
                        // ...thì gọi setState để giao diện lấy Avatar mới từ UserManager vẽ lên!
                        setState(() {}); 
                      }),
                      _buildMenuItem(Icons.help_outline, "Trung tâm trợ giúp", Colors.teal),
                      _buildMenuItem(Icons.headset_mic_outlined, "Liên hệ tổng đài", Colors.green),
                    ]),

                    // ========================================================
                    // 5. NÚT ĐĂNG XUẤT
                    // ========================================================
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.red.shade50),
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                        label: const Text("Đăng xuất", style: TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 120), 
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ HÀM HỖ TRỢ VẼ UI
  Widget _buildQuickStatCard(IconData icon, String title, String count, Color color, VoidCallback onTap) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            children: items.asMap().entries.map((entry) {
              int idx = entry.key;
              Widget item = entry.value;
              return Column(
                children: [
                  item,
                  if (idx < items.length - 1) const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF0F0F0)),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color, {VoidCallback? onTap, int badgeCount = 0}) {
    return ListTile(
      onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển'))),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }

  Widget _buildCustomProgressBar(Map<String, dynamic> tier, double spent, bool isUnlocked) {
    double min = tier['min'];
    double max = tier['max'];
    List<Map<String, dynamic>> milestones = tier['milestones'];
    double progressPercent = ((spent - min) / (max - min)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        List<Widget> stackChildren = [
          Container(width: maxWidth, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
          Container(width: maxWidth * progressPercent, height: 6, decoration: BoxDecoration(color: const Color(0xFFFF7043), borderRadius: BorderRadius.circular(10))),
          Positioned(left: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF7043), width: 3)))),
          Positioned(right: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: progressPercent == 1.0 ? const Color(0xFFFF7043) : Colors.white, width: 3)))),
        ];
        for (var ms in milestones) {
          double mPercent = ((ms['value'] - min) / (max - min)).clamp(0.0, 1.0);
          bool isMilestoneUnlocked = spent >= ms['value'];

          stackChildren.add(
            Positioned(
              left: (maxWidth * mPercent) - 18, top: -15, 
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: isUnlocked ? (isMilestoneUnlocked ? Colors.white : Colors.grey.shade300) : Colors.grey.shade400, shape: BoxShape.circle, border: Border.all(color: isMilestoneUnlocked ? const Color(0xFFFF7043) : Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(ms['icon'], size: 20, color: isUnlocked ? (isMilestoneUnlocked ? const Color(0xFFFF7043) : Colors.grey.shade600) : Colors.grey.shade600),
                    if (!isMilestoneUnlocked || !isUnlocked) Positioned(top: -2, right: -4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.lock, size: 10, color: Colors.black87)))
                  ],
                ),
              ),
            ),
          );
        }
        return Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: stackChildren);
      },
    );
  }
}

// =====================================================================
// ==================== 3 TRANG MỚI GẮN VÀO DƯỚI NÀY ===================
// =====================================================================

// ✅ 1. TRANG VÍ VOUCHER
class UserVoucherPage extends StatefulWidget {
  const UserVoucherPage({super.key});
  @override
  State<UserVoucherPage> createState() => _UserVoucherPageState();
}

class _UserVoucherPageState extends State<UserVoucherPage> {
  List<dynamic> _vouchers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  Future<void> _fetchVouchers() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/vouchers/user/${user.id}'));
      if (res.statusCode == 200) {
        _vouchers = json.decode(res.body);
        // 👉 Gắn Mắt thần: In ra console để xem có lấy được mã không
        debugPrint("=== DỮ LIỆU VÍ VOUCHER ===");
        debugPrint(_vouchers.toString()); 
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Lỗi tải ví: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ========================================================
    // ✅ TUYỆT CHIÊU: Bọc .toString() để Số 0 hay Chữ "0" đều bắt được hết!
    // ========================================================
    final available = _vouchers.where((v) {
      var state = v['Used'] ?? v['Status'] ?? 0;
      return state.toString() == '0'; 
    }).toList();

    final used = _vouchers.where((v) {
      var state = v['Used'] ?? v['Status'] ?? 0;
      return state.toString() == '1';
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Ví Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900))),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: Container(
              color: Colors.white, 
              child: TabBar(
                indicatorColor: Colors.blue.shade900,
                labelColor: Colors.blue.shade900,    
                unselectedLabelColor: Colors.grey.shade600,
                tabs: [
                  Tab(text: "Đã lưu (${available.length})"), 
                  Tab(text: "Đã sử dụng (${used.length})")
                ],
              ),
            ),
          ),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildVoucherList(available, false),
                  _buildVoucherList(used, true),
                ],
              ),
      ),
    );
  }

 Widget _buildVoucherList(List<dynamic> list, bool isUsed) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_activity_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isUsed ? "Chưa có voucher nào được dùng" : "Bạn không có voucher nào", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final v = list[index];
        // Đọc đúng tên cột từ MySQL
        String code = v['Code']?.toString() ?? "VOUCHER";
        int percent = int.tryParse(v['DiscountPercent']?.toString() ?? '0') ?? 0;
        
        String expiredStr = v['ExpiredAt']?.toString() ?? "";
        String formattedDate = "Đang cập nhật";
        try {
          if (expiredStr.isNotEmpty) {
            DateTime dt = DateTime.parse(expiredStr).toLocal();
            formattedDate = DateFormat('dd/MM/yyyy').format(dt);
          }
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUsed ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            border: isUsed ? Border.all(color: Colors.grey.shade300) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: isUsed ? Colors.grey.shade300 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Giảm", style: TextStyle(color: isUsed ? Colors.grey : Colors.blue.shade800, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text("$percent%", style: TextStyle(color: isUsed ? Colors.grey : Colors.blue.shade800, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Mã: $code", style: TextStyle(color: isUsed ? Colors.grey : Colors.blue.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text("Giảm $percent% cho mọi đơn hàng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isUsed ? Colors.grey : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(isUsed ? "Đã sử dụng" : "HSD: $formattedDate", style: TextStyle(fontSize: 12, color: isUsed ? Colors.grey : Colors.red.shade400, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ✅ 2. TRANG PHIM ĐÃ XEM 
class WatchedMoviesPage extends StatefulWidget {
  const WatchedMoviesPage({super.key});
  @override
  State<WatchedMoviesPage> createState() => _WatchedMoviesPageState();
}

class _WatchedMoviesPageState extends State<WatchedMoviesPage> {
  List<dynamic> _allMovies = [];
  String _selectedMonth = "Tất cả";
  List<String> _months = ["Tất cả"];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWatchedMovies();
  }

  Future<void> _fetchWatchedMovies() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/user/watched-movies/${user.id}'));
      if (res.statusCode == 200) {
        _allMovies = json.decode(res.body);
        Set<String> monthSet = {"Tất cả"};
        for (var m in _allMovies) {
          if (m['month_year'] != null) monthSet.add("Tháng ${m['month_year']}");
        }
        _months = monthSet.toList();
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRealImageUrl(String rawPath) {
    if (rawPath.isEmpty) return "";
    if (rawPath.startsWith("http")) return rawPath;
    if (rawPath.startsWith("/")) return "https://image.tmdb.org/t/p/w500$rawPath";
    String cleanPath = rawPath.replaceAll('\\', '/');
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return "http://192.168.1.2:3000$cleanPath"; 
  }

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900;
    
    List<dynamic> displayedMovies = _selectedMonth == "Tất cả" 
        ? _allMovies 
        : _allMovies.where((m) => "Tháng ${m['month_year']}" == _selectedMonth).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Phim đã xem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month, color: navyBlue, size: 20),
                          const SizedBox(width: 8),
                          const Text("Thời gian xem:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 14)),
                        ],
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMonth,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                          items: _months.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                          onChanged: (val) { 
                            if (val != null) setState(() => _selectedMonth = val); 
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: displayedMovies.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.movie_filter_outlined, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), Text("Không có bộ phim nào.", style: TextStyle(color: Colors.grey.shade500))]))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: displayedMovies.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final movie = displayedMovies[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(_getRealImageUrl(movie['image']?.toString() ?? ""), width: 60, height: 85, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 60, height: 85, color: Colors.grey.shade200, child: const Icon(Icons.movie, color: Colors.grey))),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(movie['movie']?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 6),
                                        Text(movie['cinema']?.toString() ?? "", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text("Xem lúc: ${movie['date']}", style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ✅ 3. TRANG LỊCH SỬ ĐÁNH GIÁ 
class UserReviewsPage extends StatefulWidget {
  const UserReviewsPage({super.key});
  @override
  State<UserReviewsPage> createState() => _UserReviewsPageState();
}

class _UserReviewsPageState extends State<UserReviewsPage> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/user/reviews/${user.id}'));
      if (res.statusCode == 200) _reviews = json.decode(res.body);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRealImageUrl(String rawPath) {
    if (rawPath.isEmpty) return "";
    if (rawPath.startsWith("http")) return rawPath;
    if (rawPath.startsWith("/")) return "https://image.tmdb.org/t/p/w500$rawPath";
    String cleanPath = rawPath.replaceAll('\\', '/');
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return "http://192.168.1.2:3000$cleanPath"; 
  }

  // ✅ HÀM NẶN ĐỐI TƯỢNG MOVIE ĐỂ TRUYỀN SANG TRANG DETAIL
  Movie _getMovieFromReviewData(Map<String, dynamic> data) {
    String rawPoster = data['poster_path']?.toString() ?? '';
    String fullPosterUrl = rawPoster.isNotEmpty 
        ? (rawPoster.startsWith('http') ? rawPoster : 'https://image.tmdb.org/t/p/w500$rawPoster') 
        : '';

    String rawBackdrop = data['backdrop_path']?.toString() ?? '';
    String fullBackdropUrl = rawBackdrop.isNotEmpty 
        ? (rawBackdrop.startsWith('http') ? rawBackdrop : 'https://image.tmdb.org/t/p/w780$rawBackdrop') 
        : fullPosterUrl;

    return Movie(
      id: int.tryParse(data['movieId']?.toString() ?? '0') ?? 0,
      title: data['movie']?.toString() ?? 'Chưa có tên phim',
      overview: data['overview']?.toString() ?? 'Chưa có thông tin...',
      posterPath: fullPosterUrl,
      backdropPaths: fullBackdropUrl.isNotEmpty ? [fullBackdropUrl] : [], 
      genres: data['genres']?.toString() ?? 'Phim chiếu rạp',
      voteAverage: double.tryParse(data['vote_average']?.toString() ?? '0') ?? 0.0,
      language: 'Phụ đề',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Đánh giá của bạn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          // ✅ BỌC REFRESH INDICATOR ĐỂ VUỐT TẢI LẠI TRANG
          : RefreshIndicator(
              onRefresh: _fetchReviews,
              color: Colors.purple,
              backgroundColor: Colors.white,
              child: _reviews.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey.shade300), 
                        const SizedBox(height: 16), 
                        Text("Bạn chưa viết đánh giá nào.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final review = _reviews[index];
                        return InkWell(
                          // ✅ ĐÃ SỬA CHUYỂN HƯỚNG SANG TRANG REVIEW DETAIL PAGE
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReviewDetailPage(
                                  review: review,
                                  movie: _getMovieFromReviewData(review),
                                  navyBlue: Colors.blue.shade900,
                                  starColor: Colors.amber,
                                )
                              )
                            );
                            // Cập nhật lại list sau khi user thoát khỏi trang Detail (lỡ user xóa review thì nó tự cập nhật)
                            _fetchReviews();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(_getRealImageUrl(review['image']?.toString() ?? ""), width: 40, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 40, height: 60, color: Colors.grey.shade200)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(review['movie']?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              Text("${review['rating'] ?? 0}/10", style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const Spacer(),
                                              Text(review['date']?.toString() ?? "", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
                                  ],
                                ),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                                Text('"${review['comment']}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87, fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
// ✅ 4. TRANG PHIM YÊU THÍCH (ĐÃ NÂNG CẤP AUTO-REFRESH & PULL-TO-REFRESH)
class FavoriteMoviesPage extends StatefulWidget {
  const FavoriteMoviesPage({super.key});

  @override
  State<FavoriteMoviesPage> createState() => _FavoriteMoviesPageState();
}

class _FavoriteMoviesPageState extends State<FavoriteMoviesPage> {
  List<dynamic> _favoriteMovies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFavoriteMovies();
  }

  // ✅ ĐÃ SỬA: Đưa _favoriteMovies vào trong setState để mỗi lần gọi lại là màn hình vẽ lại ngay
  Future<void> _fetchFavoriteMovies() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/user/favorites/${user.id}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _favoriteMovies = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(int movieId) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    
    setState(() {
      _favoriteMovies.removeWhere((m) => m['id'] == movieId);
    });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã bỏ yêu thích bộ phim này.')));

    try {
      await http.post(
        Uri.parse('http://192.168.1.2:3000/api/favorites/movie/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id,
          'movie_id': movieId,
          'is_favorite': false, 
        }),
      );
    } catch (e) {
      debugPrint('Lỗi bỏ yêu thích: $e');
    }
  }

  String _getRealImageUrl(String rawPath) {
    if (rawPath.isEmpty) return "";
    if (rawPath.startsWith("http")) return rawPath;
    if (rawPath.startsWith("/")) return "https://image.tmdb.org/t/p/w500$rawPath";
    String cleanPath = rawPath.replaceAll('\\', '/');
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return "http://192.168.1.2:3000$cleanPath"; 
  }

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Phim yêu thích', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          // ==========================================================
          // ✅ BỌC TOÀN BỘ BẰNG RefreshIndicator ĐỂ VUỐT XUỐNG RELOAD
          // ==========================================================
          : RefreshIndicator(
              onRefresh: _fetchFavoriteMovies,
              color: Colors.red, // Vòng xoay màu đỏ cho hợp với theme Yêu thích
              backgroundColor: Colors.white,
              child: _favoriteMovies.isEmpty
                  ? ListView(
                      // Bắt buộc dùng AlwaysScrollableScrollPhysics thì danh sách trống mới vuốt xuống được
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Icon(Icons.heart_broken_outlined, size: 80, color: Colors.grey.shade300), 
                        const SizedBox(height: 16), 
                        Text("Danh sách yêu thích đang trống.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _favoriteMovies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final movieData = _favoriteMovies[index];
                        return InkWell(
                          // ==========================================================
                          // ✅ TUYỆT CHIÊU AUTO-REFRESH KHI QUAY VỀ
                          // ==========================================================
                          onTap: () async {
                            final movieObject = MovieModel.fromJson(movieData);
                            // Dùng "await" để chờ user xem xong trang chi tiết
                            await Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movieObject))
                            );
                            // Khi user bấm nút Back quay lại đây, code này sẽ chạy và tự reload data!
                            _fetchFavoriteMovies();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(_getRealImageUrl(movieData['image']?.toString() ?? ""), width: 70, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 70, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.movie, color: Colors.grey))),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(movieData['title']?.toString() ?? "", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyBlue), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text(movieData['genres']?.toString() ?? "Đang cập nhật", style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.orange, size: 14),
                                          const SizedBox(width: 4),
                                          Text(movieData['rating']?.toString() ?? "0.0", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.access_time, color: Colors.grey, size: 14),
                                          const SizedBox(width: 4),
                                          Text("${movieData['duration']} phút", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () => _removeFavorite(movieData['id']),
                                  icon: const Icon(Icons.favorite, color: Colors.red, size: 26),
                                ),
                                const SizedBox(height: 6),
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 26),
                              ],
                            ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
// ✅ 5. TRANG RẠP YÊU THÍCH (AUTO-REFRESH + CHUYỂN TRANG MƯỢT MÀ)
class FavoriteCinemasPage extends StatefulWidget {
  const FavoriteCinemasPage({super.key});

  @override
  State<FavoriteCinemasPage> createState() => _FavoriteCinemasPageState();
}

class _FavoriteCinemasPageState extends State<FavoriteCinemasPage> {
  List<dynamic> _favoriteCinemas = [];
  bool _isLoading = true;
  final Color navyBlue = Colors.blue.shade900;

  @override
  void initState() {
    super.initState();
    _fetchFavoriteCinemas();
  }

  Future<void> _fetchFavoriteCinemas() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/user/favorites/cinemas/${user.id}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) setState(() {
          _favoriteCinemas = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(int cinemaId) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    
    setState(() { _favoriteCinemas.removeWhere((c) => c['id'] == cinemaId); });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã bỏ yêu thích rạp này.')));

    try {
      await http.post(
        Uri.parse('http://192.168.1.2:3000/api/favorites/cinema/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id, 'cinema_id': cinemaId, 'is_favorite': false}),
      );
    } catch (e) {
      debugPrint('Lỗi bỏ yêu thích rạp: $e');
    }
  }

  String _getLogoForCinema(String cinemaName) {
    String nameLower = cinemaName.toLowerCase();
    if (nameLower.contains('cgv')) return 'assets/cgv1.png';
    if (nameLower.contains('lotte')) return 'assets/lotte.png';
    if (nameLower.contains('galaxy')) return 'assets/galaxy.png';
    if (nameLower.contains('bhd')) return 'assets/bhd.png';
    if (nameLower.contains('cinestar')) return 'assets/cinestar.png';
    if (nameLower.contains('mega gs') || nameLower.contains('megags')) return 'assets/megags.png';
    if (nameLower.contains('dcine')) return 'assets/dcine.png';
    if (nameLower.contains('aeon beta') || nameLower.contains('aeonbeta')) return 'assets/aeonbeta.png';
    if (nameLower.contains('beta')) return 'assets/betacinema.png';
    return 'assets/dexuat.png'; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Rạp yêu thích', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFavoriteCinemas,
              color: Colors.red,
              backgroundColor: Colors.white,
              child: _favoriteCinemas.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Icon(Icons.storefront_outlined, size: 80, color: Colors.grey.shade300), 
                        const SizedBox(height: 16), 
                        Text("Bạn chưa thích rạp nào.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _favoriteCinemas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final cinema = _favoriteCinemas[index];
                        return InkWell(
                          onTap: () async {
                            // Chuyển tới màn hình lịch chiếu của rạp đó
                            await Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => CinemaShowtimesPage(
                                cinemaId: cinema['id'].toString(), 
                                cinemaName: cinema['name'], 
                                cinemaAddress: cinema['address']
                              ))
                            );
                            // Auto-refresh khi quay lại
                            _fetchFavoriteCinemas();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8), 
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)), 
                                  child: Image.asset(_getLogoForCinema(cinema['name']), width: 45, height: 45, fit: BoxFit.contain)
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cinema['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyBlue), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text(cinema['address'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () => _removeFavorite(cinema['id']),
                                      icon: const Icon(Icons.favorite, color: Colors.red, size: 26),
                                    ),
                                    const SizedBox(height: 2),
                                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 26),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}