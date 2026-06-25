import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/cinema.dart'; // 👈 BẮT BUỘC IMPORT MODEL CINEMA CỦA BẠN
import 'movie_detail_page.dart';
import 'cinema_showtimes_page.dart';

class SearchPage extends StatefulWidget {
  final List<Movie> allMovies;      
  final List<Cinema> allCinemas;   // 👈 DÙNG KIỂU DỮ LIỆU CHUẨN THAY VÌ DYNAMIC

  const SearchPage({
    super.key, 
    required this.allMovies, 
    required this.allCinemas,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _pageSize = 5;
  final Color themeColor = Colors.blue.shade900; 
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _selectedTab = 1; 
  String _searchQuery = "";
  int _visibleCinemaCount = _pageSize;
  int _visibleMovieCount = _pageSize;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), 
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSearchBar(),
            _buildTabBar(),
            Expanded(
              child: _buildBodyContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.blue.shade50.withOpacity(0.6), 
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Tìm tên phim hoặc rạp",
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _resetSearch();
                          },
                          child: Icon(Icons.cancel, color: Colors.grey.shade400, size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              "Hủy", 
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildTabItem(title: "Rạp", index: 0),
          const SizedBox(width: 12),
          _buildTabItem(title: "Phim", index: 1),
        ],
      ),
    );
  }

  Widget _buildTabItem({required String title, required int index}) {
    bool isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: themeColor, width: 1.2) : Border.all(color: Colors.transparent),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? themeColor : Colors.black54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_selectedTab == 0) return _buildCinemaResults(); 
    return _buildMovieResults(); 
  }

  // ==========================================
  // KẾT QUẢ RẠP: GỌI CHUẨN TỪ OBJECT CINEMA
  // ==========================================
  Widget _buildCinemaResults() {
    final results = widget.allCinemas.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (results.isEmpty) return _buildEmptyState(isCinema: true);

    final visibleResults = results.take(_visibleCinemaCount).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleResults.length + (results.length > visibleResults.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibleResults.length) {
          return _buildLoadMoreButton(
            label: "Xem thêm rạp",
            onPressed: () {
              setState(() {
                _visibleCinemaCount = (_visibleCinemaCount + _pageSize).clamp(_pageSize, results.length);
              });
            },
          );
        }

        final cinema = visibleResults[index];
        // =========================================================================
        // 🔥 ĐÃ SỬA: Lấy logo dựa trên cinema.name (tên rạp) thay vì cinema.brand
        // =========================================================================
        final String logoAsset = _getLogoForCinema(cinema.name);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(12), 
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Container(
                width: 50, 
                height: 50, 
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200), 
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      logoAsset,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Icon(Icons.movie_creation_outlined, color: themeColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cinema.name, // 👈 Trực tiếp gọi thuộc tính từ Object 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cinema.address, // 👈 Trực tiếp gọi thuộc tính từ Object 
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12), 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Hiển thị Rating lấy từ DB của bạn (ví dụ: 4.7)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          cinema.rating.toStringAsFixed(1), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CinemaShowtimesPage(
                      cinemaId: cinema.id.toString(),
                      cinemaName: cinema.name,
                      cinemaAddress: cinema.address,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Suất chiếu",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
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

  // =========================================================================
  // 🔥 ĐÃ SỬA: Sửa lại tên biến đầu vào cho rõ ràng là cinemaName
  // =========================================================================
  String _getLogoForCinema(String cinemaName) {
    final nameLower = cinemaName.toLowerCase();
    if (nameLower.contains('cgv')) return 'assets/cgv1.png';
    if (nameLower.contains('lotte')) return 'assets/lotte.png';
    if (nameLower.contains('galaxy')) return 'assets/galaxy.png';
    if (nameLower.contains('bhd')) return 'assets/bhd.png';
    if (nameLower.contains('cinestar')) return 'assets/cinestar.png';
    // ✅ Cẩn thận với AEON BETA (nếu có aeon thì return logo aeon trước khi rơi vào beta thường)
    if (nameLower.contains('aeon beta') || nameLower.contains('aeonbeta')) return 'assets/aeonbeta.png';
    if (nameLower.contains('beta')) return 'assets/betacinema.png';
    if (nameLower.contains('mega gs') || nameLower.contains('megags') || nameLower.contains('mega')) return 'assets/megags.png';
    if (nameLower.contains('dcine')) return 'assets/dcine.png';
    
    return 'assets/dexuat.png';
  }

  // ==========================================
  // KẾT QUẢ PHIM: GỌI CHUẨN TỪ OBJECT MOVIE
  // ==========================================
  Widget _buildMovieResults() {
    final results = widget.allMovies.where((m) {
      return m.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (results.isEmpty) return _buildEmptyState(isCinema: false);

    final visibleResults = results.take(_visibleMovieCount).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleResults.length + (results.length > visibleResults.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibleResults.length) {
          return _buildLoadMoreButton(
            label: "Xem thêm phim",
            onPressed: () {
              setState(() {
                _visibleMovieCount = (_visibleMovieCount + _pageSize).clamp(_pageSize, results.length);
              });
            },
          );
        }

        final movie = visibleResults[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(12), 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6), 
                  child: Image.network(
                    'https://image.tmdb.org/t/p/w500${movie.posterPath}', 
                    width: 50, 
                    height: 75, 
                    fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => Container(width: 50, height: 75, color: Colors.grey[300], child: const Icon(Icons.movie)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            // Cắt lấy năm từ DB (VD: 2026-02-25 => 2026)
                            movie.releaseDate != null && movie.releaseDate!.length >= 4 
                                ? movie.releaseDate!.substring(0, 4) 
                                : "2026", 
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Đang chiếu", 
                            style: TextStyle(color: Colors.green.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                  decoration: BoxDecoration(
                    color: themeColor, 
                    borderRadius: BorderRadius.circular(6),
                  ), 
                  child: const Text(
                    "Đặt vé", 
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _visibleCinemaCount = _pageSize;
      _visibleMovieCount = _pageSize;
    });
  }

  void _resetSearch() {
    setState(() {
      _searchQuery = "";
      _visibleCinemaCount = _pageSize;
      _visibleMovieCount = _pageSize;
    });
  }

  Widget _buildLoadMoreButton({required String label, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Center(
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: themeColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 18, color: themeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isCinema}) {
    String text1 = isCinema ? "Không tìm thấy rạp phù hợp trong hệ thống." : "Hệ thống không tìm thấy từ khoá này rùi";
    String text2 = isCinema ? "Bạn hãy thử nhập tên chi nhánh khác nhé" : "Bạn hãy thử lại với một từ khoá khác nha";
    String btnText = isCinema ? "Làm mới tìm kiếm" : "Xem tất cả phim";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCinema ? Icons.fmd_bad_outlined : Icons.search_off_rounded, 
            size: 70, 
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(text1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(text2, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = "");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(btnText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}