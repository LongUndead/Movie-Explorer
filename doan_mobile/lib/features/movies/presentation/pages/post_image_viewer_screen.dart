import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Import 2 file này để dùng được tính năng bấm vào thẻ phim nhảy sang Đặt vé
import '../../domain/entities/movie.dart'; 
import 'movie_detail_page.dart';

// ============================================================================
// 🚀 TRANG CHI TIẾT BÀI VIẾT (CHUẨN GIAO DIỆN APP ĐỒNG BỘ MÀU XANH NAVY)
// ============================================================================
class PostImageViewerScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  final List<String> images;
  final String apiBaseUrl;
  final VoidCallback onCommentTapped;

  const PostImageViewerScreen({
    super.key,
    required this.post,
    required this.images,
    required this.apiBaseUrl,
    required this.onCommentTapped,
  });

  // ==============================================================
  // 1. HÀM XỬ LÝ LINK ẢNH (BỌC THÉP TẦNG 2 CHỐNG JSON RÁC - FIX LỖI 404)
  // ==============================================================
  String _getRealImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null' || rawPath == '[]') return "";
    
    // 🚀 TUYỆT CHIÊU TRỊ LỖI 404 NẰM Ở ĐÂY: Xóa sạch ngoặc vuông, ngoặc kép bị dính
    String cleanPath = rawPath.trim().replaceAll('\\', '/').replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    if (cleanPath.isEmpty) return "";

    if (cleanPath.startsWith('http')) {
      if (cleanPath.contains(':3000')) {
        final parts = cleanPath.split(':3000');
        if (parts.length > 1) {
          String subPath = parts[1].replaceFirst('/public', '');
          if (!subPath.startsWith('/')) subPath = '/$subPath';
          return '$apiBaseUrl$subPath';
        }
      }
      return cleanPath;
    }

    cleanPath = cleanPath.replaceFirst('/public', '').replaceFirst('public/', '');
    String filename = cleanPath.split('/').last;

    bool isLocalImage = cleanPath.contains('upload') || filename.contains('image') || filename.contains('movie-') || filename.contains('_') || filename.contains('-');

    if (isLocalImage) {
      if (filename.startsWith('food')) return '$apiBaseUrl/foods/$filename';
      if (filename.startsWith('avatar') || filename.startsWith('user')) return '$apiBaseUrl/avatars/$filename';
      return '$apiBaseUrl/uploads/$filename';
    } else {
      if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
      return 'https://image.tmdb.org/t/p/w500$cleanPath';
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return "Vừa xong";
    try { return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(isoTime).toLocal()); } catch (_) { return "Vừa xong"; }
  }

  // ==============================================================
  // 2. HÀM VẼ AVATAR NGƯỜI ĐĂNG BÀI (ĐÃ TỐI ƯU ĐỘC LẬP)
  // ==============================================================
  Widget _buildAvatar(String? avatarUrl, String fallbackName, double size) {
    String finalUrl = _getRealImageUrl(avatarUrl);
    final Color navyBlue = Colors.blue.shade900;
    
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
                errorBuilder: (_, __, ___) => Center(child: Text(fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4)))
              )
            : Center(child: Text(fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4))),
      ),
    );
  }

  // ==============================================================
  // 3. HÀM VẼ ICON CẢM XÚC NHỎ XÍU
  // ==============================================================
  Widget _buildCircleIcon(Widget child, Color bgColor) {
    return Container(
      width: 16, height: 16,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1)),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _getIconByType(String type, Color navyBlue) {
    if (type == 'love') return _buildCircleIcon(const Icon(Icons.favorite, color: Colors.white, size: 9), Colors.red);
    if (type == 'haha') return _buildCircleIcon(const Text('😆', style: TextStyle(fontSize: 9)), Colors.white);
    if (type == 'wow') return _buildCircleIcon(const Text('😮', style: TextStyle(fontSize: 9)), Colors.white);
    if (type == 'sad') return _buildCircleIcon(const Text('😢', style: TextStyle(fontSize: 9)), Colors.white);
    if (type == 'angry') return _buildCircleIcon(const Text('😡', style: TextStyle(fontSize: 9)), Colors.white);
    return _buildCircleIcon(const Icon(Icons.thumb_up, color: Colors.white, size: 9), navyBlue);
  }

  // ====================================================================
  // 🚀 BOTTOM SHEET: DANH SÁCH NGƯỜI THẢ CẢM XÚC (Y CHANG FACEBOOK)
  // ====================================================================
  void _showReactionDetailsBottomSheet(BuildContext context, int postId, Color navyBlue) {
    // 🚀 Tự động phân luồng API: Đánh giá thì gọi API Reviews, Bài đăng nhóm gọi API Group
    bool isReview = post['CommentID'] != null || post['commentId'] != null || post['Rating'] != null || post['rating'] != null;
    String apiUrl = isReview 
        ? '$apiBaseUrl/api/movies/reviews/$postId/reactions' 
        : '$apiBaseUrl/api/group/posts/$postId/reactions';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FutureBuilder<http.Response>(
          future: http.get(Uri.parse(apiUrl)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
              return Container(
                height: 200, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: const Center(child: Text("Lỗi tải dữ liệu")),
              );
            }

            List<dynamic> reactions = jsonDecode(snapshot.data!.body);
            if (reactions.isEmpty) {
              return Container(
                height: 200, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: const Center(child: Text("Chưa có ai thả cảm xúc.", style: TextStyle(color: Colors.grey))),
              );
            }

            // GOM NHÓM DỮ LIỆU ĐỂ TẠO TABS
            Map<String, int> reactionCounts = {};
            for (var r in reactions) {
              String type = r['ReactionType'];
              reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
            }

            List<String> availableTypes = reactionCounts.keys.toList();
            availableTypes.sort((a, b) => reactionCounts[b]!.compareTo(reactionCounts[a]!));
            final List<String> tabs = ['all', ...availableTypes];

            Map<String, String> typeToEmoji = {
              'like': '👍', 'love': '❤️', 'haha': '😆', 'wow': '😮', 'sad': '😢', 'angry': '😡'
            };

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: DefaultTabController(
                length: tabs.length,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 5),
                      width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        const Text("Cảm xúc", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(height: 1),

                    TabBar(
                      isScrollable: true,
                      indicatorColor: navyBlue,
                      labelColor: navyBlue,
                      unselectedLabelColor: Colors.grey.shade600,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                      tabs: tabs.map((type) {
                        if (type == 'all') {
                          return Tab(child: Text("Tất cả ${reactions.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)));
                        }
                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(typeToEmoji[type] ?? '👍', style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text("${reactionCounts[type]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    Expanded(
                      child: TabBarView(
                        children: tabs.map((tabType) {
                          List<dynamic> tabData = tabType == 'all' 
                              ? reactions 
                              : reactions.where((r) => r['ReactionType'] == tabType).toList();

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            physics: const BouncingScrollPhysics(),
                            itemCount: tabData.length,
                            itemBuilder: (context, index) {
                              final userReact = tabData[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildAvatar(userReact['Avatar']?.toString(), userReact['Username'] ?? 'U', 46),
                                    Positioned(
                                      bottom: -2, right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        child: _getIconByType(userReact['ReactionType'], navyBlue), 
                                      ),
                                    )
                                  ],
                                ),
                                title: Text(
                                  userReact['Username'] ?? 'Người dùng', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  // ====================================================================
  // HÀM TIỆN ÍCH: TỰ ĐỘNG NẶN RA ĐỐI TƯỢNG MOVIE ĐỂ TRUYỀN QUA TRANG ĐẶT VÉ
  // ====================================================================
  Movie _getMovieFromPostData(Map<String, dynamic> data) {
    String fullPosterUrl = _getRealImageUrl(data['MovieImage']?.toString());
    String fullBackdropUrl = _getRealImageUrl(data['MovieBackdrop']?.toString());
    if (fullBackdropUrl.isEmpty) fullBackdropUrl = fullPosterUrl;

    double parsedVote = 0.0;
    if (data['MovieVoteAverage'] != null) {
      parsedVote = double.tryParse(data['MovieVoteAverage'].toString()) ?? 0.0;
    }

    return Movie(
      id: int.tryParse(data['MovieID']?.toString() ?? '0') ?? 0,
      title: data['MovieTitle']?.toString() ?? 'Chưa có tên phim',
      overview: data['MovieOverview']?.toString() ?? 'Đang cập nhật nội dung phim...',
      posterPath: fullPosterUrl,
      backdropPaths: fullBackdropUrl.isNotEmpty ? [fullBackdropUrl] : [], 
      genres: data['MovieGenres']?.toString() ?? 'Phim chiếu rạp',
      voteAverage: parsedVote,
      language: data['MovieLanguage']?.toString() ?? 'Phụ đề',
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color navyBlue = Colors.blue.shade900;

    // ---- LẤY DATA TỰ ĐỘNG (CHUẨN HÓA CẢ BẢNG POSTS LẪN BẢNG COMMENTS) ----
    String contentTxt = (post['Content'] ?? post['content'] ?? post['comment'] ?? '').toString();
    if (contentTxt == 'null') contentTxt = '';

    bool hasTaggedMovie = post['MovieID'] != null || post['movie_id'] != null;
    int totalLikes = post['total_likes'] ?? post['likeCount'] ?? 0;
    int totalComments = post['total_comments'] ?? post['replyCount'] ?? 0;
    bool isTransferPost = post['Type'] == 'transfer';
    bool isHidden = post['Status'] == 0 || post['Status'] == '0'; 

    // 🚀 BẮT RATING TỪ BẢNG COMMENTS (DB là Cột Rating)
    double? postRating;
    if (post['Rating'] != null && post['Rating'].toString() != 'null') {
      postRating = double.tryParse(post['Rating'].toString());
    } else if (post['rating'] != null && post['rating'].toString() != 'null') {
      postRating = double.tryParse(post['rating'].toString());
    }

    // 🚀 BẮT TAGS TỪ BẢNG COMMENTS (DB là Cột Tags)
    List<String> postTags = [];
    String rawTags = (post['Tags'] ?? post['tags'] ?? post['feeling'] ?? post['emotion'] ?? '').toString();
    if (rawTags.isNotEmpty && rawTags != 'null') {
      postTags = rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    
    // ĐÃ FIX: Chỉ hiện đã mua vé khi có bằng chứng từ DB
    bool hasBoughtTicket = post['IsTicketBought'] == true || post['IsTicketBought'] == 1 || post['IsTicketBought'] == 'true' || post['hasBoughtTicket'] == true;

    // 🚀 BẮT CẢM XÚC CỦA NGƯỜI DÙNG (Cho cả bảng Group và Review)
    String userReaction = (post['user_reaction'] ?? post['userReaction'] ?? '').toString();
    if (userReaction == 'null') userReaction = '';
    bool isReacted = userReaction.isNotEmpty;
    
    Widget reactionIcon = Icon(Icons.thumb_up_alt_outlined, color: Colors.grey.shade700, size: 20);
    String reactionText = "Thích";
    Color reactionColor = Colors.grey.shade700;

    if (isReacted) {
      if (userReaction == 'like') { reactionIcon = Icon(Icons.thumb_up, color: navyBlue, size: 20); reactionText = "Thích"; reactionColor = navyBlue; }
      else if (userReaction == 'love') { reactionIcon = const Text('❤️', style: TextStyle(fontSize: 18)); reactionText = "Yêu thích"; reactionColor = Colors.red; }
      else if (userReaction == 'haha') { reactionIcon = const Text('😆', style: TextStyle(fontSize: 18)); reactionText = "Haha"; reactionColor = Colors.orange; }
      else if (userReaction == 'wow') { reactionIcon = const Text('😮', style: TextStyle(fontSize: 18)); reactionText = "Wow"; reactionColor = Colors.orange; }
      else if (userReaction == 'sad') { reactionIcon = const Text('😢', style: TextStyle(fontSize: 18)); reactionText = "Buồn"; reactionColor = Colors.orange; }
      else if (userReaction == 'angry') { reactionIcon = const Text('😡', style: TextStyle(fontSize: 18)); reactionText = "Phẫn nộ"; reactionColor = Colors.red.shade700; }
    }

    // ---- CỤC ICON CẢM XÚC GÓC TRÁI (BẤM VÀO SẼ HIỆN DANH SÁCH CHI TIẾT) ----
    Widget summaryReactionIcon = const SizedBox.shrink();
    if (totalLikes > 0) {
      String topReactionsStr = (post['top_reactions'] ?? post['topReactions'] ?? 'like').toString(); 
      if (topReactionsStr == 'null' || topReactionsStr.isEmpty) topReactionsStr = 'like';
      List<String> actualReactions = topReactionsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (actualReactions.isEmpty) actualReactions = ['like']; 

      List<Widget> stackChildren = [];
      if (actualReactions.length > 1) stackChildren.add(Transform.translate(offset: const Offset(10, 0), child: _getIconByType(actualReactions[1], navyBlue)));
      stackChildren.add(_getIconByType(actualReactions[0], navyBlue));

      // 🚀 BẮT ĐÚNG ID ĐỂ GỌI API LẤY DANH SÁCH LIKE (Xử lý ID của cả Review và Group)
      int targetId = int.tryParse((post['PostID'] ?? post['CommentID'] ?? post['commentId'] ?? 0).toString()) ?? 0;

      summaryReactionIcon = GestureDetector(
        onTap: () => _showReactionDetailsBottomSheet(context, targetId, navyBlue),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(clipBehavior: Clip.none, children: stackChildren),
              SizedBox(width: actualReactions.length > 1 ? 16 : 6),
              Text(totalLikes >= 1000 ? "${(totalLikes/1000).toStringAsFixed(1)}k" : totalLikes.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Bài viết chi tiết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900))),
          ],
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]))),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // PHẦN 1: HEADER (AVATAR + INFO NGƯỜI ĐĂNG)
            // ==========================================
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              child: Row(
                children: [
                  _buildAvatar(post['Avatar']?.toString() ?? post['avatar']?.toString(), post['Username']?.toString() ?? 'U', 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(post['Username'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (post['Role']?.toString().toLowerCase() == 'admin') ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified, color: Colors.blue.shade600, size: 16),
                            ]
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(_formatTime(post['CreatedAt'] ?? post['rawDate'] ?? post['date']), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(width: 6),
                            Icon(Icons.public, color: Colors.grey.shade500, size: 12),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // PHẦN 2: ĐÁNH GIÁ & NỘI DUNG CHỮ
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Đánh giá sao
                  if (postRating != null && postRating > 0) ...[
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 22),
                        const SizedBox(width: 6),
                        Text("$postRating/10", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  
                  if (hasTaggedMovie && !isTransferPost && hasBoughtTicket) ...[
                    Text("Đã mua vé qua ứng dụng", style: TextStyle(fontSize: 13, color: navyBlue, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                  ],

                  if (contentTxt.isNotEmpty)
                    Text(
                      contentTxt,
                      style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                    ),
                  
                  // TAGS VÀ NHÃN CẢM XÚC ĐÃ ĐƯỢC CHUẨN HÓA MÀU SẮC
                  if (postTags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: postTags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(tag, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F9)),

            // ==========================================
            // PHẦN 3: THẺ ĐẶT VÉ PHIM
            // ==========================================
            if (hasTaggedMovie)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF5F5F9), width: 8))
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8), 
                      child: Image.network(
                        _getRealImageUrl(post['MovieImage']), 
                        width: 50, height: 70, fit: BoxFit.cover, 
                        errorBuilder: (_,__,___) => Container(width: 50, height: 70, color: Colors.grey.shade300, child: const Icon(Icons.movie, color: Colors.grey))
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post['MovieTitle'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(post['MovieGenres'] ?? "Phim rạp", style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHidden ? Colors.grey : navyBlue,
                        elevation: 0, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ), 
                      onPressed: () {
                         if(isHidden) return;
                         Navigator.push(
                           context, 
                           MaterialPageRoute(builder: (_) => MovieDetailPage(movie: _getMovieFromPostData(post))) 
                         );
                      }, 
                      child: Text(isHidden ? "Hết hạn" : "Đặt vé", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
                    )
                  ],
                ),
              ),

            // ==========================================
            // PHẦN 4: DANH SÁCH ẢNH DỌC BÊN DƯỚI NỀN ĐEN
            // ==========================================
            if (images.where((img) => _getRealImageUrl(img).isNotEmpty).isNotEmpty)
              Container(
                color: Colors.black, // Nền đen tôn ảnh
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    String finalImg = _getRealImageUrl(images[index]);
                    if (finalImg.isEmpty) return const SizedBox.shrink(); // 🚀 Bỏ qua nếu là link rỗng

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Image.network(
                        finalImg,
                        width: double.infinity,
                        fit: BoxFit.contain, 
                        errorBuilder: (context, error, stackTrace) {
                           return Container(
                             width: double.infinity,
                             height: 200,
                             color: Colors.grey.shade900,
                             child: const Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                 SizedBox(height: 8),
                                 Text("Ảnh không khả dụng", style: TextStyle(color: Colors.grey)),
                               ],
                             ),
                           );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      
      // ==========================================
      // PHẦN 5: THANH LIKE / COMMENT Ở ĐÁY MÀN HÌNH
      // ==========================================
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  summaryReactionIcon,
                  Text("${totalComments >= 1000 ? (totalComments/1000).toStringAsFixed(1) + 'k' : totalComments} bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chạm "Bình luận" để tương tác!')));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          reactionIcon, 
                          const SizedBox(width: 6), 
                          Text(reactionText, style: TextStyle(color: reactionColor, fontWeight: FontWeight.w600, fontSize: 14))
                        ]
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onCommentTapped,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, color: Colors.grey.shade700, size: 20), const SizedBox(width: 6), Text("Bình luận", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14))]),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      int targetId = int.tryParse((post['PostID'] ?? post['CommentID'] ?? post['commentId'] ?? 0).toString()) ?? 0;
                      String shareUrl = "https://sneeze-dust-linguist.ngrok-free.dev/share/post/$targetId";
                      Share.share(shareUrl);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shortcut, color: Colors.grey.shade700, size: 20), const SizedBox(width: 6), Text("Chia sẻ", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14))]),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}