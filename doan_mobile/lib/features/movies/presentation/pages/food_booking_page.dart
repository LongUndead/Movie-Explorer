import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import '../../domain/entities/food_model.dart';
import '../../domain/entities/cinema.dart';
import '../../data/models/cinema_model.dart';
import 'cart_page.dart';
import 'main_page.dart';
import 'cinema_search_screen.dart';

class FoodBookingPage extends StatefulWidget {
  const FoodBookingPage({super.key});

  @override
  State<FoodBookingPage> createState() => FoodBookingPageState();
}

class FoodBookingPageState extends State<FoodBookingPage> {
  final Color navyBlue = Colors.blue.shade900;
  final Color cgPink = const Color(0xFFE5398B);

  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  bool _hasShownWelcomePopup = false;
  bool _isWaitingToPopup = false;
  final ScrollController _scrollController = ScrollController();

  late List<DateTime> _availableDates;
  late DateTime _selectedDate;
  

  List<Cinema> _cinemas = [];
  Cinema? _selectedCinema;

  bool _isLoadingCinemas = true;
  bool _isLoadingFoods = false;

  List<Food> _allFoods = [];

  @override
  void initState() {
    super.initState();
    _availableDates = List.generate(
      7,
      (index) => DateTime.now().add(Duration(days: index)),
    );
    _selectedDate = _availableDates.first;
    _fetchCinemasFromApi();
  }
  int _getQuantityFromGlobalCart(Food food) {
    String cinemaName = _selectedCinema?.name ?? "";
    String date = DateFormat('dd/MM/yyyy').format(_selectedDate);
    
    final items = CartManager.instance.foods.where((f) => 
        f.food.id == food.id && 
        f.cinemaName == cinemaName && 
        f.receiveDate == date
    );
    return items.isEmpty ? 0 : items.first.quantity;
  }
  @override
    void dispose() {
      _scrollController.dispose();
      super.dispose();
    }
  // =====================================================
  // FETCH CINEMAS
  // =====================================================
void triggerWelcomePopup() {
    if (_hasShownWelcomePopup) return; // Đã hiện rồi thì không hiện nữa
    
    if (_cinemas.isNotEmpty) {
      _hasShownWelcomePopup = true;
      _isWaitingToPopup = false;
      _showWelcomePopup(); // Bung thông báo
    } else {
      // Nếu mạng chậm, rạp chưa tải xong thì đánh dấu "đang đợi"
      _isWaitingToPopup = true;
    }
  }

