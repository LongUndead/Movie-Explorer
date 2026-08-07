import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; 
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart'; 
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../bloc/movie_bloc.dart'; 
import '../../domain/entities/movie.dart';
import 'cinema_selection_page.dart'; 
import 'user_manager.dart';
import 'guest_guard.dart';
import 'review_list_page.dart';
import 'package:intl/intl.dart';

// ============================================================================
// 1. MÀN HÌNH CHI TIẾT PHIM CHÍNH
// ============================================================================
class MovieDetailPage extends StatefulWidget {
  final Movie movie;
  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  bool _isExpanded = false; 
  List<dynamic> _castList = [];

  bool _isFavorite = false; 
  final String apiBaseUrl = 'http://192.168.1.7:3000';

  final Color navyBlue = Colors.blue.shade900;
  final Color starColor = Colors.orange;

  PageController? _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  final List<String> _bannerImages = [
    'assets/banner-1.png',
    'assets/banner-2.png',
    'assets/banner-3.png',
  ];

  // ========================================================
  // 🚀 BIẾN LƯU TRỮ ĐIỂM SỐ VÀ TIẾN ĐỘ THẬT TỪ CỘNG ĐỒNG
  // ========================================================
  double _dynamicRating = 0.0;
  int _totalReviews = 0;

  // ==========================================
  // 🚀 BIẾN LƯU TRỮ THÔNG BÁO TỪ DATABASE
  // ==========================================
  List<dynamic> _notifications = [];
  int get unreadCount => _notifications.where((n) => n['IsRead'] == 0).length;

