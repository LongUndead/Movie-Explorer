import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async'; // 🚀 Thêm thư viện Timer để làm banner tự trượt

import '../../domain/entities/movie.dart';
import '../../domain/entities/food_model.dart';
import 'cart_page.dart';
import 'checkout_screen.dart'; 

class FoodSelectionScreen extends StatefulWidget {
  final Movie movie;
  final String cinemaName;
  final String selectedDate;
  final String selectedTime;
  final String roomName; 
  final int showtimeId;

  const FoodSelectionScreen({
    super.key,
    required this.movie,
    required this.cinemaName,
    required this.selectedDate,
    required this.selectedTime,
    required this.roomName, 
    required this.showtimeId,
  });

  @override
  State<FoodSelectionScreen> createState() => _FoodSelectionScreenState();
}

class _FoodSelectionScreenState extends State<FoodSelectionScreen> with TickerProviderStateMixin {
  final Color navyBlue = Colors.blue.shade900;
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  List<Food> _foods = [];
  bool _isLoading = true;
  
  final GlobalKey _cartKey = GlobalKey();

  // 🚀 THÊM BIẾN CHO BANNER TRƯỢT NGANG TỪ HOME SANG
  PageController? _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  final List<String> _bannerImages = [
    'assets/banner-1.png',
    'assets/banner-2.png',
    'assets/banner-3.png',
  ];

  @override
  void initState() {
    super.initState();
    _fetchFoods();
    
    // Khởi tạo trình chạy tự động trượt banner giống Home
    _bannerPageController = PageController(initialPage: 0);
    _setupBannerAutoScroll(); 
  }

