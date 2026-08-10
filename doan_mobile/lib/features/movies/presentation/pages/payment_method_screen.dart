import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:dotted_line/dotted_line.dart'; 
import 'dart:convert';
import 'dart:math';

import '../../domain/entities/movie.dart';
import 'payment_webview_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'cart_page.dart'; 
import 'user_manager.dart';
import 'home_page.dart';

class PaymentMethodScreen extends StatefulWidget {
  final Movie? movie; 
  final String selectedDate;
  final String selectedTime;
  final int totalAmount;
  final int showtimeId;
  final String cinemaName; 
  
  final String userName;
  final String userPhone;
  final String userEmail;
  final String roomName; 

  const PaymentMethodScreen({
    super.key,
    required this.movie,
    required this.selectedDate,
    required this.selectedTime,
    required this.totalAmount,
    required this.showtimeId,
    required this.cinemaName, 
    required this.userName,   
    required this.userPhone,  
    required this.userEmail,  
    required this.roomName,   
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  int _selectedMethod = 1; // 1: VNPAY, 2: MoMo
  final Color navyBlue = Colors.blue.shade900; 

  int? _appliedVoucherId;
  String? _appliedVoucherCode;
  int _discountAmount = 0;
  bool _isProcessing = false;
  // =================================================================
  // 🚀 LOGIC TỰ ĐỘNG KICK KHÁCH VỀ HOME KHI HẾT GIỜ GIỮ GHẾ
  // =================================================================
  bool _isTimeoutHandled = false; // Cờ chặn popup hiện 2 lần

  @override
  void initState() {
    super.initState();
    // Bắt đầu bật ăng-ten lắng nghe sự thay đổi của giỏ hàng
    CartManager.instance.addListener(_checkCartTimeout);
  }

  @override
  void dispose() {
    // Tắt ăng-ten khi rời khỏi trang để tránh rò rỉ bộ nhớ
    CartManager.instance.removeListener(_checkCartTimeout);
    super.dispose();
  }

  void _checkCartTimeout() {
    // Chỉ kích hoạt nếu là đơn mua vé phim VÀ vé trong giỏ đã bị xóa sạch (do hết giờ)
    if (widget.movie != null && CartManager.instance.tickets.isEmpty && !_isTimeoutHandled) {
      _isTimeoutHandled = true; // Khóa cờ lại
      _showTimeoutPopup();
    }
  }

  void _showTimeoutPopup() {
    showDialog(
      context: context,
      barrierDismissible: false, // Ép khách phải bấm nút, không cho bấm ra ngoài
      builder: (ctx) => PopScope(
        canPop: false, // Khóa luôn nút Back của điện thoại
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.timer_off_outlined, color: Colors.red.shade500, size: 40),
              ),
              const SizedBox(height: 16),
              const Text("Hết giờ giữ ghế", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: Text(
            "Rất tiếc, thời gian giữ ghế của bạn đã kết thúc. Vui lòng chọn lại suất chiếu và ghế nhé!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // 🚀 ĐÃ FIX LỖI ĐỎ: Dùng popUntil để lùi sạch sẽ về màn hình gốc
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Về Trang Chủ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      )
    );
  }

  int _getCinemaId(String name) {
    String text = name.toLowerCase();
    if (text.contains('cgv')) return 1;
    if (text.contains('galaxy')) return 2;
    if (text.contains('lotte')) return 3;
    if (text.contains('bhd')) return 4;
    if (text.contains('cinestar')) return 5;
    if (text.contains('mega') || text.contains('megags')) return 6;
    return 1; 
  }

  // =================================================================
  // BOTTOM SHEET CHI TIẾT HÓA ĐƠN
  // =================================================================
  void _showInvoiceDetails() {
    bool isOnlyFood = widget.movie == null;
    
    String seats = "Không có";
    int ticketPrice = 0;
    if (CartManager.instance.tickets.isNotEmpty) {
      final ticket = CartManager.instance.tickets.first;
      List<String> seatNames = ticket.selectedSeats.map((s) => s['name'].toString()).toList();
      seatNames.sort();
      seats = seatNames.join(', ');
      ticketPrice = ticket.price; 
    }

    final foods = CartManager.instance.foods;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20, top: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 24), 
                  const Text("Chi tiết hoá đơn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.black54, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (!isOnlyFood) ...[
                _buildInvoiceRow("Phim", widget.movie!.title, isBold: true, color: Colors.deepOrange),
                _buildInvoiceRow("Suất chiếu", "${widget.selectedDate} - ${widget.selectedTime}", isBold: true, color: Colors.deepOrange),
                _buildInvoiceRow("Rạp", widget.cinemaName, isBold: true, color: Colors.deepOrange),
                _buildInvoiceRow("Phòng chiếu", widget.roomName, isBold: true),
                _buildInvoiceRow("Ghế", seats, isBold: true),
                _buildInvoiceRow("Giá vé", formatter.format(ticketPrice), isBold: true),
              ] else ...[
                _buildInvoiceRow("Dịch vụ", "Thức ăn & Đồ uống", isBold: true, color: Colors.deepOrange),
                _buildInvoiceRow("Nơi nhận", widget.cinemaName, isBold: true, color: Colors.deepOrange),
                _buildInvoiceRow("Thời gian", "Trong ngày (${widget.selectedDate})", isBold: true),
              ],
              
              if (foods.isNotEmpty) ...[
                const SizedBox(height: 4), 
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Bắp nước & Dịch vụ:", style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                ...foods.map((item) {
                  final itemTotal = item.food.price * item.quantity;
                  return _buildInvoiceRow(
                    "${item.quantity}x ${item.food.name}", 
                    formatter.format(itemTotal),           
                    isBold: true
                  );
                }).toList(),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
              ),

