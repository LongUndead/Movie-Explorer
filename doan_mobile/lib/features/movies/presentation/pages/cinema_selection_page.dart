import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
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

  int _selectedDateIndex = 0;
  int _selectedTimeIndex = 0;
  int _selectedBrandIndex = 0;

  late List<Map<String, String>> _dates;

  @override
  void initState() {
    super.initState();
    _dates = _generateDates(); 
    // Tự động load tất cả rạp (Tab Đề xuất) khi vừa mở trang
    context.read<MovieBloc>().add(GetCinemasByBrandEvent(''));
  }

  List<Map<String, String>> _generateDates() {
    List<Map<String, String>> generatedDates = [];
    DateTime now = DateTime.now(); 

    for (int i = 0; i < 14; i++) {
      DateTime targetDate = now.add(Duration(days: i));
      String dateString = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}';
      String dayLabel;
      if (i == 0) {
        dayLabel = 'H.nay';
      } else {
        switch (targetDate.weekday) {
          case 1: dayLabel = 'Thứ 2'; break;
          case 2: dayLabel = 'Thứ 3'; break;
          case 3: dayLabel = 'Thứ 4'; break;
          case 4: dayLabel = 'Thứ 5'; break;
          case 5: dayLabel = 'Thứ 6'; break;
          case 6: dayLabel = 'Thứ 7'; break;
          case 7: dayLabel = 'C.Nhật'; break;
          default: dayLabel = '';
        }
      }
      generatedDates.add({'date': dateString, 'day': dayLabel});
    }
    return generatedDates;
  }

  final List<String> _times = ['Tất cả', '9:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00', '18:00 - 23:59'];

  List<String> _getFilteredShowtimes() {
    switch (_selectedTimeIndex) {
      case 1: return ["09:15", "10:30", "11:45"];
      case 2: return ["12:35", "13:45", "14:20"];
      case 3: return ["15:10", "16:30", "17:35"];
      case 4: return ["18:20", "19:50", "21:15", "23:00"];
      default: return ["12:35", "17:35", "19:50"];
    }
  }

  // ✅ ĐÃ FIX: Mọi tab đều có tham số 'image' để load ảnh local
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
    context.read<MovieBloc>().add(GetCinemasByBrandEvent(brandItem['databaseName']));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Nền xám nhạt
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // ✅ BOX 1: GHIM CỐ ĐỊNH TRÊN CÙNG (STICKY HEADER)
          // ==========================================
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

          // ==========================================
          // ✅ BOX 2 & DANH SÁCH: CÓ THỂ CUỘN TRƯỢT
          // ==========================================
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12), 
                  // Box Logo Rạp
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
                  // Đổ Data chuẩn từ CSDL
                  _buildCinemaListBloc(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // APPBAR & GIAO DIỆN
  // ==========================================
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
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.movie.title.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade300, Colors.blue.shade50],
          ),
        ),
      ),
      actions: [
        // Box "Hạt nhộng" chứa 2 icon Tai nghe và Ngôi nhà
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {},
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Icon(Icons.headset_mic_outlined, color: Colors.blue.shade900, size: 18),
                ),
              ),
              Container(
                height: 16, width: 1, color: Colors.blue.shade900.withOpacity(0.2),
              ),
              InkWell(
                onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Icon(Icons.home_outlined, color: Colors.blue.shade900, size: 18),
                ),
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
              width: 60, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                children: [
                  Expanded(flex: 1, child: Center(child: Text(_dates[index]['date']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? primaryBlue : Colors.black87)))),
                  Expanded(flex: 1, child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: isSelected ? primaryBlue : Colors.grey.shade100, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6))),
                    child: Center(child: Text(_dates[index]['day']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade600))),
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
                    // ✅ ĐÃ FIX: Chỉ dùng Image.asset cho mọi Tab
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

        if (state is CinemasLoaded) {
          cinemaCount = state.cinemas.length; 
        }

        String headerTitle = brandItem.containsKey('isCurated') ? "Rạp đề xuất" : "Rạp ${brandItem['name']}";

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$headerTitle ($cinemaCount)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.gps_fixed, size: 16, color: primaryBlue),
                label: Text("TP.HCM", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
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

  // ==========================================
  // HÀM SO KHỚP TÊN RẠP ĐỂ TRẢ VỀ ĐÚNG LOGO
  // ==========================================
  String _getLogoForCinema(String cinemaName) {
    String nameLower = cinemaName.toLowerCase();
    if (nameLower.contains('cgv')) return 'assets/cgv1.png';
    if (nameLower.contains('lotte')) return 'assets/lotte.png';
    if (nameLower.contains('galaxy')) return 'assets/galaxy.png';
    if (nameLower.contains('bhd')) return 'assets/bhd.png';
    if (nameLower.contains('cinestar')) return 'assets/cinestar.png';
    if (nameLower.contains('mega gs') || nameLower.contains('megags')) return 'assets/megags.png';
    return 'assets/dexuat.png'; // Mặc định nếu không nhận diện được
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
              // ✅ ĐÃ FIX: Gọi hàm dò Logo tự động
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
    List<String> currentShowtimes = _getFilteredShowtimes();

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("Bạn vừa chọn rạp này • -km", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
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
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(address, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4))), 
                    const SizedBox(width: 10),
                    Text("Tìm đường", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13))
                  ]),
                  const SizedBox(height: 16),
                  const Text("2D Phụ đề", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: currentShowtimes.map((time) => _buildShowtimeButton(time, "~${_calculateEndTime(time)}")).toList(),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateEndTime(String startTime) {
    try {
      final parts = startTime.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]) + 101; 
      h += m ~/ 60;
      m = m % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }

  Widget _buildShowtimeButton(String start, String end) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeatBookingPage(movie: widget.movie))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300, width: 1.2)),
        child: RichText(
          text: TextSpan(
            text: start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            children: [TextSpan(text: " $end", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal))],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// WIDGET NÚT TIM GỌI API ĐỘC LẬP
// ======================================================================
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
    setState(() {
      isFavorite = !isFavorite;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite ? 'Đã thêm ${widget.cinemaName} vào danh sách yêu thích ❤️' : 'Đã bỏ yêu thích rạp này.',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: widget.primaryBlue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.8:3000/api/favorites'), 
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cinema_id': widget.cinemaId,
          'is_favorite': isFavorite,
          'user_id': 1 
        }),
      );
      if (response.statusCode != 200) {
        print('Lỗi lưu CSDL');
      }
    } catch (e) {
      print('Chưa kết nối API Favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border, 
          size: 20, 
          color: isFavorite ? Colors.red : Colors.black54,
        ),
      ),
    );
  }
}