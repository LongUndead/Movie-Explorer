import 'package:flutter/material.dart';
import 'dart:convert'; 
import 'dart:io'; // Để dùng File cho Image Picker
import 'package:flutter_bloc/flutter_bloc.dart'; 
import 'package:image_picker/image_picker.dart'; // Thư viện chọn ảnh/video
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../bloc/movie_bloc.dart'; 
import '../../domain/entities/movie.dart';
import 'cinema_selection_page.dart'; 

// ============================================================================
// 1. MÀN HÌNH CHI TIẾT PHIM
// ============================================================================
class MovieDetailPage extends StatefulWidget {
  final Movie movie;
  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  bool _isExpanded = false; 
  List<dynamic> _castList = [];

  final Color navyBlue = Colors.blue.shade900;
  final Color starColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    try {
      if (widget.movie.castJson != null && widget.movie.castJson!.isNotEmpty) {
        _castList = jsonDecode(widget.movie.castJson!);
      }
    } catch (e) {
      debugPrint("Lỗi parse Cast JSON: $e");
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "Đang cập nhật";
    try {
      final parts = date.split('-');
      if (parts.length == 3) return "${parts[2]}/${parts[1]}/${parts[0]}";
    } catch (_) {}
    return date;
  }

  String _getAgeText(String rating) {
    if (rating.contains('18')) return "Phim được phổ biến đến người xem từ đủ 18 tuổi trở lên";
    if (rating.contains('16')) return "Phim được phổ biến đến người xem từ đủ 16 tuổi trở lên";
    if (rating.contains('13')) return "Phim được phổ biến đến người xem từ đủ 13 tuổi trở lên";
    return "Phim được phép phổ biến rộng rãi đến mọi đối tượng";
  }