  Future<void> _fetchNotifications() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return; 

    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/users/${user.id}/notifications'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = json.decode(res.body);
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải thông báo: $e");
    }
  }

  Future<void> _markAsRead(int notifId) async {
    try {
      await http.put(Uri.parse('$apiBaseUrl/api/users/notifications/$notifId/read'));
      _fetchNotifications(); 
    } catch (e) {
      debugPrint("Lỗi đánh dấu đã đọc: $e");
    }
  }
  double _pct9_10 = 0.85, _pct7_8 = 0.1, _pct5_6 = 0.02, _pct3_4 = 0.0, _pct1_2 = 0.03;

  Future<void> _fetchReviewStats() async {
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/movies/${widget.movie.id}/reviews'));
      if (res.statusCode == 200) {
        List<dynamic> reviews = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _totalReviews = reviews.length;
            if (reviews.isNotEmpty) {
              double totalScore = 0.0;
              int validCount = 0;
              int c9 = 0, c7 = 0, c5 = 0, c3 = 0, c1 = 0;

              for (var r in reviews) {
                if (r['rating'] != null) {
                  double score = double.tryParse(r['rating'].toString()) ?? 0.0;
                  totalScore += score;
                  validCount++;
                  
                  if (score >= 9) c9++;
                  else if (score >= 7) c7++;
                  else if (score >= 5) c5++;
                  else if (score >= 3) c3++;
                  else c1++;
                }
              }
              if (validCount > 0) {
                _dynamicRating = totalScore / validCount;
                _pct9_10 = c9 / validCount;
                _pct7_8 = c7 / validCount;
                _pct5_6 = c5 / validCount;
                _pct3_4 = c3 / validCount;
                _pct1_2 = c1 / validCount;
              }
            } else {
              _dynamicRating = widget.movie.voteAverage ?? 9.7; // Giữ gốc nếu chưa có ai đánh giá
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi fetch reviews stats: $e');
    }
  }
  
  // HÀM TỰ ĐỘNG CHẠY BANNER
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
  void initState() {
    super.initState();
    _dynamicRating = widget.movie.voteAverage ?? 9.7; // Set mặc định ban đầu
    _fetchReviewStats(); // 🚀 Gọi hàm đồng bộ điểm thật
    _checkFavoriteStatus();
    _fetchNotifications();
    try {
      if (widget.movie.castJson != null && widget.movie.castJson!.isNotEmpty) {
        _castList = jsonDecode(widget.movie.castJson!);
      }
    } catch (e) {
      debugPrint("Lỗi parse Cast JSON: $e");
    }
    _bannerPageController = PageController(initialPage: 0);
    _setupBannerAutoScroll();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerPageController?.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    int userId = UserManager.instance.currentUser?.id ?? 1; 
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/favorites/movie/check?user_id=$userId&movie_id=${widget.movie.id}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _isFavorite = data['isFavorite']);
      }
    } catch (e) {
      debugPrint('Lỗi check favorite: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    int userId = UserManager.instance.currentUser?.id ?? 1;
    bool newStatus = !_isFavorite;
    
    setState(() => _isFavorite = newStatus);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newStatus ? 'Đã lưu ${widget.movie.title} vào danh sách yêu thích ❤️' : 'Đã bỏ yêu thích phim này.'),
      backgroundColor: newStatus ? Colors.red : navyBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/favorites/movie/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'movie_id': widget.movie.id,
          'is_favorite': newStatus,
        }),
      );
    } catch (e) {
      debugPrint('Lỗi toggle favorite: $e');
    }
  }

  // ==========================================
  // 🚀 BẢNG HIỂN THỊ THÔNG BÁO GIỐNG Y HỆT TRANG CHỦ
  // ==========================================
  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  Text("Thông báo của bạn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                  const Divider(height: 30),
                  
                  Expanded(
                    child: _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text("Bạn chưa có thông báo nào", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            final isUnread = notif['IsRead'] == 0;
                            
                            // Parse và Format thời gian (Giả sử CreatedAt từ DB trả ra)
                            DateTime createdAt = DateTime.tryParse(notif['CreatedAt'] ?? '')?.toLocal() ?? DateTime.now();
                            String timeString = DateFormat('HH:mm - dd/MM/yyyy').format(createdAt);

                            // 🚀 PHÂN LOẠI ICON VÀ MÀU SẮC THEO TYPE (TỪ BACKEND TRẢ VỀ)
                            IconData iconData = Icons.notifications;
                            Color iconColor = Colors.white;
                            Color bgColor = navyBlue;

                            switch (notif['Type']) {
                              case 'BOOKING': // Mua vé thành công
                                iconData = Icons.confirmation_num_outlined;
                                bgColor = Colors.teal.shade500;
                                break;
                              case 'VOUCHER': // Tặng voucher
                                iconData = Icons.card_giftcard;
                                bgColor = Colors.orange.shade500;
                                break;
                              case 'MOVIE': // Thêm phim mới
                                iconData = Icons.local_movies_outlined;
                                bgColor = Colors.blue.shade500;
                                break;
                              case 'FOOD': // Thêm món mới
                                iconData = Icons.fastfood_outlined;
                                bgColor = Colors.amber.shade600;
                                break;
                              case 'REFUND': // Hoàn vé
                                iconData = Icons.currency_exchange;
                                bgColor = Colors.teal.shade500;
                                break;
                              case 'WARNING': // Cảnh báo, Khóa acc, Phạt bài viết
                              case 'BANNED':
                                iconData = Icons.gavel_rounded; // Búa phán quyết của Admin =))
                                bgColor = Colors.red.shade600;
                                break;
                              default:
                                iconData = Icons.notifications;
                                bgColor = navyBlue;
                            }

                            return GestureDetector(
                              onTap: () {
                                // 1. Đánh dấu đã đọc
                                if (isUnread) {
                                  _markAsRead(notif['NotificationID']);
                                  setModalState(() {
                                    notif['IsRead'] = 1;
                                  });
                                }

                                // 2. ĐÓNG CỬA SỔ THÔNG BÁO LẠI
                                Navigator.pop(context);

                                // 3. BẮT ĐẦU BẺ LÁI (CHUYỂN TRANG NẾU CÓ URL)
                                final actionUrl = notif['ActionURL'] ?? '';
                                if (actionUrl.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng quay lại trang chủ để mở liên kết này!')));
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUnread ? Colors.blue.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isUnread ? Colors.blue.shade100 : Colors.transparent)
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🚀 ÁP DỤNG ĐÚNG MÀU BACKGROUND TƯƠNG ỨNG NẾU CHƯA ĐỌC
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isUnread ? bgColor : Colors.grey.shade300, 
                                        shape: BoxShape.circle
                                      ),
                                      child: Icon(iconData, color: isUnread ? iconColor : Colors.grey.shade600, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(notif['Title'] ?? 'Thông báo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isUnread ? Colors.black87 : Colors.black54)),
                                          const SizedBox(height: 4),
                                          Text(notif['Content'] ?? '', style: TextStyle(color: isUnread ? Colors.black87 : Colors.black54, fontSize: 13, height: 1.4)),
                                          const SizedBox(height: 8),
                                          Text(timeString, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 8, height: 8,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // 🚀 HÀM BỌC THÉP XỬ LÝ ẢNH CHUẨN XÁC 100% (PHÂN BIỆT RÕ POSTER & AVATAR)
  String _getImage(String? path) {
    if (path == null || path.trim().isEmpty || path == 'null') {
      return 'https://via.placeholder.com/300x450?text=No+Image';
    }
    
    String cleanPath = path.trim();

    // 1. Chém bỏ TMDB bị dư thừa (nếu DB lỡ gài nhầm vào ảnh local)
    if (cleanPath.contains('image.tmdb.org') && (cleanPath.contains('uploads') || cleanPath.contains('avatars') || cleanPath.contains('public'))) {
      int cutIndex = cleanPath.indexOf('public');
      if (cutIndex == -1) cutIndex = cleanPath.indexOf('uploads');
      if (cutIndex == -1) cutIndex = cleanPath.indexOf('avatars');
      if (cutIndex != -1) cleanPath = cleanPath.substring(cutIndex); 
    }

    // 2. Link web ngoài chuẩn (VD: ui-avatars.com hoặc http bình thường)
    if (cleanPath.startsWith('http')) return cleanPath; 
    
    // 3. 📸 XỬ LÝ ẢNH DIỄN VIÊN (Backend yêu cầu phải có chữ /public/avatars/...)
    if (cleanPath.contains('avatars') || cleanPath.contains('avatar-')) {
      String filename = cleanPath.split('/').last; // Chỉ lấy đúng cái tên file (VD: avatar-123.jpg)
      return '$apiBaseUrl/public/avatars/$filename';
    }

    // 4. 🎞️ XỬ LÝ ẢNH POSTER/BACKDROP (Backend yêu cầu /uploads/... không có chữ public)
    if (cleanPath.contains('uploads') || cleanPath.contains('movie-')) {
      String filename = cleanPath.split('/').last; // Chỉ lấy đúng cái tên file (VD: movie-123.jpg)
      return '$apiBaseUrl/uploads/$filename';
    }

    // 5. Ảnh gốc từ TheMovieDB (chỉ có /abc.jpg)
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return 'https://image.tmdb.org/t/p/w500$cleanPath';
  }
  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "Đang cập nhật";
    try {
      final parts = date.split('-');
      if (parts.length == 3) return "${parts[2]}/${parts[1]}/${parts[0]}";
    } catch (_) {}
    return date;
  }

  String _getAgeText(String rating) {
    if (rating.contains('18')) return "Phim được phổ biến đến người xem từ đủ 18 tuổi trở lên";
    if (rating.contains('16')) return "Phim được phổ biến đến người xem từ đủ 16 tuổi trở lên";
    if (rating.contains('13')) return "Phim được phổ biến đến người xem từ đủ 13 tuổi trở lên";
    return "Phim được phép phổ biến rộng rãi đến mọi đối tượng";
  }

  bool _isUpcomingMovie() {
    if (widget.movie.releaseDate == null || widget.movie.releaseDate!.isEmpty) return false;
    try {
      final releaseDate = DateTime.parse(widget.movie.releaseDate!);
      final now = DateTime.now();
      return releaseDate.isAfter(now); 
    } catch (_) {
      return false;
    }
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
            Expanded(child: Text('Thông tin phim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50])),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)), // Nền trắng đục đục cho nút nổi bật
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🚀 NÚT CHUÔNG THÔNG BÁO (BỌC THÉP GUEST GUARD VÀ MỞ BOX THẬT)
                InkWell(
                  onTap: () {
                    GuestGuard.check(context, () {
                      _showNotificationBottomSheet(); // 🚀 Bấm phát mở luôn Box thông báo
                    });
                  }, 
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                    // 🚀 THÊM CỤC CHẤM ĐỎ BÁO SỐ LƯỢNG CHƯA ĐỌC
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications_outlined, color: navyBlue, size: 19),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2, right: -4, 
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                unreadCount > 9 ? '9+' : unreadCount.toString(), 
                                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, height: 1)
                              ),
                            ),
                          ),
                      ],
                    )
                  )
                ),
                Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)), // Vạch kẻ phân cách
                
                // 🚀 NÚT TRANG CHỦ
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                    child: Icon(Icons.home_outlined, color: navyBlue, size: 19)
                  )
                ),
              ],
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: _buildBottomBar(navyBlue),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BOX 1: THÔNG TIN PHIM
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_getImage(widget.movie.posterPath), width: 120, height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 120, height: 180, color: Colors.grey[300])),
                          ),
                          if (_isUpcomingMovie()) 
                            Positioned(
                              top: 8, left: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Colors.amber, 
                                  borderRadius: BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.access_time_filled, color: Colors.white, size: 10), 
                                    SizedBox(width: 4),
                                    Text("COMING SOON", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.movie.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.3, color: navyBlue), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(widget.movie.genres ?? 'Đang cập nhật', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: _getAgeColor(widget.movie.ageRating), shape: BoxShape.circle),
                                  child: Text(widget.movie.ageRating ?? 'P', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_getAgeText(widget.movie.ageRating ?? 'P'), style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    _isFavorite ? Icons.favorite : Icons.favorite_border, 
                                    "Thích",
                                    iconColor: _isFavorite ? Colors.red : navyBlue,
                                    onTap: _toggleFavorite, 
                                  )
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildActionButton(
                                    Icons.play_circle_outline, 
                                    "Trailer", 
                                    onTap: () {
                                      String url = (widget.movie.trailerUrl != null && widget.movie.trailerUrl!.isNotEmpty) 
                                          ? widget.movie.trailerUrl! 
                                          : "https://www.youtube.com/watch?v=TcMBFSGVi1c"; 
                                      
                                      _openTrailer(url);
                                    }
                                  )
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(child: _buildInfoColumn('Ngày khởi chiếu', _formatDate(widget.movie.releaseDate))),
                        VerticalDivider(color: Colors.grey.shade200, thickness: 1, width: 1),
                        Expanded(child: _buildInfoColumn('Thời lượng', _formatDuration(widget.movie.duration))), 
                        VerticalDivider(color: Colors.grey.shade200, thickness: 1, width: 1),
                        Expanded(child: _buildInfoColumn('Ngôn ngữ', widget.movie.language?.replaceAll(', ', '\n') ?? 'Phụ đề\nLồng Tiếng')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
           // BOX 2: TỔNG QUAN ĐÁNH GIÁ (STYLE ĐỒNG BỘ - GIÃN CÁCH THOÁNG ĐÃNG)
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewListPage(movie: widget.movie, navyBlue: navyBlue, starColor: starColor)));
                _fetchReviewStats(); // Reload điểm
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: navyBlue.withOpacity(0.2), width: 1.2), // Viền xanh nhạt đồng bộ
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: navyBlue.withOpacity(0.06), // Nền xanh navy siêu nhạt
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_activity, color: navyBlue, size: 20),
                              const SizedBox(width: 8),
                              Text('CinemaTickets Rating', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: navyBlue)),
                            ],
                          ),
                          Text('Xem tất cả', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: navyBlue)),
                        ],
                      ),
                    ),
                    
                    // --- NỘI DUNG (ĐÃ THÊM KHOẢNG CÁCH GIỮA 2 CỘT) ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Row(
                        children: [
                          // Cột trái: Điểm số
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Icon(Icons.star, color: starColor, size: 38),
                                      const SizedBox(width: 4),
                                      Text(_dynamicRating.toStringAsFixed(1), style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.0, color: navyBlue)),
                                      const Padding(padding: EdgeInsets.only(bottom: 6.0), child: Text('/10', style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('($_totalReviews đánh giá)', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)), 
                              ],
                            ),
                          ),
                          
                          // 🚀 THÊM KHOẢNG CÁCH "THỞ" 20 PIXELS Ở ĐÂY
                          const SizedBox(width: 20), 
                          
                          // Cột phải: Thanh biểu đồ
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildRatingBar('9-10', _pct9_10), const SizedBox(height: 6),
                                _buildRatingBar('7-8', _pct7_8), const SizedBox(height: 6),
                                _buildRatingBar('5-6', _pct5_6), const SizedBox(height: 6),
                                _buildRatingBar('3-4', _pct3_4), const SizedBox(height: 6),
                                _buildRatingBar('1-2', _pct1_2),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOX 3: NỘI DUNG PHIM
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nội dung phim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: RichText(
                      text: TextSpan(
                        text: _isExpanded ? widget.movie.overview : (widget.movie.overview.length > 150 ? '${widget.movie.overview.substring(0, 150)}...' : widget.movie.overview),
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                        children: [
                          if (widget.movie.overview.length > 150) TextSpan(text: _isExpanded ? " Thu gọn" : " Xem thêm", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // BOX 4: DIỄN VIÊN
            if (_castList.isNotEmpty)
              Container(
                width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Diễn viên và Đoàn làm phim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue))),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _castList.length,
                        itemBuilder: (context, index) {
                          final actor = _castList[index];
                          final img = (actor['profile_path'] != null && actor['profile_path'].toString().isNotEmpty) 
                            ? _getImage(actor['profile_path']) 
                            : '';
                          return Container(
                            width: 100, margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(10), child: img.isNotEmpty ? Image.network(img, height: 110, width: 100, fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage()) : _buildErrorImage()),
                                const SizedBox(height: 6),
                                Text(actor['name'] ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: navyBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(actor['character'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // BOX 5: HÌNH ẢNH VÀ VIDEO
            Container(
              width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Hình ảnh và Video', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue))),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        
                        // LẤY ẢNH BÌA TỪ YOUTUBE HOẶC POSTER
                        if (widget.movie.trailerUrl != null && widget.movie.trailerUrl!.isNotEmpty) ...[
                          Builder(
                            builder: (context) {
                              String? videoId = YoutubePlayer.convertUrlToId(widget.movie.trailerUrl!);
                              String thumbnailUrl = videoId != null 
                                  ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg' 
                                  : widget.movie.posterPath;

                              return _buildMediaItem(
                                thumbnailUrl, 
                                isVideo: true, 
                                onTap: () => _openTrailer(widget.movie.trailerUrl!)
                              );
                            }
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Poster
                        if (widget.movie.posterPath.isNotEmpty) ...[
                          _buildMediaItem(_getImage(widget.movie.posterPath), isVideo: false, onTap: () => _openImage(_getImage(widget.movie.posterPath))),
                          const SizedBox(width: 12),
                        ],

                        // Backdrops/gallery
                        if (widget.movie.backdropPaths != null) 
                          for (final bp in widget.movie.backdropPaths!) ...[
                            _buildMediaItem(_getImage(bp), isVideo: false, onTap: () => _openImage(_getImage(bp))),
                            const SizedBox(width: 12),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // BOX 6: BANNER KHUYẾN MÃI
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
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
            ),
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double percent) {
    return Row(
      children: [
        SizedBox(width: 35, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Icon(Icons.star, color: Colors.grey, size: 10),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(height: 6, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(widthFactor: percent, child: Container(height: 6, decoration: BoxDecoration(color: starColor, borderRadius: BorderRadius.circular(3)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(String url, {required bool isVideo, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(url, width: 140, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(width: 140, color: Colors.grey[300])),
            if (isVideo) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes <= 0) return 'Đang cập nhật';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h giờ $m phút';
    if (h > 0) return '$h giờ';
    return '$m phút';
  }

  void _openTrailer(String url) {
    showDialog(context: context, builder: (_) => TrailerDialog(youtubeUrl: url));
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_,__,___) => Container(color: Colors.grey[200], height: 300, width: 300))),
      ),
    );
  }

  Widget _buildBottomBar(Color primaryColor) {
    bool isUpcoming = _isUpcomingMovie(); 

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), 
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isUpcoming ? Colors.grey.shade400 : primaryColor, 
                padding: const EdgeInsets.symmetric(vertical: 14), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                elevation: 0
              ),
              onPressed: isUpcoming 
                  ? null 
                  : () {
                      // 🚀 ĐÃ BỌC THÉP NÚT MUA VÉ BẰNG GUEST GUARD!
                      GuestGuard.check(context, () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (blocContext) => BlocProvider.value(
                              value: context.read<MovieBloc>(), 
                              child: CinemaSelectionPage(movie: widget.movie)
                            )
                          )
                        );
                      });
                    },
              child: Text(
                isUpcoming ? 'Sắp chiếu (Coming soon)' : 'Mua vé', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap, Color? iconColor}) {
    return OutlinedButton.icon(
      onPressed: onTap ?? () {}, 
      icon: Icon(icon, size: 16, color: iconColor ?? navyBlue),
      label: Text(label, style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8), 
        side: BorderSide(color: navyBlue.withOpacity(0.3)), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 6),
        Text(value, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3, color: navyBlue)),
      ],
    );
  }

  Widget _buildErrorImage() => Container(height: 110, width: 100, color: Colors.grey.shade200, child: const Icon(Icons.person, color: Colors.grey, size: 40));
  
  Color _getAgeColor(String? age) {
    if (age == null) return Colors.green;
    if (age.contains('18')) return Colors.red;
    if (age.contains('16')) return Colors.orange;
    if (age.contains('13')) return Colors.orange.shade300;
    return Colors.green;
  }
}

// ============================================================================
// 2. DIALOG PHÁT TRAILER (GỘP CHUNG VÀO ĐÂY)
// ============================================================================
class TrailerDialog extends StatefulWidget {
  final String youtubeUrl;
  const TrailerDialog({super.key, required this.youtubeUrl});

  @override
  State<TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<TrailerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl) ?? 'TcMBFSGVi1c'; 
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: Colors.black, 
      elevation: 0,
      insetPadding: EdgeInsets.zero, 
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: isLandscape ? MediaQuery.of(context).size.height : null,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: YoutubePlayer(controller: _controller, showVideoProgressIndicator: true, progressIndicatorColor: Colors.red),
            ),
            SafeArea( 
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}