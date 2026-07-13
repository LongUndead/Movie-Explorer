import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/entities/movie.dart'; 
import 'write_review_page.dart';
import 'user_manager.dart';
import 'review_detail_page.dart';
import 'movie_detail_page.dart';

class ReviewListPage extends StatefulWidget {
  final Movie movie;
  final Color navyBlue;
  final Color starColor;

  const ReviewListPage({
    super.key, 
    required this.movie, 
    required this.navyBlue, 
    required this.starColor
  });

  @override
  State<ReviewListPage> createState() => _ReviewListPageState();
}

class _ReviewListPageState extends State<ReviewListPage> {
  final String apiBaseUrl = 'http://192.168.1.2:3000';
  List<dynamic> _allReviews = [];
  bool _isLoading = true;
  OverlayEntry? _overlayEntry;

  String _mediaFilter = 'all'; 
  int? _starFilter; 

  @override
  void initState() {
    super.initState();
    _fetchMovieReviews();
  }

  Future<void> _fetchMovieReviews() async {
    final user = UserManager.instance.currentUser;
    int userId = user?.id ?? 0;
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/movies/${widget.movie.id}/reviews?user_id=$userId'));
      if (res.statusCode == 200) {
        if (mounted) setState(() { _allReviews = jsonDecode(res.body); _isLoading = false; });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====================================================================
  // BỘ TÍNH NĂNG TƯƠNG TÁC LIKE / CẢM XÚC (ĐÃ SỬA LỖI KIỂU DỮ LIỆU DART)
  // ====================================================================
  Future<void> _reactToReview(int commentId, String reactionType) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    setState(() {
      int index = _allReviews.indexWhere((r) => r['commentId'] == commentId);
      if (index != -1) {
        var review = _allReviews[index];
        String currentReaction = review['userReaction']?.toString() ?? '';
        
        // ✅ ĐÃ FIX LỖI TẠI ĐÂY: Ép kiểu rõ ràng sang String trước khi xử lý mảng
        String topReactionsStr = review['topReactions']?.toString() ?? '';
        List<String> topReactionsList = topReactionsStr.split(',').where((String e) => e.trim().isNotEmpty).toList();

        if (currentReaction == reactionType) {
          // TRƯỜNG HỢP 1: Bấm lại icon cũ -> HỦY thả cảm xúc
          review['userReaction'] = '';
          if ((review['likeCount'] ?? 0) > 0) review['likeCount']--;
          
          topReactionsList.remove(reactionType);
        } else {
          // TRƯỜNG HỢP 2: Đổi icon mới hoặc Thả cảm xúc lần đầu
          if (currentReaction.isEmpty) {
            review['likeCount'] = (review['likeCount'] ?? 0) + 1;
          } else {
            topReactionsList.remove(currentReaction);
          }
          
          review['userReaction'] = reactionType;
          
          if (!topReactionsList.contains(reactionType)) {
            topReactionsList.insert(0, reactionType);
          }
        }

        // Gắn lại chuỗi sau khi xử lý xong
        review['topReactions'] = topReactionsList.join(',');
      }
    });

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/movies/reviews/react'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id, 'comment_id': commentId, 'reaction_type': reactionType})
      );
      _fetchMovieReviews();
    } catch (e) {}
  }

  void _showReactionOverlay(BuildContext context, Offset tapPosition, int commentId) {
    if (_overlayEntry != null) return;
    double screenWidth = MediaQuery.of(context).size.width;
    double leftPos = tapPosition.dx - 140; 
    if (leftPos < 10) leftPos = 10;
    if (leftPos + 280 > screenWidth - 10) leftPos = screenWidth - 290;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(onTap: _removeReactionOverlay, child: Container(color: Colors.transparent))),
            Positioned(
              left: leftPos, top: tapPosition.dy - 70, 
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildOverlayEmoji(commentId, 'like', '👍'),
                      _buildOverlayEmoji(commentId, 'love', '❤️'),
                      _buildOverlayEmoji(commentId, 'haha', '😆'),
                      _buildOverlayEmoji(commentId, 'wow', '😮'),
                      _buildOverlayEmoji(commentId, 'sad', '😢'),
                      _buildOverlayEmoji(commentId, 'angry', '😡'),
                    ],
                  ),
                ),
              ),
            )
          ],
        );
      }
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlayEmoji(int commentId, String type, String emoji) {
    return GestureDetector(
      onTap: () { _removeReactionOverlay(); _reactToReview(commentId, type); },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(emoji, style: const TextStyle(fontSize: 28))),
    );
  }

  void _removeReactionOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ====================================================================

  List<dynamic> get _filteredReviews {
    return _allReviews.where((review) {
      if (_mediaFilter == 'has_image') {
        bool hasImg = review['image'] != null && review['image'].toString().isNotEmpty;
        if (!hasImg) return false;
      }
      if (_starFilter != null) {
        double reviewRating = double.tryParse(review['rating'].toString()) ?? 0.0;
        if (reviewRating.toInt() != _starFilter) return false;
      }
      return true;
    }).toList();
  }

  void _showStarFilterBottomSheet() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text('Lọc theo số sao', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.navyBlue))),
              const Divider(),
              ListTile(
                leading: Icon(Icons.stars_rounded, color: widget.starColor),
                title: const Text('Tất cả số sao', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _starFilter == null ? Icon(Icons.check_circle, color: widget.navyBlue) : null,
                onTap: () { setState(() => _starFilter = null); Navigator.pop(context); },
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true, itemCount: 10,
                  itemBuilder: (ctx, index) {
                    int starValue = 10 - index;
                    bool isSelected = _starFilter == starValue;
                    return ListTile(
                      leading: Icon(Icons.star, color: widget.starColor),
                      title: Text('$starValue sao', style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: isSelected ? Icon(Icons.check_circle, color: widget.navyBlue) : null,
                      onTap: () { setState(() => _starFilter = starValue); Navigator.pop(context); },
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

  String _getRealImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) return "";
    if (rawPath.startsWith("http")) return rawPath;
    return "$apiBaseUrl/uploads/$rawPath"; 
  }

  String _getRatingText(double score) {
    if (score >= 9) return "Cực phẩm!";
    if (score >= 7) return "Rất hay!";
    if (score >= 5) return "Xem ổn!";
    if (score >= 3) return "Hơi chán";
    return "Quá tệ!";
  }

  // ✅ HÀM XỬ LÝ THỜI GIAN THEO CHUẨN FACEBOOK
  String _getTimeAgo(String? rawDateStr) {
    if (rawDateStr == null || rawDateStr.isEmpty) return "Vừa xong";
    try {
      DateTime parsedDate = DateTime.parse(rawDateStr).toLocal();
      Duration diff = DateTime.now().difference(parsedDate);

      if (diff.isNegative || diff.inMinutes < 1) return "Vừa xong";
      if (diff.inHours < 1) return "${diff.inMinutes} phút trước";
      if (diff.inDays < 1) return "${diff.inHours} giờ trước";
      if (diff.inDays < 7) return "${diff.inDays} ngày trước";
      if (diff.inDays < 30) return "${diff.inDays ~/ 7} tuần trước";
      if (diff.inDays < 365) return "${diff.inDays ~/ 30} tháng trước";
      return "${diff.inDays ~/ 365} năm trước";
    } catch (e) {
      // Nếu Backend chưa trả về chuẩn ISO mà vẫn trả dạng ngày tháng cũ thì giữ nguyên
      return rawDateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsList = _filteredReviews;
    double rating = widget.movie.voteAverage ?? 9.7;
    String formattedRating = rating.toStringAsFixed(1);
    String totalReviewText = _allReviews.length >= 1000 ? '${(_allReviews.length / 1000).toStringAsFixed(1)}k' : _allReviews.length.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F9), 
      // ✅ ĐÃ THÊM ICON CHUÔNG VÀ NGÔI NHÀ VÀO APPBAR
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false, titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.arrow_back_ios_new, size: 18, color: widget.navyBlue))),
            const SizedBox(width: 12),
            Expanded(child: Text('Đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: widget.navyBlue))),
          ],
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]))),
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
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.notifications_outlined, color: widget.navyBlue, size: 18))
                ),
                Container(height: 16, width: 1, color: widget.navyBlue.withOpacity(0.2)),
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)), 
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.home_outlined, color: widget.navyBlue, size: 18))
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.navyBlue))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ ĐÃ THÊM GESTURE DETECTOR ĐỂ BẤM VÀO TÊN PHIM LÀ CHUYỂN TRANG
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MovieDetailPage(movie: widget.movie),
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              text: 'Đánh giá của ',
                              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                              children: [
                                TextSpan(
                                  text: '${widget.movie.title} >', 
                                  style: TextStyle(color: widget.navyBlue, fontWeight: FontWeight.bold)
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Tổng quan đánh giá', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.navyBlue))),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.fromLTRB(16, 24, 16, 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Icon(Icons.star, color: widget.starColor, size: 32), const SizedBox(width: 4),
                                          Text(formattedRating, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.0, color: widget.navyBlue)),
                                          const Padding(padding: EdgeInsets.only(bottom: 4.0), child: Text('/10', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('($totalReviewText Đánh giá)', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)), 
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Container(
                        width: double.infinity, color: Colors.white, 
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Danh sách bài viết', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.navyBlue)),
                                  GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(context, MaterialPageRoute(builder: (_) => WriteReviewPage(movieId: widget.movie.id, movieTitle: widget.movie.title, posterPath: widget.movie.posterPath)));
                                      _fetchMovieReviews(); 
                                    },
                                    child: Text('Viết đánh giá', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.navyBlue)),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  _buildMediaTabButton('Tất cả', 'all'), const SizedBox(width: 8),
                                  _buildMediaTabButton('Có hình ảnh', 'has_image'),
                                  const Spacer(),
                                  InkWell(
                                    onTap: _showStarFilterBottomSheet, borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _starFilter != null ? widget.starColor : Colors.grey.shade300)),
                                      child: Row(
                                        children: [
                                          Icon(Icons.star, color: widget.starColor, size: 16), const SizedBox(width: 4),
                                          Text(_starFilter == null ? 'Tất cả sao' : '$_starFilter sao', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _starFilter != null ? Colors.orange.shade900 : Colors.black87)),
                                          const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // ==========================================
                // KHUNG HIỂN THỊ REVIEW POST
                // ==========================================
                reviewsList.isEmpty
                    ? SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.only(top: 40, bottom: 80),
                          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.speaker_notes_off_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text("Không tìm thấy đánh giá nào!", style: TextStyle(color: Colors.grey.shade600, fontSize: 14))])),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildReviewPostCard(reviewsList[index]);
                          },
                          childCount: reviewsList.length,
                        ),
                      ),
              ],
            ),
    );
  }

  // ==============================================================
  // API: XÓA ĐÁNH GIÁ VÀ MENU TÙY CHỌN (DẤU 3 CHẤM)
  // ==============================================================
  Future<void> _deleteReviewApi(int commentId) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    // Xóa tạm trên giao diện trước cho mượt
    setState(() {
      _allReviews.removeWhere((r) => r['commentId'] == commentId);
    });

    try {
      await http.delete(
        Uri.parse('$apiBaseUrl/api/group/comments/$commentId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id}),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bài đánh giá!')));
    } catch (e) {
      // Nếu lỗi thì gọi API load lại danh sách
      _fetchMovieReviews();
    }
  }

  void _showReviewOptionsModal(Map<String, dynamic> review) {
    final currentUserId = UserManager.instance.currentUser?.id;
    
    // Kiểm tra xem user hiện tại có phải tác giả bài viết không
    bool isAuthor = false;
    if (review['userId'] != null || review['UserID'] != null) {
      isAuthor = (review['userId'] ?? review['UserID']).toString() == currentUserId.toString();
    } else {
      // Backup: Nếu Backend chưa trả về userID, so sánh tạm bằng tên
      isAuthor = review['username'].toString().toLowerCase() == UserManager.instance.currentUser?.name.toLowerCase();
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            if (isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                title: const Text('Chỉnh sửa đánh giá', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context); 
                  
                  // ✅ TÁI SỬ DỤNG TRANG WRITE_REVIEW_PAGE: Truyền review data sang
                  await Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => WriteReviewPage(
                        movieId: widget.movie.id, 
                        movieTitle: widget.movie.title, 
                        posterPath: widget.movie.posterPath,
                        existingReview: review, // Truyền map review cũ sang đây!
                      )
                    )
                  );
                  
                  // Load lại danh sách sau khi sửa xong
                  _fetchMovieReviews();
                }
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa đánh giá', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteReviewApi(review['commentId']); 
                }
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                title: const Text('Báo cáo đánh giá', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi báo cáo vi phạm!')));
                }
              ),
            ],
          ]
        )
      )
    );
  }

  // ==============================================================
  // WIDGET HIỂN THỊ REVIEW Y HỆT BÀI ĐĂNG FACEBOOK 
  // ==============================================================
  Widget _buildReviewPostCard(Map<String, dynamic> review) {
    bool hasCommentImg = review['image'] != null && review['image'].toString().isNotEmpty;
    double score = double.tryParse(review['rating'].toString()) ?? 0.0;
    
    // LẤY RA TRẠNG THÁI MUA VÉ TỪ BACKEND
    bool hasBoughtTicket = review['hasBoughtTicket'] == true || review['hasBoughtTicket'] == 1;

    int likeCount = review['likeCount'] ?? 0;
    int replyCount = review['replyCount'] ?? 0;
    String userReaction = review['userReaction'] ?? '';
    bool isReacted = userReaction.isNotEmpty;

    // Phân giải Tags
    List<Widget> tagWidgets = [];
    String tagsStr = review['tags'] ?? ''; 
    if (tagsStr.isNotEmpty) {
      List<String> tags = tagsStr.split(',');
      tagWidgets = tags.map((t) => _buildTagChip(t.trim())).toList();
    }

    Widget reactionIcon = Icon(Icons.thumb_up_alt_outlined, color: Colors.grey.shade700, size: 18);
    String reactionText = "Thích";
    Color reactionColor = Colors.grey.shade700;

    if (isReacted) {
      if (userReaction == 'like') { reactionIcon = Icon(Icons.thumb_up, color: widget.navyBlue, size: 18); reactionText = "Thích"; reactionColor = widget.navyBlue; }
      else if (userReaction == 'love') { reactionIcon = const Text('❤️', style: TextStyle(fontSize: 16)); reactionText = "Yêu thích"; reactionColor = Colors.red; }
      else if (userReaction == 'haha') { reactionIcon = const Text('😆', style: TextStyle(fontSize: 16)); reactionText = "Haha"; reactionColor = Colors.orange; }
      else if (userReaction == 'wow') { reactionIcon = const Text('😮', style: TextStyle(fontSize: 16)); reactionText = "Wow"; reactionColor = Colors.orange; }
      else if (userReaction == 'sad') { reactionIcon = const Text('😢', style: TextStyle(fontSize: 16)); reactionText = "Buồn"; reactionColor = Colors.orange; }
      else if (userReaction == 'angry') { reactionIcon = const Text('😡', style: TextStyle(fontSize: 16)); reactionText = "Phẫn nộ"; reactionColor = Colors.red.shade700; }
    }

    Widget summaryReactionIcon = const SizedBox.shrink();
    if (likeCount > 0) {
      String topReactionsStr = review['topReactions'] ?? 'like'; 
      List<String> actualReactions = topReactionsStr.split(',').where((e) => e.isNotEmpty).toList();
      if (actualReactions.isEmpty) actualReactions = ['like']; 

      List<Widget> stackChildren = [];
      if (actualReactions.length > 1) stackChildren.add(Transform.translate(offset: const Offset(12, 0), child: _getIconByType(actualReactions[1])));
      stackChildren.add(_getIconByType(actualReactions[0]));

      summaryReactionIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(clipBehavior: Clip.none, children: stackChildren),
          SizedBox(width: actualReactions.length > 1 ? 18 : 8),
          Text(likeCount.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
        ],
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🚀 ĐÃ SỬA: Gọi hàm vẽ Avatar siêu mượt
                _buildAvatar(review['avatar']?.toString(), 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      // ✅ ĐÃ SỬA LỖI TÊN BỊ DẤU ... (Bỏ maxLines: 1 và overflow: TextOverflow.ellipsis)
                      Text(review['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(_getTimeAgo(review['rawDate'] ?? review['date']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          const SizedBox(width: 4),
                          Icon(Icons.public, color: Colors.grey.shade400, size: 12)
                        ],
                      )
                    ]
                  )
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz, color: Colors.grey.shade600),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => _showReviewOptionsModal(review),
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // 2. RATING & TEXT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: widget.starColor, size: 18),
                    const SizedBox(width: 6),
                    Text('${score.toInt()}/10 - ${_getRatingText(score)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasBoughtTicket ? "Đã mua qua Cinema Tickets" : "Chưa mua vé phim", 
                  style: TextStyle(color: hasBoughtTicket ? Colors.orange.shade700 : Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 8),
                
                if (review['comment'].toString().isNotEmpty) 
                  RichText(
                    text: TextSpan(
                      text: review['comment'].toString().length > 150 ? '${review['comment'].toString().substring(0, 150)}... ' : review['comment'],
                      style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                      children: [
                        if (review['comment'].toString().length > 150)
                          TextSpan(text: "xem thêm", style: TextStyle(color: Colors.pink.shade500, fontWeight: FontWeight.bold)),
                      ]
                    )
                  ),
                const SizedBox(height: 12),

                // ✅ ĐÃ SỬA: Bọc danh sách Tag trong SingleChildScrollView để vuốt ngang
                if (tagWidgets.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(), // Hiệu ứng nảy mượt mà của iOS
                    child: Row(
                      children: tagWidgets,
                    ),
                  ),
              ],
            ),
          ),
          // 3. ẢNH ĐÍNH KÈM
          if (hasCommentImg) 
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Image.network(_getRealImageUrl(review['image']), width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=> const SizedBox.shrink()),
            ),
          
          // 4. SUMMARY REACTIONS (✅ FIX CỨNG CHIỀU CAO TRÁNH NHẢY LAYOUT)
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 20, // Ép cứng chiều cao dòng thả tim, từ 0 lên 1 like sẽ không bị giật xuống
              child: Row(
                children: [
                  summaryReactionIcon,
                  const Spacer(),
                  // ✅ NẾU CÓ BÌNH LUẬN THÌ HIỆN (SẼ NHẢY SỐ NGAY LẬP TỨC NHỜ SETSTATE Ở DƯỚI)
                  if (replyCount > 0)
                    Text("$replyCount bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16), child: Divider(height: 1)),
          
          // 5. THANH BUTTON 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      String targetReaction = isReacted ? userReaction : 'like';
                      _reactToReview(review['commentId'], targetReaction);
                    }, 
                    onLongPressStart: (details) { _showReactionOverlay(context, details.globalPosition, review['commentId']); },
                    child: Container(
                      height: 36, // Chiều cao cố định chống giật
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          SizedBox(width: 24, height: 24, child: Center(child: reactionIcon)), 
                          const SizedBox(width: 4), 
                          // ✅ ĐÃ SỬA: Loại bỏ Flexible để chữ không bị cắt thành dấu `...` khi có màn hình chật
                          Text(reactionText, style: TextStyle(color: reactionColor, fontWeight: FontWeight.w600, fontSize: 13))
                        ]
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Khoảng cách giữa các box
                Expanded(
                  child: InkWell(
                    onTap: () async { 
                      final updatedReview = await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ReviewDetailPage(
                          review: review, 
                          movie: widget.movie, 
                          navyBlue: widget.navyBlue, 
                          starColor: widget.starColor
                        )
                      ));
                      
                      // ✅ ÉP CẬP NHẬT GIAO DIỆN NGAY LẬP TỨC 
                      if (updatedReview != null && updatedReview is Map<String, dynamic>) {
                        setState(() {
                          int index = _allReviews.indexWhere((r) => r['commentId'] == updatedReview['commentId']);
                          if (index != -1) {
                            _allReviews[index] = updatedReview; 
                          }
                        });
                      }
                      
                      // 🔄 SAU KHI CẬP NHẬT TẠM, MỚI GỌI API ĐỂ ĐỒNG BỘ LẠI TỪ SERVER
                      _fetchMovieReviews();
                    },
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          SizedBox(width: 24, height: 24, child: Center(child: Icon(Icons.chat_bubble_outline, color: Colors.grey.shade700, size: 18))), 
                          const SizedBox(width: 4), 
                          // ✅ ĐÃ SỬA: Loại bỏ Flexible để chữ không bị cắt thành dấu `...`
                          Text("Bình luận", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13))
                        ]
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Khoảng cách giữa các box
                Expanded(
                  child: InkWell(
                    onTap: () {
                      // ✅ GỌI BẢNG CHIA SẺ CỦA HỆ ĐIỀU HÀNH
                      // Truyền vào đoạn nội dung và đường link bạn muốn share
                      final String shareText = "Xem ngay đánh giá cực chất này trên App!\nhttps://cinematickets.vn/review/${review['commentId']}";
                      
                      Share.share(
                        shareText,
                        subject: 'Chia sẻ đánh giá phim', // Dành cho trường hợp user chọn share qua Email
                      );
                    },
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          SizedBox(width: 24, height: 24, child: Center(child: Icon(Icons.shortcut, color: Colors.grey.shade700, size: 18))), 
                          const SizedBox(width: 4), 
                          Text("Chia sẻ", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13))
                        ]
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16), child: Divider(height: 1)),

          // 6. KHUNG BÌNH LUẬN ẢO DƯỚI CÙNG
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
               // 🚀 ĐÃ SỬA: Gọi hàm vẽ Avatar của User hiện tại
               _buildAvatar(UserManager.instance.currentUser?.avatar, 32),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async { 
                      // ✅ NẾU BẤM VÀO ĐÂY CŨNG CHO NHẢY VÀO TRANG CHI TIẾT ĐỂ BÌNH LUẬN
                      final updatedReview = await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ReviewDetailPage(
                          review: review, 
                          movie: widget.movie, 
                          navyBlue: widget.navyBlue, 
                          starColor: widget.starColor
                        )
                      ));
                      if (updatedReview != null && updatedReview is Map<String, dynamic>) {
                        setState(() {
                          int index = _allReviews.indexWhere((r) => r['commentId'] == updatedReview['commentId']);
                          if (index != -1) {
                            _allReviews[index] = updatedReview; 
                          }
                        });
                      }
                      _fetchMovieReviews();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Text(replyCount == 0 ? "Trở thành người đầu tiên bình luận" : "Để lại bình luận của bạn...", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ),
                  )
                )
              ],
            ),
          )
        ],
      ),
    );
  }
  
  // ==============================================================
  // CÁC HÀM HỖ TRỢ VẼ UI PHỤ
  // ==============================================================
  Widget _buildRatingBar(String label, double percent) {
    return Row(
      children: [
        SizedBox(width: 35, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500))),
        const Icon(Icons.star, color: Color(0xFFE0E0E0), size: 12), const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(widthFactor: percent, child: Container(height: 6, decoration: BoxDecoration(color: widget.starColor, borderRadius: BorderRadius.circular(3)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 10), 
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), 
      child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600))
    );
  }

  Widget _buildMediaTabButton(String label, String key) {
    bool isSelected = _mediaFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _mediaFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.grey.shade800 : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.grey.shade800 : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildCircleIcon(Widget child, Color bgColor) {
    return Container(width: 18, height: 18, decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]), alignment: Alignment.center, child: child);
  }

  Widget _getIconByType(String type) {
    if (type == 'love') return _buildCircleIcon(const Icon(Icons.favorite, color: Colors.white, size: 10), Colors.red);
    if (type == 'haha') return _buildCircleIcon(const Text('😆', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'wow') return _buildCircleIcon(const Text('😮', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'sad') return _buildCircleIcon(const Text('😢', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'angry') return _buildCircleIcon(const Text('😡', style: TextStyle(fontSize: 10)), Colors.white);
    return _buildCircleIcon(const Icon(Icons.thumb_up, color: Colors.white, size: 10), widget.navyBlue);
  }
  // ==============================================================
  // ✅ HÀM HỖ TRỢ VẼ AVATAR BẤT TỬ (CÓ GẮN MẮT THẦN DEBUG)
  // ==============================================================
  Widget _buildAvatar(String? avatarUrl, double size) {
    String finalUrl = '';
    
    // Lọc sạch dữ liệu rác, null, khoảng trắng
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty && avatarUrl != 'null') {
      finalUrl = avatarUrl.startsWith('http')
          ? avatarUrl
          : '$apiBaseUrl${avatarUrl.startsWith('/') ? '' : '/'}$avatarUrl';
    }

    // 🚀 [MẮT THẦN 1] IN RA ĐƯỜNG LINK ĐỂ XEM APP CÓ NHẬN ĐƯỢC KHÔNG
    debugPrint("=== [DEBUG AVATAR] LINK GỐC TỪ DB: $avatarUrl");
    debugPrint("=== [DEBUG AVATAR] LINK CUỐI CÙNG: $finalUrl");

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: finalUrl.isNotEmpty
            ? Image.network(
                finalUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 🚀 [MẮT THẦN 2] NẾU TẢI ẢNH THẤT BẠI, IN RA RÕ LÝ DO!
                  debugPrint("❌ [DEBUG AVATAR] LỖI TẢI ẢNH: $error");
                  return Icon(Icons.person, color: Colors.blue.shade200, size: size * 0.6);
                },
              )
            : Icon(Icons.person, color: Colors.blue.shade200, size: size * 0.6),
      ),
    );
  }
}
