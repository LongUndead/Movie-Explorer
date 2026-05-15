import 'package:flutter/material.dart';
import 'home_page.dart'; 
import 'cart_page.dart';
// 1. DÒNG MỚI: Import file menu chọn rạp bạn vừa tạo
import 'cinema_menu_page.dart'; 

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final Color navyBlue = Colors.blue.shade900; 

  int notificationCount = 3;

  // 2. DÒNG ĐÃ SỬA: Thay cục Text giả lập bằng CinemaMenuPage thật
  late final List<Widget> _pages = [
    const HomePage(), 
    const CinemaMenuPage(), // <--- ĐÃ NỐI VÀO TAB SỐ 2 (Index 1)
    const Center(child: Text('Trang Bắp nước')),
    const Center(child: Text('Trang Nhóm phim')),
    const Center(child: Text('Trang Tài khoản')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), 
      appBar: _buildAppBar(), 
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  // ==========================================
  // APPBAR GRADIENT & BOX HẠT NHỘNG (GIỮ NGUYÊN 100%)
  // ==========================================
  PreferredSizeWidget _buildAppBar() {
    final String title = _selectedIndex == 1 ? 'Chọn rạp phim' : 'CINEMA TICKETS';

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade300, Colors.blue.shade50],
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. NÚT CHUÔNG THÔNG BÁO
              InkWell(
                onTap: () {
                  setState(() => notificationCount = 0);
                  _showNotificationBottomSheet(); 
                },
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _buildIconWithBadge(Icons.notifications_none, notificationCount),
                ),
              ),
              Container(
                height: 16, width: 1, color: navyBlue.withOpacity(0.2), 
              ),
              // 2. NÚT GIỎ HÀNG (Lắng nghe CartManager)
              ListenableBuilder(
                listenable: CartManager.instance,
                builder: (context, child) {
                  int cartItemCount = CartManager.instance.totalSeatsCount;
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const CartPage())
                      );
                    },
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: _buildIconWithBadge(Icons.shopping_cart_outlined, cartItemCount),
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ],
    );
  }

 Widget _buildIconWithBadge(IconData icon, int count) {
    return SizedBox(
      width: 26, 
      height: 26, 
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center, 
        children: [
          Icon(icon, color: navyBlue, size: 22),
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
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 8, 
                    fontWeight: FontWeight.bold, 
                    height: 1
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // LOGIC XỔ DANH SÁCH THÔNG BÁO TỪ DƯỚI LÊN (GIỮ NGUYÊN)
  // ==========================================
  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
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
              Text("Thông báo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
              const Divider(height: 30),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildNotificationItem("🎫 Đặt vé thành công!", "Bạn đã đặt thành công 2 vé phim 'Hẹn Em Ngày Nhật Thực'. Rạp CGV Sư Vạn Hạnh, Suất 19:00 hôm nay.", "Vừa xong", true),
                    _buildNotificationItem("🔥 Phim HOT mở bán", "Bom tấn 'Thoát Khỏi Tận Thế' đã chính thức mở bán vé sớm. Mua ngay kẻo lỡ!", "2 giờ trước", false),
                    _buildNotificationItem("🎁 Quà tặng cho bạn", "Tặng bạn voucher giảm 20K cho bắp nước khi xem phim cuối tuần này. Áp dụng mã: STU20", "Hôm qua", false),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildNotificationItem(String title, String desc, String time, bool isUnread) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isUnread ? navyBlue : Colors.grey.shade300, shape: BoxShape.circle),
            child: Icon(Icons.confirmation_num_outlined, color: isUnread ? Colors.white : Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
                const SizedBox(height: 8),
                Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION BAR (GIỮ NGUYÊN)
  // ==========================================
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
        onTap: () => setState(() => _selectedIndex = index),
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