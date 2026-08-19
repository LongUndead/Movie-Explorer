import 'package:doan_mobile/features/movies/domain/entities/cinema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'dart:convert';
import '../../domain/entities/movie.dart';
import '../bloc/movie_bloc.dart';
import '../bloc/movie_event.dart';
import '../bloc/movie_state.dart';
import 'seat_booking_page.dart';
import '../../data/models/city_model.dart'; 
import 'user_manager.dart';
import 'guest_guard.dart'; // 🚀 IMPORT TRẠM GÁC
import 'notification_bottom_sheet.dart'; // 🚀 IMPORT BẢNG THÔNG BÁO

class CinemaSelectionPage extends StatefulWidget {
  final Movie movie;

  const CinemaSelectionPage({super.key, required this.movie});

  @override
  State<CinemaSelectionPage> createState() => _CinemaSelectionPageState();
}

class _CinemaSelectionPageState extends State<CinemaSelectionPage> {
  final Color primaryBlue = Colors.blue.shade700;
  final Color navyBlue = Colors.blue.shade900;

  // ✅ ĐƯA BIẾN IP LÊN ĐÂY ĐỂ QUẢN LÝ TẬP TRUNG
  final String apiBaseUrl = 'http://10.173.120.41:3000';

  bool _isRefreshing = false;

  int _selectedDateIndex = 0;
  int _selectedTimeIndex = 0;
  int _selectedBrandIndex = 0;
  
  // ✅ ĐỒNG BỘ QUẢN LÝ TỈNH THÀNH BẰNG API
  List<CityModel> _cities = [];
  CityModel? _selectedCity;
  Position? _currentPosition;
  bool _isLoadingCities = true;

  // ==========================================
  // 🚀 BIẾN LƯU TRỮ THÔNG BÁO
  // ==========================================
  List<dynamic> _notifications = [];
  int get unreadCount => _notifications.where((n) => n['IsRead'] == 0).length;

  late List<Map<String, String>> _dates;

  @override
  void initState() {
    super.initState();
    _dates = _generateDates(); 
    _fetchCities(); 
    context.read<MovieBloc>().add(GetCinemasByBrandEvent('', random: false));
    _autoFetchLocation();
    _fetchNotifications(); // 🚀 Gọi tải chuông thông báo
  }

