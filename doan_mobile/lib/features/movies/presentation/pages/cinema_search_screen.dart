import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../../domain/entities/cinema.dart'; 
import '../../data/models/city_model.dart';

// =====================================================
// MÀN HÌNH TÌM KIẾM RẠP (ĐÃ TÁCH FILE & ĐỒNG BỘ UI)
// =====================================================
class CinemaSearchScreen extends StatefulWidget {
  final List<Cinema> allCinemas;

  const CinemaSearchScreen({
    super.key,
    required this.allCinemas,
  });

  @override
  State<CinemaSearchScreen> createState() => _CinemaSearchScreenState();
}

class _CinemaSearchScreenState extends State<CinemaSearchScreen> {
  final Color primaryBlue = Colors.blue.shade600; 
  final String apiBaseUrl = 'http://192.168.1.7:3000'; // ĐỒNG BỘ IP

  String _searchQuery = "";
  int _selectedBrandIndex = 0; 
  final TextEditingController _searchController = TextEditingController();

  // BIẾN QUẢN LÝ TỈNH THÀNH (TỪ API)
  List<CityModel> _cities = [];
  CityModel? _selectedCity;
  Position? _currentPosition;
  bool _isLoadingCities = true;

  // ✅ ĐỒNG BỘ 10 RẠP CHUẨN XÁC
  final List<Map<String, dynamic>> _brands = [
    {'name': 'Đề xuất', 'image': 'assets/dexuat.png', 'databaseName': 'RANDOM', 'isCurated': true},
    {'name': 'CGV', 'image': 'assets/cgv1.png', 'databaseName': 'CGV'},
    {'name': 'Lotte', 'image': 'assets/lotte.png', 'databaseName': 'Lotte'},
    {'name': 'Galaxy', 'image': 'assets/galaxy.png', 'databaseName': 'Galaxy'},
    {'name': 'BHD Star', 'image': 'assets/bhd.png', 'databaseName': 'BHD'},
    {'name': 'Cinestar', 'image': 'assets/cinestar.png', 'databaseName': 'Cinestar'},
    {'name': 'Mega GS', 'image': 'assets/megags.png', 'databaseName': 'MegaGS'},
    {'name': 'DCine', 'image': 'assets/dcine.png', 'databaseName': 'DCine'},
    {'name': 'Beta', 'image': 'assets/betacinema.png', 'databaseName': 'Beta'},
    {'name': 'AEON BETA', 'image': 'assets/aeonbeta.png', 'databaseName': 'AEONBETA'}
  ];

