import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart'; 

import 'cinema_showtimes_page.dart';

const String baseUrl = "http://192.168.1.4:3000/"; // Nhớ đổi đúng IP thật của bạn

class TicketDetailPage extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final Color themeColor;

  const TicketDetailPage({super.key, required this.ticket, required this.themeColor});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  bool _isRefunding = false;

  String _getRealImageUrl(String rawPath) {
    if (rawPath.isEmpty) return "";
    if (rawPath.startsWith("http")) return rawPath;
    if (rawPath.startsWith("/")) return "https://image.tmdb.org/t/p/w780$rawPath"; 
    String cleanPath = rawPath.replaceAll('\\', '/');
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return "$baseUrl$cleanPath"; 
  }

  String _getFoodImagePath(String rawPath, String cinemaName) {
    if (rawPath.startsWith("http")) return rawPath;
    if (rawPath.startsWith("assets/")) return rawPath;

    String nameLower = cinemaName.toLowerCase();
    String folder = 'cgv'; 
    if (nameLower.contains('galaxy')) folder = 'galaxy';
    else if (nameLower.contains('lotte')) folder = 'lotte';
    else if (nameLower.contains('bhd')) folder = 'bhd';
    else if (nameLower.contains('cinestar')) folder = 'cinestar';
    else if (nameLower.contains('mega') || nameLower.contains('megags')) folder = 'megags';
    else if (nameLower.contains('dcine')) folder = 'dcine';
    else if (nameLower.contains('beta')) folder = 'beta';

    if (rawPath.isEmpty) return 'assets/$folder/default.png';

    String cleanPath = rawPath.replaceAll('\\', '/');
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);

    return 'assets/$folder/$cleanPath';
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
      
      return diff.inHours >= 24; 
    } catch (e) {
      return false;
    }
  }

  void _showRefundDialog() {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Yêu cầu hoàn tiền", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Vui lòng nhập lý do bạn muốn hoàn vé (Bắt buộc):", style: TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Ví dụ: Bận việc đột xuất...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade900)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập lý do hoàn vé!")));
                  return;
                }
                Navigator.pop(context);
                _submitRefund(reasonController.text.trim());
              },
              child: const Text("Xác nhận hoàn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Future<void> _submitRefund(String reason) async {
    setState(() => _isRefunding = true);
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}api/user/refund'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': widget.ticket['code'], 
          'reason': reason
        })
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gửi yêu cầu hoàn tiền thành công! Vui lòng chờ duyệt.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
          Navigator.pop(context, true); 
        }
      } else {
        var err = jsonDecode(response.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${err['error']}")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối máy chủ!")));
    } finally {
      if (mounted) setState(() => _isRefunding = false);
    }
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

                    // PHẦN BANNER ẢNH PHIM HOẶC MÀU NỀN
                    Stack(
                      children: [
                        if (!isOnlyFood && finalBannerUrl.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              finalBannerUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                            ),
                          )
                        else if (!isOnlyFood) 
                          Container(height: 200, width: double.infinity, color: Colors.grey.shade200)
                        else 
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.asset(
                              'assets/back-bapnuoc.png', 
                              width: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.orange.shade100),
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
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                            child: QrImageView(
                              data: fullCode,
                              version: QrVersions.auto,
                              size: 110.0,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
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
                    if (!isOnlyFood) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoCol("Phòng chiếu", shortRoomName),
                          _buildInfoCol("Số vé", ticketCountStr),
                          _buildInfoCol("Số ghế", seats),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFEEEEEE), thickness: 1),
                      const SizedBox(height: 16),
                    ],

                    // ✅ ĐÃ THÊM: KHỐI HIỂN THỊ TÊN RẠP VÀ ĐỊA CHỈ TRỰC QUAN
                    Text(isOnlyFood ? "Địa điểm nhận hàng" : "Rạp chiếu", style: const TextStyle(color: Colors.black54, fontSize: 13)),
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
                                child: foodImgPath.startsWith('http')
                                  ? Image.network(
                                      foodImgPath,
                                      width: 45, height: 45, fit: BoxFit.cover,
                                      errorBuilder: (_,__,___) => Container(width: 45, height: 45, color: Colors.orange.shade50, child: const Icon(Icons.fastfood, color: Colors.orange)),
                                    )
                                  : Image.asset(
                                      foodImgPath,
                                      width: 45, height: 45, fit: BoxFit.cover,
                                      errorBuilder: (_,__,___) => Container(width: 45, height: 45, color: Colors.orange.shade50, child: const Icon(Icons.fastfood, color: Colors.orange)),
                                    ),
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
                        onPressed: _isRefunding 
                          ? null 
                          : () {
                              if (isAlreadyRefunded) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isRefunded ? "Đơn này đã được hoàn tiền!" : "Đơn đang trong quá trình chờ hoàn tiền!")));
                              } else if (!canRefund) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isOnlyFood ? "Không thể hoàn tiền đơn thức ăn đã qua ngày!" : "Chỉ hỗ trợ hoàn tiền tối thiểu 24 giờ trước suất chiếu!")));
                              } else {
                                _showRefundDialog();
                              }
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (canRefund && !isAlreadyRefunded) ? Colors.red.shade50 : Colors.grey.shade100,
                          foregroundColor: (canRefund && !isAlreadyRefunded) ? Colors.red : Colors.grey.shade600,
                          elevation: 0,
                          side: BorderSide(color: (canRefund && !isAlreadyRefunded) ? Colors.red.shade300 : Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: _isRefunding 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isAlreadyRefunded ? Icons.history_toggle_off : Icons.replay, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isAlreadyRefunded ? "Đang xử lý hoàn tiền" : "Yêu cầu hoàn tiền", 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                ),
                              ],
                            ),
                      ),
                    ),
                    
                    if (!canRefund && !isAlreadyRefunded)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            isOnlyFood 
                               ? "* Đã quá hạn hoàn tiền cho đơn hàng này" 
                               : "* Đã quá thời hạn hỗ trợ hoàn tiền cho vé này (24h)", 
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