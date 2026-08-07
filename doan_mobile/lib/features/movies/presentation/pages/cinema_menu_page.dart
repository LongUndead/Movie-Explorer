import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../widgets/scroll_to_top_wrapper.dart';
import '../bloc/movie_bloc.dart';
import '../bloc/movie_event.dart';
import '../bloc/movie_state.dart';
import '../../domain/entities/cinema.dart'; 
import 'cinema_showtimes_page.dart';
import '../../data/models/city_model.dart';
import 'user_manager.dart'; // ✅ ĐÃ THÊM IMPORT USER MANAGER
import 'guest_guard.dart'; // 🚀 IMPORT TRẠM GÁC

class CinemaMenuPage extends StatefulWidget {
  const CinemaMenuPage({super.key});

  @override
  State<CinemaMenuPage> createState() => _CinemaMenuPageState();
}

class _CinemaMenuPageState extends State<CinemaMenuPage> {
  final Color primaryBlue = Colors.blue.shade700;
  final Color navyBlue = Colors.blue.shade900;
  final Color pageBackground = const Color(0xFFF5F5F9);
  
  // ✅ THÊM BIẾN API BASE URL ĐỂ TRUYỀN VÀO NÚT YÊU THÍCH
  final String apiBaseUrl = 'http://192.168.1.7:3000';
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _selectedBrandIndex = 0;
  
  // BIẾN QUẢN LÝ TỈNH THÀNH (ĐỘNG TỪ API)
  List<CityModel> _cities = [];
  CityModel? _selectedCity;
  Position? _currentPosition;
  bool _isLoadingCities = true;

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
    _loadAllCinemas(); 
    _autoFetchLocation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

  void _loadAllCinemas() {
    context.read<MovieBloc>().add(GetCinemasByBrandEvent('', random: false));
  }

