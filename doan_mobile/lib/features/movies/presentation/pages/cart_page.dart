import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/movie.dart';
import '../../domain/entities/food_model.dart';
import 'checkout_screen.dart'; // ✅ QUAN TRỌNG: Phải import màn hình thanh toán vào đây
import 'user_manager.dart';

// =======================================================
// 1. MODELS LƯU TRỮ VÉ & BẮP NƯỚC
// =======================================================
class CartItem {
  final Movie? movie;
  final String cinemaName;
  final String selectedDate;
  final String selectedTime;
  final List<Map<String, dynamic>> selectedSeats; 
  final int price;
  
  // ✅ BỔ SUNG: Khai báo thêm để lưu ID suất chiếu và Tên phòng
  final int showtimeId;
  final String roomName;

  CartItem({
    required this.movie,
    required this.cinemaName,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedSeats,
    required this.price,
    this.showtimeId = 0,     // Mặc định
    this.roomName = "Rạp 1", // Mặc định
  });
}

class FoodCartItem {
  final Food food;
  final String cinemaName;
  final String receiveDate;
  int quantity;

  FoodCartItem({
    required this.food,
    required this.cinemaName,
    required this.receiveDate,
    required this.quantity,
  });
}

// =======================================================
// 2. KHO CHỨA TOÀN CỤC (Quản lý Danh sách & Phiên hiện tại)
// =======================================================
class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  List<CartItem> tickets = [];
  List<FoodCartItem> foods = []; 

  int holdSeconds = 600; 
  Timer? _timer;
  DateTime? expireTime;

  int get grandTotal {
    int ticketTotal = tickets.fold(0, (sum, item) => sum + item.price);
    int foodTotal = foods.fold(0, (sum, item) => sum + (item.food.price * item.quantity).toInt());
    return ticketTotal + foodTotal;
  }

  int get totalSeatsCount => tickets.fold(0, (sum, item) => sum + item.selectedSeats.length);
  int get totalFoodsCount => foods.fold(0, (sum, item) => sum + item.quantity);

  List<Map<String, dynamic>> getSeatsForShowtime(String movieId, String cinema, String date, String time) {
    final index = tickets.indexWhere((t) => 
      t.movie?.id.toString() == movieId && 
      t.cinemaName == cinema && 
      t.selectedDate == date && 
      t.selectedTime == time
    );
    if (index != -1) return tickets[index].selectedSeats;
    return []; 
  }

  // ✅ BỔ SUNG: Nhận thêm showtimeId và roomName khi thêm vé vào giỏ
  void updateCart({
    required Movie? movieObj, required String cinema, required String date,
    required String time, required List<Map<String, dynamic>> seats, required int price,
    int showtimeId = 0, String roomName = "Rạp 1",
  }) {
    int index = tickets.indexWhere((t) => 
      t.movie?.id == movieObj?.id && t.cinemaName == cinema && 
      t.selectedDate == date && t.selectedTime == time
    );

    if (seats.isEmpty) {
      if (index != -1) tickets.removeAt(index);
    } else {
      final newItem = CartItem(
        movie: movieObj, cinemaName: cinema, selectedDate: date,
        selectedTime: time, 
        selectedSeats: List.from(seats), 
        price: price,
        showtimeId: showtimeId, // Lưu vào đây
        roomName: roomName,     // Lưu vào đây
      );
      if (index != -1) tickets[index] = newItem; 
      else tickets.add(newItem); 
    }

      if (expireTime == null && (tickets.isNotEmpty || foods.isNotEmpty)) {
      expireTime = DateTime.now().add(const Duration(minutes: 10));
    }

    _checkTimer();
    notifyListeners();
  }

  void removeTicket(int index) {
    tickets.removeAt(index);
    _checkTimer();
    notifyListeners();
  }

  void updateFoodCart({
    required Food food, required String cinemaName, 
    required String date, required int quantity,
  }) {
    int index = foods.indexWhere((f) => f.food.id == food.id && f.cinemaName == cinemaName && f.receiveDate == date);
    
    if (quantity <= 0) {
      if (index != -1) foods.removeAt(index); 
    } else {
      if (index != -1) {
        foods[index].quantity = quantity; 
      } else {
        foods.add(FoodCartItem(food: food, cinemaName: cinemaName, receiveDate: date, quantity: quantity));
      }
    }
    _checkTimer();
    notifyListeners();
  }

  void removeFood(int index) {
    foods.removeAt(index);
    _checkTimer();
    notifyListeners();
  }

  void _checkTimer() {
    if (tickets.isEmpty && foods.isEmpty) {
      _timer?.cancel();
      holdSeconds = 600;
      expireTime = null; // Reset mốc thời gian
    } else if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        
        if (expireTime != null) {
          // Lấy Thời gian Đích trừ đi Thời gian ngay khoảnh khắc này
          final now = DateTime.now();
          if (expireTime!.isAfter(now)) {
            holdSeconds = expireTime!.difference(now).inSeconds;
            notifyListeners(); 
          } else {
            clearCart(); 
          }
        }
        
      });
    }
  }

  void clearCart() {
    tickets.clear();
    foods.clear();
    holdSeconds = 600;
    expireTime = null;
    _timer?.cancel();
    notifyListeners();
  }
}

