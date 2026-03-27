import 'package:flutter/material.dart';
import 'home_page.dart'; // Bắt buộc phải import file home_page

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  // ✅ ĐỒNG BỘ: Đổi sang màu Xanh Navy (shade900) giống trang chọn rạp
  final Color navyBlue = Colors.blue.shade900; 

  // LƯU Ý QUAN TRỌNG: Gọi HomePage() ở đây, không dùng MovieStoreContent nữa
  late final List<Widget> _pages = [
    const HomePage(), 
    const Center(child: Text('Trang Chọn rạp')),
    const Center(child: Text('Trang Bắp nước')),
    const Center(child: Text('Trang Nhóm phim')),
    const Center(child: Text('Trang Tài khoản')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // ✅ ĐỒNG BỘ: Nền xám nhạt
      appBar: _buildAppBar(), // ✅ ĐỒNG BỘ: Gắn AppBar Gradient xéo vào đây
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  // ==========================================
  // ✅ ĐỒNG BỘ: APPBAR GRADIENT & BOX HẠT NHỘNG
  // ==========================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      title: Text(
        "STU CINEMA",
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
        // Box "Hạt nhộng" chứa 2 icon: Thông báo và Tìm kiếm
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {},
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Icon(Icons.notifications_none, color: navyBlue, size: 18),
                ),
              ),
              Container(
                height: 16, width: 1, color: navyBlue.withOpacity(0.2), // Vách ngăn dọc mờ
              ),
              InkWell(
                onTap: () {},
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Icon(Icons.search, color: navyBlue, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBottomNavBar() {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)), // ✅ ĐỒNG BỘ: Bo tròn 2 góc trên
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      // Bọc ClipRRect để bo góc trên mượt mà không bị lẹm viền
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
            border: Border(top: BorderSide(color: isSelected ? navyBlue : Colors.transparent, width: 3)), // ✅ ĐỒNG BỘ: Dùng màu xanh navy
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isSelected ? solidIcon : outlineIcon, color: isSelected ? navyBlue : Colors.grey, size: 24), // ✅ ĐỒNG BỘ: Dùng màu xanh navy
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
              Text(label, style: TextStyle(color: isSelected ? navyBlue : Colors.grey, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), // ✅ ĐỒNG BỘ: Dùng màu xanh navy
            ],
          ),
        ),
      ),
    );
  }
}
// TUYỆT ĐỐI KHÔNG DÁN THÊM BẤT KỲ CLASS NÀO DƯỚI DÒNG NÀY NỮA