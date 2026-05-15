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

class CinemaSelectionPage extends StatefulWidget {
  final Movie movie;

  const CinemaSelectionPage({super.key, required this.movie});

  @override
  State<CinemaSelectionPage> createState() => _CinemaSelectionPageState();
}

class _CinemaSelectionPageState extends State<CinemaSelectionPage> {
  final Color primaryBlue = Colors.blue.shade700;
  final Color navyBlue = Colors.blue.shade900;

  int _selectedDateIndex = 0;
  int _selectedTimeIndex = 0;
  int _selectedBrandIndex = 0;
  
  // BIẾN LƯU THÀNH PHỐ & VỊ TRÍ GPS
  String _selectedCity = "TP.HCM"; 
  Position? _currentPosition;

  late List<Map<String, String>> _dates;

  // TỌA ĐỘ TRUNG TÂM CÁC TỈNH THÀNH
  final Map<String, Map<String, double>> _cityCoordinates = {
    'TP.HCM': {'lat': 10.762622, 'lng': 106.660172},
    'Bà Rịa - Vũng Tàu': {'lat': 10.496950, 'lng': 107.168480},
    'Bình Dương': {'lat': 11.166667, 'lng': 106.666667},
    'Đồng Nai': {'lat': 10.933333, 'lng': 107.000000},
    'Tây Ninh': {'lat': 11.300000, 'lng': 106.100000},
    'Long An': {'lat': 10.533333, 'lng': 106.666667},
  };

  // TỌA ĐỘ CÁC RẠP ĐỂ TÍNH KHOẢNG CÁCH (KM)
  final Map<String, Map<String, double>> _cinemaCoordinates = {
    'CGV Sư Vạn Hạnh': {'lat': 10.771, 'lng': 106.668},
    'Galaxy Nguyễn Du': {'lat': 10.774, 'lng': 106.695},
    'CGV Landmark 81': {'lat': 10.795, 'lng': 106.721},
    'CGV Hùng Vương Plaza': {'lat': 10.755, 'lng': 106.665},
    'CGV Vincom Đồng Khởi': {'lat': 10.777, 'lng': 106.702},
    'Lotte Cinema Nam Sài Gòn': {'lat': 10.733, 'lng': 106.700},
    'Lotte Cinema Gò Vấp': {'lat': 10.838, 'lng': 106.668},
    'Lotte Cinema Cộng Hòa': {'lat': 10.801, 'lng': 106.654},
    'Galaxy Tân Bình': {'lat': 10.793, 'lng': 106.645},
    'Galaxy Kinh Dương Vương': {'lat': 10.745, 'lng': 106.625},
    'BHD Star 3/2': {'lat': 10.771, 'lng': 106.678},
    'BHD Star Thảo Điền': {'lat': 10.802, 'lng': 106.732},
    'BHD Star Quang Trung': {'lat': 10.835, 'lng': 106.630},
    'Cinestar Satra Q6': {'lat': 10.748, 'lng': 106.634},
    'Mega GS Cao Thắng': {'lat': 10.768, 'lng': 106.681},
  };

  @override
  void initState() {
    super.initState();
    _dates = _generateDates(); 
    context.read<MovieBloc>().add(GetCinemasByBrandEvent('', random: true));
    
    // ✅ TỰ ĐỘNG QUÉT GPS NGAY KHI VỪA MỞ TRANG (KHÔNG CẦN BẤM TAY)
    _autoFetchLocation();
  }

