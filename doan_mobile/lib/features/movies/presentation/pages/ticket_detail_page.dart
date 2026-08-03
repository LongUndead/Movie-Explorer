import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart'; 
import 'ticket_refund_page.dart';
import 'cinema_showtimes_page.dart';

const String baseUrl = "http://192.168.1.7:3000/"; // Nhớ đổi đúng IP thật của bạn

class TicketDetailPage extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final Color themeColor;

  const TicketDetailPage({super.key, required this.ticket, required this.themeColor});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  bool _isRefunding = false;

  // 🚀 THÊM 3 BIẾN NÀY ĐỂ ĐỒNG BỘ VỚI ADMIN
  bool _allowRefund = true; // Mặc định mở
  int _refundBeforeHours = 24; // Mặc định 24h
  bool _isLoadingSettings = true;

  // 🚀 BIẾN CHO TRAILER VÀ KIỂM TRA ĐƠN HÀNG
  YoutubePlayerController? _youtubeController;
  // 🚀 BIẾN CHO TRAILER VÀ KIỂM TRA ĐƠN HÀNG
  late bool _isOnlyFood;
  String _trailerUrl = ""; // Chỉ cần lưu cái link

  @override
  void initState() {
    super.initState();
    _fetchSystemSettings();
    String movieName = widget.ticket['movie']?.toString() ?? "";
    String seats = widget.ticket['seats']?.toString() ?? "Không có";
    _isOnlyFood = movieName.toLowerCase().contains("đơn bắp nước") || seats == "Không có" || movieName.isEmpty;

    String rawTrailer = widget.ticket['TrailerURL']?.toString() ?? widget.ticket['trailer']?.toString() ?? ""; 
    if (rawTrailer.isNotEmpty && rawTrailer.startsWith('[')) {
      try {
        List<dynamic> parsed = jsonDecode(rawTrailer);
        if (parsed.isNotEmpty) rawTrailer = parsed[0].toString();
      } catch (e) {}
    }
    _trailerUrl = rawTrailer; // Gán link để lát bấm thì truyền qua Pop-up
  }
  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  // 🚀 HÀM GỌI API ĐỂ NGHE LỜI ADMIN
  Future<void> _fetchSystemSettings() async {
    try {
      // Gọi tới API settings của Backend
      final response = await http.get(Uri.parse('${baseUrl}api/admin/settings'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dbData = data is List ? (data.isNotEmpty ? data[0] : null) : (data['data'] ?? data);
        
        if (dbData != null) {
          if (mounted) {
            setState(() {
              // Ép kiểu boolean thông minh chống sập
              _allowRefund = dbData['allowRefund'] == 1 || dbData['allowRefund'] == true || dbData['allowRefund'] == '1';
              _refundBeforeHours = dbData['refundBeforeHours'] ?? 24;
              _isLoadingSettings = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ cấu hình Admin: $e");
    }
    if (mounted) setState(() => _isLoadingSettings = false);
  }

  // =====================================================
  // 🚀 1. HÀM XỬ LÝ ẢNH PHIM CHUẨN XÁC  // =====================================================
  // 🚀 1. HÀM XỬ LÝ ẢNH PHIM CHUẨN XÁC
  // =====================================================
  String _getRealImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null') {
      return 'https://via.placeholder.com/780x450?text=No+Image';
    }
    String cleanPath = rawPath.trim().replaceAll('\\', '/');

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
    return 'https://image.tmdb.org/t/p/w780$cleanPath';
  }

  // =====================================================
  // 🚀 2. HÀM XỬ LÝ ẢNH BẮP NƯỚC TỪ ADMIN (Đã fix folder)
  // =====================================================
  String _getFoodImagePath(String rawPath, String cinemaName) {
    String dbImage = rawPath.trim().replaceAll('\\', '/');
    
    String nameLower = cinemaName.toLowerCase();
    String folder = 'cgv'; 
    if (nameLower.contains('galaxy')) folder = 'galaxy';
    else if (nameLower.contains('lotte')) folder = 'lotte';
    else if (nameLower.contains('bhd')) folder = 'bhd';
    else if (nameLower.contains('cinestar')) folder = 'cinestar';
    else if (nameLower.contains('mega') || nameLower.contains('megags')) folder = 'megags';
    else if (nameLower.contains('dcine')) folder = 'dcine';
    else if (nameLower.contains('beta')) folder = 'beta';

    if (dbImage.isEmpty || dbImage == 'null') return 'assets/$folder/default.png';

    if (dbImage.contains('public/foods') || dbImage.contains('food-')) {
      String filename = dbImage.split('/').last; 
      return 'http://192.168.1.7:3000/public/foods/$filename'; 
    }

    if (dbImage.startsWith('http')) return dbImage;

    if (dbImage.startsWith('/')) dbImage = dbImage.substring(1);
    if (dbImage.startsWith('assets/')) return dbImage;
    if (dbImage.startsWith('$folder/')) return 'assets/$dbImage';
    
    return 'assets/$folder/$dbImage';
  }

  // =====================================================
  // 🚀 3. WIDGET VẼ ẢNH THÔNG MINH CHỐNG LỖI XÁM XỊT
  // =====================================================
  Widget _buildSmartImage(String imagePath, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (imagePath.isEmpty || imagePath == 'null') {
      return Container(width: width, height: height, color: Colors.grey.shade200, child: Icon(Icons.image_not_supported, color: Colors.grey.shade400));
    }
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath, 
        width: width, height: height, fit: fit, 
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(width: width, height: height, color: Colors.grey.shade100, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
        },
        errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.grey.shade200, child: Icon(Icons.image_not_supported, color: Colors.grey.shade400))
      );
    }
    return Image.asset(
      imagePath, 
      width: width, height: height, fit: fit, 
      errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.grey.shade200, child: Icon(Icons.image_not_supported, color: Colors.grey.shade400))
    );
  }

  String _getLogoForCinema(String cinemaName) {
    String nameLower = cinemaName.toLowerCase();
    if (nameLower.contains('cgv')) return 'assets/cgv1.png';
    if (nameLower.contains('lotte')) return 'assets/lotte.png';
    if (nameLower.contains('galaxy')) return 'assets/galaxy.png';
    if (nameLower.contains('bhd')) return 'assets/bhd.png';
    if (nameLower.contains('cinestar')) return 'assets/cinestar.png';
    if (nameLower.contains('mega') || nameLower.contains('megags')) return 'assets/megags.png';
    if (nameLower.contains('dcine')) return 'assets/dcine.png';
    if (nameLower.contains('beta')) return 'assets/betacinema.png';
    return 'assets/dexuat.png'; 
  }

  bool _checkCanRefund(String rawDate, bool isOnlyFood) {
    // 🚀 BƯỚC TƯỜNG LỬA: ADMIN TẮT TÍNH NĂNG NÀY RỒI THÌ MIỄN BÀN!
    if (!_allowRefund) return false;

    try {
      var parts = rawDate.split('|');
      if (parts.length < 2) return false;
      
      String dateStr = parts[1].trim(); 

      if (isOnlyFood) {
        DateTime receiveDate = DateFormat("dd/MM/yyyy").parse(dateStr);
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        return receiveDate.isAfter(today) || receiveDate.isAtSameMomentAs(today);
      }
      
      String timeStr = parts[0].split('-')[0].trim(); 
      DateTime showtime = DateFormat("dd/MM/yyyy HH:mm").parse("$dateStr $timeStr");
      Duration diff = showtime.difference(DateTime.now());
      
      // 🚀 CHỖ NÀY NÈ: So sánh với biến cấu hình của Admin thay vì 24 cứng
      return diff.inHours >= _refundBeforeHours; 
    } catch (e) {
      return false;
    }
  }

  // 🚀 HÀM PHÓNG TO MÃ QR FULL MÀN HÌNH + NÚT X VÀ GHI CHÚ
  void _showZoomedQRCode(String code) {
    showDialog(
      context: context,
      useSafeArea: false, // Bỏ giới hạn an toàn để tràn viền 100%
      builder: (_) => Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9), // Nền đen ngầu
        body: SafeArea(
          child: Stack(
            children: [
              // Mã QR to đùng ở giữa
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: QrImageView(data: code, version: QrVersions.auto, size: MediaQuery.of(context).size.width * 0.8), // Chiếm 80% chiều rộng máy
                    ),
                    const SizedBox(height: 24),
                    Text(code, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white)),
                    const SizedBox(height: 24),
                    // Dòng hướng dẫn nhân viên soát vé
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _isOnlyFood 
                          ? "Đưa mã này cho nhân viên quầy bắp nước để nhận hàng"
                          : "Đưa mã này cho nhân viên soát vé để nhận vé vào rạp", 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic) 
                      ),
                    ),
                  ],
                ),
              ),
              // Nút X Đóng bự góc phải
              Positioned(
                top: 16, right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 40),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _openTrailer(String url) {
    if (url.isEmpty) return;
    showDialog(context: context, builder: (_) => TrailerDialog(youtubeUrl: url));
  }
  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final Color navyBlue = Colors.blue.shade900; 
    final Color lightNavyBg = Colors.blue.shade50; 
    
    // Đọc mã QR
    String fullCode = widget.ticket['QRCode']?.toString() ?? 
                      widget.ticket['qrcode']?.toString() ?? 
                      widget.ticket['code']?.toString() ?? 
                      "00000";

    String seats = widget.ticket['seats']?.toString() ?? "Không có";
    String movieName = widget.ticket['movie']?.toString() ?? "Đơn Bắp Nước"; 
    String cinemaName = widget.ticket['cinema']?.toString() ?? "Hệ thống Rạp";
    String movieFormat = widget.ticket['format']?.toString() ?? ""; 
    
    // ĐỊA CHỈ RẠP
    String cinemaAddress = widget.ticket['cinema_address']?.toString() ?? 'Hệ thống rạp $cinemaName';
    
    bool isOnlyFood = movieName.toLowerCase().contains("đơn bắp nước") || seats == "Không có" || movieName.isEmpty;

    String ticketStatus = widget.ticket['status']?.toString() ?? "";
    bool isPendingRefund = ticketStatus.toLowerCase() == 'refund pending';
    bool isRefunded = ticketStatus.toLowerCase() == 'refunded';
    bool isAlreadyRefunded = isPendingRefund || isRefunded;
    
    List<dynamic> foodsList = [];
    var rawFoods = widget.ticket['foods'];
    if (rawFoods != null && rawFoods.toString().isNotEmpty && rawFoods.toString() != "Không mua bắp nước") {
      try {
        if (rawFoods is String) {
          foodsList = jsonDecode(rawFoods);
        } else {
          foodsList = rawFoods;
        }
      } catch (e) {
        debugPrint("Lỗi parse thức ăn: $e");
      }
    }
    
    String posterUrl = widget.ticket['image']?.toString() ?? ""; 
    String rawBackdrop = widget.ticket['backdrop']?.toString() ?? "";
    String bannerUrl = "";

    if (rawBackdrop.isNotEmpty) {
      try {
        List<dynamic> backdrops = jsonDecode(rawBackdrop);
        if (backdrops.isNotEmpty) bannerUrl = backdrops[0].toString(); 
      } catch (e) {
        bannerUrl = rawBackdrop;
      }
    }
    if (bannerUrl.isEmpty) bannerUrl = posterUrl;
    String finalBannerUrl = _getRealImageUrl(bannerUrl);

    String rawDate = widget.ticket['date']?.toString() ?? "";
    String timeStr = "";
    String dateStr = rawDate;
    String formattedDisplayDate = "";
    
    bool canRefund = _checkCanRefund(rawDate, isOnlyFood);

    if (rawDate.contains('|')) {
      var parts = rawDate.split('|');
      timeStr = parts[0].trim().replaceAll('-', '~'); 
      dateStr = parts[1].trim();
    } else if (rawDate.contains('-')) {
      var parts = rawDate.split('-');
      timeStr = parts[0].trim().replaceAll('-', '~');
      dateStr = parts[1].trim();
    }

    try {
      DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      int weekdayNum = parsedDate.weekday;
      String weekdayStr = weekdayNum == 7 ? "Chủ nhật" : "Thứ ${weekdayNum + 1}";
      formattedDisplayDate = "$weekdayStr, $dateStr";
    } catch (e) {
      formattedDisplayDate = dateStr;
    }

    String rawRoomName = widget.ticket['room']?.toString() ?? "";
    String shortRoomName = rawRoomName.contains('-') ? rawRoomName.split('-').last.trim() : rawRoomName; 
    
    int ticketCount = seats == "Không có" ? 0 : seats.split(',').length;
    String ticketCountStr = ticketCount.toString().padLeft(2, '0');

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
            Expanded(child: Text(isOnlyFood ? 'Chi Tiết Đơn Hàng' : 'Chi Tiết Vé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight, 
              colors: [Colors.blue.shade300, Colors.blue.shade50]
            )
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 40, top: 16), 
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: lightNavyBg,
                child: Column(
                  children: [
                    // PHẦN THÔNG TIN RẠP PHIM
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (widget.ticket['cinema_id'] != null) {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => CinemaShowtimesPage(
                                  cinemaId: widget.ticket['cinema_id'].toString(), 
                                  cinemaName: cinemaName, 
                                  cinemaAddress: cinemaAddress
                                )
                              )
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                                child: Image.asset(_getLogoForCinema(cinemaName), width: 44, height: 44, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.storefront, color: navyBlue, size: 32)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cinemaName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(isOnlyFood ? "Đơn thức ăn tại quầy" : movieName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (!isOnlyFood && movieFormat.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(movieFormat, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ]
                                  ],
                                ),
                              ),
                              if (widget.ticket['cinema_id'] != null)
                                Icon(Icons.chevron_right_rounded, color: navyBlue, size: 28),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // PHẦN BANNER: HIỂN THỊ TRAILER HOẶC ẢNH
                    // PHẦN BANNER: HIỂN THỊ ẢNH CÓ KÈM NÚT PLAY
                    Stack(
                      alignment: Alignment.center, // 🚀 Canh giữa nút Play
                      children: [
                        if (!_isOnlyFood && finalBannerUrl.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildSmartImage(finalBannerUrl, width: double.infinity, fit: BoxFit.cover),
                          )
                        else if (!_isOnlyFood) 
                          Container(height: 200, width: double.infinity, color: Colors.grey.shade200)
                        else 
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.asset('assets/back-bapnuoc.png', width: double.infinity, fit: BoxFit.cover, alignment: Alignment.center, errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.orange.shade100)),
                          ),

                        // 🚀 NÚT PLAY MỞ POP-UP TRAILER (Chỉ hiện khi có link youtube)
                        if (!_isOnlyFood && _trailerUrl.isNotEmpty)
                          GestureDetector(
                            onTap: () => _openTrailer(_trailerUrl),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                            ),
                          ),
                        // CHỮ GÓC TRÁI "CINEMA TICKETS" HOẶC "FOOD & DRINK"
                        Positioned(
                          bottom: 0, 
                          left: 0,   
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.55, 
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                            decoration: BoxDecoration(
                              color: navyBlue.withOpacity(0.95),
                              borderRadius: const BorderRadius.only(topRight: Radius.circular(16)),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 2))], 
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text("CINEMA", style: TextStyle(color: navyBlue, fontWeight: FontWeight.w900, fontSize: 7, letterSpacing: 0.5, height: 1.1)),
                                      Text(isOnlyFood ? "SERVICE" : "TICKETS", style: TextStyle(color: navyBlue, fontWeight: FontWeight.w900, fontSize: 7, letterSpacing: 0.5, height: 1.1)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text("|", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18, fontWeight: FontWeight.w300)),
                                const SizedBox(width: 8),
                                Icon(isOnlyFood ? Icons.fastfood_rounded : Icons.videocam_rounded, color: Colors.white, size: 22), 
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isOnlyFood ? "Đơn mua" : "Mua vé", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(isOnlyFood ? "tại rạp" : "xem phim", style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500, fontSize: 12, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // TÊN PHIM LỚN HOẶC "ĐƠN BẮP NƯỚC"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Align(
                        alignment: Alignment.centerLeft, 
                        child: Text(
                          isOnlyFood ? "Đơn thức ăn & Đồ uống" : movieName, 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color:widget.themeColor)
                        )
                      ),
                    ),
                    
                    // THÔNG TIN MÃ VÀ QR
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Mã xác nhận:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(fullCode, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.black87)),
                                
                                const SizedBox(height: 16),
                                
                                Text(isOnlyFood ? "Nhận ngày:" : "Thời gian:", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(height: 4),
                                if (!isOnlyFood && timeStr.isNotEmpty) ...[
                                  Text(timeStr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)), 
                                  const SizedBox(height: 4),
                                ],
                                Text(formattedDisplayDate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ),
                          // 🚀 BỌC INKWELL ĐỂ BẤM VÀO PHÓNG TO QR (ĐÃ BỎ KÍNH LÚP)
                          InkWell(
                            onTap: () => _showZoomedQRCode(fullCode),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade900, width: 1.5)), 
                              child: QrImageView(
                                data: fullCode,
                                version: QrVersions.auto,
                                size: 110.0,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isOnlyFood 
                              ? "Đưa mã này cho nhân viên quầy bắp nước để nhận hàng"
                              : "Đưa mã này cho nhân viên soát vé để nhận vé vào rạp", 
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic) 
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // DẤU CẮT ĐỨT KHÚC
              Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    children: [
                      Container(height: 14, color: lightNavyBg),
                      Container(height: 14, color: Colors.white),
                    ],
                  ),
                  const DottedLine(dashColor: Colors.grey, dashLength: 6, lineThickness: 1.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 14, height: 28, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)))),
                      Container(width: 14, height: 28, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)))),
                    ],
                  )
                ],
              ),

              // CHI TIẾT ĐƠN GIÁ VÀ BẮP NƯỚC
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isOnlyFood) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Expanded(child: _buildInfoCol("Phòng", shortRoomName)),
                          Expanded(child: _buildInfoCol("Số vé", ticketCountStr)),
                          Expanded(flex: 2, child: _buildInfoCol("Số ghế", seats)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFEEEEEE), thickness: 1),
                      const SizedBox(height: 16),
                    ],

                    // ✅ HIỂN THỊ TÊN RẠP, ĐỊA CHỈ, VÀ ĐỊNH DẠNG PHIM BÊN PHẢI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isOnlyFood ? "Địa điểm nhận hàng" : "Rạp chiếu", style: const TextStyle(color: Colors.black54, fontSize: 13)),
                        if (!_isOnlyFood)
                          Text(movieFormat.isEmpty ? "2D" : movieFormat, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyBlue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: Colors.red.shade400, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cinemaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(
                                cinemaAddress,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFEEEEEE), thickness: 1),
                    const SizedBox(height: 16),
                    
                    if (foodsList.isNotEmpty) ...[
                      const Text("Đồ ăn & Nước", style: TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 12),
                      ...foodsList.map((food) {
                        String rawDesc = food['desc']?.toString() ?? "Combo bắp nước tại rạp";
                        String formattedDesc = rawDesc.replaceAll(RegExp(r',\s*'), ',\n');
                        
                        String foodImgPath = _getFoodImagePath(food['image']?.toString() ?? "", cinemaName);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200, width: 1.2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildSmartImage(foodImgPath, width: 45, height: 45), // 🚀 ĐÃ GỌI HÀM VẼ ẢNH BẮP NƯỚC
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${food['name']}  x${food['qty']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text(formattedDesc, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFFEEEEEE), thickness: 1),
                      const SizedBox(height: 16),
                    ],
                    
                    _buildDetailRow("Tổng tiền", formatter.format(double.tryParse(widget.ticket['price'].toString()) ?? 0), true, color: navyBlue), 
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoadingSettings ? null : () async {
                              if (isAlreadyRefunded) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isRefunded ? "Đơn này đã được hoàn tiền!" : "Đơn đang trong quá trình chờ hoàn tiền!")));
                              } else if (!_allowRefund) {
                                // 🚀 BÁO LỖI NẾU ADMIN ĐÃ TẮT
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hệ thống rạp đang tạm khóa chức năng tự hủy vé!")));
                              } else if (!canRefund) {
                                // 🚀 HIỂN THỊ SỐ GIỜ LINH HOẠT
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isOnlyFood ? "Không thể hoàn tiền đơn thức ăn đã qua ngày!" : "Chỉ hỗ trợ hoàn tiền tối thiểu $_refundBeforeHours giờ trước suất chiếu!")));
                              } else {
                                // 🚀 CHUYỂN SANG TRANG HOÀN TIỀN MỚI
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TicketRefundPage(
                                      bookingId: widget.ticket['code'].toString(),
                                      baseUrl: baseUrl,
                                    )
                                  ),
                                );

                                // 🚀 NẾU KHÁCH HÀNG GỬI THÀNH CÔNG VÀ QUAY LẠI TRANG NÀY
                                if (result == true) {
                                  setState(() {
                                    widget.ticket['status'] = 'Refund Pending'; 
                                  });
                                }

                              }
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (canRefund && !isAlreadyRefunded) ? Colors.red.shade50 : Colors.grey.shade100,
                          foregroundColor: (canRefund && !isAlreadyRefunded) ? Colors.red : Colors.grey.shade600,
                          elevation: 0,
                          side: BorderSide(color: (canRefund && !isAlreadyRefunded) ? Colors.red.shade300 : Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: (_isRefunding)
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isRefunded ? Icons.check_circle : (isPendingRefund ? Icons.history_toggle_off : Icons.replay), 
                                  size: 20,
                                  color: isRefunded ? Colors.green.shade600 : null, // Nếu đã hoàn thì cho icon xanh lá
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  // 🚀 Tách rõ 3 trạng thái tại đây:
                                  isRefunded 
                                      ? "Đã hoàn tiền thành công" 
                                      : (isPendingRefund ? "Đang xử lý hoàn tiền" : "Yêu cầu hoàn tiền"), 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16,
                                    color: isRefunded ? Colors.green.shade600 : null // Nếu đã hoàn thì đổi chữ xanh
                                  )
                                ),
                              ],
                            ),
                      ),
                    ),
                    
                    if (!canRefund && !isAlreadyRefunded && !_isLoadingSettings)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            !_allowRefund 
                               ? "* Rạp hiện không hỗ trợ hủy vé trực tuyến." // 🚀 BÁO KHÁCH BIẾT ADMIN ĐÃ TẮT
                               : (isOnlyFood 
                                   ? "* Đã quá hạn hoàn tiền cho đơn hàng này" 
                                   : "* Đã quá thời hạn hỗ trợ hoàn tiền cho vé này (${_refundBeforeHours}h)"), // 🚀 THAY SỐ GIỜ THEO ADMIN
                            style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontStyle: FontStyle.italic)
                          )
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isBold, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        Expanded(
          child: Text(
            value, 
            textAlign: TextAlign.right, 
            style: TextStyle(color: color ?? Colors.black87, fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)
          )
        ),
      ],
    );
  }
}
// ============================================================================
// 2. DIALOG PHÁT TRAILER 
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
            Center(child: YoutubePlayer(controller: _controller, showVideoProgressIndicator: true, progressIndicatorColor: Colors.red)),
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