              _buildInvoiceRow("Người đặt", widget.userName, isBold: true),
              _buildInvoiceRow("Số điện thoại", widget.userPhone, isBold: true),
              _buildInvoiceRow("Email", widget.userEmail, isBold: true),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
              ),
              
              if (_discountAmount > 0)
                _buildInvoiceRow("Khuyến mãi", "-${formatter.format(_discountAmount)}", isBold: true, color: Colors.green),

              _buildInvoiceRow("Tạm tính", formatter.format(widget.totalAmount - _discountAmount), isBold: true, fontSize: 16),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("Đóng", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildInvoiceRow(String label, String value, {bool isBold = false, Color color = Colors.black87, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 14))),
          Expanded(
            flex: 3, 
            child: Text(
              value, 
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isOnlyFood = widget.movie == null;
    int finalAmount = widget.totalAmount - _discountAmount;
    if (finalAmount < 0) finalAmount = 0;

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
            Expanded(child: Text('Thanh toán an toàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, const Color(0xFFF5F5F9)], 
              ),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipPath(
                      clipper: TicketTopClipper(), 
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 26, 16, 16), 
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(isOnlyFood ? Icons.fastfood_rounded : Icons.videocam_outlined, color: Colors.orange.shade400, size: 26),
                                    const SizedBox(width: 8),
                                    Text(isOnlyFood ? "Đơn hàng thức ăn" : "Mua vé xem phim", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: _showInvoiceDetails,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 1.2), borderRadius: BorderRadius.circular(20)),
                                    child: const Text("Chi tiết >", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ),
                                )
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            const DottedLine(
                              dashColor: Color(0xFFDBDBDB), 
                              dashLength: 6, 
                              dashGapLength: 4, 
                              lineThickness: 1.5
                            ),
                            const SizedBox(height: 16),
                            
                            if (!isOnlyFood) ...[
                              _buildSummaryRow("Phim", widget.movie!.title, true),
                              const SizedBox(height: 12),
                              _buildSummaryRow("Rạp", widget.cinemaName, false), 
                              const SizedBox(height: 12),
                              _buildSummaryRow("Suất chiếu", "${widget.selectedDate} - ${widget.selectedTime}", true),
                            ] else ...[
                              _buildSummaryRow("Rạp nhận", widget.cinemaName, true), 
                              const SizedBox(height: 12),
                              _buildSummaryRow("Thời gian nhận", "${widget.selectedDate} - Trong ngày", false),
                            ],
                            
                            const SizedBox(height: 12),
                            _buildSummaryRow("Tạm tính", formatter.format(widget.totalAmount), false),
                          ],
                        ),
                      ),
                    ),
                    
                    Positioned(
                      left: -10, top: 60,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle)),
                    ),
                    Positioned(
                      right: -10, top: 60,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                InkWell(
                  onTap: () async {
                    // 🚀 CÔNG NGHỆ BOTTOM SHEET TRƯỢT TỪ DƯỚI LÊN
                    final selectedVoucher = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true, // Cho phép BottomSheet cao hơn 50%
                      backgroundColor: Colors.transparent, // Làm nền trong suốt để thấy được góc bo tròn
                      builder: (ctx) => VoucherBottomSheet(
                        totalAmount: widget.totalAmount,
                        currentVoucherId: _appliedVoucherId,
                      ),
                    );

                    // Khi người dùng bấm "Áp dụng", data sẽ trả về đây
                    if (selectedVoucher != null) {
                      setState(() {
                        _appliedVoucherId = selectedVoucher['id'];
                        _appliedVoucherCode = selectedVoucher['code'];
                        _discountAmount = selectedVoucher['discount'];
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(16),
                      border: _appliedVoucherCode != null 
                          ? Border.all(color: Colors.green, width: 1.5) 
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_activity, color: Colors.orange.shade400, size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Ưu đãi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                if (_appliedVoucherCode != null)
                                  Text("Đã áp dụng: $_appliedVoucherCode", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        Text(_appliedVoucherCode != null ? "-${formatter.format(_discountAmount)} >" : "Chọn hoặc nhập mã >", 
                          style: TextStyle(color: _appliedVoucherCode != null ? Colors.green : Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    const Text("Trả ngay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.grey.shade600),
                  ],
                ),
                const SizedBox(height: 12),
                
                _buildPaymentMethodItem(1, "VNPAY", "Thanh toán qua mã QR hoặc thẻ ATM", 'assets/vnpay.png'), 
                const SizedBox(height: 12),
                _buildPaymentMethodItem(2, "Ví MoMo", "Thanh toán siêu tốc", 'assets/momo.png'),
                const SizedBox(height: 12),
                // ✅ ĐÃ THÊM ZALOPAY
                _buildPaymentMethodItem(3, "Ví ZaloPay", "Thanh toán bằng ví hoặc thẻ ngân hàng", 'assets/zalopay.png'),
                
              ],
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền', style: TextStyle(fontSize: 15, color: Colors.black54)),
                Row(
                  children: [
                    Text(formatter.format(finalAmount), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navyBlue)),
                    const Icon(Icons.keyboard_arrow_up),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_outline, color: Colors.white, size: 18),
                label: const Text('Xác nhận', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                
                // 🚀 ĐÃ NÂNG CẤP: KHÓA NÚT NẾU ĐANG XỬ LÝ
                onPressed: _isProcessing ? null : () async {
                  setState(() { _isProcessing = true; }); // Khóa nút ngay lập tức

                  showDialog(
                    context: context, 
                    barrierDismissible: false, 
                    builder: (_) => Center(child: CircularProgressIndicator(color: navyBlue))
                  );

                  try {
                    List<Map<String, dynamic>> seatPayload = [];
                    
                    if (CartManager.instance.tickets.isNotEmpty) {
                      final currentTicket = CartManager.instance.tickets.first;
                      seatPayload = currentTicket.selectedSeats.map((seat) => {
                        'id': int.tryParse((seat['SeatID'] ?? seat['seatId'] ?? seat['id'] ?? 0).toString()) ?? 0,       
                        'price': int.tryParse((seat['price'] ?? seat['Price'] ?? 0).toString()) ?? 0 
                      }).toList();
                    }

                    int cinemaId = _getCinemaId(widget.cinemaName);
                    final userId = UserManager.instance.currentUser?.id ?? 0;

                    // 1. GỌI API TẠO ĐƠN PENDING TRONG DATABASE
                    final bookingRes = await http.post(
                      Uri.parse('http://192.168.1.7:3000/api/bookings/create_pending'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'userId': userId, 
                        'showtimeId': widget.showtimeId,
                        'cinemaId': cinemaId,
                        'seats': seatPayload,
                        'foods': CartManager.instance.foods.map((item) => {
                           'id': item.food.id,        
                           'quantity': item.quantity, 
                           'price': item.food.price   
                        }).toList(),
                        'voucherId': _appliedVoucherId 
                      }),
                    );

                    if (bookingRes.statusCode == 200) {
                      
                      if (_appliedVoucherId != null) {
                        try {
                          await http.post(
                            Uri.parse('http://192.168.1.7:3000/api/vouchers/mark-used'),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({ 'userId': userId, 'voucherId': _appliedVoucherId }),
                          );
                        } catch (e) {
                          debugPrint("Lỗi cập nhật trạng thái voucher: $e");
                        }
                      }

                      final pendingResponseData = json.decode(bookingRes.body);
                      final String realBookingId = pendingResponseData['bookingId'];
                      final int serverFinalAmount = pendingResponseData['finalAmount'] ?? finalAmount;

                      String API_URL = '';
                      if (_selectedMethod == 1) {
                        API_URL = 'http://192.168.1.7:3000/api/vnpay/create_url';
                      } else if (_selectedMethod == 2) {
                        API_URL = 'http://192.168.1.7:3000/api/momo/create_url';
                      } else if (_selectedMethod == 3) {
                        API_URL = 'http://192.168.1.7:3000/api/zalopay/create_url';
                      }

                      String orderInfoMsg = 'Thanh toan don hang $realBookingId';
                      http.Response? payRes;
                      bool isPaymentSuccess = false;

                      // 2. GỌI CỔNG THANH TOÁN (ZALOPAY/MOMO) CHỜ TỐI ĐA 30S
                      try {
                        payRes = await http.post(
                          Uri.parse(API_URL),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'orderId': realBookingId, 
                            'amount': serverFinalAmount, 
                            'orderInfo': orderInfoMsg 
                          }),
                        ).timeout(const Duration(seconds: 30));

                        if (payRes.statusCode == 200) {
                          isPaymentSuccess = true;
                        } else {
                          debugPrint('⚠️ Lỗi từ Cổng thanh toán: ${payRes.body}');
                        }
                      } catch (e) {
                        debugPrint('⚠️ Timeout Cổng thanh toán: $e');
                      }

                      // Tắt vòng xoay Loading
                      if (context.mounted) Navigator.pop(context); 

                      // 3. NẾU THÀNH CÔNG -> MỞ WEBVIEW
                      if (isPaymentSuccess && payRes != null) {
                        final responseData = json.decode(payRes.body);
                        final String paymentUrl = responseData['paymentUrl']; 

                        await WebViewCookieManager().clearCookies();

                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PaymentWebViewScreen(
                              paymentUrl: paymentUrl,
                              movie: widget.movie,
                              date: widget.selectedDate,
                              time: widget.selectedTime,
                              cinemaName: widget.cinemaName, 
                              bookingId: realBookingId,
                              amount: serverFinalAmount, 
                            )
                          ));
                        }
                      } 
                      // 4. 🚀 NẾU THẤT BẠI DÙ CỔNG THANH TOÁN SẬP
                      else {
                        // 🧹 GỌI API AUTO-ROLLBACK HỦY CÁI ĐƠN VỪA TẠO ĐỂ DỌN RÁC DB
                        try {
                           await http.post(
                             Uri.parse('http://192.168.1.7:3000/api/bookings/cancel_payment'),
                             headers: {'Content-Type': 'application/json'},
                             body: json.encode({ 'bookingId': realBookingId })
                           );
                           debugPrint('🧹 Đã tự động dọn dẹp đơn rác $realBookingId');
                        } catch(e) {}

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Cổng thanh toán đang quá tải. Đã hủy lệnh!'), 
                            backgroundColor: Colors.orange
                          ));
                        }
                      }
                    } else {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi lưu đơn hàng vào máy chủ!'), backgroundColor: Colors.red));
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xảy ra lỗi: $e'), backgroundColor: Colors.red));
                    }
                  } finally {
                    // 🚀 MỞ KHÓA NÚT DÙ CHO THÀNH CÔNG HAY THẤT BẠI
                    if (mounted) setState(() { _isProcessing = false; });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, bool isHighlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        Expanded( 
          child: Text(
            value, 
            textAlign: TextAlign.right,
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isHighlight ? navyBlue : Colors.black87)
          ),
        ),
      ],
    );
  }

  // =======================================================================
  // ✅ NÂNG CẤP GIAO DIỆN NÚT CHỌN THANH TOÁN (VIỀN BO GÓC, ĐỔ BÓNG, CHECKBOX XỊN)
  // =======================================================================
  Widget _buildPaymentMethodItem(int id, String title, String subtitle, String iconPath) {
    bool isSelected = _selectedMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? navyBlue.withOpacity(0.03) : Colors.white, // Highlight nhẹ nền
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? navyBlue : Colors.grey.shade300, width: 1.5), 
        ),
        child: Row(
          children: [
            // ✅ BOX chứa Logo (Nền trắng, viền mờ, bo góc)
            Container(
              width: 44, height: 44,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Image.asset(iconPath, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.credit_card, color: Colors.blue)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSelected ? navyBlue : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            // ✅ Nút Check tròn (Style Shopee/Grab)
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? navyBlue : Colors.transparent,
                border: Border.all(color: isSelected ? navyBlue : Colors.grey.shade400, width: isSelected ? 0 : 1.5), 
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            )
          ],
        ),
      ),
    );
  }
}

class TicketTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);

    double radius = 4.0;
    double spacing = 14.0; 
    int numScallops = (size.width / spacing).floor();
    double remainingSpace = size.width - (numScallops * spacing);
    double startOffset = remainingSpace / 2;

    for (int i = numScallops - 1; i >= 0; i--) {
      double x = startOffset + i * spacing + radius * 2;
      path.lineTo(x, 0);
      path.arcToPoint(
        Offset(x - radius * 2, 0),
        radius: Radius.circular(radius),
        clockwise: false,
      );
    }
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


// =====================================================================
// ✅ BOTTOM SHEET CHỌN VOUCHER (CHUẨN SHOPEE/GRAB)
// =====================================================================
class VoucherBottomSheet extends StatefulWidget {
  final int totalAmount;
  final int? currentVoucherId;

  const VoucherBottomSheet({super.key, required this.totalAmount, this.currentVoucherId});

  @override
  State<VoucherBottomSheet> createState() => _VoucherBottomSheetState();
}

class _VoucherBottomSheetState extends State<VoucherBottomSheet> {
  final Color navyBlue = Colors.blue.shade900;
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final String apiBaseUrl = 'http://192.168.1.7:3000'; 

  List<dynamic> _vouchers = []; // Chứa voucher ĐÃ LƯU
  bool _isLoading = true;
  int? _selectedVoucherId;
  int? _bestVoucherId;
  
