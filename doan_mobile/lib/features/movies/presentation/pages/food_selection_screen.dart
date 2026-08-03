import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

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

  @override
  void initState() {
    super.initState();
    _fetchFoods();
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
      final res = await http.get(Uri.parse('http://192.168.1.7:3000/api/foods?brand_id=$brandId'));
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

  // =====================================================
  // 🚀 1. HÀM XỬ LÝ ẢNH BẮP NƯỚC TỪ ADMIN (Đã fix folder)
  // =====================================================
  String _getFoodImagePath(Food food) {
    String dbImage = (food.imageUrl ?? '').trim();
    if (dbImage.isEmpty || dbImage == 'null') return 'assets/cgv/default.png';

    if (dbImage.contains('public/foods') || dbImage.contains('food-')) {
      String filename = dbImage.split('/').last; 
      return 'http://192.168.1.7:3000/public/foods/$filename'; 
    }

    if (dbImage.startsWith('http')) return dbImage;

    final folders = {1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags', 7: 'dcine', 8: 'beta', 9: 'aeonbeta'};
    String folder = folders[food.brandId] ?? 'cgv';
    
    if (dbImage.startsWith('/')) dbImage = dbImage.substring(1);
    if (dbImage.startsWith('assets/')) return dbImage;
    if (dbImage.startsWith('$folder/')) return 'assets/$dbImage';
    
    return 'assets/$folder/$dbImage';
  }

  // =====================================================
  // 🚀 2. HÀM VẼ ẢNH THÔNG MINH CHỐNG LỖI XÁM XỊT
  // =====================================================
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

  // ==========================================
  // ✅ ĐÃ SỬA: CHỈNH THỜI GIAN BAY CHẬM LẠI THÀNH 1000ms (1 GIÂY)
  // ==========================================
  void _runAddToCartAnimation(BuildContext startContext, String imgPath) {
    final RenderBox? itemBox = startContext.findRenderObject() as RenderBox?;
    if (itemBox == null) return;
    final Offset startOffset = itemBox.localToGlobal(Offset.zero);

    final RenderBox? cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartBox == null) return;
    final Offset endOffset = cartBox.localToGlobal(Offset.zero);

    // Tăng thời gian từ 600 lên 1000 milliseconds để bay chậm hơn
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
                  child: _buildFoodImage(imgPath, size: 50), // 🚀 ĐÃ GỌI HÀM VẼ ẢNH THÔNG MINH
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
            Icon(Icons.shopping_cart_outlined, color: navyBlue, size: 20), // Đổi về size 20 cho bằng ngôi nhà
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      // ==========================================
      // ✅ ĐÃ SỬA: ĐỒNG BỘ GIAO DIỆN BOX CHỨA GIỎ HÀNG VÀ HOME NHƯ MẪU
      // ==========================================
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade100, Colors.white], 
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: navyBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Combo - Bắp nước', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: _cartKey, // Gắn Key tại đây để làm tọa độ đích cho hiệu ứng bay
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: _buildCartIconWithBadge(), 
                  ),
                ),
                Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)), // Thanh dọc phân cách
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Icon(Icons.home_outlined, color: navyBlue, size: 20),
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
              Container(
                height: 100, width: double.infinity,
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text("🎫 Tặng Voucher 20K khi mua Bắp Nước Online!", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              
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
                child: _buildFoodImage(imgPath, size: 80), // 🚀 ĐÃ GỌI HÀM VẼ ẢNH THÔNG MINH
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
                        // DÙNG BUILDER ĐỂ LẤY TỌA ĐỘ NÚT CHO ANIMATION
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