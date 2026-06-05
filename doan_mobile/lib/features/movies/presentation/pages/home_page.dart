import 'package:flutter/material.dart';
import 'dart:async'; 
import '../../domain/entities/movie.dart';
import '../../domain/entities/cinema.dart';
import '../../domain/repositories/movie_repository.dart';
import '../../../../injection_container.dart';
import 'movie_detail_page.dart';
import 'all_movies_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<Movie>>? _futureMovies;
  final Color navyBlue = Colors.blue.shade900;

  PageController? _featuredPageController;
  Timer? _featuredTimer;
  int _currentFeaturedPage = 1000; 
  List<Movie> _featuredMoviesList = [];

  PageController? _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  final List<String> _bannerImages = [
    'assets/banner-1.png',
    'assets/banner-2.png',
    'assets/banner-3.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _featuredPageController = PageController(viewportFraction: 0.72, initialPage: _currentFeaturedPage);
    _setupAutoScroll();

    _bannerPageController = PageController(initialPage: 0);
    _setupBannerAutoScroll(); 
  }

  void _loadData() {
    _futureMovies = sl<MovieRepository>().getPopularMovies();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadData(); 
    });
    await _futureMovies; 
  }

  void _setupAutoScroll() {
    _featuredTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_featuredPageController != null && _featuredPageController!.hasClients && _featuredMoviesList.isNotEmpty) {
        _featuredPageController!.nextPage(
          duration: const Duration(milliseconds: 600), 
          curve: Curves.easeInOut, 
        );
      }
    });
  }

  void _setupBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bannerPageController != null && _bannerPageController!.hasClients) {
        int nextPage = _currentBannerIndex + 1;
        if (nextPage >= _bannerImages.length) {
          _bannerPageController!.jumpToPage(0);
        } else {
          _bannerPageController!.jumpToPage(nextPage);
        }
      }
    });
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _featuredPageController?.dispose();
    _bannerTimer?.cancel();
    _bannerPageController?.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
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
        
        final List<Movie> allMovies = snapshot.data ?? [];
        if (allMovies.isEmpty) return const Center(child: Text("Không có phim"));

        final DateTime now = DateTime.now();

        List<Movie> topFeatured = allMovies.where((m) {
          final date = _parseDate(m.releaseDate);
          if (date == null) return false;
          return date.year >= 2024 && (date.isBefore(now) || date.isAtSameMomentAs(now));
        }).toList();
        topFeatured.sort((a, b) => (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0));
        _featuredMoviesList = topFeatured.take(5).toList();

        List<Movie> nowShowing = allMovies.where((m) {
          final date = _parseDate(m.releaseDate);
          if (date == null) return true; 
          return date.isBefore(now) || date.isAtSameMomentAs(now);
        }).toList();
        
        nowShowing.sort((a, b) {
          final dateA = _parseDate(a.releaseDate) ?? DateTime(1970);
          final dateB = _parseDate(b.releaseDate) ?? DateTime(1970);
          return dateB.compareTo(dateA); 
        });

        List<Movie> vietnameseMovies = allMovies.where((m) {
          final lang = m.language?.toLowerCase() ?? '';
          return lang.contains('việt') || lang.contains('vn') || lang.contains('viet');
        }).toList();

        List<Movie> upcoming = allMovies.where((m) {
          final date = _parseDate(m.releaseDate);
          if (date == null) return false;
          final lang = m.language?.toLowerCase() ?? '';
          bool isVietnamese = lang.contains('việt') || lang.contains('vn') || lang.contains('viet');
          return date.isAfter(now) && !isVietnamese;
        }).toList();
        
        upcoming.sort((a, b) {
          final dateA = _parseDate(a.releaseDate) ?? DateTime(2100);
          final dateB = _parseDate(b.releaseDate) ?? DateTime(2100);
          return dateA.compareTo(dateB); 
        });

        return RefreshIndicator(
          color: navyBlue, 
          backgroundColor: Colors.white, 
          onRefresh: _onRefresh, 
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), 
              child: Stack(
                children: [
                  // LỚP DƯỚI: ẢNH NỀN CHẠY DÀI 280PX TỪ TRÊN XUỐNG
                  Container(
                    height: MediaQuery.of(context).size.height * 0.3, 
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF64B5F6), // Xanh da trời mướt mắt ở trên cùng
                          Color(0xFFF5F5F9), // Loang từ từ xuống màu nền trắng xám của App ở dưới
                        ],
                        // Có thể dùng stops để chỉnh điểm bắt đầu loang, nhưng mặc định Flutter đã chia rất đều
                      ),
                    ),
                  ),
                  
                  // LỚP TRÊN: TOÀN BỘ NỘI DUNG CUỘN ĐÈ LÊN ẢNH NỀN
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Khoảng lùi an toàn để không đè vào chữ của AppBar
                      const SizedBox(height: 105), 
                      
                      _buildSearchBar(allMovies),
                      
                      _buildPromoBanner(),
                      
                      _buildSectionTitle("Phim nổi bật", hasSeeAll: false),
                      _buildFeaturedMovies(_featuredMoviesList),
                      
                      _buildSectionTitle(
                        "Phim hay đang chiếu", 
                        hasSeeAll: true,
                        onSeeAllTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AllMoviesPage(
                            pageTitle: "Phim đang chiếu", 
                            movies: allMovies, 
                            initialIndex: 0,
                          )));
                        },
                      ),
                      _buildNowShowingMovies(nowShowing.take(5).toList()), 
                      
                      if (vietnameseMovies.isNotEmpty) ...[
                        _buildSectionTitle(
                          "Phim Việt Nam", 
                          hasSeeAll: true,
                          onSeeAllTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => AllMoviesPage(
                              pageTitle: "Phim Việt Nam", 
                              movies: allMovies, 
                              initialIndex: 2, 
                            )));
                          },
                        ),
                        _buildVietnameseMovies(vietnameseMovies.take(5).toList()),
                      ],

                      _buildSectionTitle(
                        "Phim sắp chiếu", 
                        hasSeeAll: true,
                        onSeeAllTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AllMoviesPage(
                            pageTitle: "Phim sắp chiếu", 
                            movies: allMovies, 
                            initialIndex: 1,
                          )));
                        },
                      ),
                      _buildUpcomingMovies(upcoming.take(5).toList()), 
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// ✅ SỬA LẠI: Thêm tham số allMovies và bọc GestureDetector để chuyển trang
Widget _buildSearchBar(List<Movie> allMovies) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final currentCinemasFromDB = await sl<MovieRepository>().getCinemasByBrand('');

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchPage(
                      allMovies: allMovies,
                      allCinemas: currentCinemasFromDB,
                    ),
                  ),
                );
              },
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: Colors.grey.shade500, size: 22),
                    const SizedBox(width: 10),
                    Text("Tìm tên phim hoặc rạp", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Nút Bộ Lọc
          InkWell(
            onTap: () => _showFilterBottomSheet(context, allMovies),
            borderRadius: BorderRadius.circular(23),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: navyBlue.withOpacity(0.3), width: 1.2),
                borderRadius: BorderRadius.circular(23),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, color: navyBlue, size: 18), 
                  const SizedBox(width: 6),
                  Text('Bộ lọc', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, List<Movie> allMovies) {
    final Color primaryBlue = Colors.blue.shade800;
    String selectedStatus = 'Đang chiếu';
    String selectedAge = 'Tất cả';
    List<String> selectedGenres = [];

    final List<String> statuses = _buildStatusOptions(allMovies);
    final List<String> ages = _buildAgeOptions(allMovies);
    final List<String> genres = _buildGenreOptions(allMovies);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.7,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        const Text(
                          'Bộ Lọc Phim',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close_rounded, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterSectionTitle('Trạng thái'),
                          _buildSingleChoiceChips(statuses, selectedStatus, (val) {
                            setModalState(() => selectedStatus = val);
                          }, primaryBlue),
                          const SizedBox(height: 20),
                          _buildFilterSectionTitle('Độ tuổi'),
                          _buildSingleChoiceChips(ages, selectedAge, (val) {
                            setModalState(() => selectedAge = val);
                          }, primaryBlue),
                          const SizedBox(height: 20),
                          _buildFilterSectionTitle('Thể loại (Có thể chọn nhiều)'),
                          _buildMultiChoiceChips(genres, selectedGenres, (val, isSelected) {
                            setModalState(() {
                              if (isSelected) {
                                selectedGenres.add(val);
                              } else {
                                selectedGenres.remove(val);
                              }
                            });
                          }, primaryBlue),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedStatus = 'Tất cả';
                                selectedAge = 'Tất cả';
                                selectedGenres.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Đặt lại', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final filteredMovies = _filterMovies(
                                allMovies,
                                status: selectedStatus,
                                age: selectedAge,
                                genres: selectedGenres,
                              );

                              Navigator.pop(context);
                              Navigator.push(
                                this.context,
                                MaterialPageRoute(
                                  builder: (context) => AllMoviesPage(
                                    pageTitle: 'Danh Sách Phim',
                                    movies: filteredMovies,
                                    initialIndex: _getInitialIndexForStatus(selectedStatus),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Áp dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _buildStatusOptions(List<Movie> movies) {
    final now = DateTime.now();
    final options = <String>{'Tất cả'};

    for (final movie in movies) {
      final releaseDate = _parseDate(movie.releaseDate);
      final language = movie.language?.toLowerCase() ?? '';

      if (releaseDate != null && (releaseDate.isBefore(now) || releaseDate.isAtSameMomentAs(now))) {
        options.add('Đang chiếu');
      }

      if (releaseDate != null && releaseDate.isAfter(now)) {
        options.add('Sắp chiếu');
      }

      if (language.contains('việt') || language.contains('vn') || language.contains('viet')) {
        options.add('Việt Nam');
      }

      if ((movie.voteAverage ?? 0) > 8.0) {
        options.add('Suất chiếu sớm');
      }
    }

    return options.toList();
  }

  List<String> _buildAgeOptions(List<Movie> movies) {
    final options = <String>{'Tất cả'};

    for (final movie in movies) {
      final ageRating = movie.ageRating?.trim();
      if (ageRating != null && ageRating.isNotEmpty) {
        options.add(ageRating);
      }
    }

    if (options.length == 1) {
      options.addAll(['P', 'C13', 'C16', 'C18']);
    }

    return options.toList();
  }

  List<String> _buildGenreOptions(List<Movie> movies) {
    final options = <String>{};

    for (final movie in movies) {
      final rawGenres = movie.genres ?? '';
      for (final genre in rawGenres.split(',')) {
        final trimmed = genre.trim();
        if (trimmed.isNotEmpty) {
          options.add(trimmed);
        }
      }
    }

    if (options.isEmpty) {
      options.addAll(['Hành động', 'Kinh dị', 'Hài hước', 'Anime', 'Tình cảm', 'Viễn tưởng']);
    }

    return options.toList();
  }

  List<Movie> _filterMovies(
    List<Movie> movies, {
    required String status,
    required String age,
    required List<String> genres,
  }) {
    final now = DateTime.now();

    return movies.where((movie) {
      final releaseDate = _parseDate(movie.releaseDate);
      final language = movie.language?.toLowerCase() ?? '';
      final movieAge = movie.ageRating?.trim() ?? '';
      final movieGenres = (movie.genres ?? '')
          .split(',')
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toList();

      final matchesStatus = switch (status) {
        'Tất cả' => true,
        'Đang chiếu' => releaseDate == null || releaseDate.isBefore(now) || releaseDate.isAtSameMomentAs(now),
        'Sắp chiếu' => releaseDate != null && releaseDate.isAfter(now),
        'Việt Nam' => language.contains('việt') || language.contains('vn') || language.contains('viet'),
        'Suất chiếu sớm' => (movie.voteAverage ?? 0) > 8.0,
        _ => true,
      };

      final matchesAge = age == 'Tất cả' || movieAge == age;
      final matchesGenre = genres.isEmpty || movieGenres.any(genres.contains);

      return matchesStatus && matchesAge && matchesGenre;
    }).toList();
  }

  int _getInitialIndexForStatus(String status) {
    switch (status) {
      case 'Sắp chiếu':
        return 1;
      case 'Việt Nam':
        return 2;
      case 'Suất chiếu sớm':
        return 3;
      case 'Đang chiếu':
      case 'Tất cả':
      default:
        return 0;
    }
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSingleChoiceChips(List<String> items, String selectedValue, Function(String) onSelect, Color primaryColor) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = item == selectedValue;
        return ChoiceChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (_) => onSelect(item),
          selectedColor: primaryColor.withValues(alpha: 0.1),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? primaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildMultiChoiceChips(List<String> items, List<String> selectedValues, Function(String, bool) onSelect, Color primaryColor) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = selectedValues.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (selected) => onSelect(item, selected),
          selectedColor: primaryColor.withValues(alpha: 0.1),
          backgroundColor: Colors.white,
          checkmarkColor: primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? primaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: 155,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PageView.builder(
                controller: _bannerPageController,
                onPageChanged: (index) {
                  setState(() => _currentBannerIndex = index);
                },
                itemCount: _bannerImages.length,
                itemBuilder: (context, index) {
                  return Image.asset(
                    _bannerImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.blue.shade50,
                      child: Center(
                        child: Text('Banner Khuyến Mãi ${index + 1}', style: TextStyle(color: navyBlue))
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentBannerIndex + 1}/${_bannerImages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required bool hasSeeAll, VoidCallback? onSeeAllTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (hasSeeAll)
            GestureDetector(
              onTap: onSeeAllTap, 
              child: Row(
                children: [
                  Text('Xem tất cả ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navyBlue)),
                  Icon(Icons.arrow_forward_ios, size: 12, color: navyBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedMovies(List<Movie> movies) {
    if(movies.isEmpty) return const SizedBox();
    return SizedBox(
      height: 420, 
      child: PageView.builder(
        controller: _featuredPageController,
        onPageChanged: (index) {
          if (mounted) setState(() => _currentFeaturedPage = index);
        },
        itemBuilder: (context, index) {
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
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10), 
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
                            '${movieIndex + 1}',
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
    if(movies.isEmpty) return const SizedBox();
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12), 
                        child: Image.network(
                          _getImage(movie.posterPath), 
                          height: 200, width: 140, fit: BoxFit.cover, 
                          errorBuilder: (_,__,___) => Container(height: 200, width: 140, color: Colors.grey[200])
                        )
                      ),
                      Positioned(top: 8, left: 8, child: _buildAgeBadgeBadge(movie.ageRating ?? "P")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.star, color: Colors.deepOrange, size: 14),
                    const SizedBox(width: 4),
                    Text('${(movie.voteAverage ?? 0.0).toStringAsFixed(1)}/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _buildVietnameseMovies(List<Movie> movies) {
    return _buildNowShowingMovies(movies);
  }

  Widget _buildUpcomingMovies(List<Movie> movies) {
    if(movies.isEmpty) return const SizedBox();
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
                    clipBehavior: Clip.none, 
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12), 
                        child: Image.network(
                          _getImage(movie.posterPath), 
                          height: 200, width: 140, fit: BoxFit.cover, 
                          errorBuilder: (_,__,___) => Container(height: 200, width: 140, color: Colors.grey[200])
                        )
                      ),
                      Positioned(top: 8, right: 8, child: _buildAgeBadgeBadge(movie.ageRating ?? "18+")),
                      Positioned(
                        top: 8, left: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.access_time_filled, color: Colors.white, size: 10), 
                              SizedBox(width: 4),
                              Text("COMING SOON", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_formatDateShort(movie.releaseDate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyBlue)), 
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

  String _getImage(String? path) {
    if (path != null) return path;
    return 'https://image.tmdb.org/t/p/w500$path';
  }

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
        color: navyBlue, 
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