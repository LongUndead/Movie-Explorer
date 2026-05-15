import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// =======================================================
// 1. MODEL LƯU TRỮ VÉ (Để chứa nhiều phim trong List)
// =======================================================
class CartItem {
  final Movie? movie;
  final String cinemaName;
  final String selectedDate;
  final String selectedTime;
  final Map<String, int> selectedSeats;
  final int price;

  CartItem({
    required this.movie,
    required this.cinemaName,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedSeats,
    required this.price,
  });
}

// =======================================================
// 2. KHO CHỨA TOÀN CỤC (Quản lý Danh sách & Phiên hiện tại)
// =======================================================
class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  List<CartItem> tickets = [];
  int holdSeconds = 600; // 10 phút
  Timer? _timer;

  // Tổng tiền tất cả các vé
  int get grandTotal => tickets.fold(0, (sum, item) => sum + item.price);

  // Tổng số lượng ghế đã đặt (dùng để đếm số lượng hiển thị trên icon giỏ hàng)
  int get totalSeatsCount => tickets.fold(0, (sum, item) => sum + item.selectedSeats.length);

  // Lấy danh sách ghế đang chọn của riêng 1 suất chiếu cụ thể
  Map<String, int> getSeatsForShowtime(String movieId, String cinema, String date, String time) {
    final index = tickets.indexWhere((t) => 
      t.movie?.id.toString() == movieId && 
      t.cinemaName == cinema && 
      t.selectedDate == date && 
      t.selectedTime == time
    );
    if (index != -1) return tickets[index].selectedSeats;
    return {};
  }

  void updateCart({
    required Movie? movieObj,
    required String cinema,
    required String date,
    required String time,
    required Map<String, int> seats,
    required int price,
  }) {
    int index = tickets.indexWhere((t) => 
      t.movie?.id == movieObj?.id && 
      t.cinemaName == cinema && 
      t.selectedDate == date && 
      t.selectedTime == time
    );

    if (seats.isEmpty) {
      if (index != -1) tickets.removeAt(index);
    } else {
      final newItem = CartItem(
        movie: movieObj,
        cinemaName: cinema,
        selectedDate: date,
        selectedTime: time,
        selectedSeats: Map.from(seats),
        price: price,
      );
      
      if (index != -1) {
        tickets[index] = newItem; // Cập nhật số ghế mới vào vé cũ
      } else {
        tickets.add(newItem); // Thêm phim hoàn toàn mới vào danh sách
      }
    }

    // Quản lý đồng hồ đếm ngược
    if (tickets.isEmpty) {
      _timer?.cancel();
      holdSeconds = 600;
    } else if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (holdSeconds > 0) {
          holdSeconds--;
          notifyListeners(); 
        } else {
          clearCart(); 
        }
      });
    }
    notifyListeners();
  }

  void removeTicket(int index) {
    tickets.removeAt(index);
    if (tickets.isEmpty) {
      _timer?.cancel();
      holdSeconds = 600;
    }
    notifyListeners();
  }

  void clearCart() {
    tickets.clear();
    holdSeconds = 600;
    _timer?.cancel();
    notifyListeners();
  }
}
// =======================================================
// 3. GIAO DIỆN TRANG GIỎ HÀNG (GIỮ NGUYÊN UI GỐC CỦA BẠN)
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
        bool isEmpty = manager.tickets.isEmpty;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F5F9),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Giỏ hàng của tôi', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
              bottom: TabBar(
                indicatorColor: Colors.amber.shade700,
                indicatorWeight: 3,
                labelColor: navyBlue,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'VÉ PHIM', icon: Icon(Icons.local_movies_outlined)),
                  Tab(text: 'BẮP NƯỚC', icon: Icon(Icons.fastfood_outlined)),
                ],
              ),
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
                      const Text('Tổng thanh toán', style: TextStyle(fontSize: 16, color: Colors.black54)),
                      // ✅ DÙNG grandTotal ĐỂ TÍNH TẤT CẢ CÁC VÉ
                      Text(formatter.format(manager.grandTotal), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue)),
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

            body: TabBarView(
              children: [
                // TAB 1: DANH SÁCH VÉ PHIM
                isEmpty
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: manager.tickets.length,
                      itemBuilder: (context, index) {
                        final item = manager.tickets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: SwipeableCartItem(
                            onDelete: () {
                              manager.removeTicket(index);
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
                                      (item.movie?.posterPath != null && item.movie!.posterPath!.isNotEmpty)
                                          ? 'https://image.tmdb.org/t/p/w200${item.movie!.posterPath}'
                                          : '', 
                                      width: 70, height: 100, fit: BoxFit.cover,
                                      errorBuilder: (_,__,___) => Container(width: 70, height: 100, color: Colors.grey[300], child: const Icon(Icons.movie_creation_outlined, color: Colors.grey)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.movie?.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        Text(item.cinemaName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('2D Phụ đề | ${item.selectedDate} | ${item.selectedTime}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                                child: Text('Ghế: ${(item.selectedSeats.keys.toList()..sort()).join(', ')}', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(formatter.format(item.price), style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // ✅ FIX LỖI 00:589: Quy đổi giây ra Phút:Giây chuẩn xác
                                        Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 14, color: Colors.red),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Giữ ghế: ${(manager.holdSeconds ~/ 60).toString().padLeft(2, '0')}:${(manager.holdSeconds % 60).toString().padLeft(2, '0')}", 
                                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)
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
                        );
                      },
                    ),

                // TAB 2: BẮP NƯỚC
                const Center(child: Text("Danh sách bắp nước sẽ hiện ở đây")),
              ],
            ),
          ),
        );
      }
    );
  }
}

// =======================================================
// 4. WIDGET VUỐT XÓA (GIỮ NGUYÊN 100% HIỆU ỨNG CỦA BẠN)
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
  final double _maxDragDistance = 80.0;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _controller.addListener(() => setState(() => _dragExtent = _animation.value));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent -= details.primaryDelta!;
      if (_dragExtent < 0) _dragExtent = 0;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isOpen && _dragExtent > _maxDragDistance + 20) {
      widget.onDelete();
      return;
    }
    if (_dragExtent > _maxDragDistance / 2) {
      _isOpen = true;
      _animation = Tween<double>(begin: _dragExtent, end: _maxDragDistance).animate(_controller);
      _controller.forward(from: 0);
    } else {
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
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.red.shade500, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(width: _maxDragDistance, color: Colors.transparent, alignment: Alignment.center, child: const Icon(Icons.delete_outline, color: Colors.white, size: 30)),
              ),
            ),
          ),
          Transform.translate(offset: Offset(-_dragExtent, 0), child: widget.child),
        ],
      ),
    );
  }
}