// =======================================================
// 3. GIAO DIỆN TRANG GIỎ HÀNG
// =======================================================
class CartPage extends StatelessWidget {
  final int initialIndex;
  const CartPage({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900;
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        final manager = CartManager.instance;
        bool isEmptyCart = manager.tickets.isEmpty && manager.foods.isEmpty;

        return DefaultTabController(
          initialIndex: initialIndex,
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
                tabs: [
                  Tab(text: 'VÉ PHIM (${manager.tickets.length})', icon: const Icon(Icons.local_movies_outlined)),
                  Tab(text: 'BẮP NƯỚC (${manager.foods.length})', icon: const Icon(Icons.fastfood_outlined)),
                ],
              ),
            ),
            
            bottomNavigationBar: isEmptyCart ? const SizedBox.shrink() : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng thanh toán', style: TextStyle(fontSize: 16, color: Colors.black54)),
                      Text(formatter.format(manager.grandTotal), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: navyBlue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      onPressed: () {
                        // ========================================================
                        // ✅ ĐÃ SỬA: LOGIC CHUYỂN TRANG THÔNG MINH CHO NÚT THANH TOÁN
                        // ========================================================
                        if (manager.tickets.isEmpty && manager.foods.isEmpty) return;

                        Movie? checkoutMovie;
                        String checkoutCinema = "";
                        String checkoutDate = "";
                        String checkoutTime = "";
                        String checkoutRoom = "";
                        int checkoutShowtimeId = 0;

                        if (manager.tickets.isNotEmpty) {
                          // TRƯỜNG HỢP 1: Có mua vé phim -> Lấy data từ vé
                          final firstTicket = manager.tickets.first;
                          checkoutMovie = firstTicket.movie;
                          checkoutCinema = firstTicket.cinemaName;
                          checkoutDate = firstTicket.selectedDate;
                          checkoutTime = firstTicket.selectedTime;
                          checkoutRoom = firstTicket.roomName;
                          checkoutShowtimeId = firstTicket.showtimeId;
                        } else {
                          // TRƯỜNG HỢP 2: CHỈ MUA BẮP NƯỚC -> Cho movie = null
                          final firstFood = manager.foods.first;
                          checkoutMovie = null; // Ép chuẩn thành null
                          checkoutCinema = firstFood.cinemaName;
                          checkoutDate = firstFood.receiveDate;
                          checkoutTime = "Trong ngày";
                          checkoutRoom = "Quầy Dịch Vụ";
                          checkoutShowtimeId = 0; 
                        }

                        // Đẩy hết dữ liệu sang Màn hình Checkout
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheckoutScreen(
                              movie: checkoutMovie,
                              cinemaName: checkoutCinema,
                              selectedDate: checkoutDate,
                              selectedTime: checkoutTime,
                              roomName: checkoutRoom,
                              showtimeId: checkoutShowtimeId,
                            ),
                          ),
                        );
                      },
                      child: const Text('Tiến hành thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            body: TabBarView(
              children: [
                // TAB 1: DANH SÁCH VÉ PHIM
                manager.tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_movies_outlined, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('Chưa có vé phim nào', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: manager.tickets.length,
                      itemBuilder: (context, index) {
                        final item = manager.tickets[index];

                        List<String> seatNames = item.selectedSeats.map((s) => s['name'].toString()).toList();
                        seatNames.sort();
                        String formattedSeats = seatNames.join(', ');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: SwipeableCartItem(
                            onDelete: () {
                              // =======================================================
                              // ✅ LOGIC CHUẨN: NHẢ GHẾ TRÊN SERVER TRƯỚC KHI XÓA
                              // =======================================================
                              final ticketToCancel = manager.tickets[index];
                              final user = UserManager.instance.currentUser;
                              
                              if (user != null && ticketToCancel.selectedSeats.isNotEmpty) {
                                // Lặp qua từng ghế trong vé này để báo Server nhả ra
                                for (var seat in ticketToCancel.selectedSeats) {
                                  int realSeatId = seat['id'];
                                  
                                  try {
                                    // 🚀 Pro-tip: Không dùng 'await' ở đây để App bắn API ngầm, vuốt xóa mượt mà không bị khựng
                                    http.post(
                                      Uri.parse('http://192.168.1.2:3000/api/seats/release'), 
                                      headers: {'Content-Type': 'application/json'},
                                      body: json.encode({
                                        'userId': user.id,
                                        'showtimeId': ticketToCancel.showtimeId,
                                        'seatId': realSeatId
                                      }),
                                    );
                                    debugPrint("Đã bắn tín hiệu nhả ghế ID: $realSeatId");
                                  } catch (e) {
                                    debugPrint("Lỗi nhả ghế: $e");
                                  }
                                }
                              }

                              // Cuối cùng: Xóa vé khỏi RAM để App cập nhật giao diện (Mất khỏi giỏ hàng)
                              manager.removeTicket(index);
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
                                                child: Text('Ghế: $formattedSeats', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(formatter.format(item.price), style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 14, color: Colors.red),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Giữ chỗ: ${(manager.holdSeconds ~/ 60).toString().padLeft(2, '0')}:${(manager.holdSeconds % 60).toString().padLeft(2, '0')}", 
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

                // TAB 2: DANH SÁCH BẮP NƯỚC
                manager.foods.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fastfood_outlined, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('Chưa có bắp nước nào', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: manager.foods.length,
                      itemBuilder: (context, index) {
                        final item = manager.foods[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: SwipeableCartItem(
                            onDelete: () => manager.removeFood(index),
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
                                  // Hình bắp nước
                                  Container(
                                    width: 70, height: 70,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: const Color(0xFFF5F5F9), borderRadius: BorderRadius.circular(8)),
                                    child: Builder(
                                      builder: (context) {
                                        String dbImg = (item.food.imageUrl ?? '').trim();
                                        String finalPath = '';
                                        if (dbImg.startsWith('http')) {
                                          finalPath = dbImg;
                                        } else {
                                          final folders = {1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags'};
                                          String folder = folders[item.food.brandId] ?? 'cgv';
                                          if (dbImg.isNotEmpty) {
                                            if (dbImg.startsWith('/')) dbImg = dbImg.substring(1);
                                            finalPath = dbImg.startsWith('assets/') ? dbImg : (dbImg.startsWith('$folder/') ? 'assets/$dbImg' : 'assets/$folder/$dbImg');
                                          } else {
                                            finalPath = 'assets/$folder/default.png';
                                          }
                                        }

                                        if (finalPath.startsWith('http')) {
                                          return Image.network(finalPath, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.fastfood, color: Colors.grey, size: 30));
                                        }
                                        return Image.asset(finalPath, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.fastfood, color: Colors.grey, size: 30));
                                      }
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Thông tin bắp nước
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        Text(item.cinemaName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('Nhận ngày: ${item.receiveDate}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Số lượng: x${item.quantity}', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(formatter.format(item.food.price * item.quantity), style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                                          ],
                                        ),
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
              ],
            ),
          ),
        );
      }
    );
  }
}

// =======================================================
// 4. WIDGET VUỐT XÓA (Giữ nguyên)
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