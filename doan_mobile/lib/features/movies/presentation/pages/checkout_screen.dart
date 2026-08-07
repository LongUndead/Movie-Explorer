import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../domain/entities/movie.dart';
import '../../domain/entities/food_model.dart';
import 'cart_page.dart'; 
import 'user_manager.dart';
import 'payment_method_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Movie? movie; 
  final String cinemaName;
  final String selectedDate;
  final String selectedTime;
  final String roomName; 
  final int showtimeId;

  const CheckoutScreen({
    super.key,
    required this.movie,
    required this.cinemaName,
    required this.selectedDate,
    required this.selectedTime,
    required this.roomName, 
    required this.showtimeId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Color navyBlue = Colors.blue.shade900;
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _noteController = TextEditingController();

  bool _isLoadingUser = true;
  bool _isLoadingFoods = true;
  
  // Các biến này chỉ lưu TẠM THỜI ở màn hình này để truyền đi in hóa đơn
  String _userName = ""; 
  String _userPhone = "";
  String _userEmail = "";
  
  List<Food> _availableFoods = []; 
  final int currentUserId = UserManager.instance.currentUser?.id ?? 0;

  bool _startedEmpty = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); 
    _fetchFoodsData(); 

    final initialFoods = CartManager.instance.foods.where((f) => f.cinemaName == widget.cinemaName && f.receiveDate == widget.selectedDate).toList();
    _startedEmpty = initialFoods.isEmpty;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _getFormattedDateWithYear(String date) {
    if (date.contains('202')) return date; 
    return "$date/${DateTime.now().year}"; 
  }

  Map<String, dynamic> _getAgeRatingInfo(String ratingCode) {
    String code = ratingCode.toUpperCase();
    if (code.contains('T18')) return {'label': 'T18', 'color': Colors.red, 'desc': 'Phim được phổ biến đến người xem từ đủ 18 tuổi trở lên.'};
    if (code.contains('T16')) return {'label': 'T16', 'color': Colors.orange, 'desc': 'Phim được phổ biến đến người xem từ đủ 16 tuổi trở lên.'};
    if (code.contains('T13')) return {'label': 'T13', 'color': Colors.amber.shade600, 'desc': 'Phim được phổ biến đến người xem từ đủ 13 tuổi trở lên.'};
    if (code.contains('K')) return {'label': 'K', 'color': Colors.blue, 'desc': 'Được phổ biến đến người xem dưới 13 tuổi nếu xem cùng cha mẹ/người giám hộ.'};
    if (code.contains('P')) return {'label': 'P', 'color': Colors.green, 'desc': 'Phim được phép phổ biến đến người xem mọi độ tuổi.'};
    return {'label': 'T18', 'color': Colors.red, 'desc': 'Phim được phổ biến đến người xem từ đủ 18 tuổi trở lên.'};
  }

  // 🚀 ĐÃ BỔ SUNG: BẮT THÊM CÁC RẠP DCINE, BETA... ĐỂ GỌI API BẮP NƯỚC CHO CHUẨN
  int _getBrandIdFromCinema(String name) {
    String text = name.toLowerCase();
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

  Future<void> _fetchFoodsData() async {
    try {
      int brandId = _getBrandIdFromCinema(widget.cinemaName);
      final res = await http.get(Uri.parse('http://192.168.1.7:3000/api/foods?brand_id=$brandId'));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _availableFoods = data.map<Food>((e) => Food.fromJson(e)).toList();
            _isLoadingFoods = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFoods = false);
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final url = Uri.parse('http://192.168.1.7:3000/api/users/$currentUserId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _userName = data['Username'] ?? data['username'] ?? data['name'] ?? data['FullName'] ?? data['fullname'] ?? '';
            _userEmail = data['Email'] ?? data['email'] ?? '';
            _userPhone = data['Phone'] ?? data['phone'] ?? data['PhoneNumber'] ?? '';
            _isLoadingUser = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  String _getImage(String? path) {
    if (path == null || path.trim().isEmpty || path == 'null') {
      return 'https://via.placeholder.com/300x450?text=No+Image';
    }
    String cleanPath = path.trim();

    if (cleanPath.contains('image.tmdb.org') && (cleanPath.contains('uploads') || cleanPath.contains('avatars') || cleanPath.contains('public'))) {
      int cutIndex = cleanPath.indexOf('public');
      if (cutIndex == -1) cutIndex = cleanPath.indexOf('uploads');
      if (cutIndex == -1) cutIndex = cleanPath.indexOf('avatars');
      if (cutIndex != -1) cleanPath = cleanPath.substring(cutIndex); 
    }

    if (cleanPath.startsWith('http')) return cleanPath; 
    
    if (cleanPath.contains('uploads') || cleanPath.contains('movie-')) {
      String filename = cleanPath.split('/').last; 
      return 'http://192.168.1.7:3000/uploads/$filename';
    }

    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return 'https://image.tmdb.org/t/p/w200$cleanPath';
  }

  // 🚀 ĐÃ BỔ SUNG: BẮT LOGO DÀNH CHO RẠP DCINE VÀ BETA
  String _getCinemaLogo(String name) {
    String text = name.toLowerCase();
    if (text.contains('cgv')) return 'assets/cgv1.png';
    if (text.contains('lotte')) return 'assets/lotte.png';
    if (text.contains('bhd')) return 'assets/bhd.png';
    if (text.contains('galaxy')) return 'assets/galaxy.png';
    if (text.contains('cinestar')) return 'assets/cinestar.png';
    if (text.contains('mega')) return 'assets/megags.png';
    if (text.contains('dcine')) return 'assets/dcine.png'; // Fix DCine
    if (text.contains('beta')) return 'assets/beta.png';   // Fix Beta
    return 'assets/dexuat.png';
  }

  String _getFoodImagePath(Food food) {
    String dbImage = (food.imageUrl ?? '').trim();
    if (dbImage.isEmpty || dbImage == 'null') return 'assets/cgv/default.png';

    if (dbImage.contains('public/foods') || dbImage.contains('food-')) {
      String filename = dbImage.split('/').last; 
      return 'http://192.168.1.7:3000/public/foods/$filename'; 
    }

    if (dbImage.startsWith('http')) return dbImage;

    final folders = {
      1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags', 7: 'dcine', 8: 'beta', 9: 'aeonbeta'
    };
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

  Future<void> _navigateToEditUserInfo() async {
    final result = await Navigator.push(context, MaterialPageRoute(
        builder: (context) => EditUserInfoScreen(initialName: _userName, initialPhone: _userPhone, initialEmail: _userEmail)));

    if (result != null && result is Map<String, String>) {
      setState(() {
        _userName = result['name'] ?? '';
        _userPhone = result['phone'] ?? '';
        _userEmail = result['email'] ?? '';
      });
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Stack(
            clipBehavior: Clip.none, 
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        widget.movie != null ? "Xác nhận đặt vé" : "Xác nhận đơn hàng", 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (widget.movie != null) ...[
                      const Text("Bạn đang đặt vé xem phim:", style: TextStyle(color: Colors.black87, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(widget.movie!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                      const SizedBox(height: 20),
                    ],
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center, 
                      children: [
                        Container(
                          width: 36,  
                          height: 36,
                          padding: const EdgeInsets.all(4), 
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300), 
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              _getCinemaLogo(widget.cinemaName), 
                              fit: BoxFit.contain, 
                              errorBuilder: (_,__,___) => Icon(Icons.movie_creation_outlined, color: navyBlue, size: 20)
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.cinemaName, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 15)),
                              Text("TP.HCM", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Icon(Icons.access_time, color: navyBlue, size: 24),
                        const SizedBox(width: 12),
                        Text(widget.selectedTime, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: navyBlue, size: 24),
                        const SizedBox(width: 12),
                        Text(_getFormattedDateWithYear(widget.selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyBlue, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0
                        ),
                        onPressed: () {
                          Navigator.pop(context); 
                          
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PaymentMethodScreen(
                              movie: widget.movie,
                              selectedDate: widget.selectedDate,
                              selectedTime: widget.selectedTime,
                              totalAmount: CartManager.instance.grandTotal,
                              showtimeId: widget.showtimeId,
                              cinemaName: widget.cinemaName, 
                              
                              userName: _userName,
                              userPhone: _userPhone,
                              userEmail: _userEmail,
                              roomName: widget.roomName,
                            )
                          ));
                        },
                        child: const Text("Xác nhận", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
              
              Positioned(
                top: -10,
                right: -10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = CartManager.instance;
    
    List<Map<String, dynamic>> currentSeats = [];
    if (widget.movie != null) {
      currentSeats = List<Map<String, dynamic>>.from(
        manager.getSeatsForShowtime(widget.movie!.id.toString(), widget.cinemaName, widget.selectedDate, widget.selectedTime) ?? []
      );
    }

    List<String> seatNames = currentSeats.map((s) => s['name'].toString()).toList();
    seatNames.sort();
    String formattedSeats = seatNames.join(', ');

    String displayRoom = widget.roomName;
    if (displayRoom.length >= 5) {
      displayRoom = displayRoom.substring(displayRoom.length - 5);
    }
    if (displayRoom.isEmpty) displayRoom = "Rạp 1";

    final ageInfo = _getAgeRatingInfo("T18"); 

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
            Expanded(child: Text('Thông tin thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(widget.movie != null ? "Thông tin đặt vé" : "Chi tiết đơn hàng", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.movie != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _getImage(widget.movie!.posterPath), 
                          width: 80, 
                          height: 110, 
                          fit: BoxFit.cover, 
                          errorBuilder: (_,__,___) => Container(width: 80, height: 110, color: Colors.grey.shade300)
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(_getCinemaLogo(widget.cinemaName), width: 24, height: 24, errorBuilder: (_,__,___) => const Icon(Icons.movie, size: 20)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(widget.cinemaName, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 6),

                          Text(
                            widget.movie != null ? widget.movie!.title : "Đơn Bắp Nước Tại Rạp", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, height: 1.2), 
                            maxLines: 2, overflow: TextOverflow.ellipsis
                          ),
                          
                          if (widget.movie != null) ...[
                            const SizedBox(height: 6),
                            Text("Hành động, Phiêu lưu", style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                  decoration: BoxDecoration(color: ageInfo['color'].withOpacity(0.1), border: Border.all(color: ageInfo['color'].withOpacity(0.5)), borderRadius: BorderRadius.circular(4)), 
                                  child: Text(ageInfo['label'], style: TextStyle(color: ageInfo['color'], fontWeight: FontWeight.bold, fontSize: 11))
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(ageInfo['desc'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic, height: 1.2))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.black12)),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.movie != null ? "Thời gian:" : "Lấy bắp ngày:", style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 4),
                      if (widget.movie != null) 
                        Text(widget.selectedTime, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 15)),
                      Text(_getFormattedDateWithYear(widget.selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 13)),
                    ]),
                    
                    if (widget.movie != null)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text("Định dạng:", style: TextStyle(color: Colors.black54, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text("2D Phụ đề", style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 15)),
                      ]),
                  ],
                ),

                if (widget.movie != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Phòng chiếu:", style: TextStyle(color: Colors.black54, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(displayRoom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text("Số ghế:", style: TextStyle(color: Colors.black54, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(formattedSeats, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Địa điểm nhận:", style: TextStyle(color: Colors.black54, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text("Quầy dịch vụ ${widget.cinemaName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                    ],
                  ),
                ]
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text("Dịch vụ ăn uống", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),

          ListenableBuilder(
            listenable: CartManager.instance,
            builder: (context, child) {
              final selectedFoods = manager.foods.where((f) => f.cinemaName == widget.cinemaName && f.receiveDate == widget.selectedDate).toList();

              bool showHorizontal = _startedEmpty;
              if (selectedFoods.isEmpty) {
                _startedEmpty = true; 
                showHorizontal = true;
              }

              if (showHorizontal) {
                if (_isLoadingFoods) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                if (_availableFoods.isEmpty) return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: const Center(child: Text("Rạp này chưa hỗ trợ bán bắp nước online.", style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic))));
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Bắp thơm nước ngọt mời bạn xơi nha!", style: TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 125, 
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _availableFoods.length,
                        itemBuilder: (context, index) {
                          final food = _availableFoods[index];
                          String imgPath = _getFoodImagePath(food);
                          
                          int qty = 0;
                          var existItem = CartManager.instance.foods.where((f) => f.food.id == food.id && f.cinemaName == widget.cinemaName && f.receiveDate == widget.selectedDate);
                          if (existItem.isNotEmpty) qty = existItem.first.quantity;
                          
                          return Container(
                            width: 300, 
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildFoodImage(imgPath, size: 80),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(
                                        (food.description.isNotEmpty ? food.description : "1 Bắp lớn, 2 Nước ngọt").replaceAll(RegExp(r',\s*'), ',\n'), 
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.3),
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(formatter.format(food.price), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  if (qty > 0) {
                                                    // 🚀 KIỂM TRA MUA LẺ: Đảm bảo không giảm món cuối cùng về 0
                                                    if (widget.movie == null && CartManager.instance.totalFoodsCount <= 1 && qty == 1) {
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đơn đặt thức ăn cần có ít nhất 1 sản phẩm!'), backgroundColor: Colors.red));
                                                      return;
                                                    }
                                                    CartManager.instance.updateFoodCart(food: food, cinemaName: widget.cinemaName, date: widget.selectedDate, quantity: qty - 1);
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: qty > 0 ? navyBlue : Colors.grey.shade300, width: 1.5)),
                                                  child: Icon(Icons.remove, size: 16, color: qty > 0 ? navyBlue : Colors.grey.shade400),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  CartManager.instance.updateFoodCart(food: food, cinemaName: widget.cinemaName, date: widget.selectedDate, quantity: qty + 1);
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: navyBlue, width: 1.5)),
                                                  child: Icon(Icons.add, size: 16, color: navyBlue),
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              } 
              
              return Column(
                children: selectedFoods.map((f) {
                  String imgPath = _getFoodImagePath(f.food);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildFoodImage(imgPath, size: 50),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                (f.food.description.isNotEmpty ? f.food.description : "1 Bắp lớn, 2 Nước ngọt").replaceAll(RegExp(r',\s*'), ',\n'),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                              ),
                              const SizedBox(height: 6),
                              Text(formatter.format(f.food.price), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // 🚀 KIỂM TRA MUA LẺ: Đảm bảo không giảm món cuối cùng về 0
                                  if (widget.movie == null && CartManager.instance.totalFoodsCount <= 1 && f.quantity == 1) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đơn đặt thức ăn cần có ít nhất 1 sản phẩm!'), backgroundColor: Colors.red));
                                    return;
                                  }
                                  CartManager.instance.updateFoodCart(food: f.food, cinemaName: widget.cinemaName, date: widget.selectedDate, quantity: f.quantity - 1);
                                },
                                child: const Icon(Icons.remove, size: 18, color: Colors.black54)
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text("${f.quantity}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyBlue)),
                              ),
                              GestureDetector(
                                onTap: () => CartManager.instance.updateFoodCart(food: f.food, cinemaName: widget.cinemaName, date: widget.selectedDate, quantity: f.quantity + 1),
                                child: const Icon(Icons.add, size: 18, color: Colors.black54)
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }).toList(),
              );
            }
          ),

          const SizedBox(height: 24),
          const Text("Thông tin liên hệ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: _isLoadingUser 
            ? Center(child: Padding(padding: const EdgeInsets.all(8.0), child: CircularProgressIndicator(color: navyBlue)))
            : Row(
              children: [
                Expanded(
                  child: (_userName.isNotEmpty && _userPhone.isNotEmpty)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text("$_userPhone | $_userEmail", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    )
                  : const Text("Chưa có thông tin liên hệ. Vui lòng cập nhật để tiếp tục.", style: TextStyle(color: Colors.red, fontSize: 13, fontStyle: FontStyle.italic)),
                ),
                IconButton(onPressed: _navigateToEditUserInfo, icon: const Icon(Icons.edit_square, color: Colors.grey, size: 20)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text("Ghi chú", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),

          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Nhập ghi chú cho nhân viên rạp (nếu có)...",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: navyBlue)),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
      
      bottomNavigationBar: ListenableBuilder(
        listenable: CartManager.instance,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng thanh toán', style: TextStyle(fontSize: 15, color: Colors.black54)),
                    Text(formatter.format(CartManager.instance.grandTotal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_userName.isEmpty || _userPhone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng cập nhật đầy đủ thông tin liên hệ!'), backgroundColor: Colors.red));
                        return;
                      }
                      // 🚀 KIỂM TRA CHỐT CUỐI: Chặn nút bấm nếu giỏ hàng 0đ
                      if (CartManager.instance.grandTotal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giỏ hàng trống hoặc có giá 0đ! Vui lòng chọn sản phẩm.'), backgroundColor: Colors.red));
                        return;
                      }
                      
                      _showConfirmationDialog();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: const Text('Tiếp tục', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

// =======================================================
// MÀN HÌNH CHỈNH SỬA THÔNG TIN KHÁCH HÀNG (GIỮ NGUYÊN)
// =======================================================
class EditUserInfoScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialEmail;

  const EditUserInfoScreen({super.key, required this.initialName, required this.initialPhone, required this.initialEmail});

  @override
  State<EditUserInfoScreen> createState() => _EditUserInfoScreenState();
}

class _EditUserInfoScreenState extends State<EditUserInfoScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController emailCtrl;
  final Color navyBlue = Colors.blue.shade900;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialName);
    phoneCtrl = TextEditingController(text: widget.initialPhone);
    emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Chỉnh sửa thông tin', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Họ và tên", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Số điện thoại", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                onPressed: () => Navigator.pop(context, {'name': nameCtrl.text, 'phone': phoneCtrl.text, 'email': emailCtrl.text}),
                child: const Text("Xác nhận thông tin", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}