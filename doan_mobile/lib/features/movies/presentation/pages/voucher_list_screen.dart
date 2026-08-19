import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_manager.dart';

// =====================================================================
// ✅ 1. TRANG KHO VOUCHER (ĐỒNG BỘ 1 MÀU NAVY BLUE)
// =====================================================================
class VoucherListScreen extends StatefulWidget {
  final bool initialStoreMode;
  const VoucherListScreen({super.key, this.initialStoreMode = false});

  @override
  State<VoucherListScreen> createState() => _VoucherListScreenState();
}

class _VoucherListScreenState extends State<VoucherListScreen> {
  final Color navyBlue = Colors.blue.shade900;
  final String apiBaseUrl = 'http://10.173.120.41:3000'; 

  List<dynamic> _allVouchers = [];
  List<int> _savedVoucherIds = []; 
  bool _isLoading = true;
  
  int _currentPoints = 0; 
  late bool _isStoreMode;

  @override
  void initState() {
    super.initState();
    _isStoreMode = widget.initialStoreMode;
    _fetchAllData(); 
  }

  // HÀM RÚT GỌN TIỀN TỆ
  String _formatCompactMoney(int amount) {
    if (amount >= 1000000) {
      double val = amount / 1000000;
      return "${val == val.toInt() ? val.toInt() : val.toStringAsFixed(1)}trđ";
    } else if (amount >= 1000) {
      double val = amount / 1000;
      return "${val == val.toInt() ? val.toInt() : val.toStringAsFixed(1)}kđ";
    }
    return "${amount}đ";
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    
    try {
      final allVouchersResponse = await http.get(Uri.parse('$apiBaseUrl/api/vouchers'));
      if (allVouchersResponse.statusCode == 200) {
        _allVouchers = json.decode(allVouchersResponse.body);
      }

      final currentUser = UserManager.instance.currentUser;
      if (currentUser != null) {
        int usedPoints = 0; 
        
        final savedVouchersResponse = await http.get(Uri.parse('$apiBaseUrl/api/vouchers/user/${currentUser.id}'));
        if (savedVouchersResponse.statusCode == 200) {
          final List<dynamic> savedList = json.decode(savedVouchersResponse.body);
          _savedVoucherIds = savedList.map<int>((v) => v['VoucherID'] as int).toList();
          
          for (var v in savedList) {
             String vCode = v['Code']?.toString() ?? '';
             if (vCode.startsWith('P') && vCode.contains('_')) {
                 String ptsStr = vCode.split('_')[0].replaceAll('P', '');
                 usedPoints += int.tryParse(ptsStr) ?? 0;
             }
          }
        }

        final spentRes = await http.get(Uri.parse('$apiBaseUrl/api/user/total-spent/${currentUser.id}'));
        if (spentRes.statusCode == 200) {
            final spentData = json.decode(spentRes.body);
            double totalSpent = double.tryParse(spentData['totalSpent'].toString()) ?? 0.0;
            _currentPoints = (totalSpent / 10000).floor() - usedPoints; 
            if (_currentPoints < 0) _currentPoints = 0; 
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =====================================================================
  // 🚀 POPUP XÁC NHẬN ĐỔI ĐIỂM
  // =====================================================================
  void _confirmAndSaveVoucher(int voucherId, String code, int requiredPoints) {
    if (requiredPoints > 0 && _currentPoints < requiredPoints) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cần thêm ${requiredPoints - _currentPoints} điểm nữa!"), backgroundColor: Colors.orange.shade800));
        return;
    }

    if (requiredPoints > 0) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Bo góc mềm mại
                title: Column(
                    children: [
                        Icon(Icons.stars_rounded, color: navyBlue, size: 48), 
                        const SizedBox(height: 12),
                        const Text("Xác nhận đổi điểm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                ),
                content: Text(
                    "Bạn có chắc chắn muốn dùng $requiredPoints điểm để đổi lấy mã giảm giá $code không?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Suy nghĩ lại", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                        onPressed: () {
                            Navigator.pop(ctx);
                            _executeSaveVoucherApi(voucherId, code, requiredPoints); 
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: navyBlue, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                        ),
                        child: const Text("Đổi ngay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
            )
        );
    } else {
        _executeSaveVoucherApi(voucherId, code, 0);
    }
  }

  Future<void> _executeSaveVoucherApi(int voucherId, String code, int requiredPoints) async {
    final currentUser = UserManager.instance.currentUser;
    if (currentUser == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/vouchers/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': currentUser.id, 'voucherId': voucherId}),
      );

      if (response.statusCode == 200) {
        _fetchAllData(); 
        
        if (mounted) {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Bo góc mềm mại
                    title: Column(
                        children: [
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                child: Icon(Icons.check_circle_rounded, color: Colors.green.shade500, size: 48),
                            ),
                            const SizedBox(height: 12),
                            Text(requiredPoints > 0 ? "Đổi mã thành công!" : "Đã lưu mã thành công!", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        ],
                    ),
                    content: Text(
                        "Mã ưu đãi $code đã được thêm vào Ví Voucher của bạn.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                        ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
                            ),
                            child: const Text("Tuyệt vời", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                    ],
                )
            );
        }
      } else {
        final errData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errData['error'] ?? errData['message'] ?? "Lỗi!"), backgroundColor: Colors.orange));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối!"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedVouchers = _allVouchers.where((v) {
      String code = v['Code']?.toString() ?? '';
      bool isPointVoucher = code.startsWith('P') && code.contains('_');
      return _isStoreMode ? isPointVoucher : !isPointVoucher;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0, 
        title: Row(
          children: [
            const SizedBox(width: 16), 
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                        _isStoreMode ? 'Cửa Hàng VIP' : 'Kho Ưu Đãi', 
                        key: ValueKey<bool>(_isStoreMode), 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)
                    )
                )
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50])),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                  borderRadius: BorderRadius.circular(20), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 
                    child: Icon(Icons.home_outlined, color: navyBlue, size: 19)
                  )
                ),
              ],
            ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _isStoreMode = !_isStoreMode),
        elevation: 6,
        backgroundColor: navyBlue, 
        icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(_isStoreMode ? Icons.local_activity_rounded : Icons.storefront_rounded, key: ValueKey(_isStoreMode), color: Colors.white),
        ),
        label: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(_isStoreMode ? "Về Kho Ưu Đãi" : "Cửa Hàng Đổi Điểm", key: ValueKey(_isStoreMode), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: navyBlue))
        : Column(
            children: [
              if (UserManager.instance.currentUser != null)
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [navyBlue, Colors.blue.shade500]),
                        boxShadow: [BoxShadow(color: navyBlue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        child: Text(_isStoreMode ? "Cửa Hàng Đặc Quyền" : "Điểm tích lũy của bạn", key: ValueKey(_isStoreMode), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))
                                    ),
                                    const SizedBox(height: 4),
                                    AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        child: Text(_isStoreMode ? "Dùng điểm săn mã xịn!" : "Nhận 1 điểm mỗi 10.000đ", key: ValueKey(_isStoreMode), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))
                                    ),
                                ],
                            ),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.5))),
                                child: Row(
                                    children: [
                                        const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 6),
                                        Text("$_currentPoints", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                    ],
                                ),
                            )
                        ],
                    ),
                ),

              Expanded(
                child: displayedVouchers.isEmpty 
                  ? Center(child: Text(_isStoreMode ? "Chưa có mã đổi điểm nào." : "Hiện chưa có ưu đãi chung nào.", style: const TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      color: navyBlue,
                      onRefresh: _fetchAllData, 
                      child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: ListView.builder(
                            key: ValueKey<bool>(_isStoreMode), 
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(left: 12, right: 12, top: 16, bottom: 80),
                            itemCount: displayedVouchers.length,
                            itemBuilder: (context, index) {
                              final voucher = displayedVouchers[index];
                              int voucherId = int.tryParse(voucher['VoucherID']?.toString() ?? '0') ?? 0;
                              String code = voucher['Code']?.toString() ?? 'Khuyến mãi';
                              int percent = int.tryParse(voucher['DiscountPercent']?.toString() ?? '0') ?? 0;
                              int qty = int.tryParse(voucher['Quantity']?.toString() ?? '0') ?? 0;
                              int minOrderValue = int.tryParse(voucher['MinOrderValue']?.toString() ?? '0') ?? 0;
                              int maxDiscountAmount = int.tryParse(voucher['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
                              int discountAmount = int.tryParse(voucher['DiscountAmount']?.toString() ?? '0') ?? 0;
                              
                              bool isSaved = _savedVoucherIds.contains(voucherId);
                              bool isOut = qty <= 0;

                              int requiredPoints = 0;
                              bool isPointVoucher = false;
                              if (code.startsWith('P') && code.contains('_')) {
                                  String ptsStr = code.split('_')[0].replaceAll('P', '');
                                  requiredPoints = int.tryParse(ptsStr) ?? 0;
                                  isPointVoucher = true;
                              }

                              String expiredStr = voucher['ExpiredAt']?.toString() ?? "";
                              String formattedDate = "Đang cập nhật";
                              try {
                                if (expiredStr.isNotEmpty) {
                                  DateTime dt = DateTime.parse(expiredStr).toLocal();
                                  formattedDate = DateFormat('dd/MM/yyyy').format(dt);
                                }
                              } catch (_) {}

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

                              Color activeColor = navyBlue;
                              LinearGradient bgGradient = (isSaved || isOut)
                                  ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
                                  : LinearGradient(colors: [activeColor, Colors.blue.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight);

                              return TweenAnimationBuilder(
                                duration: Duration(milliseconds: 300 + (index * 100).clamp(0, 500)), 
                                tween: Tween<double>(begin: 0, end: 1),
                                curve: Curves.easeOutCubic,
                                builder: (context, double value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 50 * (1 - value)), 
                                    child: Opacity(opacity: value, child: child),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      height: 130, 
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8), // Bo góc mượt 8px
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Row(
                                          children: [
                                            // 🚀 CỘT TRÁI CÓ 12 LỖ KHOÉT RĂNG CƯA CHUẨN ĐÚC
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
                                                        const Padding(
                                                          padding: EdgeInsets.only(top: 4),
                                                          child: Text("VIP TICKET", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                // 🚀 RĂNG CƯA LỖ TRÒN LẸM VÀO THẺ
                                                Positioned(
                                                  left: -4, top: 0, bottom: 0,
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                    children: List.generate(12, (index) => Container(
                                                      width: 8, height: 8,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFFF5F5F9), // Màu xám nền App
                                                        shape: BoxShape.circle,
                                                      ),
                                                    )),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                                            // RÃNH XÉ VÉ DỌC
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

                                            // CỘT PHẢI (THÔNG TIN)
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            margin: const EdgeInsets.only(bottom: 6),
                                                            decoration: BoxDecoration(
                                                              color: (isSaved || isOut) ? Colors.grey.shade100 : Colors.blue.shade50, 
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(color: (isSaved || isOut) ? Colors.grey.shade300 : Colors.blue.shade200, width: 0.5),
                                                            ),
                                                            child: Text(
                                                              isPointVoucher ? "Mã VIP: $code" : "Mã: $code", 
                                                              style: TextStyle(color: (isSaved || isOut) ? Colors.grey.shade600 : Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold)
                                                            ),
                                                          ),

                                                          Text(titleText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                          const SizedBox(height: 4),
                                                          
                                                          if (!isFixed && maxDiscountAmount < 999999)
                                                            Text("Tối đa ${_formatCompactMoney(maxDiscountAmount)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                                          
                                                          if (minOrderValue > 0)
                                                            Text("Đơn tối thiểu ${_formatCompactMoney(minOrderValue)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                                          
                                                          const Spacer(),
                                                          Row(
                                                            children: [
                                                              Expanded(child: Text(isOut ? "Hết lượt" : "HSD: $formattedDate", style: TextStyle(fontSize: 11, color: isOut ? Colors.grey : Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    
                                                    const SizedBox(width: 6),
                                                    Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        if (isPointVoucher && !isSaved && !isOut)
                                                          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text("Cần $requiredPoints điểm", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: activeColor))),
                                                        SizedBox(
                                                          height: 32, width: 76,
                                                          child: OutlinedButton(
                                                            onPressed: (isSaved || isOut) ? null : () => _confirmAndSaveVoucher(voucherId, code, requiredPoints),
                                                            style: OutlinedButton.styleFrom(
                                                              foregroundColor: isSaved ? Colors.grey : activeColor,
                                                              side: BorderSide(color: isSaved ? Colors.grey.shade300 : activeColor, width: 1.2),
                                                              padding: const EdgeInsets.symmetric(horizontal: 0),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), 
                                                            ),
                                                            child: Text(isSaved ? "Đã lưu" : (isOut ? "Hết mã" : (isPointVoucher ? "Đổi mã" : "Lưu ngay")), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!isSaved && !isOut)
                                      Positioned(
                                        top: 0, right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomLeft: Radius.circular(6))),
                                          child: const Text("Mới!", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                  ],
                                ),
                              );
                            },
                          ),
                      ),
                    ),
              ),
            ],
          ),
    );
  }
}

// =====================================================================
// ✅ 2. TRANG VÍ VOUCHER CỦA TÔI
// =====================================================================
class UserVoucherPage extends StatefulWidget {
  const UserVoucherPage({super.key});
  @override
  State<UserVoucherPage> createState() => _UserVoucherPageState();
}

class _UserVoucherPageState extends State<UserVoucherPage> {
  List<dynamic> _vouchers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  Future<void> _fetchVouchers() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('http://10.173.120.41:3000/api/vouchers/user/${user.id}'));
      if (res.statusCode == 200) {
        _vouchers = json.decode(res.body);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCompactMoney(int amount) {
    if (amount >= 1000000) {
      double val = amount / 1000000;
      return "${val == val.toInt() ? val.toInt() : val.toStringAsFixed(1)}trđ";
    } else if (amount >= 1000) {
      double val = amount / 1000;
      return "${val == val.toInt() ? val.toInt() : val.toStringAsFixed(1)}kđ";
    }
    return "${amount}đ";
  }

  @override
  Widget build(BuildContext context) {
    final available = _vouchers.where((v) {
      var state = v['Used'] ?? v['Status'] ?? 0;
      return state.toString() == '0'; 
    }).toList();

    final used = _vouchers.where((v) {
      var state = v['Used'] ?? v['Status'] ?? 0;
      return state.toString() == '1';
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0, 
          title: Row(
            children: [
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Ví Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900))),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: Container(
              color: Colors.white, 
              child: TabBar(
                indicatorColor: Colors.blue.shade900,
                labelColor: Colors.blue.shade900,    
                unselectedLabelColor: Colors.grey.shade600,
                tabs: [
                  Tab(text: "Đã lưu (${available.length})"), 
                  Tab(text: "Đã sử dụng (${used.length})")
                ],
              ),
            ),
          ),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildVoucherList(available, false),
                  _buildVoucherList(used, true),
                ],
              ),
      ),
    );
  }

 Widget _buildVoucherList(List<dynamic> list, bool isUsed) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_activity_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isUsed ? "Chưa có voucher nào được dùng" : "Bạn không có voucher nào", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    
    final Color navyBlue = Colors.blue.shade900;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final v = list[index];
        String code = v['Code']?.toString() ?? "VOUCHER";
        int percent = int.tryParse(v['DiscountPercent']?.toString() ?? '0') ?? 0;
        int minOrderValue = int.tryParse(v['MinOrderValue']?.toString() ?? '0') ?? 0;
        int maxDiscountAmount = int.tryParse(v['MaxDiscountAmount']?.toString() ?? '999999999') ?? 999999999;
        int discountAmount = int.tryParse(v['DiscountAmount']?.toString() ?? '0') ?? 0;
        
        bool isPointVoucher = code.startsWith('P') && code.contains('_');

        String expiredStr = v['ExpiredAt']?.toString() ?? "";
        String formattedDate = "Đang cập nhật";
        try {
          if (expiredStr.isNotEmpty) {
            DateTime dt = DateTime.parse(expiredStr).toLocal();
            formattedDate = DateFormat('dd/MM/yyyy').format(dt);
          }
        } catch (_) {}

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

        Color activeColor = navyBlue;
        LinearGradient bgGradient = isUsed
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
            : LinearGradient(colors: [activeColor, Colors.blue.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight);

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 100).clamp(0, 500)),
          tween: Tween<double>(begin: 0, end: 1),
          curve: Curves.easeOutCubic,
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 130, 
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      // 🚀 RĂNG CƯA TRONG VÍ
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
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text("VIP TICKET", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: -4, top: 0, bottom: 0,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(12, (index) => Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5F5F9), 
                                  shape: BoxShape.circle,
                                ),
                              )),
                            ),
                          ),
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
                          padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: isUsed ? Colors.grey.shade100 : Colors.blue.shade50, 
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isUsed ? Colors.grey.shade300 : Colors.blue.shade200, width: 0.5),
                                      ),
                                      child: Text(
                                        isPointVoucher ? "Mã VIP: $code" : "Mã: $code", 
                                        style: TextStyle(color: isUsed ? Colors.grey.shade600 : Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold)
                                      ),
                                    ),

                                    Text(titleText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    
                                    if (!isFixed && maxDiscountAmount < 999999)
                                      Text("Tối đa ${_formatCompactMoney(maxDiscountAmount)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                    
                                    if (minOrderValue > 0)
                                      Text("Đơn tối thiểu ${_formatCompactMoney(minOrderValue)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                    
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Expanded(child: Text(isUsed ? "Đã dùng" : "HSD: $formattedDate", style: TextStyle(fontSize: 11, color: isUsed ? Colors.grey : Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 6),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    height: 32, width: 76,
                                    child: OutlinedButton(
                                      onPressed: isUsed ? null : () {}, 
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isUsed ? Colors.grey : activeColor,
                                        side: BorderSide(color: isUsed ? Colors.grey.shade300 : activeColor, width: 1.2),
                                        padding: const EdgeInsets.symmetric(horizontal: 0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: Text(isUsed ? "Đã dùng" : "Dùng ngay", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isUsed)
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomLeft: Radius.circular(6))),
                    child: const Text("Mới!", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
        );
      },
    );
  }
}