  // ✅ HÀM TỰ ĐỘNG LẤY VỊ TRÍ
  // ✅ HÀM TỰ ĐỘNG LẤY VỊ TRÍ CÓ BẮT LỖI
  Future<void> _autoFetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return; 

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      }

      // Thêm giới hạn 10s để không bị kẹt nếu mạng yếu
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() {
          _selectedCity = "Vị trí của tôi"; 
          _currentPosition = position;      
        });
      }
    } catch (e) {
      debugPrint("Lỗi Auto GPS: $e");
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    final brandItem = _brands[_selectedBrandIndex];
    if (mounted) {
      context.read<MovieBloc>().add(GetCinemasByBrandEvent(
        brandItem['databaseName'],
        random: brandItem['isCurated'] == true,
      ));
    }
  }

  // TẠO DANH SÁCH 14 NGÀY TIẾP THEO FORMAT DD/MM
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

  final List<Map<String, dynamic>> _brands = [
    {'name': 'Đề xuất', 'image': 'assets/dexuat.png', 'isCurated': true, 'databaseName': ''},
    {'name': 'CGV', 'image': 'assets/cgv1.png', 'databaseName': 'CGV'},
    {'name': 'Lotte', 'image': 'assets/lotte.png', 'databaseName': 'Lotte'},
    {'name': 'Galaxy', 'image': 'assets/galaxy.png', 'databaseName': 'Galaxy'},
    {'name': 'BHD Star', 'image': 'assets/bhd.png', 'databaseName': 'BHD'},
    {'name': 'Cinestar', 'image': 'assets/cinestar.png', 'databaseName': 'Cinestar'},
    {'name': 'Mega GS', 'image': 'assets/megags.png', 'databaseName': 'MegaGS'},
  ];

  void _handleBrandSelection(int index) {
    setState(() => _selectedBrandIndex = index);
    final brandItem = _brands[index];
    context.read<MovieBloc>().add(GetCinemasByBrandEvent(
      brandItem['databaseName'],
      random: brandItem['isCurated'] == true,
    ));
  }

  // TÍNH KHOẢNG CÁCH CHÍNH XÁC (KM) TỪ USER ĐẾN RẠP
  // ✅ TÍNH KHOẢNG CÁCH LÁI XE THỰC TẾ BẰNG OSRM API (MIỄN PHÍ 100%)
  Future<String> _getDistanceTextAsync(String cinemaName) async {
    double? userLat;
    double? userLng;

    if (_selectedCity == "Vị trí của tôi" && _currentPosition != null) {
      userLat = _currentPosition!.latitude;
      userLng = _currentPosition!.longitude;
    } else if (_cityCoordinates.containsKey(_selectedCity)) {
      userLat = _cityCoordinates[_selectedCity]!['lat'];
      userLng = _cityCoordinates[_selectedCity]!['lng'];
    }

    if (userLat != null && userLng != null && _cinemaCoordinates.containsKey(cinemaName)) {
      double cinLat = _cinemaCoordinates[cinemaName]!['lat']!;
      double cinLng = _cinemaCoordinates[cinemaName]!['lng']!;
      
      try {
        // Gọi API OSRM để tính đường đi thực tế (Lưu ý OSRM nhận Kinh độ trước, Vĩ độ sau)
        final url = 'http://router.project-osrm.org/route/v1/driving/$userLng,$userLat;$cinLng,$cinLat?overview=false';
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            // OSRM trả về khoảng cách lái xe chính xác bằng mét
            double distanceMeters = data['routes'][0]['distance'];
            return "${(distanceMeters / 1000).toStringAsFixed(1)} km";
          }
        }
      } catch (e) {
        debugPrint("Lỗi OSRM: $e");
      }

      // Fallback: Nếu không có mạng hoặc API OSRM quá tải, tự lùi về cách tính cũ
      double straightDistanceMeters = Geolocator.distanceBetween(userLat, userLng, cinLat, cinLng);
      return "${((straightDistanceMeters / 1000) * 1.3).toStringAsFixed(1)} km";
    }
    return "- km"; 
  }

  // GỌI API SHOWTIMES THỰC TẾ
  Future<List<dynamic>> _fetchRealShowtimes(String cinemaId) async {
    try {
      String rawDate = _dates[_selectedDateIndex]['date']!; 
      int year = DateTime.now().year;
      String formattedDate = "$year-${rawDate.split('/')[1]}-${rawDate.split('/')[0]}"; 

      // Gọi vào API Node.js của bạn
      String url = 'https://movie-explorer-be.onrender.com/api/showtimes?movie_id=${widget.movie.id}&cinema_id=$cinemaId&date=$formattedDate';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body); 
      } else {
        debugPrint("API trả về lỗi: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Lỗi gọi API suất chiếu: $e');
    }
    return []; 
  }

  // MỞ ỨNG DỤNG GOOGLE MAPS TÌM ĐƯỜNG
  Future<void> _openGoogleMaps(String cinemaName, String address) async {
    final query = Uri.encodeComponent('$cinemaName $address');
    final url = Uri.parse('http://maps.google.com/?q=$query?q=$query'); 
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở Google Maps.')));
    }
  }

  // BÓC TÁCH GIỜ TỪ CHUỖI DATETIME
  // ✅ ÉP CỨNG MÚI GIỜ VIỆT NAM (GMT+7) BẤT CHẤP CÀI ĐẶT CỦA ĐIỆN THOẠI MÁY ẢO
  String _extractTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "12:00";
    try {
      // Ép Flutter nhận diện đây là chuỗi ngày giờ
      DateTime parsedTime = DateTime.parse(dateTimeStr);
      
      // Nếu API trả về đuôi 'Z' (chuẩn giờ quốc tế UTC), ta cộng cứng 7 tiếng
      if (dateTimeStr.endsWith('Z') || dateTimeStr.contains('T')) {
        // Nếu DateTime đang ở UTC, cộng 7 tiếng để ra Việt Nam
        if (parsedTime.isUtc) {
          parsedTime = parsedTime.add(const Duration(hours: 7));
        } else {
          // Nếu nó lỡ parse ra local của máy ảo, ta ép nó về UTC trước rồi mới cộng 7
          parsedTime = parsedTime.toUtc().add(const Duration(hours: 7));
        }
      }
      
      // Trả về định dạng HH:mm chuẩn xác
      return "${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      // Cứu cánh cuối cùng nếu format lạ: Cắt chuỗi thủ công
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

  // TÍNH TOÁN GIỜ KẾT THÚC PHIM
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
              InkWell(
                onTap: () {},
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.headset_mic_outlined, color: navyBlue, size: 18)),
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
        if (state is CinemasLoaded) cinemaCount = state.cinemas.length; 
        String headerTitle = brandItem['isCurated'] == true ? "Rạp đề xuất" : "Chọn Rạp";
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$headerTitle ($cinemaCount)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              OutlinedButton.icon(
                onPressed: _showLocationPicker, 
                icon: Icon(Icons.gps_fixed, size: 16, color: primaryBlue),
                label: Text(_selectedCity, style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
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

  void _showLocationPicker() {
    final List<String> cities = ['TP.HCM', 'Bà Rịa - Vũng Tàu', 'Bình Dương', 'Đồng Nai', 'Tây Ninh', 'Long An'];

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
              
              // ✅ NÚT LẤY GPS HIỆN TẠI (ĐÃ CÓ THÔNG BÁO LỖI VÀ TIMEOUT)
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
                    
                    // Chờ tối đa 10s, nếu không bắt được sóng vệ tinh thì báo lỗi
                    Position position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                      timeLimit: const Duration(seconds: 10),
                    );
                    
                    if (mounted) {
                      setState(() {
                        _selectedCity = "Vị trí của tôi";
                        _currentPosition = position;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã cập nhật vị trí thành công!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    debugPrint("Lỗi GPS: $e");
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lấy GPS (Hãy thử ra nơi thoáng đãng): $e')));
                  }
                },
              ),
              Divider(height: 1, color: Colors.grey.shade200),

              Expanded(
                child: ListView.separated(
                  itemCount: cities.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    bool isSelected = _selectedCity == cities[index];
                    return ListTile(
                      title: Text(cities[index], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? primaryBlue : Colors.black87)),
                      trailing: isSelected ? Icon(Icons.check, color: primaryBlue) : null,
                      onTap: () {
                        setState(() {
                          _selectedCity = cities[index];
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

  String _getLogoForCinema(String cinemaName) {
    String nameLower = cinemaName.toLowerCase();
    if (nameLower.contains('cgv')) return 'assets/cgv1.png';
    if (nameLower.contains('lotte')) return 'assets/lotte.png';
    if (nameLower.contains('galaxy')) return 'assets/galaxy.png';
    if (nameLower.contains('bhd')) return 'assets/bhd.png';
    if (nameLower.contains('cinestar')) return 'assets/cinestar.png';
    if (nameLower.contains('mega gs') || nameLower.contains('megags')) return 'assets/megags.png';
    return 'assets/dexuat.png'; 
  }

  Widget _buildCinemaListBloc() {
    return BlocBuilder<MovieBloc, MovieState>(
      builder: (context, state) {
        if (state is CinemasLoading) return Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: primaryBlue)));
        if (state is CinemasError) return Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(state.message, style: const TextStyle(color: Colors.red))));
        if (state is CinemasLoaded) {
          final cinemas = state.cinemas;
          if (cinemas.isEmpty) return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text("Hôm nay rạp này chưa có suất chiếu.")));
          return Column(
            children: cinemas.map((cinema) {
              String correctLogo = _getLogoForCinema(cinema.name);
              return _buildCinemaCard(cinema.id.toString(), cinema.name, cinema.address, correctLogo, cinemas.indexOf(cinema) == 0);
            }).toList(),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

Widget _buildCinemaCard(String cinemaId, String name, String address, String logo, bool expand) {
    

    return Container(
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
                child: Image.asset(logo, width: 45, height: 45, fit: BoxFit.contain)
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  // DÁN ĐOẠN NÀY ĐÈ VÀO CHỖ CŨ:
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 4),
                    
                    // DÙNG FUTURE BUILDER ĐỂ CHỜ API TÍNH XONG KM SẼ HIỆN RA
                    FutureBuilder<String>(
                      future: _getDistanceTextAsync(name),
                      builder: (context, snapshot) {
                        String dist = snapshot.data ?? "Đang tính...";
                        return Text("Cách bạn $dist", style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
                      }
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FavoriteButtonWidget(cinemaId: cinemaId, cinemaName: name, primaryBlue: primaryBlue),
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
                      Expanded(child: Text(address, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4))), 
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _openGoogleMaps(name, address),
                        child: Text("Tìm đường", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline)),
                      )
                    ]
                  ),
                  const SizedBox(height: 16),
                  const Text("2D Phụ đề", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 12),
                  
                  FutureBuilder<List<dynamic>>(
                    future: _fetchRealShowtimes(cinemaId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: primaryBlue));
                      }
                      
                      // ✅ ĐÃ THÊM LOGIC LỌC THEO GIỜ CHIẾU Ở ĐÂY
                      List<dynamic> filteredShowtimes = [];
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        filteredShowtimes = snapshot.data!.where((show) {
                          if (_selectedTimeIndex == 0) return true; // Index 0: Tất cả
                          
                          // Lấy ra số Giờ (Ví dụ: "19:30" -> 19)
                          String startStr = _extractTime(show['StartTime']?.toString() ?? show['time']?.toString());
                          int hour = int.tryParse(startStr.split(':')[0]) ?? 0;
                          
                          // Lọc theo từng khung giờ
                          if (_selectedTimeIndex == 1 && hour >= 9 && hour < 12) return true;
                          if (_selectedTimeIndex == 2 && hour >= 12 && hour < 15) return true;
                          if (_selectedTimeIndex == 3 && hour >= 15 && hour < 18) return true;
                          if (_selectedTimeIndex == 4 && hour >= 18 && hour <= 23) return true;
                          
                          return false; // Không thuộc khung giờ nào thì loại bỏ
                        }).toList();
                      }

                      // Nếu mảng rỗng (Chưa có dữ liệu hoặc đã bị lọc hết)
                      if (filteredShowtimes.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text("Hôm nay chưa có suất chiếu nào được cập nhật trên hệ thống.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        );
                      }

                      // Vẽ các nút suất chiếu đã vượt qua bộ lọc
                      return Wrap(
                        spacing: 12, runSpacing: 12,
                        children: filteredShowtimes.map((show) => _buildShowtimeButton(show, name)).toList(),
                      );
                    }
                  )
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
    
    // ✅ 1. LẤY ID SUẤT CHIẾU TỪ DATABASE
    int showtimeId = int.tryParse(show['ShowtimeID']?.toString() ?? '0') ?? 0;
    
    bool isCinetour = show['IsCinetour'] == 1 || show['IsCinetour'] == true || show['isCinetour'] == true;

    bool isAlmostFull = availableSeats < 20;
    String selectedDateString = "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']}";

    return InkWell(
      // ✅ 2. TRUYỀN THÊM BIẾN showtimeId VÀO ĐỂ FIX LỖI ĐỎ
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeatBookingPage(
        movie: widget.movie,
        cinemaName: cinemaName, 
        roomCapacity: totalSeats,
        selectedDate: selectedDateString, 
        selectedTime: "$start - $end",
        showtimeId: showtimeId,     
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

  const FavoriteButtonWidget({super.key, required this.cinemaId, required this.cinemaName, required this.primaryBlue});

  @override
  State<FavoriteButtonWidget> createState() => _FavoriteButtonWidgetState();
}

class _FavoriteButtonWidgetState extends State<FavoriteButtonWidget> {
  bool isFavorite = false;

  void _toggleFavorite() async {
    setState(() { isFavorite = !isFavorite; });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFavorite ? 'Đã thêm ${widget.cinemaName} vào danh sách yêu thích ❤️' : 'Đã bỏ yêu thích rạp này.', style: const TextStyle(color: Colors.white)), backgroundColor: widget.primaryBlue, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    try {
      final response = await http.post(Uri.parse('https://movie-explorer-be.onrender.com/api/favorites'), headers: {'Content-Type': 'application/json'}, body: json.encode({'cinema_id': widget.cinemaId, 'is_favorite': isFavorite, 'user_id': 1}));
      if (response.statusCode != 200) debugPrint('Lỗi lưu CSDL');
    } catch (e) { debugPrint('Chưa kết nối API Favorite: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 20, color: isFavorite ? Colors.red : Colors.black54),
      ),
    );
  }
}