  void _selectBrand(int index) {
    setState(() => _selectedBrandIndex = index);
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
            final distanceMeters = data['routes'][0]['distance'];
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

    // XỬ LÝ THANH TÌM KIẾM (Giữ nguyên)
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((cinema) {
        final name = cinema.name.toLowerCase();
        final address = cinema.address.toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }

    return filtered;
  }

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
                      await Geolocator.openLocationSettings();
                      return;
                    }
                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.deniedForever) return;
                    
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) return;
                    }

                    final position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10),
                    );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.3, 
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF64B5F6), Color(0xFFF5F5F9)],
              ),
            ),
          ),
          
          // 🚀 BỌC SCROLL TO TOP WRAPPER VÀO ĐÂY
          ScrollToTopWrapper(
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController, // 🚀 DÙNG CONTROLLER CỦA KHUNG THẦN THÁNH
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 105), 
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildBrandSelector(),
                    const SizedBox(height: 16),
                    
                    Container(
                      constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                      ),
                      child: _buildCinemaListContent(),
                    ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(29),
          boxShadow: [BoxShadow(color: navyBlue.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Tìm rạp phim...',
            hintStyle: TextStyle(color: Color(0xFF9C9C9C), fontSize: 16),
            prefixIcon: Icon(Icons.search, color: Color(0xFF546A84), size: 30),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          onChanged: (value) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildBrandSelector() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _brands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final brand = _brands[index];
          final isSelected = _selectedBrandIndex == index;
          return GestureDetector(
            onTap: () => _selectBrand(index),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 66, height: 66,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isSelected ? primaryBlue : const Color(0xFFE1E1E1), width: isSelected ? 2.6 : 1.3),
                      boxShadow: [BoxShadow(color: isSelected ? primaryBlue.withOpacity(0.12) : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Image.asset(brand['image'] as String, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    brand['name'] as String, maxLines: 2, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, height: 1.05, color: isSelected ? primaryBlue : const Color(0xFF6C6C6C), fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCinemaListContent() {
    return BlocBuilder<MovieBloc, MovieState>(
      builder: (context, state) {
        if (state is CinemasLoading || _isLoadingCities) {
          return const Padding(padding: EdgeInsets.only(top: 50), child: Center(child: CircularProgressIndicator()));
        }
        if (state is CinemasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
          );
        }
        if (state is CinemasLoaded) {
          final filteredCinemas = _filterCinemas(state.cinemas);
          
          if (filteredCinemas.isEmpty) {
            return const Padding(padding: EdgeInsets.only(top: 50), child: Center(child: Text('Không có rạp phù hợp')));
          }

          final brandItem = _brands[_selectedBrandIndex];
          final title = brandItem['isCurated'] == true ? 'Rạp đề xuất' : 'Rạp ${brandItem['name']}';
          String displayCity = _currentPosition != null ? "Vị trí của tôi" : (_selectedCity?.name ?? "Chọn khu vực");

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), 
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: filteredCinemas.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$title (${filteredCinemas.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2E2E2E))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryBlue, width: 1.4)),
                        child: InkWell(
                          onTap: _showLocationPicker,
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gps_fixed, size: 17, color: primaryBlue),
                              const SizedBox(width: 8),
                              Text(displayCity, style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800, fontSize: 13.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final cinema = filteredCinemas[index - 1];
              return _buildCinemaCard(cinema, index - 1);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCinemaCard(Cinema cinema, int index) {
    double lat = cinema.latitude;
    double lng = cinema.longitude;
    String district = _extractDistrict(cinema.address);

    return Container(
      // =========================================================
      // 🔥 CHÈN VALUEKEY VÀO ĐÂY ĐỂ TRỊ BỆNH "THẢ TIM LÂY LAN"
      // =========================================================
      key: ValueKey('cinema_${cinema.id}'),
      
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9E9E9))),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(_getLogoForCinema(cinema.name), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF2F2F2), child: Center(child: Icon(Icons.local_movies_outlined, color: Colors.grey, size: 18)))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown, 
                              alignment: Alignment.centerLeft,
                              child: Text(
                                cinema.name,
                                style: const TextStyle(
                                  fontSize: 15.5, 
                                  fontWeight: FontWeight.w800, 
                                  color: Color(0xFF2F2F2F),
                                  height: 1.0, 
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          
                          // GỌI WIDGET NÚT YÊU THÍCH XỊN VÀO ĐÂY
                          FavoriteButtonWidget(
                            // Đảm bảo widget Favorite được tái tạo (reset) dựa trên id của Rạp mới
                            key: ValueKey('fav_${cinema.id}'), 
                            cinemaId: cinema.id.toString(),
                            cinemaName: cinema.name,
                            primaryBlue: primaryBlue,
                            apiBaseUrl: apiBaseUrl,
                          ),
                          
                          const SizedBox(width: 8),
                          // 🚀 BỌC THÉP: Chặn khách vãng lai tò mò bấm vào xem suất chiếu (tránh làm loạn hệ thống giữ ghế ảo)
                          GestureDetector(
                            onTap: () {
                              GuestGuard.check(context, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaShowtimesPage(cinemaId: cinema.id.toString(), cinemaName: cinema.name, cinemaAddress: cinema.address)));
                              });
                            },
                            child: Icon(Icons.chevron_right_rounded, color: navyBlue.withOpacity(0.55), size: 30),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<String>(
                              future: _getDistanceTextAsync(lat, lng), 
                              builder: (context, snapshot) {
                                final distance = snapshot.data ?? '- km';
                                return Text(
                                  '$district • $distance', 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis, 
                                  style: TextStyle(
                                    fontSize: 13.5, 
                                    color: primaryBlue, 
                                    fontWeight: FontWeight.w600,
                                    height: 1.0, 
                                  )
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(cinema.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.2)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _openGoogleMaps(cinema.name, cinema.address),
                  child: Text('Tìm đường', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
  void _openGoogleMaps(String cinemaName, String address) async {
    final query = Uri.encodeComponent('$cinemaName $address');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ============================================================================
// ✅ CLASS NÚT YÊU THÍCH ĐỘC LẬP (CHỈ KHAI BÁO DUY NHẤT 1 LẦN Ở CUỐI FILE)
// ============================================================================
class FavoriteButtonWidget extends StatefulWidget {
  final String cinemaId;
  final String cinemaName;
  final Color primaryBlue;
  final String apiBaseUrl;

  const FavoriteButtonWidget({
    super.key, 
    required this.cinemaId, 
    required this.cinemaName, 
    required this.primaryBlue, 
    required this.apiBaseUrl
  });

  @override
  State<FavoriteButtonWidget> createState() => _FavoriteButtonWidgetState();
}

class _FavoriteButtonWidgetState extends State<FavoriteButtonWidget> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus(); 
  }

  Future<void> _checkFavoriteStatus() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return; // 🚀 Khách thì không cần gọi API check tim làm gì cho tốn tài nguyên
    int userId = user.id;
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

  void _toggleFavorite() {
    // 🚀 BỌC THÉP: Chặn đứng khách vãng lai, yêu cầu đăng nhập
    GuestGuard.check(context, () async {
      final user = UserManager.instance.currentUser;
      if (user == null) return; 
      int userId = user.id;
      
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
        await http.post(
          Uri.parse('${widget.apiBaseUrl}/api/favorites/cinema/toggle'), 
          headers: {'Content-Type': 'application/json'}, 
          body: json.encode({'cinema_id': widget.cinemaId, 'is_favorite': isFavorite, 'user_id': userId})
        );
      } catch (e) { 
        debugPrint('Lỗi toggle favorite: $e'); 
      }
    }); // <-- Kết thúc GuestGuard
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        width: 38, height: 38, 
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
        child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border_rounded, size: 20, color: isFavorite ? Colors.red : const Color(0xFF3A3A3A)),
      ),
    );
  }
}