  // =====================================================
  // TẢI RẠP XONG NẾU ĐANG ĐỢI SẼ BUNG POP-UP
  // =====================================================
  Future<void> _fetchCinemasFromApi() async {
    setState(() => _isLoadingCinemas = true);

    try {
      final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/cinemas'));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        List<Cinema> tempCinemas = [];

        for (var item in data) {
          try {
            tempCinemas.add(CinemaModel.fromJson(item));
          } catch (e) {
            debugPrint("Lỗi 1 rạp: $e");
          }
        }

        if (mounted) {
          setState(() {
            _cinemas = tempCinemas;
            if (_cinemas.isNotEmpty && _selectedCinema == null) {
              _selectedCinema = _cinemas.firstWhere(
                (c) {
                  String name = c.name.toLowerCase();
                  return name.contains('sư vạn hạnh') || name.contains('su van hanh');
                },
                orElse: () => _cinemas.first, 
              );
              
              // Lập tức gọi API tải bắp nước của CGV lên để chờ sẵn
              _fetchFoodsFromApi(_selectedCinema!);
            }
          });
          
          // ✅ CHỈ BẬT POP-UP NẾU Ở NGOÀI ĐÃ BẤM VÀO TAB BẮP NƯỚC
          if (_isWaitingToPopup && _cinemas.isNotEmpty) {
            _hasShownWelcomePopup = true;
            _isWaitingToPopup = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showWelcomePopup(); 
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi Mạng: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCinemas = false);
    }
  }
  
  // =====================================================
  // FETCH FOODS
  // =====================================================
  Future<void> _fetchFoodsFromApi(Cinema cinema) async {
    setState(() {
      _isLoadingFoods = true;
      _allFoods.clear();
    });

    try {
      int targetBrandId = _getBrandIdFromCinema(cinema);
      final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/foods?brand_id=$targetBrandId'));

      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        List<Food> fetchedFoods = data.map<Food>((e) => Food.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _allFoods = fetchedFoods;
          });
        }
      }
    } catch (e) {
      debugPrint("LOAD FOODS ERROR => $e");
    } finally {
      if (mounted) setState(() => _isLoadingFoods = false);
    }
  }

  // =====================================================
  // BRAND ID & LOGO
  // =====================================================
  int _getBrandIdFromCinema(Cinema cinema) {
    String text = cinema.name.toLowerCase();
    if (text.contains('cgv')) return 1;
    if (text.contains('galaxy')) return 2;
    if (text.contains('lotte')) return 3;
    if (text.contains('bhd')) return 4;
    if (text.contains('cinestar')) return 5;
    if (text.contains('mega')) return 6;
    if (text.contains('dcine')) return 7;
    // Bắt buộc check aeon trước beta
    if (text.contains('aeon beta') || text.contains('aeonbeta')) return 9; 
    if (text.contains('beta')) return 8;
    return -1;
  }

  String _getCinemaLogo(Cinema cinema) {
    String text = cinema.name.toLowerCase();
    if (text.contains('cgv')) return 'assets/cgv1.png';
    if (text.contains('lotte')) return 'assets/lotte.png';
    if (text.contains('bhd')) return 'assets/bhd.png';
    if (text.contains('galaxy')) return 'assets/galaxy.png';
    if (text.contains('cinestar')) return 'assets/cinestar.png';
    if (text.contains('mega')) return 'assets/megags.png';
    if (text.contains('dcine')) return 'assets/dcine.png';
    if (text.contains('aeon beta') || text.contains('aeonbeta')) return 'assets/aeonbeta.png';
    if (text.contains('beta')) return 'assets/betacinema.png';
    return 'assets/dexuat.png';
  }

  // =====================================================
  // FOOD IMAGE
  // =====================================================
  String _getFoodImagePath(Food food) {
    String dbImage = (food.imageUrl ?? '').trim();
    if (dbImage.startsWith('http')) return dbImage;

    final folders = {
      1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags',
    };
    String folder = folders[food.brandId] ?? 'cgv';

    if (dbImage.isNotEmpty) {
      if (dbImage.startsWith('/')) dbImage = dbImage.substring(1);
      if (dbImage.startsWith('assets/')) return dbImage;
      if (dbImage.startsWith('$folder/')) return 'assets/$dbImage';
      return 'assets/$folder/$dbImage';
    }
    return 'assets/$folder/default.png';
  }

  Widget _buildImage(String path) {
    if (path.isEmpty) return const Icon(Icons.fastfood, size: 40);
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40));
    }
    return Image.asset(path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40, color: Colors.red));
  }

  // =====================================================
  // TOTAL
  // =====================================================
  int get _totalCartItems => CartManager.instance.totalFoodsCount;

  double get _totalCartPrice {
    return CartManager.instance.foods.fold(
      0.0, 
      (sum, item) => sum + (item.food.price * item.quantity)
    );
  }

  // =====================================================
  // HIỆU ỨNG BAY VÀO GIỎ HÀNG (FLY TO CART)
  // =====================================================
  void _runAddToCartAnimation(Food food) {
    // 1. Dò tìm tọa độ cụm Icon trên góc phải màn hình
    RenderBox? cartBox = mainCartKey.currentContext?.findRenderObject() as RenderBox?;
    
    // Đích đến: Góc phải trên cùng (vị trí icon giỏ hàng). Nếu lỗi dò tọa độ thì lấy mặc định góc trên phải
    Offset endPosition = cartBox != null 
        ? cartBox.localToGlobal(const Offset(15, 15)) 
        : Offset(MediaQuery.of(context).size.width - 60, 40);

    // Điểm xuất phát: Chính giữa màn hình (nơi pop-up vừa đóng)
    Offset startPosition = Offset(MediaQuery.of(context).size.width / 2 - 30, MediaQuery.of(context).size.height / 2);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700), // Thời gian bay 0.7 giây ngắm cho mượt
          curve: Curves.easeOutCubic,
          onEnd: () => entry.remove(),
          builder: (context, double value, child) {
            // Tính toán đường cong Parabola bay ngược lên trên rồi lao xuống đích
            final currentX = startPosition.dx + (endPosition.dx - startPosition.dx) * value;
            final currentY = startPosition.dy + (endPosition.dy - startPosition.dy) * value - (math.sin(value * math.pi) * 150);
            
            // Kích thước thu nhỏ dần khi bay gần tới giỏ
            final size = 70.0 * (1.0 - (value * 0.7)); 

            return Positioned(
              left: currentX,
              top: currentY,
              child: Material(
                color: Colors.transparent,
                elevation: 4,
                shape: const CircleBorder(),
                child: Container(
                  width: size, height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: navyBlue, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)]
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: _buildImage(_getFoodImagePath(food)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    Overlay.of(context).insert(entry);
  }
  // =====================================================
  // UI
  // =====================================================
 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 2️⃣ FIX LỖI ĐÁY MÀN HÌNH: Sơn trắng toàn bộ nền
      body: Stack(
        children: [
          // NỀN GRADIENT XANH DƯƠNG (Cố định ở trên cùng)
          Container(
            height: MediaQuery.of(context).size.height * 0.35, 
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF64B5F6), 
                  Colors.white, // Chuyển dần sang trắng cho mượt
                ],
              ),
            ),
          ),
          
          // NỘI DUNG CUỘN LÊN XUỐNG
          SingleChildScrollView(
            controller: _scrollController, // 3️⃣ FIX LỖI APPBAR: Gắn controller để MainPage bắt được tín hiệu cuộn
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 105), // Khoảng trống đẩy xuống tránh AppBar
                
                _buildHeader(), // Bộ lọc rạp và ngày sẽ trôi lên khi lướt
                
                const SizedBox(height: 16),
                
                // KHUNG BO GÓC MÀU TRẮNG CHỨA DANH SÁCH MÓN
                Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.6, 
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: _selectedCinema != null
                      ? _buildFoodList()
                      : Padding(
                          padding: const EdgeInsets.only(top: 50.0),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              "Vui lòng chọn rạp", 
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade700)
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: CartManager.instance,
        builder: (context, child) {
          bool hasItems = CartManager.instance.totalFoodsCount > 0 || CartManager.instance.totalSeatsCount > 0;
          return hasItems ? _buildBottomCartBar() : const SizedBox.shrink();
        }
      ),
    );
  }
  
  String _formatDateWithDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = targetDate.difference(today).inDays;

    String dayString = "";
    if (difference == 0) {
      dayString = "Hôm nay";
    } else if (difference == 1) {
      dayString = "Ngày mai";
    } else {
      switch (date.weekday) {
        case 1: dayString = "Thứ 2"; break;
        case 2: dayString = "Thứ 3"; break;
        case 3: dayString = "Thứ 4"; break;
        case 4: dayString = "Thứ 5"; break;
        case 5: dayString = "Thứ 6"; break;
        case 6: dayString = "Thứ 7"; break;
        case 7: dayString = "Chủ nhật"; break;
      }
    }
    
    final dateString = DateFormat('dd/MM/yyyy').format(date);
    return "$dateString, $dayString";
  }

  // =====================================================
  // 2. HEADER: BỘ LỌC RẠP & NGÀY (Cập nhật giao diện nổi bật trên nền xanh)
  // =====================================================
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16), // Khoảng cách từ viền Box vào phần tử bên trong
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Bo góc cho Box tổng
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06), 
              blurRadius: 12, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Column(
          children: [
            // BỘ LỌC CHỌN RẠP
            GestureDetector(
              onTap: _openCinemaSearchPage,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Nhận Tại Rạp',
                  labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), 
                    borderSide: BorderSide(color: Colors.grey.shade300)
                  ),
                ),
                child: Row(
                  children: [
                    if (_selectedCinema != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.asset(_getCinemaLogo(_selectedCinema!), width: 32, height: 32),
                      ),
                    Expanded(
                      child: Text(
                        _selectedCinema?.name ?? "Vui lòng chọn rạp",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16), 

            // BỘ LỌC CHỌN NGÀY
            GestureDetector(
              onTap: _showDateSelector,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Ngày Nhận',
                  labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), 
                    borderSide: BorderSide(color: Colors.grey.shade300)
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateWithDay(_selectedDate), // 👈 DÙNG HÀM MỚI ĐỂ HIỆN THỨ
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _openCinemaSearchPage() async {
    if (_isLoadingCinemas) return;
    
    // Bay sang trang CinemaSearchScreen mà tụi mình đã tách file
    final Cinema? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CinemaSearchScreen(allCinemas: _cinemas),
      ),
    );

    if (result != null) {
      if (_selectedCinema?.id != result.id) {
        while (CartManager.instance.foods.isNotEmpty) {
          CartManager.instance.removeFood(0);
        }
      }
      setState(() {
        _selectedCinema = result;
      });
      _fetchFoodsFromApi(result);
    }
  }
// =====================================================
  // HÀM HIỆN POP-UP KHI MỚI VÀO TRANG BẮP NƯỚC
  // =====================================================
  void _showWelcomePopup() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          // ✅ CỰC KỲ QUAN TRỌNG: Lệnh này giúp bo tròn 2 góc trên cùng của tấm hình khớp với Pop-up!
          clipBehavior: Clip.antiAlias, 
          
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==========================================
              // 1. HÌNH ẢNH SẼ TRÀN SÁT MÉP TẠI ĐÂY
              // ==========================================
              Image.asset(
                'assets/popup.png', 
                width: double.infinity, // Kéo dãn chiều ngang kịch trần
                fit: BoxFit.fitWidth, // Phóng to, cắt xén ảnh để lấp đầy mọi khoảng trắng
                errorBuilder: (_, __, ___) => Container(
                  width: double.infinity, height: 200,
                  color: Colors.orange.shade50,
                  child: Icon(Icons.fastfood_rounded, size: 80, color: Colors.orange.shade400),
                ),
              ),
              
              // ==========================================
              // 2. PHẦN CHỮ VÀ NÚT BẤM (BỊ ĐẨY LÙI VÀO 20px)
              // ==========================================
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      "Bạn muốn nhận bắp nước\ntại rạp nào?",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue, height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Cinema Tickets sẽ nhắn rạp chuẩn bị sẵn sàng bắp nước giòn tan nóng hổi, chờ đón bạn tới xem phim nè!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        // NÚT HỦY
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(context); 
                            },
                            child: Text("Hủy", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // NÚT CHỌN RẠP
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navyBlue, 
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context); 
                              _openCinemaSearchPage(); 
                            },
                            child: const Text("Chọn rạp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // =====================================================
  // DATE SELECTOR (ĐÃ FIX: CÓ TIÊU ĐỀ, NÚT X, TÍCH XANH)
  // =====================================================
  void _showDateSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 5),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),

              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text("Chọn Ngày", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), 
                itemCount: _availableDates.length,
                itemBuilder: (_, index) {
                  final date = _availableDates[index];
                  final isSelected = _selectedDate == date;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? navyBlue : Colors.transparent, 
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: Text(
                        _formatDateWithDay(date), // 👈 DÙNG HÀM MỚI Ở ĐÂY LUÔN
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? navyBlue : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: navyBlue) : null, 
                      onTap: () {
                        setState(() => _selectedDate = date);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  // =====================================================
  // FOOD LIST
  // =====================================================
  Widget _buildFoodList() {
    if (_isLoadingFoods) return const Padding(padding: EdgeInsets.only(top: 50), child: Center(child: CircularProgressIndicator()));
    
    // NẾU RẠP KHÔNG CÓ ĐỒ ĂN THÌ HIỂN THỊ MÀN HÌNH NÀY
    if (_allFoods.isEmpty) {
      return Container(
        padding: const EdgeInsets.only(top: 60),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Chưa có sản phẩm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Rạp này hiện chưa cập nhật menu đồ ăn\ntrên hệ thống.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        return ListView.builder(
          shrinkWrap: true, 
          physics: const NeverScrollableScrollPhysics(), 
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 20),
          itemCount: _allFoods.length,
          itemBuilder: (_, index) {
            final food = _allFoods[index];
            int qty = _getQuantityFromGlobalCart(food);

            return GestureDetector(
              onTap: () => _showFoodDetail(food), 
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                  border: Border.all(color: Colors.grey.shade100)
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    SizedBox(
                      width: 80, height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImage(_getFoodImagePath(food)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            food.description,
                            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatter.format(food.price),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (qty > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: navyBlue, borderRadius: BorderRadius.circular(20)),
                                  child: Text("x$qty", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }
  // =====================================================
  // CHI TIẾT MÓN ĂN (BOTTOM SHEET MỚI)
  // =====================================================
// =====================================================
  // CHI TIẾT MÓN ĂN (LAYOUT MỚI CHUẨN UX/UI)
  // =====================================================
  void _showFoodDetail(Food food) {
    int tempQty = _getQuantityFromGlobalCart(food); 
    if (tempQty == 0) tempQty = 1; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (food.type.isNotEmpty ? food.type : "MÓN ĂN").toUpperCase(),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyBlue, letterSpacing: 0.5),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 24),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      height: 220,
                      color: const Color(0xFFF5F5F9), 
                      padding: const EdgeInsets.all(20),
                      child: _buildImage(_getFoodImagePath(food)),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(food.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            Text(food.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(formatter.format(food.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 20),
                                        color: tempQty > 1 ? Colors.black87 : Colors.grey.shade300,
                                        onPressed: () { if (tempQty > 1) setModalState(() => tempQty--); },
                                      ),
                                      SizedBox(
                                        width: 32,
                                        child: Text('$tempQty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 20),
                                        color: Colors.black87,
                                        onPressed: () { setModalState(() => tempQty++); },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyBlue, 
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          // 1. Thêm vào giỏ hàng
                          CartManager.instance.updateFoodCart(
                            food: food,
                            cinemaName: _selectedCinema?.name ?? "Chưa chọn rạp",
                            date: DateFormat('dd/MM/yyyy').format(_selectedDate),
                            quantity: tempQty,
                          );
                          
                          if (mounted) {
                            setState(() {});
                          }

                          // 2. Tắt màn hình Pop-up đi
                          Navigator.pop(context);

                          // 3. Đợi Pop-up tắt xong (khoảng 0.1 giây) thì gọi hiệu ứng bay ảnh
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _runAddToCartAnimation(food);
                          });
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text("$tempQty", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            const Expanded(
                              child: Center(child: Text("Thêm món", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                            ),
                            Text(formatter.format(food.price * tempQty), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  // =====================================================
  // CART BAR
  // =====================================================
 Widget _buildBottomCartBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), 
            blurRadius: 10, 
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cụm hiển thị tổng cộng số món và số tiền hiện tại
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tổng cộng (${CartManager.instance.totalFoodsCount} món)", 
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatter.format(_totalCartPrice),
                    style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            
            // Nút Tiếp tục chuyển thẳng tới Giỏ hàng Bắp nước
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: navyBlue, // Tông xanh chủ đạo
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                // 👈 LỆNH CHUYỂN TRANG: Ép mở Tab số 1 (BẮP NƯỚC)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CartPage(initialIndex: 1),
                  ),
                );
              },
              child: const Text(
                "Tiếp tục", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


