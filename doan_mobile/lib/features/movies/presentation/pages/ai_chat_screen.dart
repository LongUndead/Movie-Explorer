import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; 
import 'dart:convert';
import 'dart:math' as math;

import '../../../movies/data/models/movie_model.dart';
import '../../data/models/cinema_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/cinema.dart';
import '../../domain/entities/movie.dart';
import 'movie_detail_page.dart';
import 'user_manager.dart';
import 'cinema_showtimes_page.dart';
import 'food_booking_page.dart';
import 'voucher_list_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _chatHistoryList = [];
  bool _isNewSession = true; 
  String? _currentSessionId;
  Cinema? _tempCinemaForFood;
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PageController _carouselController = PageController(viewportFraction: 0.65, initialPage: 999);
  late AnimationController _borderAnimationController;
  final FocusNode _focusNode = FocusNode();

  bool _isChatting = false; 
  bool _isLoading = false;
  bool _isTyping = false; 
  final Color navyBlue = Colors.blue.shade900;
  final Color primaryBlue = Colors.blue.shade700;

  
  final String apiBaseUrl = 'http://10.173.120.41:3000'; // NHỚ ĐỔI ĐÚNG IP

  // Format Tiền (VNĐ)
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

 @override
  void initState() {
    super.initState();
    _borderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
    });

    _focusNode.addListener(() {
      setState(() {}); 
    });

    _loadHistoryFromLocal(); // 🚀 ĐỌC LỊCH SỬ CỦA USER NÀY TỪ MÁY LÊN
    _startNewChat(); 
  }

  @override
  void dispose() {
    _carouselController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _borderAnimationController.dispose();
    _focusNode.dispose(); // 🚀 Giải phóng bộ nhớ FocusNode
    super.dispose();
  }

  // 🚀 HÀM LOAD LỊCH SỬ TỪ BỘ NHỚ THEO ID NGƯỜI DÙNG (ĐÃ FIX ÉP KIỂU AN TOÀN)
  Future<void> _loadHistoryFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = UserManager.instance.currentUser?.id?.toString() ?? 'guest';
    final String? savedData = prefs.getString('chat_history_$userId');

    if (savedData != null) {
      setState(() {
        // 🚀 Ép kiểu cẩn thận từ chuỗi JSON sang List<Map<String, dynamic>>
        final List<dynamic> decodedList = json.decode(savedData);
        _chatHistoryList = decodedList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    }
  }

  // 🚀 HÀM LƯU LỊCH SỬ XUỐNG BỘ NHỚ
  Future<void> _saveHistoryToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = UserManager.instance.currentUser?.id?.toString() ?? 'guest';
    await prefs.setString('chat_history_$userId', json.encode(_chatHistoryList));
  }

  // 🚀 KHỞI TẠO CUỘC TRÒ CHUYỆN MỚI
  void _startNewChat() {
    setState(() {
      _messages.clear();
      _isChatting = false;
      _isNewSession = true; 
      _currentSessionId = null;
      _messages.add({
        "role": "ai",
        "content": "${_getGreeting()},\nBạn cần hỗ trợ hay tìm phim gì hôm nay? ✨",
        "type": "text",
        "data": []
      });
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Buổi sáng năng lượng 🌤️";
    if (hour < 18) return "Buổi chiều vui vẻ ⛅";
    return "Buổi tối thư giãn 🌙";
  }

  String _getLogoForCinema(String cinemaName) {
    String nameLower = cinemaName.toLowerCase();
    if (nameLower.contains('cgv')) return 'assets/cgv1.png';
    if (nameLower.contains('lotte')) return 'assets/lotte.png';
    if (nameLower.contains('galaxy')) return 'assets/galaxy.png';
    if (nameLower.contains('bhd')) return 'assets/bhd.png';
    if (nameLower.contains('cinestar')) return 'assets/cinestar.png';
    if (nameLower.contains('mega')) return 'assets/megags.png';
    if (nameLower.contains('dcine')) return 'assets/dcine.png';
    if (nameLower.contains('aeon beta') || nameLower.contains('aeonbeta')) return 'assets/aeonbeta.png';
    if (nameLower.contains('beta')) return 'assets/betacinema.png';
    return 'assets/dexuat.png'; 
  }

  // 🚀 HÀM LOAD ẢNH BẮP NƯỚC (ĐÃ FIX LỖI KHÔNG ĐÚNG BRAND)
  String _getFoodImagePath(Map<String, dynamic> food) {
    String dbImage = (food['ImageURL']?.toString() ?? '').trim();
    if (dbImage.isEmpty || dbImage == 'null') return 'assets/cgv/default.png';

    if (dbImage.contains('public/foods') || dbImage.contains('food-')) {
      String filename = dbImage.split('/').last; 
      return '$apiBaseUrl/public/foods/$filename'; 
    }
    if (dbImage.startsWith('http')) return dbImage;

    final folders = {1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags', 7: 'dcine', 8: 'beta', 9: 'aeonbeta'};
    // Lấy brand_id (Hỗ trợ cả viết hoa và viết thường từ MySQL)
    final rawBrandId = food['brand_id']?.toString() ?? food['BrandID']?.toString() ?? '1';
    int bId = int.tryParse(rawBrandId) ?? 1;
    String folder = folders[bId] ?? 'cgv';
    
    if (dbImage.startsWith('/')) dbImage = dbImage.substring(1);
    if (dbImage.startsWith('assets/')) return dbImage;
    if (dbImage.startsWith('$folder/')) return 'assets/$dbImage';
    
    return 'assets/$folder/$dbImage';
  }

  Widget _buildFoodImage(String imagePath, {double? width, double? height}) {
    if (imagePath.isEmpty || imagePath == 'null') {
      return Container(width: width, height: height, color: Colors.orange.shade50, child: Icon(Icons.fastfood, color: Colors.orange.shade200));
    }
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath, width: width, height: height, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.orange.shade50, child: Icon(Icons.fastfood, color: Colors.orange.shade200))
      );
    }
    return Image.asset(
      imagePath, width: width, height: height, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.orange.shade50, child: Icon(Icons.fastfood, color: Colors.orange.shade200))
    );
  }

  // Hàm load ảnh Phim (Bản Full không bị cắt xén)
  String _getImage(String? path) {
    if (path == null || path.trim().isEmpty || path == 'null') {
      return 'https://via.placeholder.com/300x450?text=No+Image';
    }
    
    String cleanPath = path.trim();
    
    // 1. Gỡ lỗi Database lưu nhầm TMDB với file Local
    if (cleanPath.contains('image.tmdb.org') && (cleanPath.contains('uploads') || cleanPath.contains('avatars') || cleanPath.contains('public'))) {
      int cutIndex = cleanPath.indexOf('public');
      if (cutIndex == -1) cutIndex = cleanPath.indexOf('uploads');
      if (cutIndex == -1) cutIndex = cleanPath.indexOf('avatars');
      if (cutIndex != -1) cleanPath = cleanPath.substring(cutIndex); 
    }
    
    // 2. Link web ngoài chuẩn thì giữ nguyên
    if (cleanPath.startsWith('http')) return cleanPath; 
    
    // 3. Xử lý ảnh diễn viên
    if (cleanPath.contains('avatars') || cleanPath.contains('avatar-')) {
      return '$apiBaseUrl/public/avatars/${cleanPath.split('/').last}';
    }
    
    // 4. Xử lý ảnh Phim (Poster/Backdrop) tự upload
    if (cleanPath.contains('uploads') || cleanPath.contains('movie-')) {
      return '$apiBaseUrl/uploads/${cleanPath.split('/').last}';
    }
    
    // 5. Ảnh gốc từ TheMovieDB
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return 'https://image.tmdb.org/t/p/w500$cleanPath';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 🚀 LƯU SESSION MỚI VÀO LỊCH SỬ CHAT
    if (_isNewSession) {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _chatHistoryList.insert(0, {
        "id": _currentSessionId, 
        "title": text,
        "messages": [] // Chứa toàn bộ nội dung chat của session này
      });
      _isNewSession = false;
    }

    setState(() {
      _isChatting = true;
      _messages.add({"role": "user", "content": text, "type": "text", "data": []});
      _updateHistorySession(); // Update lại lịch sử
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    double? lat; double? lng;
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 3));
      lat = position.latitude; lng = position.longitude;
    } catch (_) {}

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': text, 'userName': UserManager.instance.currentUser?.name ?? 'Bạn', 'lat': lat, 'lng': lng}),
      );

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        setState(() {
          _messages.add({"role": "ai", "content": resData['reply'] ?? "", "type": resData['type'] ?? "text", "data": resData['data'] ?? []});
          _updateHistorySession(); // Update lại lịch sử khi AI trả lời
        });
      } else {
        setState(() => _messages.add({"role": "ai", "content": "AI đang bảo trì! 😥", "type": "text", "data": []}));
      }
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "content": "Mất kết nối server rồi! 🔌", "type": "text", "data": []}));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // 🚀 ĐÃ SỬA LẠI: LƯU VÀO BIẾN XONG THÌ LƯU LUÔN XUỐNG BỘ NHỚ MÁY
  void _updateHistorySession() {
    if (_currentSessionId == null) return;
    final index = _chatHistoryList.indexWhere((s) => s['id'] == _currentSessionId);
    if (index != -1) {
      _chatHistoryList[index]['messages'] = List<Map<String, dynamic>>.from(_messages);
    }
    _saveHistoryToLocal(); // 🚀 GHI ĐÈ XUỐNG MÁY TẠI ĐÂY
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ========================================================
  // 🕒 BOTTOM SHEET LỊCH SỬ CHAT CÓ CHỨA TIN NHẮN THẬT
  // ========================================================
  void _showChatHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1F22), 
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(10)))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("Gần đây", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade400))),
                  Expanded(
                    child: _chatHistoryList.isEmpty 
                      ? Center(child: Text("Chưa có lịch sử trò chuyện", style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _chatHistoryList.length,
                          itemBuilder: (context, index) {
                            final session = _chatHistoryList[index];
                            bool isCurrentSession = _currentSessionId == session['id']; 
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(color: isCurrentSession ? const Color(0xFF2B2D31) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.only(left: 16, right: 8),
                                title: Text(session['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                                  color: const Color(0xFF2B2D31),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text('Xóa', style: TextStyle(color: Colors.redAccent))])),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      setModalState(() {
                                        _chatHistoryList.removeAt(index);
                                        _saveHistoryToLocal(); // 🚀 XÓA TRONG BIẾN XONG PHẢI XÓA DƯỚI MÁY
                                        if (isCurrentSession) _startNewChat();
                                      });
                                      setState((){}); 
                                    }
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  // 🚀 RESTORE LẠI BOX CHAT TỪ LỊCH SỬ
                                  setState(() {
                                    _currentSessionId = session['id'];
                                    _messages.clear();
                                    _messages.addAll(List<Map<String, dynamic>>.from(session['messages']));
                                    _isChatting = true;
                                    _isNewSession = false;
                                  });
                                  _scrollToBottom();
                                },
                              ),
                            );
                          }
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white, elevation: 0, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      icon: const Icon(Icons.add_comment_rounded, size: 20),
                      label: const Text("Bắt đầu trò chuyện mới", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.pop(context);
                        _startNewChat();
                      },
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Stack(
        children: [ // 🚀 MỞ MẢNG CHILDREN CỦA STACK
          
          // 🚀 HIỆU ỨNG NỀN FULL MÀN HÌNH: SÓNG XOAY MƯỢT MÀ VÔ TẬN
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _borderAnimationController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      // 🚀 Cố định điểm bắt đầu/kết thúc để tránh bị giật tọa độ
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade300,
                        Colors.purple.shade300,
                        Colors.pink.shade300,
                        Colors.orange.shade200,
                        Colors.blue.shade300, 
                      ],
                      // 🚀 Thần chú tạo sóng: Xoay dải màu 360 độ liên tục, khớp 100% khi reset vòng lặp
                      transform: GradientRotation(_borderAnimationController.value * 2 * math.pi),
                    ),
                  ),
                  // 🚀 MẶT NẠ ĐIỀU CHỈNH ĐỘ ĐẬM NHẠT TỪ TRÊN XUỐNG DƯỚI (Giữ nguyên)
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFF4F6FB).withOpacity(0.92), 
                        const Color(0xFFF4F6FB).withOpacity(0.65), 
                        const Color(0xFFF4F6FB).withOpacity(0.0),  
                      ],
                      stops: const [0.0, 0.6, 1.0], 
                    ),
                  ),
                );
              },
            ),
          ), // 🚀 NHỚ DẤU PHẨY Ở ĐÂY ĐỂ NGĂN CÁCH 2 LỚP

          // 🚀 LỚP THỨ 2 (NẰM ĐÈ LÊN TRÊN): GIAO DIỆN CHAT VÀ NÚT BẤM
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
                        ),
                      ),
                      Text('Trợ lý ăn chơi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
                      const SizedBox(width: 34),
                    ],
                  ),
                ),
                Expanded(child: _isChatting ? _buildChatUI() : _buildWelcomeUI()),
                _buildBottomInput(),
              ],
            ),
          ),

        ], // 🚀 ĐÓNG MẢNG CHILDREN CỦA STACK KẾT THÚC TẠI ĐÂY
      ),
    );
  }
  Widget _buildWelcomeUI() {
    List<String> titles = [
      "Khuyến mãi\nmới nhất", 
      "Phim hot\nđang chiếu rạp", 
      "Địa chỉ rạp\nnào ở gần tôi"
    ];
    
    // 🚀 KHAI BÁO MẢNG ẢNH ĐỂ ĐƯA VÀO 3 THẺ CAROUSEL
    List<String> images = [
      "assets/banner_khuyenmai.png", 
      "assets/banner_phimhot.png", 
      "assets/banner_rap.png"
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🚀 THAY ICON BẰNG ẢNH GIF BO TRÒN GÓC
                Container(
                  width: 52, 
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50, // Giữ lại nền xanh nhạt cho xịn
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/bot.gif', // 🚀 NHỚ ĐỔI THÀNH ĐÚNG TÊN FILE GIF CỦA ÔNG NHÉ!
                      fit: BoxFit.cover,
                      // Xử lý lỗi nếu ông chưa kịp chép file gif vào thì nó vẫn hiện icon mặc định
                      errorBuilder: (_, __, ___) => const Center(child: Text("🤖", style: TextStyle(fontSize: 28))),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text("${_getGreeting()},\nBạn muốn xem gì hôm nay?", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.3))),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text("Mọi người thường hỏi gì?", style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          
          // 🚀 GIẢM HEIGHT TỪ 350 XUỐNG 200 ĐỂ KÉO PHẦN GỢI Ý LÊN TRÊN
          SizedBox(
            height: 350, 
            child: PageView.builder(
              controller: _carouselController,
              itemBuilder: (context, index) {
                final realIndex = index % titles.length; 
                return AnimatedBuilder(
                  animation: _carouselController,
                  builder: (context, child) {
                    double pageOffset = 0;
                    if (_carouselController.position.haveDimensions) {
                      pageOffset = _carouselController.page! - index;
                    } else {
                      pageOffset = (999.0 - index).toDouble(); 
                    }
                    double scale = (1 - (pageOffset.abs() * 0.15)).clamp(0.8, 1.0);
                    double opacity = (1 - (pageOffset.abs() * 0.3)).clamp(0.5, 1.0);
                    return Transform.scale(scale: scale, child: Opacity(opacity: opacity, child: child));
                  },
                  // 🚀 TRUYỀN THÊM BIẾN ẢNH VÀO HÀM CARD
                  child: _buildCarouselCard(titles[realIndex], images[realIndex], realIndex + 1, titles.length),
                );
              },
            ),
          ),
          
          // 🚀 THU GỌN KHOẢNG TRỐNG NÀY ĐỂ MỤC GỢI Ý NẰM SÁT CAROUSEL NHẤT
          const SizedBox(height: 12), 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Gợi ý dành cho bạn", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), 
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildSuggestionChip("Danh sách món\ntại CGV"),
                _buildSuggestionChip("Phim sắp chiếu\nngày thứ 6"),
                _buildSuggestionChip("Bảng xếp hạng\nchiếu rạp\ntuần này"),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  // 🚀 NHẬN THÊM BIẾN imagePath
  Widget _buildCarouselCard(String title, String imagePath, int currentIndex, int total) {
    return GestureDetector(
      onTap: () => _sendMessage(title.replaceAll('\n', ' ')),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // 🚀 XÓA CONTAINER CHỨA ICON, THAY BẰNG CLIPRRECT CHỨA ẢNH
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.asset(
                      imagePath, 
                      width: double.infinity, 
                      height: double.infinity, 
                      fit: BoxFit.cover, // 🚀 THẦN CHÚ "COVER": Tự động cắt xén ảnh vừa khít mọi khung hình mà không bị méo!
                      errorBuilder: (_,__,___) => Container(color: Colors.blue.shade50, child: Center(child: Icon(Icons.movie_filter_rounded, size: 70, color: Colors.blue.shade200))),
                    ),
                  ),
                  Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(12)), child: Text("$currentIndex/$total", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [Icon(Icons.local_activity, color: primaryBlue, size: 22), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 2))]),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text.replaceAll('\n', ' ')),
      child: Container(
        width: 130, height: 90, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
        child: Center(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.3), textAlign: TextAlign.left)),
      ),
    );
  }

  Widget _buildChatUI() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // 🚀 ĐÃ BỎ VÒNG XOAY TRÒN, THAY BẰNG KHUNG CHAT AN ỦI CHỜ ĐỢI
        // 🚀 HIỆU ỨNG TỪNG CHỮ CÁI NHẢY MÚA LƯỢN SÓNG (WAVE ANIMATION)
        if (index == _messages.length && _isLoading) {
          String fullName = UserManager.instance.currentUser?.name ?? 'bạn';
          String shortName = fullName.trim().split(' ').last;
          String waitText = "$shortName ơi, đợi trợ lý tí nhé...";

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), 
                  topRight: Radius.circular(20), 
                  bottomLeft: Radius.circular(4), 
                  bottomRight: Radius.circular(20)
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
              ),
              child: AnimatedBuilder(
                animation: _borderAnimationController,
                builder: (context, child) {
                  // 🚀 Dùng Wrap và List.generate để "chẻ" câu nói ra thành từng ký tự riêng biệt
                  return Wrap(
                    children: List.generate(waitText.length, (i) {
                      // Tính độ trễ (phase): Ký tự thứ i sẽ trễ nhịp (0.3) so với ký tự trước nó
                      final double phase = i * 0.3; 
                      // Tính toán độ cao dy cho từng ký tự dựa theo hàm lượng giác và độ trễ
                      final dy = math.sin((_borderAnimationController.value * 6 * math.pi) - phase) * 2.5;

                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Text(
                          waitText[i], // Vẽ từng ký tự một
                          style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          );
        }
        final msg = _messages[index];
        final isUser = msg["role"] == "user";
        final String uiType = msg["type"] ?? "text";
        final List<dynamic> aiData = msg["data"] ?? [];

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                decoration: BoxDecoration(
                  color: isUser ? navyBlue : Colors.white, 
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(isUser ? 20 : 4), bottomRight: Radius.circular(isUser ? 4 : 20)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                ),
                child: Text(msg["content"]!, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15, height: 1.4)),
              ),
              
              if (!isUser && uiType == "movie" && aiData.isNotEmpty) _buildMovieHorizontalList(aiData),
              if (!isUser && uiType == "food" && aiData.isNotEmpty) _buildFoodHorizontalList(aiData), 
              // 🚀 THÊM LOẠI "cinema_for_food" ĐỂ XUẤT LIST CHI NHÁNH RẠP
              if (!isUser && (uiType == "cinema" || uiType == "voucher" || uiType == "cinema_for_food") && aiData.isNotEmpty) _buildVerticalCardList(aiData, uiType), 
            ],
          ),
        );
      },
    );
  }

  // 🚀 ĐÃ GỌT SẠCH POP-UP THỪA. BẤM MÓN ĂN LÀ BAY THẲNG VÀO RẠP ĐÃ CHỌN!
  Widget _buildFoodHorizontalList(List<dynamic> foods) {
    return Container(
      height: 190,
      margin: const EdgeInsets.only(bottom: 16, left: 4),
      width: MediaQuery.of(context).size.width * 0.85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length,
        itemBuilder: (context, idx) {
          final food = foods[idx];

          final rawPrice = food['Price']?.toString() ?? food['price']?.toString() ?? '0';
          final int price = double.tryParse(rawPrice)?.toInt() ?? 0;

          return GestureDetector(
            onTap: () {
              // 🚀 BAY THẲNG SANG TRANG FOOD VÀ TRUYỀN CÁI RẠP ĐÃ CHỌN Ở BƯỚC TRƯỚC VÀO
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => FoodBookingPage(initialCinema: _tempCinemaForFood)
                )
              );
            },
            child: Container(
              width: 130, margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _buildFoodImage(_getFoodImagePath(food), width: 130, height: 110),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(food['Name'] ?? 'Bắp nước', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87, height: 1.2)),
                        const SizedBox(height: 6),
                        Text(formatter.format(price), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red.shade400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildMovieHorizontalList(List<dynamic> movies) {
    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 16, left: 4),
      width: MediaQuery.of(context).size.width * 0.85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        itemBuilder: (context, idx) {
          final rawMap = Map<String, dynamic>.from(movies[idx]);
          final movie = MovieModel.fromJson(rawMap);

          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
            child: Container(
              width: 120, margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_getImage(movie.posterPath), height: 160, width: 120, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(height: 160, width: 120, color: Colors.blue.shade50, child: Center(child: Icon(Icons.movie_creation_outlined, color: Colors.blue.shade200, size: 40))))),
                  const SizedBox(height: 6),
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalCardList(List<dynamic> items, String type) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.only(bottom: 16, left: 4),
      child: Column(
        children: items.map((item) {
          String title = "";
          String subtitle = "";
          Widget leadingWidget;
          
          if (type == "cinema" || type == "cinema_for_food") {
            title = item['name'] ?? 'Tên rạp';
            subtitle = item['address'] ?? 'Địa chỉ';
            leadingWidget = Image.asset(_getLogoForCinema(title), fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.theaters, color: Colors.blue));
          } else {
            title = "Mã: ${item['Code']}";
            subtitle = "Giảm ${item['DiscountPercent']}%";
            leadingWidget = Icon(Icons.card_giftcard_rounded, color: primaryBlue, size: 26);
          }

          return GestureDetector(
            onTap: () {
              if (type == "cinema") {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaShowtimesPage(cinemaId: item['id'].toString(), cinemaName: item['name'], cinemaAddress: item['address'])));
              } else if (type == "voucher") {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherListScreen())); 
              } else if (type == "cinema_for_food") {
                // 🚀 LƯU LẠI RẠP KHÁCH VỪA BẤM VÀ GỬI LỆNH LẤY BẮP NƯỚC
                _tempCinemaForFood = CinemaModel.fromJson(Map<String, dynamic>.from(item));
                
                int bId = 1;
                String nameLower = title.toLowerCase();
                if (nameLower.contains('galaxy')) bId = 2;
                else if (nameLower.contains('lotte')) bId = 3;
                else if (nameLower.contains('bhd')) bId = 4;
                else if (nameLower.contains('cinestar')) bId = 5;
                else if (nameLower.contains('mega')) bId = 6;
                else if (nameLower.contains('dcine')) bId = 7;
                else if (nameLower.contains('beta')) bId = 8;
                else if (nameLower.contains('aeon')) bId = 9;

                // Gửi tin nhắn ngầm báo hệ thống load món của rạp này
                _sendMessage("Đã chọn chi nhánh: $title | brand: $bId");
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
              child: Row(
                children: [
                  Container(
                    width: 45, height: 45, padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade100)),
                    child: leadingWidget,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), // 🚀 Thu nhỏ padding ngoài
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _showChatHistoryBottomSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 10, bottom: 2),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white, 
                shape: BoxShape.circle, 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]
              ),
              child: Icon(Icons.history_rounded, color: Colors.grey.shade700, size: 20),
            ),
          ),
          
          Expanded(
            child: AnimatedBuilder(
              animation: _borderAnimationController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: SweepGradient(
                      colors: [Colors.blue.shade900, Colors.pink.shade300, Colors.purple.shade400, Colors.blue.shade300, Colors.blue.shade900],
                      transform: GradientRotation(_borderAnimationController.value * 2 * math.pi),
                    ),
                  ),
                  padding: const EdgeInsets.all(1.8), 
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(22)),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode, 
                  onSubmitted: _sendMessage,
                  minLines: 1,
                  maxLines: 4, 
                  style: const TextStyle(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: "Nhập nội dung...", 
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.5),
                    prefixIcon: !_focusNode.hasFocus 
                      ? Icon(Icons.auto_awesome, color: primaryBlue, size: 20) 
                      : null, 
                    suffixIcon: _isTyping 
                      ? IconButton(
                          icon: Icon(Icons.send_rounded, color: primaryBlue, size: 22),
                          onPressed: () => _sendMessage(_messageController.text),
                        )
                      : const SizedBox.shrink(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // 🚀 Giảm padding dọc từ 14 xuống 10 cho box mỏng lại
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}