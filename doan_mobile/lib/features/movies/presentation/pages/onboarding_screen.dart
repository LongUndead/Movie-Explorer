import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Color primaryBlue = const Color(0xFF1565C0);

  // Data cho 3 màn hình lướt
  final List<Map<String, dynamic>> onboardingData = [
    {
      "title": "Chào mừng đến với\nCinematickets",
      "description": "Khám phá và đặt vé những bộ phim yêu thích một cách dễ dàng. Tận hưởng các ưu đãi và phần thưởng độc quyền!",
      "image": "assets/onboard_1.png", 
      "icon": Icons.local_movies_rounded
    },
    {
      "title": "Đặt Ghế Của Bạn",
      "description": "Tìm vị trí ngồi đẹp nhất tại rạp và đặt trước cho những bộ phim bom tấn mà bạn yêu thích.",
      "image": "assets/onboard_2.png", 
      "icon": Icons.chair_rounded
    },
    {
      "title": "Trải Nghiệm Tuyệt Vời",
      "description": "Bắp thơm, nước ngọt và không gian điện ảnh đỉnh cao đang chờ đón bạn. Bắt đầu ngay thôi!",
      "image": "assets/onboard_3.png", 
      "icon": Icons.fastfood_rounded
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header: Tên App và nút Skip (Bỏ qua)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title App đồng bộ với màn hình Login/Register
                  Text(
                    "CINEMATICKETS", 
                    style: TextStyle(
                      color: primaryBlue, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 14, 
                      letterSpacing: 1.2
                    )
                  ),
                  // Nút Skip (Bỏ qua)
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: Text("Bỏ qua", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            // Khu vực vuốt màn hình
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ảnh minh họa
                        Image.asset(
                          onboardingData[index]["image"],
                          height: 250,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(onboardingData[index]["icon"], size: 150, color: Colors.amber.shade400),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          onboardingData[index]["title"],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          onboardingData[index]["description"],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dấu chấm chuyển trang
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 6),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? primaryBlue : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Nút ĐĂNG KÝ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: const Text("ĐĂNG KÝ", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nút ĐĂNG NHẬP
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: Text("ĐĂNG NHẬP", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}