  // 🚀 HÀM TỰ ĐỘNG CHẠY BANNER
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
    _bannerTimer?.cancel();
    _bannerPageController?.dispose();
    super.dispose();
  }

  int _getBrandIdFromCinema(String cinemaName) {
    String text = cinemaName.toLowerCase();
    if (text.contains('cgv')) return 1;
    if (text.contains('galaxy')) return 2;
    if (text.contains('lotte')) return 3;
    if (text.contains('bhd')) return 4;
    if (text.contains('cinestar')) return 5;
    if (text.contains('mega')) return 6;
    if (text.contains('dcine')) return 7;
    if (text.contains('beta')) return 8;
    return 1;
  }

  Future<void> _fetchFoods() async {
    try {
      int brandId = _getBrandIdFromCinema(widget.cinemaName);
      final res = await http.get(Uri.parse('http://10.173.120.41:3000/api/foods?brand_id=$brandId'));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _foods = data.map<Food>((e) => Food.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải bắp nước: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _getQuantityInCart(Food food) {
    final items = CartManager.instance.foods.where((f) => 
        f.food.id == food.id && 
        f.cinemaName == widget.cinemaName && 
        f.receiveDate == widget.selectedDate
    );
    return items.isEmpty ? 0 : items.first.quantity;
  }

  String _getFoodImagePath(Food food) {
    String dbImage = (food.imageUrl ?? '').trim();
    if (dbImage.isEmpty || dbImage == 'null') return 'assets/cgv/default.png';

    if (dbImage.contains('public/foods') || dbImage.contains('food-')) {
      String filename = dbImage.split('/').last; 
      return 'http://10.173.120.41:3000/public/foods/$filename'; 
    }

    if (dbImage.startsWith('http')) return dbImage;

    final folders = {1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags', 7: 'dcine', 8: 'beta', 9: 'aeonbeta'};
    String folder = folders[food.brandId] ?? 'cgv';
    
    if (dbImage.startsWith('/')) dbImage = dbImage.substring(1);
    if (dbImage.startsWith('assets/')) return dbImage;
    if (dbImage.startsWith('$folder/')) return 'assets/$dbImage';
    
    return 'assets/$folder/$dbImage';
  }

  Widget _buildFoodImage(String imagePath, {required double size}) {
    if (imagePath.isEmpty || imagePath == 'null') {
      return Container(width: size, height: size, color: Colors.grey.shade200, child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: size * 0.6));
    }
    
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath, 
        width: size, height: size, fit: BoxFit.cover, 
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(width: size, height: size, color: Colors.grey.shade100, child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
        },
        errorBuilder: (_, __, ___) => Container(width: size, height: size, color: Colors.grey.shade200, child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: size * 0.6))
      );
    }
    
    return Image.asset(
      imagePath, 
      width: size, height: size, fit: BoxFit.cover, 
      errorBuilder: (_, __, ___) => Container(width: size, height: size, color: Colors.grey.shade200, child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: size * 0.6))
    );
  }

  void _runAddToCartAnimation(BuildContext startContext, String imgPath) {
    final RenderBox? itemBox = startContext.findRenderObject() as RenderBox?;
    if (itemBox == null) return;
    final Offset startOffset = itemBox.localToGlobal(Offset.zero);

    final RenderBox? cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartBox == null) return;
    final Offset endOffset = cartBox.localToGlobal(Offset.zero);

    AnimationController animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    final Animation<double> moveCurve = CurvedAnimation(parent: animController, curve: Curves.easeInOutCubic);
    final Animation<double> sizeCurve = Tween<double>(begin: 1.0, end: 0.2).animate(animController);

    OverlayEntry? currentEntry;

    currentEntry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: animController,
          builder: (context, child) {
            double x = startOffset.dx + (endOffset.dx - startOffset.dx) * moveCurve.value;
            double y = startOffset.dy + (endOffset.dy - startOffset.dy) * moveCurve.value;
            double bounce = sin(moveCurve.value * pi) * -80; 

            return Positioned(
              left: x,
              top: y + bounce,
              child: Transform.scale(
                scale: sizeCurve.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: _buildFoodImage(imgPath, size: 50),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(currentEntry);

    animController.forward().then((_) {
      currentEntry?.remove();
      animController.dispose();
    });
  }

  Widget _buildCartIconWithBadge() {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        int count = CartManager.instance.totalSeatsCount + CartManager.instance.totalFoodsCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.shopping_cart_outlined, color: navyBlue, size: 20),
            if (count > 0)
              Positioned(
                top: -6, right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1)
                  ),
                ),
              ),
          ],
        );
      }
    );
  }

  // 🚀 HÀM VẼ BANNER QUẢNG CÁO BÊ TỪ FILE HOME QUA
  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight, 
              colors: [Colors.blue.shade300, Colors.blue.shade50]
            )
          ),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Combo - Bắp nước', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: _cartKey,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: _buildCartIconWithBadge(),
                  ),
                ),
                Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.home_outlined, color: navyBlue, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: navyBlue))
        : ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              // 🚀 ĐÃ BỎ KHUNG CHỮ VOUCHER CŨ, THAY BẰNG BANNER TRƯỢT NGANG Y HỆT TRANG CHỦ
              _buildPromoBanner(),
              
              const Text("Danh sách bắp nước", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text("Bắp thơm nước ngọt mời bạn xơi nha!", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 16),

              ..._foods.map((food) => _buildFoodItem(food)).toList(),
              const SizedBox(height: 80), 
            ],
          ),
      bottomNavigationBar: _buildBottomCheckoutBar(),
    );
  }

  Widget _buildFoodItem(Food food) {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        int qty = _getQuantityInCart(food);
        String imgPath = _getFoodImagePath(food);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildFoodImage(imgPath, size: 80),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    
                    Text(
                      (food.description.isNotEmpty ? food.description : "1 Bắp lớn, 2 Nước ngọt").replaceAll(RegExp(r',\s*'), ',\n'), 
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4), 
                    ),
                    
                    const SizedBox(height: 8),
                    Text(formatter.format(food.price), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        _buildQtyBtn(Icons.remove, qty > 0 ? navyBlue : Colors.grey.shade300, () {
                          if (qty > 0) CartManager.instance.updateFoodCart(food: food, cinemaName: widget.cinemaName, date: widget.selectedDate, quantity: qty - 1);
                        }),
                        Container(
                          width: 40, alignment: Alignment.center,
                          child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Builder(
                          builder: (btnContext) {
                            return _buildQtyBtn(Icons.add, navyBlue, () {
                              CartManager.instance.updateFoodCart(food: food, cinemaName: widget.cinemaName, date: widget.selectedDate, quantity: qty + 1);
                              _runAddToCartAnimation(btnContext, imgPath); 
                            });
                          }
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildQtyBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildBottomCheckoutBar() {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        int total = CartManager.instance.grandTotal; 
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tạm tính', style: TextStyle(fontSize: 14, color: Colors.black54)),
                    Text(formatter.format(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
              SizedBox(
                width: 150, height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(movie: widget.movie, cinemaName: widget.cinemaName, selectedDate: widget.selectedDate, selectedTime: widget.selectedTime, roomName: widget.roomName, showtimeId: widget.showtimeId)));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: const Text('Tiếp tục', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}