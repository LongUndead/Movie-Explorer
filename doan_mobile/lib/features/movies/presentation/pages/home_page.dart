import 'package:flutter/material.dart';
import 'dart:async'; 
import '../../domain/entities/movie.dart';
import '../../domain/repositories/movie_repository.dart';
import '../../../../injection_container.dart';
import 'movie_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<Movie>>? _futureMovies;
  // ✅ ĐỒNG BỘ: Chuyển sang màu Xanh Navy đậm
  final Color navyBlue = Colors.blue.shade900;

  PageController? _featuredPageController;
  Timer? _featuredTimer;
  // BẮT ĐẦU TỪ SỐ 1000 để có thể lướt qua trái hay qua phải đều vô tận
  int _currentFeaturedPage = 1000; 
  List<Movie> _featuredMoviesList = [];

  @override
  void initState() {
    super.initState();
    _futureMovies = sl<MovieRepository>().getPopularMovies();
    
    // ĐÃ CHỈNH viewportFraction THÀNH 0.72 ĐỂ LỘ RÕ 2 THẺ BÊN CẠNH NHƯ MẪU
    _featuredPageController = PageController(viewportFraction: 0.72, initialPage: _currentFeaturedPage);
    _setupAutoScroll();
  }

  void _setupAutoScroll() {
    _featuredTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_featuredPageController != null && _featuredPageController!.hasClients && _featuredMoviesList.isNotEmpty) {
        // CHỈ CẦN LƯỚT TỚI LIÊN TỤC, KHÔNG BAO GIỜ CUỘN NGƯỢC LẠI
        _featuredPageController!.nextPage(
          duration: const Duration(milliseconds: 600), 
          curve: Curves.easeInOut, 
        );
      }
    });
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _featuredPageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_futureMovies == null) {
      return Center(child: CircularProgressIndicator(color: navyBlue));
    }

    return FutureBuilder<List<Movie>>(
      future: _futureMovies!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: navyBlue));
        if (snapshot.hasError) return const Center(child: Text("Lỗi tải dữ liệu."));
        final movies = snapshot.data ?? [];
        if (movies.isEmpty) return const Center(child: Text("Không có phim"));

        _featuredMoviesList = movies.take(5).toList();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopSection(),
              _buildPromoBanner(),
              _buildSectionTitle("Phim nổi bật", hasSeeAll: false),
              
              // KHỐI PHIM NỔI BẬT (VÒNG LẶP VÔ TẬN)
              _buildFeaturedMovies(_featuredMoviesList),
              
              _buildSectionTitle("Phim hay đang chiếu", hasSeeAll: true),
              _buildNowShowingMovies(movies.skip(5).take(5).toList()),
              _buildSectionTitle("Phim sắp chiếu", hasSeeAll: true),
              _buildUpcomingMovies(movies.reversed.take(5).toList()),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET XÂY DỰNG GIAO DIỆN CON ---

  Widget _buildTopSection() {
    return Stack(
      children: [
        // ✅ ĐỒNG BỘ: Background Gradient nhạt phía sau Header
        Container(
          height: 120, // Giảm height do không còn title STU CINEMA ở đây nữa (nó ở main_page rồi)
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.blue.shade100, const Color(0xFFF5F5F9)], // Chuyển từ xanh nhạt về nền xám
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10), // Đẩy thanh search xuống một chút
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // ✅ ĐỒNG BỘ: Thanh tìm kiếm bo tròn nổi bật
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(25), 
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search, color: navyBlue.withOpacity(0.6)), // Icon search màu xanh mờ
                      const SizedBox(width: 10),
                      const Expanded(child: Text("Tìm tên phim hoặc rạp", style: TextStyle(color: Colors.grey, fontSize: 14))),
                      // Nút Trợ lý ảo
                      Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: navyBlue.withOpacity(0.1), // Nền xanh nhạt
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.face, size: 16, color: navyBlue), // Icon xanh đậm
                            const SizedBox(width: 4),
                            Text('Trợ lý', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          'https://salt.tikicdn.com/ts/upload/5e/5c/41/0088cb187c5dc73250d4ff5cb7ea96e5.png', 
          height: 90, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_,__,___) => Container(height: 90, color: Colors.blue.shade50, child: Center(child: Text('Banner Khuyến Mãi', style: TextStyle(color: navyBlue)))),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required bool hasSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ ĐỒNG BỘ: Tiêu đề danh mục màu đen đậm, kích thước to
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (hasSeeAll)
            Row(
              children: [
                Text('Xem tất cả ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navyBlue)),
                Icon(Icons.arrow_forward_ios, size: 12, color: navyBlue),
              ],
            ),
        ],
      ),
    );
  }

  // TÍNH NĂNG VÒNG LẶP VÔ TẬN VÀ LỘ 2 THẺ BÊN CẠNH
  Widget _buildFeaturedMovies(List<Movie> movies) {
    return SizedBox(
      height: 420, // Tăng thêm chiều cao để không lẹm viền khi Zoom in
      child: PageView.builder(
        controller: _featuredPageController,
        onPageChanged: (index) {
          if (mounted) setState(() => _currentFeaturedPage = index);
        },
        // KHÔNG CÓ itemCount -> NÓ SẼ LƯỚT VÔ TẬN THEO CHIỀU NGANG
        itemBuilder: (context, index) {
          // Dùng toán tử chia lấy dư (%) để lặp lại 5 bộ phim mãi mãi (0,1,2,3,4 -> 0,1,2,3,4)
          final int movieIndex = index % movies.length;
          final movie = movies[movieIndex];
          
          double scale = (index == _currentFeaturedPage) ? 1.0 : 0.85;

          return AnimatedScale(
            scale: scale, 
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10), // Ép nhỏ margin ngang để lộ thẻ rõ hơn
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Stack(
                      clipBehavior: Clip.none, 
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            _getImage(movie.posterPath), 
                            height: 330, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => Container(height: 330, width: double.infinity, color: Colors.grey[300]),
                          ),
                        ),
                        Positioned(top: 10, left: 10, child: _buildBlueBadge("SNEAKSHOW")),
                        Positioned(top: 10, right: 10, child: _buildAgeBadgeBadge(movie.ageRating ?? "16+")),
                        Positioned(
                          bottom: -15, left: 10,
                          child: Text(
                            '${movieIndex + 1}', // In ra đúng số thứ tự của 5 phim (1 đến 5)
                            style: TextStyle(
                              fontSize: 80, fontWeight: FontWeight.bold,
                              foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(movie.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(movie.genres ?? "Đang cập nhật", textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNowShowingMovies(List<Movie> movies) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_getImage(movie.posterPath), height: 200, width: 140, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(height: 200, width: 140, color: Colors.grey[200]))),
                      Positioned(top: 8, left: 8, child: _buildAgeBadgeBadge(movie.ageRating ?? "P")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.star, color: Colors.deepOrange, size: 14),
                    const SizedBox(width: 4),
                    Text('${movie.voteAverage ?? 7.9}/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(movie.genres ?? "Đang cập nhật", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingMovies(List<Movie> movies) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_getImage(movie.posterPath), height: 200, width: 140, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(height: 200, width: 140, color: Colors.grey[200]))),
                      Positioned(top: 8, left: 8, child: _buildAgeBadgeBadge(movie.ageRating ?? "18+")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_formatDateShort(movie.releaseDate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyBlue)), // ✅ ĐỒNG BỘ: Màu chữ navy
                  const SizedBox(height: 2),
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(movie.genres ?? "Đang cập nhật", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- HELPER METHODS ---

  String _getImage(String? path) => path != null ? path : 'https://image.tmdb.org/t/p/w500$path';

  String _formatDateShort(String? date) {
    if (date == null || date.isEmpty) return "Sắp chiếu";
    try {
      final parts = date.split('-');
      if (parts.length == 3) return "${parts[2]} Thg ${parts[1]}";
    } catch (_) {}
    return date;
  }

  Widget _buildAgeBadgeBadge(String age) {
    Color bgColor = Colors.green;
    if (age.contains('13')) bgColor = Colors.orange.shade300;
    if (age.contains('16')) bgColor = Colors.orange; 
    if (age.contains('18')) bgColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1), 
      ),
      child: Text(age, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBlueBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: navyBlue, // ✅ ĐỒNG BỘ: Đổi sang màu Xanh Navy
        borderRadius: BorderRadius.circular(4)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}