  @override
  void initState() {
    super.initState();
    _fetchCities(); 
    _autoFetchLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =====================================================
  // HÀM LẤY TỈNH THÀNH & TỌA ĐỘ 
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _selectedCity = null; 
        });
      }
    } catch (e) {
      debugPrint('Lỗi Auto GPS: $e');
    }
  }

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
            final distanceMeters = (data['routes'][0]['distance'] as num).toDouble();
            return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
          }
        }
      } catch (e) {
        debugPrint('Lỗi OSRM: $e');
      }

      final straightDistanceMeters = Geolocator.distanceBetween(userLat, userLng, cinLat, cinLng);
      return '${((straightDistanceMeters / 1000) * 1.3).toStringAsFixed(1)} km';
    }

    return '- km';
  }

  // =====================================================
  // CÁC HÀM XỬ LÝ CHUỖI & LOGO ĐỒNG BỘ
  // =====================================================
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

  void _openGoogleMaps(String cinemaName, String address) async {
    final query = Uri.encodeComponent('$cinemaName $address');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query?q=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // =====================================================
  // HÀM LỌC RẠP KẾT HỢP (THANH TÌM KIẾM + LOGO BRAND)
  // =====================================================
  // =====================================================
  // HÀM LỌC RẠP KẾT HỢP (THANH TÌM KIẾM + LOGO BRAND)
  // =====================================================
  List<Cinema> _filterCinemas() {
    List<Cinema> filtered = widget.allCinemas;
    final brandItem = _brands[_selectedBrandIndex];

    // 1. Lọc theo Logo (Brand)
    if (brandItem['isCurated'] != true) {
      final targetBrand = brandItem['databaseName'].toString().toLowerCase().replaceAll(' ', '');
      
      filtered = filtered.where((cinema) {
        final cName = cinema.name.toLowerCase().replaceAll(' ', '');
        
        // ========================================================
        // 🔥 XỬ LÝ LỖI XUNG ĐỘT TÊN GIỮA "BETA" VÀ "AEON BETA"
        // ========================================================
        if (targetBrand == 'beta') {
          // Nếu đang chọn tab Beta, thì tên rạp phải chứa 'beta' VÀ KHÔNG CHỨA 'aeon'
          return cName.contains('beta') && !cName.contains('aeon');
        }
        
        // Các rạp khác lọc bình thường
        return cName.contains(targetBrand);
      }).toList();
    }

    // 2. Lọc theo Thanh Tìm Kiếm (Từ khóa)
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((cinema) {
        final name = cinema.name.toLowerCase();
        final address = cinema.address.toLowerCase();
        return name.contains(_searchQuery) || address.contains(_searchQuery);
      }).toList();
    }

    // 3. Nếu là Đề xuất và không tìm kiếm gì thì chỉ lấy 5 rạp
    if (brandItem['isCurated'] == true && _searchQuery.isEmpty) {
      filtered = filtered.take(5).toList();
    }

    return filtered;
  }

  PreferredSizeWidget _buildAppBar() {
    final Color navyBlue = Colors.blue.shade900;

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
                'CHỌN THEO RẠP', // Đổi chữ thành viết hoa cho sang trọng
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue),
              ),
            ),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight, 
            colors: [Colors.blue.shade300, Colors.blue.shade50]
          ), 
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
                onTap: () {
                  // TODO: Chuyển hướng sang giỏ hàng nếu cần
                },
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                  child: Icon(Icons.shopping_cart_outlined, color: navyBlue, size: 18) // Icon Giỏ hàng
                ),
              ),
              Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
              InkWell(
                onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                  child: Icon(Icons.home_outlined, color: navyBlue, size: 18) // Icon Trang chủ
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterCinemas();
    final brandItem = _brands[_selectedBrandIndex];
    String displayBrandName = brandItem['isCurated'] == true 
        ? "RẠP ĐỀ XUẤT" 
        : brandItem['name'].toString().toUpperCase();

    String displayCity = _currentPosition != null ? "Vị trí của tôi" : (_selectedCity?.name ?? "Chọn khu vực");

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      // ✅ 1. GẮN APPBAR MỚI VÀO ĐÂY
      appBar: _buildAppBar(), 
      body: Column(
        children: [
          // ✅ 2. PHẦN TÌM KIẾM GỌN GÀNG HƠN (Đã bỏ Row chứa nút Back cũ)
          Container(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, const Color(0xFFF5F5F9)], // Đổ màu nối tiếp từ AppBar xuống
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ô TÌM KIẾM
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Tìm rạp phim, địa chỉ...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(Icons.cancel, color: Colors.grey.shade400, size: 18),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(height: 16),
                
                // THANH CHỌN THƯƠNG HIỆU
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: _brands.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var brand = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: _buildBrandPill(idx, brand['name'], brand['image']),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // TIÊU ĐỀ KẾT QUẢ & NÚT CHỌN VỊ TRÍ 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$displayBrandName (${filtered.length})', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: _showLocationPicker,
                  icon: Icon(Icons.location_on, color: primaryBlue, size: 18),
                  label: Text(
                    displayCity.length > 10 ? '${displayCity.substring(0, 10)}...' : displayCity,
                    style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // DANH SÁCH RẠP 
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('Không tìm thấy rạp nào', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      return _buildCinemaCard(filtered[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  // =====================================================
  // GIAO DIỆN TỪNG RẠP (ĐỒNG BỘ 100% TỪ MENU PAGE)
  // =====================================================
  Widget _buildCinemaCard(Cinema cinema) {
    String district = _extractDistrict(cinema.address);

    return GestureDetector(
      // =========================================================
      // 🔥 ĐÃ THÊM VALUEKEY: Khóa định danh chống lỗi tái sử dụng
      // =========================================================
      key: ValueKey(cinema.id),

      onTap: () => Navigator.pop(context, cinema), // Bấm vào trả rạp về trang Đặt Đồ Ăn
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE9E9E9)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(_getLogoForCinema(cinema.name), fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cinema.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Color(0xFF2F2F2F), height: 1.0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<String>(
                          future: _getDistanceTextAsync(cinema.latitude, cinema.longitude),
                          builder: (context, snapshot) {
                            String dist = snapshot.data ?? "Đang tính...";
                            return Text(
                              "$district • $dist",
                              style: TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.w600, height: 1.0),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cinema.address,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.2),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openGoogleMaps(cinema.name, cinema.address),
                    child: Text('Tìm đường', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandPill(int index, String label, String asset) {
    bool active = _selectedBrandIndex == index; 
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBrandIndex = active ? 0 : index; // Bấm lần nữa để tắt (về Đề xuất)
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 66, height: 66,
            padding: const EdgeInsets.all(14), 
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? primaryBlue : Colors.grey.shade300, width: active ? 2.0 : 1.0),
              boxShadow: [if (active) BoxShadow(color: primaryBlue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Image.asset(asset, fit: BoxFit.contain), 
          ),
          const SizedBox(height: 8), 
          Text(
            label, 
            style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.w600, color: active ? primaryBlue : Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BẢNG CHỌN TỈNH THÀNH (ĐỒNG BỘ)
  // =====================================================
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
                        child: const TextField(
                          decoration: InputDecoration(
                            icon: Icon(Icons.search, color: Colors.grey),
                            hintText: 'Tìm kiếm tỉnh, thành phố...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Hủy', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.my_location, color: primaryBlue),
                title: Text('Sử dụng vị trí hiện tại của tôi', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng bật GPS trên điện thoại!')));
                      await Geolocator.openLocationSettings();
                      return;
                    }
                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) return;
                    }
                    if (permission == LocationPermission.deniedForever) return;
                    
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang lấy tọa độ GPS...', style: TextStyle(color: primaryBlue)), backgroundColor: Colors.white, duration: const Duration(seconds: 1)));
                    
                    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10));
                    if (mounted) {
                      setState(() {
                        _currentPosition = position;
                        _selectedCity = null; 
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vị trí thành công!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    debugPrint('Lỗi GPS: $e');
                  }
                },
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: _isLoadingCities 
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                  itemCount: _cities.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    final isSelected = _selectedCity?.id == city.id && _currentPosition == null;
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
}