  // ✅ HÀM KIỂM TRA PHIM CÓ ĐANG SẮP CHIẾU HAY KHÔNG
  bool _isUpcomingMovie() {
    if (widget.movie.releaseDate == null || widget.movie.releaseDate!.isEmpty) return false;
    try {
      final releaseDate = DateTime.parse(widget.movie.releaseDate!);
      final now = DateTime.now();
      return releaseDate.isAfter(now); // Ngày ra mắt > Hiện tại -> Sắp chiếu
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), 
      
      appBar: AppBar(
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
            Expanded(child: Text('Thông tin phim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50])),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(onTap: () {}, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.headset_mic_outlined, color: navyBlue, size: 18))),
                Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
                InkWell(onTap: () => Navigator.popUntil(context, (route) => route.isFirst), borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.home_outlined, color: navyBlue, size: 18))),
              ],
            ),
          ),
        ],
      ),
      
      // ✅ NÚT MUA VÉ ĐƯỢC KIỂM SOÁT BỞI TRẠNG THÁI SẮP CHIẾU
      bottomNavigationBar: _buildBottomBar(navyBlue),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BOX 1: THÔNG TIN PHIM
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ ĐÃ THÊM LOGO COMING SOON TRÊN POSTER
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(widget.movie.posterPath, width: 120, height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 120, height: 180, color: Colors.grey[300])),
                          ),
                          if (_isUpcomingMovie()) // Chỉ hiện nếu là phim Sắp chiếu
                            Positioned(
                              top: 8, left: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Colors.amber, // Nền vàng
                                  borderRadius: BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.access_time_filled, color: Colors.white, size: 10), // Logo đồng hồ
                                    SizedBox(width: 4),
                                    Text("COMING SOON", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.movie.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.3, color: navyBlue), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(widget.movie.genres ?? 'Đang cập nhật', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: _getAgeColor(widget.movie.ageRating), shape: BoxShape.circle),
                                  child: Text(widget.movie.ageRating ?? 'P', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_getAgeText(widget.movie.ageRating ?? 'P'), style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildActionButton(Icons.favorite_border, "Thích")),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildActionButton(
                                    Icons.play_circle_outline, 
                                    "Trailer", 
                                    onTap: () {
                                      String url = (widget.movie.trailerUrl != null && widget.movie.trailerUrl!.isNotEmpty) 
                                          ? widget.movie.trailerUrl! 
                                          : "https://www.youtube.com/watch?v=TcMBFSGVi1c"; 
                                      
                                      showDialog(
                                        context: context,
                                        builder: (context) => TrailerDialog(youtubeUrl: url),
                                      );
                                    }
                                  )
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(child: _buildInfoColumn('Ngày khởi chiếu', _formatDate(widget.movie.releaseDate))),
                        VerticalDivider(color: Colors.grey.shade200, thickness: 1, width: 1),
                        Expanded(child: _buildInfoColumn('Thời lượng', '2 giờ 18 phút')), 
                        VerticalDivider(color: Colors.grey.shade200, thickness: 1, width: 1),
                        Expanded(child: _buildInfoColumn('Ngôn ngữ', widget.movie.language?.replaceAll(', ', '\n') ?? 'Phụ đề\nLồng Tiếng')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // BOX 2: TỔNG QUAN ĐÁNH GIÁ
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewListPage(movie: widget.movie, navyBlue: navyBlue, starColor: starColor))),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Icon(Icons.star, color: starColor, size: 28), const SizedBox(width: 4),
                                Text((widget.movie.voteAverage ?? 9.7).toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                                const Padding(padding: EdgeInsets.only(bottom: 4.0), child: Text('/10', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Đánh giá', style: TextStyle(fontSize: 12, color: Colors.grey)), 
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildRatingBar('9-10', 0.85), const SizedBox(height: 6),
                            _buildRatingBar('7-8', 0.1), const SizedBox(height: 6),
                            _buildRatingBar('5-6', 0.02), const SizedBox(height: 6),
                            _buildRatingBar('3-4', 0.0), const SizedBox(height: 6),
                            _buildRatingBar('1-2', 0.03),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // BOX 3: NỘI DUNG PHIM
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nội dung phim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: RichText(
                      text: TextSpan(
                        text: _isExpanded ? widget.movie.overview : (widget.movie.overview.length > 150 ? '${widget.movie.overview.substring(0, 150)}...' : widget.movie.overview),
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                        children: [
                          if (widget.movie.overview.length > 150) TextSpan(text: _isExpanded ? " Thu gọn" : " Xem thêm", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // BOX 4: DIỄN VIÊN
            if (_castList.isNotEmpty)
              Container(
                width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Diễn viên và Đoàn làm phim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue))),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _castList.length,
                        itemBuilder: (context, index) {
                          final actor = _castList[index];
                          final img = actor['profile_path'] != null ? 'https://image.tmdb.org/t/p/w200${actor['profile_path']}' : '';
                          return Container(
                            width: 100, margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(10), child: img.isNotEmpty ? Image.network(img, height: 110, width: 100, fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage()) : _buildErrorImage()),
                                const SizedBox(height: 6),
                                Text(actor['name'] ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: navyBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(actor['character'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // BOX 5: HÌNH ẢNH VÀ VIDEO
            Container(
              width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Hình ảnh và Video', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue))),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildMediaItem(widget.movie.posterPath, isVideo: true), const SizedBox(width: 12),
                        _buildMediaItem(widget.movie.posterPath, isVideo: false), const SizedBox(width: 12),
                        _buildMediaItem(widget.movie.posterPath, isVideo: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // BOX 6: BANNER KHUYẾN MÃI
            Container(
              width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network('https://salt.tikicdn.com/ts/upload/5e/5c/41/0088cb187c5dc73250d4ff5cb7ea96e5.png', height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(height: 120, color: Colors.blue.shade50, child: Center(child: Text('Banner Khuyến Mãi', style: TextStyle(color: navyBlue))))),
              ),
            ),
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double percent) {
    return Row(
      children: [
        SizedBox(width: 35, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Icon(Icons.star, color: Colors.grey, size: 10),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(height: 6, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(widthFactor: percent, child: Container(height: 6, decoration: BoxDecoration(color: starColor, borderRadius: BorderRadius.circular(3)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(String imageUrl, {required bool isVideo}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(imageUrl, width: 140, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(width: 140, color: Colors.grey[300])),
          if (isVideo) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white)),
        ],
      ),
    );
  }

  // ✅ ĐÃ SỬA: THANH BOTTOM BAR BIẾN ĐỔI THEO TRẠNG THÁI PHIM SẮP CHIẾU
  Widget _buildBottomBar(Color primaryColor) {
    bool isUpcoming = _isUpcomingMovie(); 

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), 
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isUpcoming ? Colors.grey.shade400 : primaryColor, 
                padding: const EdgeInsets.symmetric(vertical: 14), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                elevation: 0
              ),
              onPressed: isUpcoming 
                  ? null // Phim sắp chiếu -> Disable nút không cho bấm
                  : () => Navigator.push(context, MaterialPageRoute(builder: (blocContext) => BlocProvider.value(value: context.read<MovieBloc>(), child: CinemaSelectionPage(movie: widget.movie)))),
              child: Text(
                isUpcoming ? 'Sắp chiếu (Coming soon)' : 'Mua vé', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap ?? () {}, 
      icon: Icon(icon, size: 16, color: navyBlue), 
      label: Text(label, style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8), 
        side: BorderSide(color: navyBlue.withOpacity(0.3)), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 6),
        Text(value, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3, color: navyBlue)),
      ],
    );
  }

  Widget _buildErrorImage() => Container(height: 110, width: 100, color: Colors.grey.shade200, child: const Icon(Icons.person, color: Colors.grey, size: 40));
  
  Color _getAgeColor(String? age) {
    if (age == null) return Colors.green;
    if (age.contains('18')) return Colors.red;
    if (age.contains('16')) return Colors.orange;
    if (age.contains('13')) return Colors.orange.shade300;
    return Colors.green;
  }
}

// ============================================================================
// 2. MÀN HÌNH DANH SÁCH ĐÁNH GIÁ (Giữ nguyên)
// ============================================================================
class ReviewListPage extends StatelessWidget {
  final Movie movie;
  final Color navyBlue;
  final Color starColor;

  const ReviewListPage({super.key, required this.movie, required this.navyBlue, required this.starColor});

  @override
  Widget build(BuildContext context) {
    double rating = movie.voteAverage ?? 9.7;
    String formattedRating = rating.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), 
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false, titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue))),
            const SizedBox(width: 12),
            Expanded(child: Text('Đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]))),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity, color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('Đánh giá của ', style: TextStyle(fontSize: 14, color: Colors.black87)),
                  Expanded(child: Text('${movie.title} >', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: navyBlue), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            Container(
              width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng quan đánh giá', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Icon(Icons.star, color: starColor, size: 28), const SizedBox(width: 4),
                                      Text(formattedRating, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                                      const Padding(padding: EdgeInsets.only(bottom: 4.0), child: Text('/10', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Đánh giá', style: TextStyle(fontSize: 12, color: Colors.grey)), 
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildRatingBar('9-10', 0.85), const SizedBox(height: 6),
                                  _buildRatingBar('7-8', 0.1), const SizedBox(height: 6),
                                  _buildRatingBar('5-6', 0.02), const SizedBox(height: 6),
                                  _buildRatingBar('3-4', 0.0), const SizedBox(height: 6),
                                  _buildRatingBar('1-2', 0.03),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16), const Divider(), const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [_buildTagChip('Đáng xem'), _buildTagChip('Tuyệt vời'), _buildTagChip('Ý nghĩa'), _buildTagChip('Cảm động'), _buildTagChip('Khóc trôi rạp')],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Danh sách bài viết', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WriteReviewPage(movieTitle: movie.title, posterPath: movie.posterPath))),
                          child: Text('Viết đánh giá', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.pink.shade400)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('Có hình ảnh', false),
                        _buildFilterChip('⭐ 10', true), 
                        _buildFilterChip('⭐ 9', false),
                        _buildFilterChip('⭐ 8', false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.speaker_notes_off_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text("Chưa có đánh giá nào.\nHãy là người đầu tiên đánh giá!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double percent) {
    return Row(
      children: [
        SizedBox(width: 35, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const Icon(Icons.star, color: Colors.grey, size: 10), const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(height: 6, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(widthFactor: percent, child: Container(height: 6, decoration: BoxDecoration(color: starColor, borderRadius: BorderRadius.circular(3)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(String label) {
    return Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)));
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: isSelected ? Colors.orange.shade50 : Colors.white, border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade300), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.orange.shade800 : Colors.black87)),
    );
  }
}

// ============================================================================
// 3. MÀN HÌNH VIẾT ĐÁNH GIÁ (Giữ nguyên)
// ============================================================================
class WriteReviewPage extends StatefulWidget {
  final String movieTitle;
  final String posterPath; 
  const WriteReviewPage({super.key, required this.movieTitle, required this.posterPath});

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  final Color navyBlue = Colors.blue.shade900;
  int _selectedStar = 0;
  double _helpfulSliderValue = 1.0; 
  
  File? _selectedImage;
  File? _selectedVideo;
  final ImagePicker _picker = ImagePicker();

  void _updateHelpfulSlider() {
    double val = 1.0;
    if (_selectedStar == 10) val = 2.0; 
    if (_selectedImage != null || _selectedVideo != null) val = 3.0; 
    
    setState(() {
      _helpfulSliderValue = val;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedVideo = null; 
        });
        _updateHelpfulSlider();
      }
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _selectedImage = null; 
        });
        _updateHelpfulSlider();
      }
    } catch (e) {
      debugPrint("Lỗi chọn video: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false, titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Viết đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(widget.posterPath, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 40, height: 40, color: Colors.grey, child: const Icon(Icons.movie, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.movieTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 30),
            
            const Center(child: Text('Nhấn để đánh giá', style: TextStyle(color: Colors.grey, fontSize: 13))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(10, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStar = index + 1);
                    _updateHelpfulSlider(); 
                  },
                  child: Icon(index < _selectedStar ? Icons.star : Icons.star_border, color: index < _selectedStar ? Colors.orange : Colors.grey.shade300, size: 30),
                );
              }),
            ),
            const SizedBox(height: 30),

            const Text('Cảm nhận thêm về bộ phim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              height: 150, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: TextField(maxLines: null, decoration: InputDecoration(hintText: 'Giờ là lúc ngôn từ lên ngôi ✍️', border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)))),
                  Align(alignment: Alignment.bottomRight, child: Text('0/10000', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: _selectedImage != null 
                    ? _buildMediaPreview(FileImage(_selectedImage!), isVideo: false)
                    : _buildAddMediaBox(Icons.add_a_photo_outlined, 'Thêm ảnh', false),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickVideo,
                  child: _selectedVideo != null
                    ? _buildMediaPreview(null, isVideo: true)
                    : _buildAddMediaBox(Icons.videocam_outlined, 'Thêm video\n(Tối đa 30MB)', true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('*Chỉ thêm 1 video hoặc nhiều ảnh. Không thể đăng cả hai.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mức độ giúp ích người dùng khác:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Slider(
                    value: _helpfulSliderValue, min: 1, max: 3, divisions: 2, 
                    activeColor: Colors.orange, inactiveColor: Colors.grey.shade200, 
                    onChanged: (val) => setState(() => _helpfulSliderValue = val)
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text('Khá', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('Tốt', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('Tuyệt vời', style: TextStyle(color: Colors.grey, fontSize: 12))],
                  ),
                  const SizedBox(height: 16), const Divider(), const SizedBox(height: 8),
                  const Text('Bạn có thể giúp ích người dùng khác bằng cách:\n⭐ Nhấn đánh giá sao', style: TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(children: [Text('Đánh giá của bạn sẽ hiển thị công khai trên STU Cinema ', style: TextStyle(color: Colors.grey, fontSize: 12)), Icon(Icons.info_outline, size: 14, color: Colors.grey)]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                onPressed: () {}, child: const Text('Gửi đánh giá', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMediaBox(IconData icon, String label, bool isNew) {
    return Container(
      width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid, width: 1.5), borderRadius: BorderRadius.circular(12)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.grey.shade600, size: 28), const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          if (isNew) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(6)), child: const Text('Mới', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(ImageProvider? image, {required bool isVideo}) {
    return Container(
      width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: Colors.orange, width: 2), borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!isVideo && image != null) Image(image: image, width: 100, height: 100, fit: BoxFit.cover),
            if (isVideo) Container(color: Colors.grey.shade800, width: 100, height: 100),
            if (isVideo) const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
            Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. DIALOG PHÁT TRAILER CÓ NÚT "X" ĐỂ ĐÓNG
// ============================================================================
// ============================================================================
// 4. DIALOG PHÁT TRAILER (HỖ TRỢ FULL MÀN HÌNH KHI QUAY NGANG)
// ============================================================================
class TrailerDialog extends StatefulWidget {
  final String youtubeUrl;
  const TrailerDialog({super.key, required this.youtubeUrl});

  @override
  State<TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<TrailerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl) ?? 'TcMBFSGVi1c'; 
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true, 
        mute: false,
        // Có thể thêm hideThumbnail: true nếu muốn mượt hơn
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra xem điện thoại đang cầm dọc hay ngang
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: Colors.black, // ✅ Đổi thành nền đen cho chuẩn rạp phim
      elevation: 0,
      insetPadding: EdgeInsets.zero, // ✅ QUAN TRỌNG NHẤT: Ép mất viền, tràn 100% màn hình
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: isLandscape ? MediaQuery.of(context).size.height : null, // Xoay ngang thì ép chiều cao 100%
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // TRÌNH PHÁT VIDEO NẰM CHÍNH GIỮA
            Center(
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red, 
              ),
            ),
            
            // ✅ NÚT X ĐÓNG VIDEO NẰM TRÊN CÙNG BÊN PHẢI
            SafeArea( // Dùng SafeArea để khi quay ngang nút X không bị lẹm vào tai thỏ (Notch)
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}