import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// =======================================================
// 1. KHO CHỨA TOÀN CỤC (Lưu trữ Vé và Đồng hồ đếm ngược)
// =======================================================
class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  Movie? movie;
  String cinemaName = '';
  String selectedDate = '';
  String selectedTime = '';
  Map<String, int> selectedSeats = {}; 
  int totalPrice = 0;

  int holdSeconds = 60;
  Timer? _timer;

  void updateCart({
    required Movie? movieObj,
    required String cinema,
    required String date,
    required String time,
    required Map<String, int> seats,
    required int price,
  }) {
    movie = movieObj;
    cinemaName = cinema;
    selectedDate = date;
    selectedTime = time;
    selectedSeats = Map.from(seats);
    totalPrice = price;

    if (selectedSeats.isEmpty) {
      _timer?.cancel();
      holdSeconds = 60;
    } else {
      if (_timer == null || !_timer!.isActive) {
        holdSeconds = 60;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (holdSeconds > 0) {
            holdSeconds--;
            notifyListeners(); 
          } else {
            clearCart(); 
          }
        });
      }
    }
    notifyListeners();
  }

  void clearCart() {
    selectedSeats.clear();
    totalPrice = 0;
    holdSeconds = 60;
    _timer?.cancel();
    notifyListeners();
  }
}

// =======================================================
// 2. GIAO DIỆN TRANG GIỎ HÀNG
// =======================================================
class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900;
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        final manager = CartManager.instance;
        bool isEmpty = manager.selectedSeats.isEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Giỏ hàng của tôi', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          
          bottomNavigationBar: isEmpty ? const SizedBox.shrink() : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tiền', style: TextStyle(fontSize: 16, color: Colors.black54)),
                    Text(formatter.format(manager.totalPrice), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: navyBlue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: () {},
                    child: const Text('Tiến hành thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),

          body: isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Giỏ hàng trống', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ],
                ),
              )
            : ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              // ✅ SỬ DỤNG WIDGET VUỐT TỰ TẠO Ở BÊN DƯỚI
              SwipeableCartItem(
                onDelete: () {
                  manager.clearCart();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã xóa vé khỏi giỏ hàng'),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    )
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          'https://image.tmdb.org/t/p/w200${manager.movie?.posterPath ?? ''}', 
                          width: 70, height: 100, fit: BoxFit.cover,
                          errorBuilder: (_,__,___) => Container(width: 70, height: 100, color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(manager.movie?.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(manager.cinemaName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('2D Phụ đề | ${manager.selectedDate} | ${manager.selectedTime}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text('Ghế: ${(manager.selectedSeats.keys.toList()..sort()).join(', ')}', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(formatter.format(manager.totalPrice), style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 14, color: Colors.red.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  "Thời gian giữ ghế: 00:${manager.holdSeconds.toString().padLeft(2, '0')}", 
                                  style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 12)
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

// =======================================================
// 3. WIDGET TỰ TẠO: VUỐT ĐỂ HIỆN NÚT XÓA CHUẨN UX
// =======================================================
class SwipeableCartItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const SwipeableCartItem({super.key, required this.child, required this.onDelete});

  @override
  State<SwipeableCartItem> createState() => _SwipeableCartItemState();
}

class _SwipeableCartItemState extends State<SwipeableCartItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0.0;
  final double _maxDragDistance = 80.0; // Độ rộng của nút xóa hiện ra
  bool _isOpen = false; // Trạng thái nút xóa đang bật hay tắt

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _controller.addListener(() {
      setState(() {
        _dragExtent = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent -= details.primaryDelta!;
      if (_dragExtent < 0) _dragExtent = 0; // Không cho vuốt sang phải
    });
  }

  void _onDragEnd(DragEndDetails details) {
    // Nếu nút XÓA đang hiện, mà khách hàng vuốt thêm sang trái nữa -> Thực hiện XÓA
    if (_isOpen && _dragExtent > _maxDragDistance + 20) {
      widget.onDelete();
      return;
    }

    // Nếu vuốt quá nửa chiều dài nút -> Tự động bật nút Xóa
    if (_dragExtent > _maxDragDistance / 2) {
      _isOpen = true;
      _animation = Tween<double>(begin: _dragExtent, end: _maxDragDistance).animate(_controller);
      _controller.forward(from: 0);
    } else {
      // Nếu vuốt nhẹ tay -> Trượt đóng lại
      _isOpen = false;
      _animation = Tween<double>(begin: _dragExtent, end: 0.0).animate(_controller);
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // Lớp nền phía sau chứa nút Xóa
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade500,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onDelete, // Chạm vào nút Xóa -> Xóa
                child: Container(
                  width: _maxDragDistance,
                  height: double.infinity,
                  color: Colors.transparent, // Bắt buộc để nhận diện vùng chạm
                  alignment: Alignment.center,
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
          
          // Lớp hiển thị nội dung Vé đè lên trên (Trượt qua lại)
          Transform.translate(
            offset: Offset(-_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}