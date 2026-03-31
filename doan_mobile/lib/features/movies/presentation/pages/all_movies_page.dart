import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import 'movie_detail_page.dart';
import 'cinema_selection_page.dart'; 

class AllMoviesPage extends StatefulWidget {
  final String pageTitle;
  final List<Movie> movies;
  final int initialIndex; 

  const AllMoviesPage({
    super.key,
    required this.pageTitle,
    required this.movies,
    this.initialIndex = 0, 
  });

  @override
  State<AllMoviesPage> createState() => _AllMoviesPageState();
}

class _AllMoviesPageState extends State<AllMoviesPage> {
  final Color navyBlue = Colors.blue.shade900;
  final Color secondaryGrey = const Color(0xFF757575);

  final List<String> _categories = [
    "Đang chiếu",
    "Sắp chiếu",
    "Phim Việt Nam",
    "Suất chiếu sớm",
  ];

  late int _selectedIndex; 

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  // ✅ HÀM GIẢ LẬP KÉO XUỐNG ĐỂ REFRESH
  Future<void> _onRefresh() async {
    // Đợi 1 giây để có hiệu ứng xoay vòng mượt mà
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      // Vì data list lấy từ Home truyền sang nên không cần gọi API ở đây, 
      // chỉ cần gọi lại setState để làm mới giao diện.
    });
  }

  List<Movie> get _filteredMovies {
    final now = DateTime.now();

    if (_selectedIndex == 0) {
      return widget.movies.where((m) {
        if (m.releaseDate == null || m.releaseDate!.isEmpty) return true;
        try {
          final release = DateTime.parse(m.releaseDate!);
          return release.isBefore(now) || release.isAtSameMomentAs(now);
        } catch (_) { return true; } 
      }).toList();

    } else if (_selectedIndex == 1) {
      return widget.movies.where((m) {
        if (m.releaseDate == null || m.releaseDate!.isEmpty) return false;
        try {
          final release = DateTime.parse(m.releaseDate!);
          return release.isAfter(now);
        } catch (_) { return false; }
      }).toList();

    } else if (_selectedIndex == 2) {
      return widget.movies.where((m) {
        final lang = m.language?.toLowerCase() ?? '';
        return lang.contains('việt') || lang.contains('vn') || lang.contains('viet');
      }).toList();

    } else {
      return widget.movies.where((m) => (m.voteAverage ?? 0) > 8.0).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayMovies = _filteredMovies;

    return Scaffold(
      backgroundColor: Colors.white,
      
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, 
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade100, const Color(0xFFF5F5F9)], 
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true, 
        title: Text(
          widget.pageTitle, 
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black87),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ],
      ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            height: 65,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index), 
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? navyBlue : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? navyBlue : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ✅ BỌC BẰNG RefreshIndicator ĐỂ VUỐT XUỐNG LÀ LOAD
          Expanded(
            child: RefreshIndicator(
              color: navyBlue,
              backgroundColor: Colors.white,
              onRefresh: _onRefresh, // Gọi hàm _onRefresh
              child: displayMovies.isEmpty
                  ? ListView( // Chuyển thành ListView để vẫn kéo được khi rỗng
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Text(
                            "Chưa có phim nào ở mục này!",
                            style: TextStyle(color: secondaryGrey, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(), // Bắt buộc
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                      itemCount: displayMovies.length, 
                      separatorBuilder: (context, index) => const Divider(
                        height: 32,
                        thickness: 1,
                        color: Color(0xFFF0F0F0), 
                      ),
                      itemBuilder: (context, index) {
                        return _buildMovieCard(displayMovies[index]); 
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    String rating = (movie.voteAverage ?? 0.0).toStringAsFixed(1);
    int reviewCount = (movie.id % 500) + 120; 

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10), 
              child: Image.network(
                _getImage(movie.posterPath),
                width: 110,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 110, height: 160, color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
            
            if ((movie.voteAverage ?? 0) > 8.0) 
              Positioned(
                top: 6, left: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xFF03A9F4),
                    borderRadius: BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.videocam, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text("SNEAKSHOW", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

            Positioned(
              top: 6, right: 6,
              child: _buildAgeBadge(movie.ageRating),
            ),
          ],
        ),

        const SizedBox(width: 16), 

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.deepOrange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "$rating/10",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    " ($reviewCount đánh giá)",
                    style: TextStyle(color: secondaryGrey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              
              Text(
                movie.genres ?? 'Đang cập nhật',
                style: TextStyle(fontSize: 13, color: secondaryGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: secondaryGrey),
                  const SizedBox(width: 4),
                  Text(
                    "${movie.duration ?? 120} phút",
                    style: TextStyle(fontSize: 12, color: secondaryGrey),
                  ),
                  const SizedBox(width: 12), 
                  Container(width: 1, height: 12, color: Colors.grey.shade400), 
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today_outlined, size: 13, color: secondaryGrey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(movie.releaseDate),
                    style: TextStyle(fontSize: 12, color: secondaryGrey),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => _navigateToDetail(movie),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          "Chi tiết",
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CinemaSelectionPage(movie: movie), 
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white, 
                          side: BorderSide(color: navyBlue, width: 1.2), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          "Mua vé",
                          style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13), 
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--/--/----';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _buildAgeBadge(String? age) {
    String label = age ?? 'P';
    Color color = Colors.green;
    
    if (label.contains('18') || label.contains('C18')) color = const Color(0xFFD32F2F);
    else if (label.contains('16') || label.contains('C16') || label.contains('13')) color = Colors.orange.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getImage(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  void _navigateToDetail(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailPage(movie: movie),
      ),
    );
  }
}