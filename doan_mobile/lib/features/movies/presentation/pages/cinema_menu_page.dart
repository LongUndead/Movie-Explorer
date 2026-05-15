import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../bloc/movie_bloc.dart';
import '../bloc/movie_event.dart';
import '../bloc/movie_state.dart';
import 'cinema_showtimes_page.dart';

class CinemaMenuPage extends StatefulWidget {
  const CinemaMenuPage({super.key});

  @override
  State<CinemaMenuPage> createState() => _CinemaMenuPageState();
}

class _CinemaMenuPageState extends State<CinemaMenuPage> {
  final Color primaryBlue = Colors.blue.shade700;
  final Color navyBlue = Colors.blue.shade900;
  final Color pageBackground = const Color(0xFFF5F5F9);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _selectedBrandIndex = 0;
  String _selectedCity = 'TP.HCM';
  Position? _currentPosition;
  bool _isScrolled = false;

  final Map<String, Map<String, double>> _cityCoordinates = {
    'TP.HCM': {'lat': 10.762622, 'lng': 106.660172},
    'Bà Rịa - Vũng Tàu': {'lat': 10.496950, 'lng': 107.168480},
    'Bình Dương': {'lat': 11.166667, 'lng': 106.666667},
    'Đồng Nai': {'lat': 10.933333, 'lng': 107.000000},
    'Tây Ninh': {'lat': 11.300000, 'lng': 106.100000},
    'Long An': {'lat': 10.533333, 'lng': 106.666667},
  };

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

  final List<Map<String, dynamic>> _brands = [
    {'name': 'Đề xuất', 'image': 'assets/dexuat.png', 'databaseName': 'RANDOM', 'isCurated': true},
    {'name': 'CGV', 'image': 'assets/cgv1.png', 'databaseName': 'CGV'},
    {'name': 'Lotte', 'image': 'assets/lotte.png', 'databaseName': 'Lotte'},
    {'name': 'Galaxy', 'image': 'assets/galaxy.png', 'databaseName': 'Galaxy'},
    {'name': 'BHD Star', 'image': 'assets/bhd.png', 'databaseName': 'BHD'},
    {'name': 'Cinestar', 'image': 'assets/cinestar.png', 'databaseName': 'Cinestar'},
    {'name': 'Mega GS', 'image': 'assets/megags.png', 'databaseName': 'MegaGS'},
  ];

  final Map<String, String> _logoByBrand = {
    'cgv': 'assets/cgv1.png',
    'lotte': 'assets/lotte.png',
    'galaxy': 'assets/galaxy.png',
    'bhd': 'assets/bhd.png',
    'cinestar': 'assets/cinestar.png',
    'mega gs': 'assets/megags.png',
    'megags': 'assets/megags.png',
  };

  @override
  void initState() {
    super.initState();
    _loadCinemasForSelectedBrand();
    _autoFetchLocation();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final bool nextScrolled = _scrollController.hasClients && _scrollController.offset > 12;
    if (nextScrolled != _isScrolled && mounted) {
      setState(() {
        _isScrolled = nextScrolled;
      });
    }
  }

  void _loadCinemasForSelectedBrand() {
    final brandItem = _brands[_selectedBrandIndex];
    context.read<MovieBloc>().add(
      GetCinemasByBrandEvent(
        brandItem['databaseName'] as String,
        random: brandItem['isCurated'] == true,
      ),
    );
  }

