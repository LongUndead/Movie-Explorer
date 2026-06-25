import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:dotted_line/dotted_line.dart'; 
import 'dart:convert';

import '../../domain/entities/movie.dart';
import 'payment_webview_screen.dart';
import 'cart_page.dart'; 
import 'user_manager.dart';

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
        backgroundColor: Colors.blue.shade50, 
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: navyBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Thanh toán an toàn', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    final selectedVoucher = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VoucherSelectionScreen(totalAmount: widget.totalAmount)),
                    );

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
                
                // ✅ ĐÃ SỬA: Dùng đúng tên file ảnh bạn cung cấp
                _buildPaymentMethodItem(1, "VNPAY", "Thanh toán qua mã QR hoặc thẻ ATM", 'assets/vnpay.png'), 
                const SizedBox(height: 12),
                _buildPaymentMethodItem(2, "Ví MoMo", "Thanh toán siêu tốc", 'assets/momo.png'),
                
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
                
                onPressed: () async {
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
                        'id': seat['id'],       
                        'price': seat['price']  
                      }).toList();
                    }

                    int cinemaId = _getCinemaId(widget.cinemaName);
                    final userId = UserManager.instance.currentUser?.id ?? 0;

                    final bookingRes = await http.post(
                      Uri.parse('http://192.168.1.2:3000/api/bookings/create_pending'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'userId': userId, 
                        'showtimeId': widget.showtimeId,
                        'cinemaId': cinemaId,
                        'totalAmount': finalAmount, 
                        'seats': seatPayload,
                        'foods': CartManager.instance.foods.map((item) => {
                           'id': item.food.id,        
                           'quantity': item.quantity, 
                           'price': item.food.price   
                        }).toList()
                      }),
                    );

                    if (bookingRes.statusCode == 200) {
                      
                      if (_appliedVoucherId != null) {
                        try {
                          await http.post(
                            Uri.parse('http://192.168.1.2:3000/api/vouchers/mark-used'),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'userId': userId,
                              'voucherId': _appliedVoucherId
                            }),
                          );
                        } catch (e) {
                          debugPrint("Lỗi cập nhật trạng thái voucher: $e");
                        }
                      }

                      final String realBookingId = json.decode(bookingRes.body)['bookingId'];

                      String apiUrl = _selectedMethod == 1 
                          ? 'http://192.168.1.2:3000/api/vnpay/create_url' 
                          : 'http://192.168.1.2:3000/api/momo/create_url';

                      String orderInfoMsg = isOnlyFood 
                          ? 'Thanh toan don bap nuoc' 
                          : 'Thanh toan ve phim ${widget.movie!.title}';

                      final payRes = await http.post(
                        Uri.parse(apiUrl),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'orderId': realBookingId, 
                          'amount': finalAmount, 
                          'orderInfo': orderInfoMsg 
                        }),
                      );

                      if (context.mounted) Navigator.pop(context); 

                      if (payRes.statusCode == 200) {
                        final responseData = json.decode(payRes.body);
                        final String paymentUrl = responseData['paymentUrl']; 

                        CartManager.instance.clearCart();

                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PaymentWebViewScreen(
                              paymentUrl: paymentUrl,
                              movie: widget.movie,
                              date: widget.selectedDate,
                              time: widget.selectedTime,
                              cinemaName: widget.cinemaName, 
                            )
                          ));
                        }
                      } else {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối máy chủ thanh toán!'), backgroundColor: Colors.red));
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
// ✅ MÀN HÌNH CHỌN VOUCHER TỪ API
// =====================================================================
class VoucherSelectionScreen extends StatefulWidget {
  final int totalAmount; 
  const VoucherSelectionScreen({super.key, required this.totalAmount});

  @override
  State<VoucherSelectionScreen> createState() => _VoucherSelectionScreenState();
}

class _VoucherSelectionScreenState extends State<VoucherSelectionScreen> {
  final Color navyBlue = Colors.blue.shade900;
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final String apiBaseUrl = 'http://192.168.1.2:3000'; 

  List<dynamic> _vouchers = [];
  bool _isLoading = true;
  int? _selectedVoucherId;

  @override
  void initState() {
    super.initState();
    _fetchMyVouchers();
  }

  Future<void> _fetchMyVouchers() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/vouchers/user/${user.id}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        if (mounted) {
          setState(() {
            _vouchers = data.where((v) {
              var state = v['Used'] ?? v['Status'] ?? 0;
              return state.toString() == '0'; 
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Lỗi tải voucher: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedData;
    if (_selectedVoucherId != null) {
      final v = _vouchers.firstWhere((v) => v['VoucherID'] == _selectedVoucherId);
      int percent = int.tryParse(v['DiscountPercent']?.toString() ?? '0') ?? 0;
      
      int calculatedDiscount = (widget.totalAmount * percent / 100).round();
      
      selectedData = {
        'id': v['VoucherID'], 
        'code': v['Code'],
        'discount': calculatedDiscount,
      };
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: navyBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ưu đãi', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: Icon(Icons.notifications_none, color: navyBlue), onPressed: () {}),
          IconButton(
            icon: Icon(Icons.home_outlined, color: navyBlue),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Nhập mã khuyến mãi",
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 48, padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text("Kiểm tra", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text("Mã giảm giá của bạn", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyBlue)),
          ),

          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: navyBlue))
              : _vouchers.isEmpty
                ? const Center(child: Text("Bạn chưa lưu mã ưu đãi nào.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _vouchers.length,
                    itemBuilder: (context, index) {
                      final v = _vouchers[index];
                      
                      int voucherId = int.tryParse(v['VoucherID']?.toString() ?? '0') ?? 0;
                      String code = v['Code']?.toString() ?? 'Khuyến mãi';
                      int percent = int.tryParse(v['DiscountPercent']?.toString() ?? '0') ?? 0;
                      String expiredStr = v['ExpiredAt']?.toString() ?? "";
                      
                      String formattedDate = "Đang cập nhật";
                      try {
                        if (expiredStr.isNotEmpty) {
                          DateTime dt = DateTime.parse(expiredStr).toLocal();
                          formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                        }
                      } catch (_) {}

                      int simulatedDiscount = (widget.totalAmount * percent / 100).round();
                      bool isSelected = _selectedVoucherId == voucherId;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedVoucherId = null; 
                            } else {
                              _selectedVoucherId = voucherId; 
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? navyBlue : Colors.transparent, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("Giảm", style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                                      Text("$percent%", style: TextStyle(color: Colors.orange.shade800, fontSize: 20, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Mã: $code", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text("Giảm tối đa ${formatter.format(simulatedDiscount)}", style: TextStyle(color: Colors.green.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text("HSD: $formattedDate", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isSelected ? navyBlue : Colors.grey.shade400, width: 2),
                                    borderRadius: BorderRadius.circular(6),
                                    color: isSelected ? navyBlue : Colors.white,
                                  ),
                                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
        child: SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _selectedVoucherId != null ? () {
              Navigator.pop(context, selectedData); 
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
    );
  }
}