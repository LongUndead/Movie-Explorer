import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math'; 
import '../../domain/entities/movie.dart';
import 'ticket_detail_page.dart'; 

class TicketResultScreen extends StatefulWidget {
  // ✅ 1. SỬA: Cho phép movie null
  final Movie? movie;
  final String date;
  final String time;
  final String cinemaName; 
  final Map<String, dynamic>? fullTicketData; 

  const TicketResultScreen({
    super.key, 
    required this.movie, 
    required this.date, 
    required this.time,
    required this.cinemaName, 
    this.fullTicketData,
  });

  @override
  State<TicketResultScreen> createState() => _TicketResultScreenState();
}

class _TicketResultScreenState extends State<TicketResultScreen> {
  late String bookingCode;
  late Map<String, dynamic> ticketForDetail;

  @override
  void initState() {
    super.initState();
    
    final dbCode = widget.fullTicketData?['QRCode'] ?? 
                   widget.fullTicketData?['qrcode'] ?? 
                   widget.fullTicketData?['code'];

    bookingCode = dbCode?.toString() ?? _generateRandomCode();

    if (widget.fullTicketData != null) {
      ticketForDetail = Map<String, dynamic>.from(widget.fullTicketData!);
      ticketForDetail['code'] = bookingCode; 
    } else {
      // ✅ 2. SỬA: Lập dữ liệu ảo (Mock data) cho trường hợp test
      ticketForDetail = {
        'code': bookingCode, 
        'movie': widget.movie != null ? widget.movie!.title : "Đơn Bắp Nước",
        'cinema': widget.cinemaName,
        'date': widget.movie != null ? "${widget.time} | ${widget.date}" : "Nhận trong ngày | ${widget.date}",
        'price': '0',
        'seats': widget.movie != null ? 'Đang cập nhật' : 'Không có',
        'room': widget.movie != null ? 'Phòng chiếu' : 'Quầy Bắp Nước',
        'format': widget.movie != null ? '2D' : '',
        'image': widget.movie?.posterPath ?? '',
        'status': 'Paid'
      };
    }
  }

  String _generateRandomCode() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    Random rnd = Random();

    List<String> chars = [];
    for (int i = 0; i < 5; i++) {
      chars.add(letters[rnd.nextInt(letters.length)]);
    }
    for (int i = 0; i < 2; i++) {
      chars.add(numbers[rnd.nextInt(numbers.length)]);
    }
    chars.shuffle(rnd);
    return chars.join(''); 
  }

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900; 

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.popUntil(context, (route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F9), 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Thanh toán thành công', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50])),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(onTap: () {}, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.headset_mic_outlined, color: navyBlue, size: 18))),
                  Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
                  InkWell(onTap: () => Navigator.popUntil(context, (route) => route.isFirst), borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.home_outlined, color: navyBlue, size: 18))),
                ],
              ),
            ),
          ],
        ),
        body: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                const Text("Mã giao dịch của bạn", style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 6),
                
                Text(
                  bookingCode, 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navyBlue, letterSpacing: 3.0),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                  child: QrImageView(
                    data: bookingCode, 
                    version: QrVersions.auto,
                    size: 200.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  ),
                ),
                
                const SizedBox(height: 24),
                Row(
                  children: List.generate(
                    40, 
                    (index) => Expanded(
                      child: Container(color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade400, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ✅ 3. SỬA: Hiển thị tên phim hoặc "Đơn hàng dịch vụ"
                if (widget.movie != null) ...[
                  Text(widget.movie!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text("${widget.date} - ${widget.time}", style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                ] else ...[
                  const Text("Đơn hàng thức ăn & đồ uống", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text("Nhận tại: ${widget.cinemaName}", style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                ],
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton(
                          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navyBlue, 
                            side: BorderSide(color: navyBlue, width: 1.5), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: const Text("Trang chủ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => TicketDetailPage(
                                  ticket: ticketForDetail, 
                                  themeColor: navyBlue
                                )
                              )
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navyBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: const Text("Chi tiết đơn", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}