  void _selectBrand(int index) {
    setState(() => _selectedBrandIndex = index);
    _loadCinemasForSelectedBrand();
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
          _selectedCity = 'Vị trí của tôi';
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Lỗi Auto GPS: $e');
    }
  }

  Future<String> _getDistanceTextAsync(String cinemaName) async {
    double? userLat;
    double? userLng;

    if (_selectedCity == 'Vị trí của tôi' && _currentPosition != null) {
      userLat = _currentPosition!.latitude;
      userLng = _currentPosition!.longitude;
    } else if (_cityCoordinates.containsKey(_selectedCity)) {
      userLat = _cityCoordinates[_selectedCity]!['lat'];
      userLng = _cityCoordinates[_selectedCity]!['lng'];
    }

    if (userLat != null && userLng != null && _cinemaCoordinates.containsKey(cinemaName)) {
      final cinLat = _cinemaCoordinates[cinemaName]!['lat']!;
      final cinLng = _cinemaCoordinates[cinemaName]!['lng']!;

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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng bật GPS trên điện thoại!')));
                      }
                      await Geolocator.openLocationSettings();
                      return;
                    }

                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn đã từ chối quyền vị trí!')));
                        }
                        return;
                      }
                    }

                    if (permission == LocationPermission.deniedForever) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quyền vị trí bị chặn vĩnh viễn. Hãy mở Cài đặt để cấp quyền!')));
                      }
                      return;
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang lấy tọa độ GPS...', style: TextStyle(color: primaryBlue)), backgroundColor: Colors.white, duration: const Duration(seconds: 1)));
                    }

                    final position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                      timeLimit: const Duration(seconds: 10),
                    );

                    if (mounted) {
                      setState(() {
                        _selectedCity = 'Vị trí của tôi';
                        _currentPosition = position;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vị trí thành công!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    debugPrint('Lỗi GPS: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lấy GPS (Hãy thử ra nơi thoáng đãng): $e')));
                    }
                  }
                },
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView.separated(
                  itemCount: cities.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedCity == cities[index];
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

  @override
  Widget build(BuildContext context) {
    final headerBackground = _isScrolled
        ? pageBackground
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0xFFD6ECFF), Color(0xFFF5F5F9)],
            stops: [0.0, 0.33],
          );

    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: _isScrolled ? pageBackground : null,
          gradient: _isScrolled ? null : headerBackground as LinearGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              _buildSearchBar(),
              const SizedBox(height: 10),
              _buildBrandSelector(),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildListHeader(),
                      Expanded(child: _buildCinemaList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          const Expanded(
            child: SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(29),
          boxShadow: [
            BoxShadow(
              color: navyBlue.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
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
          onChanged: (value) {
            setState(() {});
          },
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
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? primaryBlue : const Color(0xFFE1E1E1),
                        width: isSelected ? 2.6 : 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? primaryBlue.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(brand['image'] as String, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    brand['name'] as String,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.05,
                      color: isSelected ? primaryBlue : const Color(0xFF6C6C6C),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
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
        final brandItem = _brands[_selectedBrandIndex];
        final title = brandItem['isCurated'] == true ? 'Rạp đề xuất' : 'Rạp ${brandItem['name']}';
        final cinemaCount = state is CinemasLoaded ? state.cinemas.length : 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$title ($cinemaCount)',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryBlue, width: 1.4),
                ),
                child: InkWell(
                  onTap: _showLocationPicker,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed, size: 17, color: primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCity,
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCinemaList() {
    return BlocBuilder<MovieBloc, MovieState>(
      builder: (context, state) {
        if (state is CinemasLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CinemasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (state is CinemasLoaded) {
          final filteredCinemas = _filterCinemas(state.cinemas);
          if (filteredCinemas.isEmpty) {
            return const Center(child: Text('Không có rạp phù hợp'));
          }

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: filteredCinemas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final cinema = filteredCinemas[index];
              return _buildCinemaCard(
                cinema.id.toString(),
                cinema.name,
                cinema.address,
                index,
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  List<dynamic> _filterCinemas(List<dynamic> cinemas) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return cinemas;
    return cinemas.where((cinema) {
      final name = cinema.name.toString().toLowerCase();
      final address = cinema.address.toString().toLowerCase();
      return name.contains(query) || address.contains(query);
    }).toList();
  }

  Widget _buildCinemaCard(String cinemaId, String name, String address, int index) {
    final logo = _logoForCinema(name);
    final subtitle = _subtitleForCinema(index);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9E9E9)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      logo,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const ColoredBox(
                          color: Color(0xFFF2F2F2),
                          child: Center(child: Icon(Icons.local_movies_outlined, color: Colors.grey, size: 18)),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2F2F2F),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildFavoriteButton(cinemaId, name),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CinemaShowtimesPage(
                                    cinemaId: cinemaId,
                                    cinemaName: name,
                                    cinemaAddress: address,
                                  ),
                                ),
                              );
                            },
                            child: Icon(Icons.chevron_right_rounded, color: navyBlue.withValues(alpha: 0.55), size: 30),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: index == 0 ? primaryBlue : const Color(0xFF2584FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          FutureBuilder<String>(
                            future: _getDistanceTextAsync(name),
                            builder: (context, snapshot) {
                              final distance = snapshot.data ?? '- km';
                              return Text(
                                ' • $distance',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: index == 0 ? primaryBlue : const Color(0xFF2584FF),
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
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
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _openGoogleMaps(name, address),
                  child: Text(
                    'Tìm đường',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(String cinemaId, String cinemaName) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã chọn $cinemaName')),
        );
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: const Icon(Icons.favorite_border_rounded, color: Color(0xFF3A3A3A), size: 20),
      ),
    );
  }

  String _logoForCinema(String cinemaName) {
    final lower = cinemaName.toLowerCase();
    for (final entry in _logoByBrand.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'assets/dexuat.png';
  }

  String _subtitleForCinema(int index) {
    const subtitles = [
      'Bạn vừa chọn rạp này',
      'Bạn ở gần rạp này',
      'Bạn ở gần rạp này',
      'Bạn vừa chọn rạp này',
      'Bạn vừa chọn rạp này',
      'Bạn ở gần rạp này',
      'Bạn vừa chọn rạp này',
    ];
    return subtitles[index % subtitles.length];
  }

  void _openGoogleMaps(String cinemaName, String address) async {
    final query = Uri.encodeComponent('$cinemaName $address');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
