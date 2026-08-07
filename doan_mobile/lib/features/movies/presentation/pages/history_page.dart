import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ticket_detail_page.dart'; 
import 'user_manager.dart';

const String baseUrl = "http://192.168.1.7:3000/"; // ✅ NHỚ SỬA LẠI IP CHO ĐÚNG MÁY BẠN

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  List<dynamic> _realTickets = [];
  List<dynamic> _filteredTickets = []; 
  bool _isLoadingHistory = true; 
  
  String _selectedBrand = 'Tất cả';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final List<String> _brands = ['Tất cả', 'CGV', 'Galaxy', 'Lotte', 'BHD', 'Cinestar', 'Beta', 'Mega GS', 'DCine'];

  @override
  void initState() {
    super.initState();
    _fetchHistory(); 
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final user = UserManager.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingHistory = false);
      return;
    }

    try {
      final ticketRes = await http.get(Uri.parse('${baseUrl}api/user/tickets/${user.id}'));
      
      if (ticketRes.statusCode == 200) {
        _realTickets = json.decode(ticketRes.body);
        _filteredTickets = List.from(_realTickets);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi Server: ${ticketRes.body}"), 
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            )
          );
        }
      }
      if (mounted) setState(() => _isLoadingHistory = false);
    } catch (e) {
      debugPrint("Lỗi tải lịch sử: $e");
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi kết nối mạng hoặc sai IP: $e"), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          )
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTickets = _realTickets.where((ticket) {
        String cinema = ticket['cinema']?.toString().toLowerCase() ?? '';
        String rawMovie = ticket['movie']?.toString() ?? '';
        String seats = ticket['seats']?.toString() ?? 'Không có';
        
        bool isOnlyFood = rawMovie.isEmpty || seats == "Không có";
        String movieSearchTerm = isOnlyFood ? 'đơn thức ăn đồ uống bắp nước' : rawMovie.toLowerCase();

        bool matchesBrand = _selectedBrand == 'Tất cả' || cinema.contains(_selectedBrand.toLowerCase());
        bool matchesSearch = _searchQuery.isEmpty || movieSearchTerm.contains(_searchQuery) || cinema.contains(_searchQuery);
        
        return matchesBrand && matchesSearch;
      }).toList();
    });
  }

  void _showBrandBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              Text("Chọn Hệ thống Rạp", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              const SizedBox(height: 8),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _brands.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _selectedBrand == _brands[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade50 : Colors.transparent, 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue.shade900 : Colors.transparent, 
                          width: 1.8,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          _brands[index], 
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.blue.shade900 : Colors.black87
                          )
                        ),
                        trailing: isSelected ? Icon(Icons.check_circle, color: Colors.blue.shade900) : null,
                        onTap: () {
                          setState(() { _selectedBrand = _brands[index]; });
                          _applyFilters();
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Map<String, List<dynamic>> _getGroupedTickets() {
    Map<String, List<dynamic>> grouped = {};
    for (var t in _filteredTickets) {
      String rawDate = t['date']?.toString() ?? "";
      String dateKey = "Không xác định";
      if (rawDate.contains('|')) {
        dateKey = rawDate.split('|')[1].trim();
      } else if (rawDate.contains('-')) {
        var parts = rawDate.split('-');
        if (parts.length > 1) dateKey = parts[1].trim();
      } else {
        dateKey = rawDate; 
      }
      if (!grouped.containsKey(dateKey)) { grouped[dateKey] = []; }
      grouped[dateKey]!.add(t);
    }
    return grouped; 
  }

  // 🚀 ĐÃ FIX: Xử lý thông minh bắt cả ảnh Admin lẫn TMDB
  String _getRealImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null') return "";
    String cleanPath = rawPath.trim().replaceAll('\\', '/');

    // 1. Ảnh tải từ Admin
    if (cleanPath.contains('uploads') || cleanPath.contains('movie-')) {
      String filename = cleanPath.split('/').last;
      return '${baseUrl}uploads/$filename';
    }

    // 2. Link web ngoài
    if (cleanPath.startsWith('http')) return cleanPath;

    // 3. Link phim TMDB
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return 'https://image.tmdb.org/t/p/w500$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900;
    
    // 🚀 ĐÃ SỬA: TÍNH LẠI TỔNG TIỀN (TRỪ ĐƠN ĐÃ HOÀN/HỦY)
    double totalSpent = 0;
    for (var t in _filteredTickets) {
      String status = t['status']?.toString() ?? ""; 
      // Chỉ cộng tiền những đơn KHÔNG PHẢI là hoàn/hủy
      if (status != 'Refunded' && status != 'Cancelled') {
        totalSpent += double.tryParse(t['price'].toString()) ?? 0;
      }
    }

    Map<String, List<dynamic>> groupedTickets = _getGroupedTickets();
    List<String> dateKeys = groupedTickets.keys.toList();

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
            Expanded(child: Text('Lịch sử giao dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
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
      body: _isLoadingHistory
          ? Center(child: CircularProgressIndicator(color: navyBlue))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. THỂ THỐNG KÊ CHI TIÊU
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [navyBlue, Colors.blue.shade600]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: navyBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tổng chi tiêu (${_selectedBrand})", style: TextStyle(color: Colors.blue.shade100, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(formatter.format(totalSpent), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Container(height: 1, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.confirmation_number_outlined, color: Colors.blue.shade100, size: 18),
                          const SizedBox(width: 8),
                          Text("Số lượng đơn: ${_filteredTickets.length}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      )
                    ],
                  ),
                ),

                // 2. THANH TÌM KIẾM + COMBO BOX RẠP
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) { _searchQuery = value.toLowerCase(); _applyFilters(); },
                          decoration: InputDecoration(
                            hintText: 'Tìm phim, rạp...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: navyBlue, size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: navyBlue, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      InkWell(
                        onTap: _showBrandBottomSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 110, 
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Rạp', 
                              labelStyle: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 14),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              filled: true,
                              fillColor: Colors.white, 
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedBrand, 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyBlue),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: navyBlue, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. DANH SÁCH VÉ GỘP THEO NGÀY
                Expanded(
                  child: _filteredTickets.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        physics: const BouncingScrollPhysics(),
                        itemCount: dateKeys.length,
                        itemBuilder: (context, index) {
                          String dateKey = dateKeys[index];
                          List<dynamic> ticketsInDate = groupedTickets[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text(dateKey, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              ...ticketsInDate.map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTicketCard(t, navyBlue),
                              )).toList(),
                            ],
                          );
                        },
                      ),
                ),
              ],
            ),
    );
  }

  // ========================================================
  // ✅ ĐÃ SỬA: THÊM BĂNG ĐÔ "ĐÃ HOÀN", LÀM MỜ VÀ CHẶN CLICK
  // ========================================================
  Widget _buildTicketCard(Map<String, dynamic> ticket, Color themeColor) {
    String rawMovie = ticket['movie']?.toString() ?? "";
    String seats = ticket['seats']?.toString() ?? "Không có";
    
    // KIỂM TRA TRẠNG THÁI HOÀN/HỦY
    String status = ticket['status']?.toString() ?? "";
    bool isRefunded = status == 'Refunded' || status == 'Cancelled';

    // KIỂM TRA XEM LÀ ĐƠN GÌ
    bool isOnlyFood = rawMovie.isEmpty || seats == "Không có";
    
    String titleDisplay = isOnlyFood ? "Đơn Thức ăn & Đồ uống" : rawMovie;
    String imageUrl = _getRealImageUrl(ticket['image']?.toString() ?? "");
    String rawDate = ticket['date']?.toString() ?? "";
    String timeOnly = rawDate.contains('|') ? rawDate.split('|')[0].trim() : rawDate;

    return Opacity(
      opacity: isRefunded ? 0.6 : 1.0, // Làm mờ 60% nếu là đơn đã hoàn
      child: InkWell(
        onTap: () {
          if (isRefunded) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Đơn hàng này đã hoàn tiền/hủy, không thể xem chi tiết."),
                backgroundColor: Colors.orange,
              )
            );
            return; // Chặn không cho chuyển trang
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetailPage(ticket: ticket, themeColor: themeColor)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 60, height: 85,
                    decoration: BoxDecoration(
                      color: isOnlyFood ? Colors.orange.shade50 : themeColor.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      // ✅ LOGIC CHỌN ẢNH THÔNG MINH
                      child: isOnlyFood
                          ? Image.asset(
                              'assets/poster-bapnuoc.png', 
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.fastfood_rounded, color: Colors.orange, size: 28),
                            )
                          : (imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.movie, color: themeColor, size: 28))
                              : Icon(Icons.movie, color: themeColor, size: 28)),
                    ),
                  ),
                  // 🚀 BĂNG ĐÔ "ĐÃ HOÀN" NẰM ĐÈ LÊN ẢNH
                  if (isRefunded)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700.withOpacity(0.9),
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))
                        ),
                        child: const Text("ĐÃ HOÀN", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    )
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      isOnlyFood ? "${ticket['cinema']}\nNhận hàng: $timeOnly" : "${ticket['cinema']}\nGiờ chiếu: $timeOnly", 
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)
                    ),
                    const SizedBox(height: 6),
                    // Gạch ngang giá tiền nếu đã hoàn
                    Text(
                      formatter.format(double.tryParse(ticket['price'].toString()) ?? 0), 
                      style: TextStyle(
                        color: isRefunded ? Colors.grey.shade500 : (isOnlyFood ? Colors.orange.shade800 : themeColor), 
                        fontWeight: FontWeight.bold, 
                        fontSize: 14,
                        decoration: isRefunded ? TextDecoration.lineThrough : null, // Gạch ngang tiền
                      )
                    ),
                  ],
                ),
              ),
              Icon(isRefunded ? Icons.block : Icons.chevron_right, color: isRefunded ? Colors.red.shade300 : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("Không tìm thấy giao dịch nào.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }
}