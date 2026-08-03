import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_manager.dart';

class VoucherListScreen extends StatefulWidget {
  const VoucherListScreen({super.key});

  @override
  State<VoucherListScreen> createState() => _VoucherListScreenState();
}

class _VoucherListScreenState extends State<VoucherListScreen> {
  final Color navyBlue = Colors.blue.shade900;
  final String apiBaseUrl = 'http://192.168.1.7:3000'; // Đảm bảo IP đúng với máy của bạn

  List<dynamic> _allVouchers = [];
  List<int> _savedVoucherIds = []; // Danh sách các ID voucher mà User hiện tại đã lưu
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllData(); // Gọi API ngay khi mở trang
  }

  // ========================================================
  // 1. TẢI ĐỒNG THỜI TẤT CẢ VOUCHER & VÍ VOUCHER CỦA USER
  // ========================================================
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    
    try {
      // Gọi API 1: Lấy tất cả voucher có trên hệ thống
      final allVouchersResponse = await http.get(Uri.parse('$apiBaseUrl/api/vouchers'));
      if (allVouchersResponse.statusCode == 200) {
        _allVouchers = json.decode(allVouchersResponse.body);
      } else {
        throw Exception('Failed to load all vouchers');
      }

      // Gọi API 2: Lấy danh sách ID voucher đã nằm trong "ví" của User hiện tại
      final currentUser = UserManager.instance.currentUser;
      if (currentUser != null) {
        final savedVouchersResponse = await http.get(Uri.parse('$apiBaseUrl/api/vouchers/user/${currentUser.id}'));
        if (savedVouchersResponse.statusCode == 200) {
          final List<dynamic> savedList = json.decode(savedVouchersResponse.body);
          // Trích xuất các ID voucher đã lưu vào list để tiện kiểm tra
          _savedVoucherIds = savedList.map<int>((v) => v['VoucherID'] as int).toList();
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Lỗi tải API Vouchers: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi kết nối máy chủ!"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ========================================================
  // 2. GỌI API LƯU VOUCHER VÀO VÍ NGƯỜI DÙNG
  // ========================================================
  Future<void> _saveVoucher(int voucherId, String code) async {
    final currentUser = UserManager.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để lưu ưu đãi!"), backgroundColor: Colors.red)
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/vouchers/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': currentUser.id,
          'voucherId': voucherId
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Đã lưu mã $code thành công!"),
          backgroundColor: Colors.green,
        ));
        
        // Tải lại dữ liệu để nút bấm chuyển sang màu xám
        _fetchAllData(); 
      } else {
        final errData = jsonDecode(response.body);
        String errorMsg = errData['message'] ?? errData['error'] ?? "Lỗi không xác định từ Server!";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lỗi kết nối máy chủ!"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ưu đãi dành cho bạn', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: navyBlue))
        : _allVouchers.isEmpty 
          ? const Center(child: Text("Hiện chưa có khuyến mãi nào.", style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
              color: navyBlue,
              onRefresh: _fetchAllData, 
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _allVouchers.length,
                itemBuilder: (context, index) {
                  final voucher = _allVouchers[index];
                  
                  int voucherId = int.tryParse(voucher['VoucherID']?.toString() ?? '0') ?? 0;
                  String code = voucher['Code']?.toString() ?? 'Khuyến mãi';
                  int percent = int.tryParse(voucher['DiscountPercent']?.toString() ?? '0') ?? 0;
                  int qty = int.tryParse(voucher['Quantity']?.toString() ?? '0') ?? 0;
                  
                  // Lấy 2 cột giới hạn mới thêm từ Database
                  int minOrderValue = int.tryParse(voucher['MinOrderValue']?.toString() ?? '0') ?? 0;
                  int maxDiscountAmount = int.tryParse(voucher['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
                  int discountAmount = int.tryParse(voucher['DiscountAmount']?.toString() ?? '0') ?? 0;
                  
                  // Kiểm tra xem User đã lưu mã này chưa
                  bool isSaved = _savedVoucherIds.contains(voucherId);
                  bool isOut = qty <= 0;

                  String expiredStr = voucher['ExpiredAt']?.toString() ?? "";
                  String formattedDate = "Đang cập nhật";
                  try {
                    if (expiredStr.isNotEmpty) {
                      DateTime dt = DateTime.parse(expiredStr).toLocal();
                      formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                    }
                  } catch (_) {}

                  // Định dạng số tiền (Ví dụ: 100.000đ)
                  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

                  // ========================================================
                  // 🚀 LOGIC XỬ LÝ HIỂN THỊ: % HAY SỐ TIỀN (K)
                  // ========================================================
                  String displayValue = "";
                  double displayFontSize = 26;

                  if (discountAmount > 0 || (percent == 100 && maxDiscountAmount < 999999)) {
                    int realAmount = discountAmount > 0 ? discountAmount : maxDiscountAmount;
                    if (realAmount >= 1000) {
                      displayValue = "${(realAmount / 1000).toStringAsFixed(0)}K"; 
                    } else {
                      displayValue = "${realAmount}đ";
                    }
                    displayFontSize = 22; 
                  } else if (percent > 0 && percent <= 100) {
                    displayValue = "$percent%";
                  } else {
                    displayValue = "HOT";
                    displayFontSize = 20;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Giảm", style: TextStyle(color: Colors.blue.shade800, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(displayValue, style: TextStyle(color: Colors.blue.shade800, fontSize: displayFontSize, fontWeight: FontWeight.w900, height: 1.1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                                child: Text("Mã: $code", style: TextStyle(color: Colors.blue.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 8),
                              
                              Text("Giảm $displayValue cho mọi đơn hàng", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                              
                              // ✅ Nếu đã giảm thẳng tiền thì KHÔNG CẦN dòng "Giảm tối đa..." nữa, nếu là % mới hiện
                              if (displayValue.contains('%') && maxDiscountAmount < 999999)
                                Text("Giảm tối đa ${formatter.format(maxDiscountAmount)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade600)),
                              
                              if (minOrderValue > 0)
                                Text("Đơn tối thiểu ${formatter.format(minOrderValue)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                              
                              const SizedBox(height: 4),
                              Text("HSD: $formattedDate", style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                              Text("Còn lại: $qty lượt", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // NÚT LƯU VOUCHER
                        ElevatedButton(
                          onPressed: (isSaved || isOut) ? null : () => _saveVoucher(voucherId, code),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSaved ? Colors.grey.shade400 : (isOut ? Colors.grey.shade300 : navyBlue),
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                          child: Text(
                            isSaved ? "Đã lưu" : (isOut ? "Hết mã" : "Lưu"), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}