  // ==========================================
  // 🚀 HÀM XỬ LÝ THÔNG BÁO
  // ==========================================
  Future<void> _fetchNotifications() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return; 
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/users/${user.id}/notifications'));
      if (res.statusCode == 200) {
        if (mounted) setState(() => _notifications = json.decode(res.body));
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

  // =====================================================
  // HÀM LẤY TỈNH THÀNH (ĐỒNG BỘ TỪ MENU)
  // =====================================================
  Future<void> _fetchCities() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/cities'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _cities = data.map((e) => CityModel.fromJson(e)).toList();
            if (_cities.isNotEmpty) {
              _selectedCity = _cities.first; 
            }
            _isLoadingCities = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải Cities: $e");
      setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _autoFetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return; 

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _selectedCity = null; // Tắt tỉnh thành tĩnh nếu có GPS
        });
      }
    } catch (e) {
      debugPrint("Lỗi Auto GPS: $e");
    }
  }

  Future<void> _onRefresh() async {
    // Nếu đang trong quá trình refresh rồi thì chặn lại, không cho gọi trùng lặp
    if (_isRefreshing) return; 
    
    setState(() => _isRefreshing = true); // Bật cờ khóa

    try {
      // 1. Gọi API tải lại danh sách Tỉnh/Thành phố trước
      await _fetchCities();
      await _fetchNotifications(); // 🚀 Cập nhật cả thông báo khi kéo refresh

      if (mounted) {
        // =======================================================
        // 🔥 SỬA QUAN TRỌNG: LUÔN TẢI LẠI TOÀN BỘ RẠP (TRUYỀN '')
        // =======================================================
        context.read<MovieBloc>().add(GetCinemasByBrandEvent(
          '', // Lấy tất cả rạp
          random: false,
        ));
      }

      // 3. Tạo một khoảng trễ 800ms để luồng API của BLoC 
      await Future.delayed(const Duration(milliseconds: 800));
      
    } catch (e) {
      debugPrint("Lỗi xảy ra khi làm mới dữ liệu: $e");
    } finally {
      // Tắt cờ loading để giải phóng trạng thái màn hình
      if (mounted) setState(() => _isRefreshing = false); 
    }
  }

  List<Map<String, String>> _generateDates() {
    List<Map<String, String>> generatedDates = [];
    DateTime now = DateTime.now(); 

    for (int i = 0; i < 14; i++) {
      DateTime targetDate = now.add(Duration(days: i));
      String dateString = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}';
      String dayLabel;
      if (i == 0) {
        dayLabel = 'Hôm nay';
      } else {
        switch (targetDate.weekday) {
          case 1: dayLabel = 'Thứ 2'; break;
          case 2: dayLabel = 'Thứ 3'; break;
          case 3: dayLabel = 'Thứ 4'; break;
          case 4: dayLabel = 'Thứ 5'; break;
          case 5: dayLabel = 'Thứ 6'; break;
          case 6: dayLabel = 'Thứ 7'; break;
          case 7: dayLabel = 'CN'; break;
          default: dayLabel = '';
        }
      }
      generatedDates.add({'date': dateString, 'day': dayLabel});
    }
    return generatedDates;
  }

  final List<String> _times = ['Tất cả', '9:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00', '18:00 - 23:59'];

  // ✅ ĐÃ THÊM 3 RẠP MỚI VÀO BỘ LỌC
  final List<Map<String, dynamic>> _brands = [
    {'name': 'Đề xuất', 'image': 'assets/dexuat.png', 'isCurated': true, 'databaseName': ''},
    {'name': 'CGV', 'image': 'assets/cgv1.png', 'databaseName': 'CGV'},
    {'name': 'Lotte', 'image': 'assets/lotte.png', 'databaseName': 'Lotte'},
    {'name': 'Galaxy', 'image': 'assets/galaxy.png', 'databaseName': 'Galaxy'},
    {'name': 'BHD Star', 'image': 'assets/bhd.png', 'databaseName': 'BHD'},
    {'name': 'Cinestar', 'image': 'assets/cinestar.png', 'databaseName': 'Cinestar'},
    {'name': 'Mega GS', 'image': 'assets/megags.png', 'databaseName': 'MegaGS'},
    {'name': 'DCine', 'image': 'assets/dcine.png', 'databaseName': 'DCine'},
    {'name': 'Beta', 'image': 'assets/betacinema.png', 'databaseName': 'Beta'},
    {'name': 'AEON BETA', 'image': 'assets/aeonbeta.png', 'databaseName': 'AEONBETA'},
  ];

  // ✅ CHỈ ĐỔI UI, KHÔNG GỌI API NỮA
  void _handleBrandSelection(int index) {
    setState(() => _selectedBrandIndex = index);
  }

  // ✅ HÀM LỌC Y CHANG MENU PAGE
  List<Cinema> _filterCinemas(List<Cinema> allCinemas) {
    List<Cinema> filtered = allCinemas;
    final brandItem = _brands[_selectedBrandIndex];
    
    if (brandItem['isCurated'] != true) {
      final targetBrand = brandItem['databaseName'].toString().toLowerCase().replaceAll(' ', '');
      
      filtered = filtered.where((cinema) {
        final cName = cinema.name.toLowerCase().replaceAll(' ', '');
        
        // ========================================================
        // 🔥 XỬ LÝ LỖI XUNG ĐỘT TÊN GIỮA "BETA" VÀ "AEON BETA"
        // ========================================================
        if (targetBrand == 'beta') {
          // Chỉ lấy những rạp có chữ 'beta' NHƯNG KHÔNG CÓ chữ 'aeon'
          return cName.contains('beta') && !cName.contains('aeon');
        }
        
        // Các rạp khác lọc bình thường
        return cName.contains(targetBrand);
      }).toList();
      
    } else {
      filtered = filtered.take(6).toList(); 
    }
    return filtered;
  }
  // =====================================================
  // ✅ TÍNH KHOẢNG CÁCH BẰNG TỌA ĐỘ THẬT
  // =====================================================
  Future<String> _getDistanceTextAsync(double cinLat, double cinLng) async {
    double? userLat;
    double? userLng;

    if (_currentPosition != null) {
      userLat = _currentPosition!.latitude;
      userLng = _currentPosition!.longitude;
    } else if (_selectedCity != null) {
      userLat = _selectedCity!.latitude;
      userLng = _selectedCity!.longitude;
    }

    if (userLat != null && userLng != null) {
      try {
        final url = 'http://router.project-osrm.org/route/v1/driving/$userLng,$userLat;$cinLng,$cinLat?overview=false';
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            double distanceMeters = (data['routes'][0]['distance'] as num).toDouble();
    return "${(distanceMeters / 1000).toStringAsFixed(1)} km";
          }
        }
      } catch (e) {
        debugPrint("Lỗi OSRM: $e");
      }

      double straightDistanceMeters = Geolocator.distanceBetween(userLat, userLng, cinLat, cinLng);
      return "${((straightDistanceMeters / 1000) * 1.3).toStringAsFixed(1)} km";
    }
    return "- km"; 
  }

  // ✅ ĐỒNG BỘ HÀM TÁCH QUẬN
  String _extractDistrict(String address) {
    final parts = address.split(',');
    for (var part in parts.reversed) {
      final p = part.trim();
      final lowerP = p.toLowerCase();
      if (lowerP.startsWith('quận') || lowerP.startsWith('huyện') || lowerP.startsWith('tp. thủ đức') || lowerP.startsWith('thành phố thủ đức')) {
        return p; 
      }
    }
    return 'Vị trí rạp'; 
  }

  Future<List<dynamic>> _fetchRealShowtimes(String cinemaId) async {
    try {
      String rawDate = _dates[_selectedDateIndex]['date']!; 
      int year = DateTime.now().year;
      String formattedDate = "$year-${rawDate.split('/')[1]}-${rawDate.split('/')[0]}"; 

      // ✅ CHUYỂN SANG DÙNG BIẾN apiBaseUrl
      String url = '$apiBaseUrl/api/showtimes?movie_id=${widget.movie.id}&cinema_id=$cinemaId&date=$formattedDate';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body); 
      }
    } catch (e) {
      debugPrint('Lỗi gọi API suất chiếu: $e');
    }
    return []; 
  }

  Future<void> _openGoogleMaps(String cinemaName, String address) async {
    final query = Uri.encodeComponent('$cinemaName $address');
    final url = Uri.parse('http://maps.google.com/?q=$query?q=$query'); 
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở Google Maps.')));
    }
  }

  String _extractTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "12:00";
    try {
      DateTime parsedTime = DateTime.parse(dateTimeStr);
      if (dateTimeStr.endsWith('Z') || dateTimeStr.contains('T')) {
        if (parsedTime.isUtc) {
          parsedTime = parsedTime.add(const Duration(hours: 7));
        } else {
          parsedTime = parsedTime.toUtc().add(const Duration(hours: 7));
        }
      }
      return "${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      try {
        if (dateTimeStr.contains('T')) {
          return dateTimeStr.split('T')[1].substring(0, 5); 
        } else if (dateTimeStr.contains(' ')) {
          return dateTimeStr.split(' ')[1].substring(0, 5); 
        }
      } catch (_) {}
      return "12:00";
    }
  }

  String _calculateEndTime(String startTime) {
    try {
      final parts = startTime.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]) + (widget.movie.duration ?? 120); 
      h += m ~/ 60;
      m = m % 60;
      if (m < 8) m = 0;
      else if (m < 23) m = 15;
      else if (m < 38) m = 30;
      else if (m < 53) m = 45;
      else { m = 0; h += 1; }
      if (h >= 24) h -= 24; 
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), 
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                _buildDateSelector(),
                const SizedBox(height: 4), 
                _buildTimeSelector(),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: navyBlue,
              backgroundColor: Colors.white,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12), 
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                      ),
                      child: _buildBrandSelector(),
                    ),
                    _buildListHeader(),
                    _buildCinemaListBloc(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.movie.title.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue),
              ),
            ),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]), 
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🚀 NÚT CHUÔNG ĐÃ THAY THẾ HEADPHONE
              InkWell(
                onTap: () {
                  GuestGuard.check(context, () {
                    NotificationBottomSheet.show(
                      context: context, 
                      notifications: _notifications, 
                      onMarkAsRead: _markAsRead,
                      primaryColor: navyBlue
                    );
                  });
                },
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_outlined, color: navyBlue, size: 18),
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
                  ),
                ),
              ),
              Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
              InkWell(
                onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.home_outlined, color: navyBlue, size: 18)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 65,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedDateIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedDateIndex = index),
            child: Container(
              width: 70, margin: const EdgeInsets.only(right: 10), 
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                children: [
                  Expanded(flex: 1, child: Center(child: Text(_dates[index]['date']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? primaryBlue : Colors.black87)))),
                  Expanded(flex: 1, child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: isSelected ? primaryBlue : Colors.grey.shade100, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6))),
                    child: Center(child: Text(_dates[index]['day']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade600))),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    return SizedBox(
      height: 35,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _times.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedTimeIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedTimeIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade300, width: 1.2),
              ),
              child: Center(child: Text(_times[index], style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandSelector() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          bool isSelected = _selectedBrandIndex == index;
          return GestureDetector(
            onTap: () => _handleBrandSelection(index),
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade200, width: 2),
                      boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0), 
                        child: Image.asset(brand['image'], width: 40, height: 40, fit: BoxFit.contain)
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(brand['name'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? primaryBlue : Colors.grey.shade600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListHeader() {
    return BlocBuilder<MovieBloc, MovieState>(
      builder: (context, state) {
        int cinemaCount = 0;
        final brandItem = _brands[_selectedBrandIndex];
        
        // ✅ SỬA ĐOẠN NÀY: Đếm số rạp sau khi lọc
        if (state is CinemasLoaded) {
          cinemaCount = _filterCinemas(state.cinemas).length; 
        }
        
        String headerTitle = brandItem['isCurated'] == true ? "Rạp đề xuất" : "Chọn Rạp";
        String displayCity = _currentPosition != null ? "Vị trí của tôi" : (_selectedCity?.name ?? "Chọn khu vực");
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$headerTitle ($cinemaCount)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              OutlinedButton.icon(
                onPressed: _showLocationPicker, 
                icon: Icon(Icons.gps_fixed, size: 16, color: primaryBlue),
                label: Text(displayCity, style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                  side: BorderSide(color: primaryBlue), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ BẢNG CHỌN TỈNH THÀNH (ĐỒNG BỘ API TỪ MENU)
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9, 
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        child: TextField(
                          decoration: InputDecoration(
                            icon: Icon(Icons.search, color: Colors.grey.shade500),
                            hintText: 'Tìm kiếm tỉnh, thành phố...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text("Hủy", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.my_location, color: primaryBlue),
                title: Text("Sử dụng vị trí hiện tại của tôi", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context); 
                  try {
                    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng bật GPS trên điện thoại!')));
                      await Geolocator.openLocationSettings();
                      return;
                    }

                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn đã từ chối quyền vị trí!')));
                        return; 
                      }
                    }

                    if (permission == LocationPermission.deniedForever) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quyền vị trí bị chặn vĩnh viễn. Hãy mở Cài đặt để cấp quyền!')));
                      return;
                    }

                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang lấy tọa độ GPS...', style: TextStyle(color: primaryBlue)), backgroundColor: Colors.white, duration: const Duration(seconds: 1)));
                    
                    Position position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                      timeLimit: const Duration(seconds: 10),
                    );
                    
                    if (mounted) {
                      setState(() {
                        _currentPosition = position;
                        _selectedCity = null; 
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vị trí thành công!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    debugPrint("Lỗi GPS: $e");
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lấy GPS: $e')));
                  }
                },
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: _isLoadingCities 
                  ? Center(child: CircularProgressIndicator(color: primaryBlue))
                  : ListView.separated(
                  itemCount: _cities.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    bool isSelected = _selectedCity?.id == city.id && _currentPosition == null;
                    return ListTile(
                      title: Text(city.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? primaryBlue : Colors.black87)),
                      trailing: isSelected ? Icon(Icons.check, color: primaryBlue) : null,
                      onTap: () {
                        setState(() {
                          _selectedCity = city;
                          _currentPosition = null; 
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ ĐỒNG BỘ LOGO (THÊM 3 RẠP MỚI)
  String _getLogoForCinema(String cinemaName) {
    String nameLower = cinemaName.toLowerCase();
    if (nameLower.contains('cgv')) return 'assets/cgv1.png';
    if (nameLower.contains('lotte')) return 'assets/lotte.png';
    if (nameLower.contains('galaxy')) return 'assets/galaxy.png';
    if (nameLower.contains('bhd')) return 'assets/bhd.png';
    if (nameLower.contains('cinestar')) return 'assets/cinestar.png';
    if (nameLower.contains('mega gs') || nameLower.contains('megags')) return 'assets/megags.png';
    if (nameLower.contains('dcine')) return 'assets/dcine.png';
    if (nameLower.contains('aeon beta') || nameLower.contains('aeonbeta')) return 'assets/aeonbeta.png';
    if (nameLower.contains('beta')) return 'assets/betacinema.png';
    return 'assets/dexuat.png'; 
  }

  Widget _buildCinemaListBloc() {
    return BlocBuilder<MovieBloc, MovieState>(
      builder: (context, state) {
        if (state is CinemasLoading || _isLoadingCities) return Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: primaryBlue)));
        if (state is CinemasError) return Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(state.message, style: const TextStyle(color: Colors.red))));
        
        if (state is CinemasLoaded) {
          // ✅ LẤY DANH SÁCH TỪ HÀM LỌC TRƯỚC KHI VẼ
          final filteredCinemas = _filterCinemas(state.cinemas);
          
          if (filteredCinemas.isEmpty) return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text("Hôm nay rạp này chưa có suất chiếu.")));
          
          return Column(
            children: filteredCinemas.map((cinema) {
              return _buildCinemaCard(cinema, filteredCinemas.indexOf(cinema) == 0);
            }).toList(),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
// ✅ SỬA CARD CHUẨN UX: TRUYỀN OBJECT CINEMA ĐỂ LẤY TỌA ĐỘ THẬT
Widget _buildCinemaCard(Cinema cinema, bool expand) {
    String correctLogo = _getLogoForCinema(cinema.name);
    String district = _extractDistrict(cinema.address);

    return Container(
      // =========================================================
      // 🔥 CHÈN VALUEKEY VÀO ĐÂY ĐỂ TRỊ BỆNH "THẢ TIM LÂY LAN"
      // =========================================================
      key: ValueKey('cinema_${cinema.id}'),

      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))] 
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expand,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          iconColor: Colors.black87, collapsedIconColor: Colors.black87,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6), 
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)), 
                child: Image.asset(correctLogo, width: 45, height: 45, fit: BoxFit.contain)
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(cinema.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Color(0xFF2F2F2F), height: 1.0)),
                    ),
                    const SizedBox(height: 4),
                    // ✅ GOM QUẬN VÀ KM (BẢN TỐI ƯU HEIGHT: 1.0)
                    FutureBuilder<String>(
                      future: _getDistanceTextAsync(cinema.latitude, cinema.longitude),
                      builder: (context, snapshot) {
                        String dist = snapshot.data ?? "Đang tính...";
                        return Text("$district • $dist", style: TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.w600, height: 1.0));
                      }
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // =========================================================
              // 🔥 GẮN VALUEKEY CHO NÚT THẢ TIM ĐỂ NÓ RESET THEO TỪNG RẠP
              // =========================================================
              FavoriteButtonWidget(
                key: ValueKey('fav_${cinema.id}'),
                cinemaId: cinema.id.toString(), 
                cinemaName: cinema.name, 
                primaryBlue: primaryBlue, 
                apiBaseUrl: apiBaseUrl
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Colors.grey.shade100, thickness: 1.5),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Expanded(child: Text(cinema.address, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4))), 
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _openGoogleMaps(cinema.name, cinema.address),
                        child: Text("Tìm đường", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline)),
                      )
                    ]
                  ),
                  const SizedBox(height: 16),
                  
                  // ========================================================
                  // ✅ BẮT ĐẦU PHẦN TỰ ĐỘNG GOM NHÓM ĐỊNH DẠNG PHIM
                  // ========================================================
                  FutureBuilder<List<dynamic>>(
                    future: _fetchRealShowtimes(cinema.id.toString()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: primaryBlue));
                      }
                      
                      List<dynamic> filteredShowtimes = [];
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        filteredShowtimes = snapshot.data!.where((show) {
                          if (_selectedTimeIndex == 0) return true; 
                          
                          String startStr = _extractTime(show['StartTime']?.toString() ?? show['time']?.toString());
                          int hour = int.tryParse(startStr.split(':')[0]) ?? 0;
                          
                          if (_selectedTimeIndex == 1 && hour >= 9 && hour < 12) return true;
                          if (_selectedTimeIndex == 2 && hour >= 12 && hour < 15) return true;
                          if (_selectedTimeIndex == 3 && hour >= 15 && hour < 18) return true;
                          if (_selectedTimeIndex == 4 && hour >= 18 && hour <= 23) return true;
                          
                          return false; 
                        }).toList();
                      }

                      if (filteredShowtimes.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text("Hôm nay chưa có suất chiếu nào được cập nhật trên hệ thống.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        );
                      }

                      // 1. TẠO MAP ĐỂ GOM NHÓM SUẤT CHIẾU THEO ĐỊNH DẠNG (movie_format)
                      Map<String, List<dynamic>> groupedShowtimes = {};
                      
                      for (var show in filteredShowtimes) {
                        // Bắt cả 2 trường hợp viết thường hoặc viết hoa (khớp với SQL của bạn)
                        String format = show['movie_format']?.toString() ?? show['MovieFormat']?.toString() ?? '2D Phụ đề';
                        if (format.trim().isEmpty) format = '2D Phụ đề'; // Sơ cua nếu dữ liệu bị rỗng
                        
                        if (!groupedShowtimes.containsKey(format)) {
                          groupedShowtimes[format] = [];
                        }
                        groupedShowtimes[format]!.add(show);
                      }

                      // 2. VẼ GIAO DIỆN TỪNG CỤM ĐỊNH DẠNG
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: groupedShowtimes.entries.map((entry) {
                          String formatName = entry.key; // Tên định dạng (VD: IMAX, 2D Premium)
                          List<dynamic> shows = entry.value; // Danh sách suất chiếu của định dạng đó

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0), // Khoảng cách giữa các cụm
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // TIÊU ĐỀ ĐỊNH DẠNG PHIM
                                Text(
                                  formatName, 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)
                                ),
                                const SizedBox(height: 12),
                                // DANH SÁCH GIỜ CHIẾU
                                Wrap(
                                  spacing: 12, runSpacing: 12,
                                  children: shows.map((show) => _buildShowtimeButton(show, cinema.name)).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }
                  )
                  // ========================================================
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildShowtimeButton(dynamic show, String cinemaName) {
    String start = _extractTime(show['StartTime']?.toString() ?? show['time']?.toString());
    String end = show['EndTime'] != null ? _extractTime(show['EndTime'].toString()) : _calculateEndTime(start); 
    int availableSeats = int.tryParse(show['AvailableSeats']?.toString() ?? '100') ?? 100;
    int totalSeats = int.tryParse(show['TotalSeats']?.toString() ?? '200') ?? 200;
    
    int showtimeId = int.tryParse(show['ShowtimeID']?.toString() ?? '0') ?? 0;
    bool isCinetour = show['IsCinetour'] == 1 || show['IsCinetour'] == true || show['isCinetour'] == true;
    bool isAlmostFull = availableSeats < 20;
    String selectedDateString = "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']}";
    final rawPrice = show['Price']?.toString() ?? show['price']?.toString() ?? '85000';
    final parsedPrice = double.tryParse(rawPrice)?.toInt() ?? 85000;
    String format = show['movie_format']?.toString() ?? show['MovieFormat']?.toString() ?? '2D Phụ đề';

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeatBookingPage(
        movie: widget.movie,
        cinemaName: cinemaName, 
        roomCapacity: totalSeats,
        selectedDate: selectedDateString, 
        selectedTime: "$start - $end",
        showtimeId: showtimeId,  
        roomName: show['RoomName']?.toString() ?? "Phòng chiếu", 
        basePrice: parsedPrice,
        movieFormat: format,
      ))),
      child: Container(
        width: 105, 
        decoration: BoxDecoration(
          color: isAlmostFull ? Colors.orange.shade50 : Colors.white, 
          borderRadius: BorderRadius.circular(8), 
          border: Border.all(color: isAlmostFull ? Colors.orange.shade300 : Colors.grey.shade300, width: 1.2)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCinetour)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade200, Colors.blue.shade50]),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6))
                ),
                child: Text("CINETOUR", textAlign: TextAlign.center, style: TextStyle(color: navyBlue, fontSize: 10, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1.2)),
              ),
            
            Padding(
              padding: EdgeInsets.fromLTRB(8, isCinetour ? 8 : 12, 8, 8),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      text: start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      children: [TextSpan(text: " ~$end", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal))],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("$availableSeats/$totalSeats ghế", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAlmostFull ? Colors.deepOrange : Colors.green.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoriteButtonWidget extends StatefulWidget {
  final String cinemaId;
  final String cinemaName;
  final Color primaryBlue;
  final String apiBaseUrl;

  const FavoriteButtonWidget({super.key, required this.cinemaId, required this.cinemaName, required this.primaryBlue, required this.apiBaseUrl});

  @override
  State<FavoriteButtonWidget> createState() => _FavoriteButtonWidgetState();
}

class _FavoriteButtonWidgetState extends State<FavoriteButtonWidget> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus(); // Gọi kiểm tra khi vừa vẽ nút
  }

  Future<void> _checkFavoriteStatus() async {
    final user = UserManager.instance.currentUser;
    int userId = user?.id ?? 1;
    try {
      final response = await http.get(Uri.parse('${widget.apiBaseUrl}/api/favorites/cinema/check?user_id=$userId&cinema_id=${widget.cinemaId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => isFavorite = data['isFavorite']);
      }
    } catch (e) {
      debugPrint('Lỗi check favorite cinema: $e');
    }
  }

  void _toggleFavorite() async {
    final user = UserManager.instance.currentUser;
    int userId = user?.id ?? 1;
    
    setState(() { isFavorite = !isFavorite; });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isFavorite ? 'Đã thêm ${widget.cinemaName} vào rạp yêu thích ❤️' : 'Đã bỏ yêu thích rạp này.', style: const TextStyle(color: Colors.white)), 
      backgroundColor: widget.primaryBlue, 
      duration: const Duration(seconds: 2), 
      behavior: SnackBarBehavior.floating, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
    ));
    
    try {
      // Gọi API cập nhật vào Database
      await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/favorites/cinema/toggle'), 
        headers: {'Content-Type': 'application/json'}, 
        body: json.encode({'cinema_id': widget.cinemaId, 'is_favorite': isFavorite, 'user_id': userId})
      );
    } catch (e) { 
      debugPrint('Lỗi toggle favorite: $e'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border_rounded, size: 20, color: isFavorite ? Colors.red : const Color(0xFF3A3A3A)),
      ),
    );
  }
}