  int _currentPoints = 0; 

  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedVoucherId = widget.currentVoucherId;
    _fetchMyVouchers();
  }

  String _formatCompactMoney(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}tr';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    return '${amount}đ';
  }

  // ========================================================
  // 🚀 TẠO POPUP BÁO LỖI/THÀNH CÔNG NẰM GIỮA MÀN HÌNH (THAY THẾ SNACKBAR)
  // ========================================================
  void _showNotificationDialog(String message, bool isError) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: isError ? Colors.red.shade500 : Colors.green.shade500,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isError ? Colors.red.shade500 : Colors.green.shade500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text("Đã hiểu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  Future<void> _fetchMyVouchers() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/vouchers/user/${user.id}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        
        int usedPoints = 0;
        for (var v in data) {
             String vCode = v['Code']?.toString() ?? '';
             if (vCode.startsWith('P') && vCode.contains('_')) {
                 String ptsStr = vCode.split('_')[0].replaceAll('P', '');
                 usedPoints += int.tryParse(ptsStr) ?? 0;
             }
        }
        final spentRes = await http.get(Uri.parse('$apiBaseUrl/api/user/total-spent/${user.id}'));
        if (spentRes.statusCode == 200) {
            final spentData = json.decode(spentRes.body);
            double totalSpent = double.tryParse(spentData['totalSpent'].toString()) ?? 0.0;
            _currentPoints = (totalSpent / 10000).floor() - usedPoints; 
            if (_currentPoints < 0) _currentPoints = 0; 
        }

        if (mounted) {
          setState(() {
            _vouchers = data.where((v) {
              var state = v['Used'] ?? v['Status'] ?? 0;
              return state.toString() == '0'; 
            }).toList();

            _findBestVoucher(); 
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _findBestVoucher() {
    int maxDiscountFound = -1;
    int? bestId;

    for (var v in _vouchers) {
      int voucherId = int.tryParse(v['VoucherID']?.toString() ?? '0') ?? 0;
      int percent = int.tryParse(v['DiscountPercent']?.toString() ?? '0') ?? 0;
      int minOrderValue = int.tryParse(v['MinOrderValue']?.toString() ?? '0') ?? 0;
      int maxDiscountAmount = int.tryParse(v['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
      int discountAmount = int.tryParse(v['DiscountAmount']?.toString() ?? '0') ?? 0;

      if (widget.totalAmount >= minOrderValue) {
        int calcDiscount = 0;
        if (percent == 100) {
          calcDiscount = discountAmount > 0 ? discountAmount : maxDiscountAmount;
        } else {
          calcDiscount = (widget.totalAmount * percent / 100).round();
          calcDiscount = calcDiscount > maxDiscountAmount ? maxDiscountAmount : calcDiscount;
        }
        
        calcDiscount = calcDiscount > widget.totalAmount ? widget.totalAmount : calcDiscount;

        if (calcDiscount > maxDiscountFound && calcDiscount > 0) {
          maxDiscountFound = calcDiscount;
          bestId = voucherId;
        }
      }
    }
    _bestVoucherId = bestId;
  }

  Future<void> _handleCheckCode() async {
    FocusScope.of(context).unfocus(); 

    String inputCode = _codeController.text.trim().toUpperCase();
    if (inputCode.isEmpty) {
      _showNotificationDialog("Vui lòng nhập mã khuyến mãi!", true); // 🚀 DÙNG DIALOG THAY CHO SNACKBAR
      return;
    }

    final alreadySavedVoucher = _vouchers.firstWhere((v) => (v['Code']?.toString().toUpperCase() ?? '') == inputCode, orElse: () => null);

    if (alreadySavedVoucher != null) {
      int minOrderValue = int.tryParse(alreadySavedVoucher['MinOrderValue']?.toString() ?? '0') ?? 0;
      if (widget.totalAmount < minOrderValue) {
        _showNotificationDialog("Mã này chỉ áp dụng cho đơn từ ${formatter.format(minOrderValue)}", true); // 🚀 DÙNG DIALOG
        return;
      }
      setState(() => _selectedVoucherId = int.tryParse(alreadySavedVoucher['VoucherID']?.toString() ?? '0') ?? 0);
      _showNotificationDialog("Đã áp dụng mã thành công!", false); // 🚀 DÙNG DIALOG
      _codeController.clear();
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/vouchers'));
      Navigator.pop(context); // Tắt loading

      if (res.statusCode == 200) {
        final List<dynamic> allGlobalVouchers = json.decode(res.body);
        final foundVoucher = allGlobalVouchers.firstWhere((v) => (v['Code']?.toString().toUpperCase() ?? '') == inputCode, orElse: () => null);

        if (foundVoucher == null) {
          _showNotificationDialog("Mã không tồn tại hoặc đã hết hạn!", true); // 🚀 DÙNG DIALOG
          return;
        }

        int voucherId = int.tryParse(foundVoucher['VoucherID']?.toString() ?? '0') ?? 0;
        int percent = int.tryParse(foundVoucher['DiscountPercent']?.toString() ?? '0') ?? 0;
        int minOrderValue = int.tryParse(foundVoucher['MinOrderValue']?.toString() ?? '0') ?? 0;
        int maxDiscountAmount = int.tryParse(foundVoucher['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
        int discountAmount = int.tryParse(foundVoucher['DiscountAmount']?.toString() ?? '0') ?? 0;
        int qty = int.tryParse(foundVoucher['Quantity']?.toString() ?? '0') ?? 0;

        if (qty <= 0) {
          _showNotificationDialog("Rất tiếc! Mã này đã hết lượt sử dụng.", true); // 🚀 DÙNG DIALOG
          return;
        }

        bool isPointVoucher = inputCode.startsWith('P') && inputCode.contains('_');
        int requiredPoints = 0;
        if (isPointVoucher) {
            String ptsStr = inputCode.split('_')[0].replaceAll('P', '');
            requiredPoints = int.tryParse(ptsStr) ?? 0;
        }

        _showSaveVoucherPopup(voucherId, inputCode, percent, minOrderValue, maxDiscountAmount, discountAmount, isPointVoucher, requiredPoints);

      }
    } catch (e) {
      Navigator.pop(context); // Tắt loading
      _showNotificationDialog("Lỗi kết nối mạng!", true); // 🚀 DÙNG DIALOG
    }
  }

  void _showSaveVoucherPopup(int voucherId, String code, int percent, int minOrderValue, int maxDiscountAmount, int discountAmount, bool isPointVoucher, int requiredPoints) {
    bool isFixed = percent == 100;
    String titleText = "";
    String leftBlockText = ""; 
    if (isFixed) {
      int realAmount = discountAmount > 0 ? discountAmount : maxDiscountAmount;
      leftBlockText = _formatCompactMoney(realAmount);
      titleText = "Giảm $leftBlockText";
    } else {
      leftBlockText = "$percent%";
      titleText = "Giảm $leftBlockText";
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFF5F5F9), borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: const Text("Tìm thấy ưu đãi!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 90,
                              decoration: BoxDecoration(gradient: LinearGradient(colors: [navyBlue, Colors.blue.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("GIẢM", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                  Text(leftBlockText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                  if (isPointVoucher) const Padding(padding: EdgeInsets.only(top: 4), child: Text("VIP TICKET", style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            Positioned(left: -4, top: 0, bottom: 0, child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(10, (index) => Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle))))),
                          ],
                        ),
                        Container(
                          width: 14, color: Colors.white,
                          child: Stack(
                            children: [
                              Center(child: DottedLine(direction: Axis.vertical, lineThickness: 1.5, dashLength: 4, dashColor: Colors.grey.shade300)),
                              Positioned(top: -7, left: 0, right: 0, child: Container(height: 14, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle))),
                              Positioned(bottom: -7, left: 0, right: 0, child: Container(height: 14, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(isPointVoucher ? "VIP: $code" : "Mã: $code", style: TextStyle(color: Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(titleText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87), maxLines: 1),
                                const Spacer(),
                                if (minOrderValue > 0) Text("Đơn từ ${_formatCompactMoney(minOrderValue)}", style: TextStyle(fontSize: 10, color: Colors.grey.shade600))
                                else Text("Mọi đơn hàng", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isPointVoucher 
                  ? Text("Bạn đang có: $_currentPoints điểm\nMã này yêu cầu: $requiredPoints điểm", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _currentPoints >= requiredPoints ? Colors.green.shade700 : Colors.red.shade600, fontWeight: FontWeight.bold))
                  : const Text("Lưu mã này vào ví để sử dụng nhé!", style: TextStyle(fontSize: 13, color: Colors.black54)),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isPointVoucher && _currentPoints < requiredPoints) 
                          ? null 
                          : () {
                              Navigator.pop(ctx);
                              _executeSaveVoucher(voucherId, code, requiredPoints);
                            },
                        style: ElevatedButton.styleFrom(backgroundColor: navyBlue, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: Text(isPointVoucher ? "Đổi $requiredPoints điểm" : "Lưu mã", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  Future<void> _executeSaveVoucher(int voucherId, String code, int requiredPoints) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/vouchers/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': user.id, 'voucherId': voucherId}),
      );
      
      Navigator.pop(context); // Tắt loading

      if (response.statusCode == 200) {
        await _fetchMyVouchers();
        setState(() {
          _selectedVoucherId = voucherId;
        });
        _showNotificationDialog(requiredPoints > 0 ? "Đổi điểm và áp dụng mã thành công!" : "Lưu và áp dụng mã thành công!", false); // 🚀 DÙNG DIALOG 
        _codeController.clear();
      } else {
        final errData = jsonDecode(response.body);
        _showNotificationDialog(errData['error'] ?? errData['message'] ?? "Lỗi!", true); // 🚀 DÙNG DIALOG
      }
    } catch (e) {
      Navigator.pop(context);
      _showNotificationDialog("Lỗi kết nối mạng!", true); // 🚀 DÙNG DIALOG
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedData;
    
    if (_selectedVoucherId != null) {
      final v = _vouchers.firstWhere((v) => v['VoucherID'] == _selectedVoucherId, orElse: () => null);
      if (v != null) {
        int percent = int.tryParse(v['DiscountPercent']?.toString() ?? '0') ?? 0;
        int maxDiscountAmount = int.tryParse(v['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
        int discountAmount = int.tryParse(v['DiscountAmount']?.toString() ?? '0') ?? 0;

        int calculatedDiscount = 0;
        if (percent == 100) {
           calculatedDiscount = discountAmount > 0 ? discountAmount : maxDiscountAmount;
        } else {
           calculatedDiscount = (widget.totalAmount * percent / 100).round();
        }

        calculatedDiscount = calculatedDiscount > maxDiscountAmount ? maxDiscountAmount : calculatedDiscount;
        calculatedDiscount = calculatedDiscount > widget.totalAmount ? widget.totalAmount : calculatedDiscount;

        selectedData = {
          'id': v['VoucherID'], 
          'code': v['Code'],
          'discount': calculatedDiscount,
        };
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, 
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24), 
                    Text("Chọn Ưu Đãi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.black54, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: TextField(
                          controller: _codeController, 
                          textCapitalization: TextCapitalization.characters, 
                          decoration: InputDecoration(
                            hintText: "Nhập mã khuyến mãi",
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _handleCheckCode, 
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 46, padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(color: navyBlue, borderRadius: BorderRadius.circular(8)), 
                        alignment: Alignment.center,
                        child: const Text("Kiểm tra", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: navyBlue))
                  : _vouchers.isEmpty
                    ? const Center(child: Text("Bạn chưa lưu mã ưu đãi nào.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _vouchers.length,
                        itemBuilder: (context, index) {
                          final v = _vouchers[index];
                          int voucherId = int.tryParse(v['VoucherID']?.toString() ?? '0') ?? 0;
                          String code = v['Code']?.toString() ?? 'Khuyến mãi';
                          int percent = int.tryParse(v['DiscountPercent']?.toString() ?? '0') ?? 0;
                          String expiredStr = v['ExpiredAt']?.toString() ?? "";
                          int minOrderValue = int.tryParse(v['MinOrderValue']?.toString() ?? '0') ?? 0;
                          int maxDiscountAmount = int.tryParse(v['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
                          int discountAmount = int.tryParse(v['DiscountAmount']?.toString() ?? '0') ?? 0;

                          bool isPointVoucher = code.startsWith('P') && code.contains('_');
                          bool isFixed = percent == 100;
                          bool isEligible = widget.totalAmount >= minOrderValue; 
                          bool isSelected = _selectedVoucherId == voucherId;
                          bool isBestDeal = _bestVoucherId == voucherId; 

                          String formattedDate = "Đang cập nhật";
                          try {
                            if (expiredStr.isNotEmpty) {
                              DateTime dt = DateTime.parse(expiredStr).toLocal();
                              formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                            }
                          } catch (_) {}

                          String titleText = "";
                          String leftBlockText = ""; 
                          
                          if (isFixed) {
                            int realAmount = discountAmount > 0 ? discountAmount : maxDiscountAmount;
                            leftBlockText = _formatCompactMoney(realAmount);
                            titleText = "Giảm $leftBlockText";
                          } else {
                            leftBlockText = "$percent%";
                            titleText = "Giảm $leftBlockText";
                          }

                          Color activeColor = isEligible ? navyBlue : Colors.grey.shade400;
                          LinearGradient bgGradient = LinearGradient(
                              colors: isEligible ? [activeColor, Colors.blue.shade500] : [Colors.grey.shade400, Colors.grey.shade400], 
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                          );

                          return GestureDetector(
                            onTap: () {
                              if (!isEligible) {
                                _showNotificationDialog("Mã này chỉ áp dụng cho đơn từ ${formatter.format(minOrderValue)}", true); // 🚀 DÙNG DIALOG THAY SNACKBAR
                                return; 
                              }
                              setState(() {
                                _selectedVoucherId = isSelected ? null : voucherId; 
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              height: 135,
                              decoration: BoxDecoration(
                                color: isEligible ? Colors.white : Colors.grey.shade50, 
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? navyBlue : Colors.transparent, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          width: 104,
                                          decoration: BoxDecoration(gradient: bgGradient),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text("GIẢM", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                              const SizedBox(height: 2),
                                              Text(leftBlockText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                              if (isPointVoucher)
                                                const Padding(padding: EdgeInsets.only(top: 4), child: Text("VIP TICKET", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold))),
                                            ],
                                          ),
                                        ),
                                        Positioned(left: -4, top: 0, bottom: 0, child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(12, (index) => Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle)))))
                                      ],
                                    ),
                                    Container(
                                      width: 14, color: isEligible ? Colors.white : Colors.grey.shade50,
                                      child: Stack(
                                        children: [
                                          Center(child: DottedLine(direction: Axis.vertical, lineThickness: 1.5, dashLength: 4, dashColor: Colors.grey.shade300)),
                                          Positioned(top: -7, left: 0, right: 0, child: Container(height: 14, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle))),
                                          Positioned(bottom: -7, left: 0, right: 0, child: Container(height: 14, decoration: const BoxDecoration(color: Color(0xFFF5F5F9), shape: BoxShape.circle))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        margin: EdgeInsets.only(bottom: 6, top: isBestDeal ? 16 : 0),
                                                        decoration: BoxDecoration(color: isEligible ? Colors.blue.shade50 : Colors.grey.shade200, borderRadius: BorderRadius.circular(4), border: Border.all(color: isEligible ? Colors.blue.shade200 : Colors.grey.shade300, width: 0.5)),
                                                        child: Text(isPointVoucher ? "VIP: $code" : "Mã: $code", style: TextStyle(color: isEligible ? Colors.blue.shade800 : Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                                                      ),
                                                      Text(titleText, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isEligible ? Colors.black87 : Colors.grey, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                      const SizedBox(height: 4),
                                                      if (!isFixed && maxDiscountAmount < 999999) Text("Tối đa ${_formatCompactMoney(maxDiscountAmount)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                                      if (minOrderValue > 0) Text("Đơn tối thiểu ${_formatCompactMoney(minOrderValue)}", style: TextStyle(fontSize: 11, color: isEligible ? Colors.grey.shade600 : Colors.grey.shade400, fontWeight: FontWeight.w500)),
                                                      const Spacer(),
                                                      Text("HSD: $formattedDate", style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 24, height: 24,
                                                  decoration: BoxDecoration(border: Border.all(color: isSelected ? navyBlue : Colors.grey.shade400, width: 2), borderRadius: BorderRadius.circular(6), color: isSelected ? navyBlue : (isEligible ? Colors.white : Colors.grey.shade200)),
                                                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                                )
                                              ],
                                            ),
                                          ),
                                          if (isBestDeal)
                                            Positioned(
                                              top: 0, left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8), bottomLeft: Radius.circular(8))),
                                                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_fire_department, color: Colors.amber, size: 12), SizedBox(width: 4), Text("Ưu đãi tốt nhất", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]),
                                              ),
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
          ),
          
          // 🚀 NÚT ÁP DỤNG MÃ
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _selectedVoucherId != null ? () {
                  Navigator.pop(context, selectedData); // Trả data về khi đóng
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Áp dụng', style: TextStyle(color: _selectedVoucherId != null ? Colors.white : Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}