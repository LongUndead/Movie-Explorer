import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO; // 🚀 GẮN SOCKET VÀO ĐÂY
import '../../domain/entities/movie.dart'; 
import 'user_manager.dart';
import 'movie_detail_page.dart';
import 'guest_guard.dart';
import 'post_image_viewer_screen.dart';

class ReviewDetailPage extends StatefulWidget {
  final Map<String, dynamic> review;
  final Movie movie;
  final Color navyBlue;
  final Color starColor;

  const ReviewDetailPage({
    super.key,
    required this.review,
    required this.movie,
    required this.navyBlue,
    required this.starColor,
  });

  @override
  State<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends State<ReviewDetailPage> {
  final String apiBaseUrl = 'http://10.173.120.41:3000';
  late Map<String, dynamic> _currentReview;
  OverlayEntry? _overlayEntry;

  // BIẾN CHO PHẦN BÌNH LUẬN & GIAO DIỆN
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  File? _selectedCommentImage;
  bool _isSubmitting = false;
  
  List<dynamic> _childComments = [];
  bool _isLoadingComments = true;

  int? _replyingToCommentId;
  String? _replyingToUsername;

  // CÁC BIẾN CHO CHỨC NĂNG SỬA BÌNH LUẬN
  int? _editingCommentId;
  final TextEditingController _editCommentController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  File? _editSelectedImage; 
  bool _keepOldImage = true; 
  bool _isUpdatingComment = false;
  
  // BIẾN LƯU TRẠNG THÁI HIỂN THỊ PHẢN HỒI
  Set<int> _expandedCommentIds = {};
  IO.Socket? socket; // 🚀 KHAI BÁO BIẾN SOCKET

  @override
  void initState() {
    super.initState();
    _currentReview = Map<String, dynamic>.from(widget.review);
    _fetchChildComments(); 
    _connectSocket(); // 🚀 BẬT RADA SOCKET KHI MỞ TRANG
    
    // 🚀 ĐÃ THÊM: Lắng nghe bàn phím và nội dung chữ để tự động thu/phóng Avatar
    _commentFocusNode.addListener(() { if (mounted) setState(() {}); });
    _commentController.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    socket?.disconnect(); // 🚀 TẮT RADA CHỐNG HAO PIN
    socket?.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _editCommentController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  // ====================================================================
  // 🚀 HÀM KẾT NỐI SOCKET VÀ LẮNG NGHE SỰ KIỆN LƯỢT LIKE BÌNH LUẬN
  // ====================================================================
  void _connectSocket() {
    socket = IO.io(apiBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    socket?.connect(); // 🚀 Bọc thép chống null

    socket?.on('post_reaction_updated', (data) {
      if (!mounted) return;
      setState(() {
        int commentId = int.tryParse(data['post_id']?.toString() ?? '0') ?? 0;
        if (_currentReview['commentId'] == commentId) {
          _currentReview['likeCount'] = data['total_likes'];
          _currentReview['topReactions'] = data['top_reactions'];
        }
      });
    });
  }

  // ====================================================================
  // API LẤY DANH SÁCH BÌNH LUẬN CON 
  // ====================================================================
  Future<void> _fetchChildComments() async {
    int reviewId = _currentReview['commentId'];
    final user = UserManager.instance.currentUser;
    int userId = user?.id ?? 0;

    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/movies/reviews/$reviewId/comments?user_id=$userId'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            List<dynamic> rawComments = jsonDecode(res.body);
            List<Map<String, dynamic>> flatComments = rawComments.map((c) {
              Map<String, dynamic> item = Map<String, dynamic>.from(c as Map);
              item['userReaction'] = item['userReaction'] ?? ''; 
              item['likeCount'] = item['likeCount'] ?? 0;
              item['topReactions'] = item['topReactions'] ?? ''; 
              item['replies'] = <Map<String, dynamic>>[]; 
              
              item['CommentID'] = int.tryParse((c['CommentID'] ?? c['commentId'] ?? c['id']).toString()) ?? 0;
              item['ParentID'] = int.tryParse((c['ParentID'] ?? c['parentId'] ?? c['parent_id']).toString()) ?? 0;
              
              item['Content'] = c['Content'] ?? c['content'] ?? c['comment'] ?? '';
              item['UserID'] = c['UserID'] ?? c['userId'] ?? c['user_id'];
              item['ImageURL'] = c['ImageURL'] ?? c['image'] ?? c['image_url'] ?? '';
              item['Username'] = c['Username'] ?? c['username'] ?? 'User';
              item['CreatedAt'] = c['CreatedAt'] ?? c['rawDate'] ?? c['date'] ?? '';
              
              return item;
            }).toList();

            Map<int, Map<String, dynamic>> commentMap = {};
            for (var c in flatComments) { 
              if (c['CommentID'] != 0) {
                commentMap[c['CommentID']] = c; 
              }
            }

            List<Map<String, dynamic>> treeComments = [];
            for (var c in flatComments) {
              int parentId = c['ParentID']; 
              if (parentId != 0 && commentMap.containsKey(parentId)) {
                commentMap[parentId]!['replies'].add(c);
              } else {
                treeComments.add(c);
              }
            }

            _childComments = treeComments;
            _currentReview['replyCount'] = flatComments.length; 
            _isLoadingComments = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingComments = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty && _selectedCommentImage == null) return;

    final user = UserManager.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để bình luận!')));
      return;
    }

    setState(() => _isSubmitting = true);
    int reviewId = _currentReview['commentId'];

    try {
      var uri = Uri.parse('$apiBaseUrl/api/movies/reviews/$reviewId/comments');
      var request = http.MultipartRequest('POST', uri);

      request.fields['UserID'] = user.id.toString(); 
      request.fields['user_id'] = user.id.toString(); 
      request.fields['Content'] = _commentController.text.trim();
      request.fields['content'] = _commentController.text.trim();
      
      if (_replyingToCommentId != null) {
        request.fields['ParentID'] = _replyingToCommentId.toString(); 
        request.fields['parent_id'] = _replyingToCommentId.toString();
      }

      if (_selectedCommentImage != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _selectedCommentImage!.path));
      }

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        setState(() {
          _selectedCommentImage = null;
          
          if (_replyingToCommentId != null) {
            _expandedCommentIds.add(_replyingToCommentId!);
          }
          
          _replyingToCommentId = null;
          _replyingToUsername = null;
        });
        FocusScope.of(context).unfocus(); 
        await _fetchChildComments(); 
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi đăng bình luận!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối tới máy chủ!')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickCommentImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() { _selectedCommentImage = File(image.path); });
      _commentFocusNode.requestFocus();
    }
  }

  Future<void> _pickEditCommentImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _editSelectedImage = File(image.path);
        _keepOldImage = false; 
      });
      _editFocusNode.requestFocus();
    }
  }

  Future<void> _updateCommentApi(Map<String, dynamic> comment) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    
    int commentId = comment['CommentID'];
    setState(() => _isUpdatingComment = true);

    try {
      var uri = Uri.parse('$apiBaseUrl/api/group/comments/$commentId');
      var request = http.MultipartRequest('PUT', uri); 

      request.fields['user_id'] = user.id.toString();
      request.fields['content'] = _editCommentController.text.trim();
      request.fields['keep_old_image'] = _keepOldImage.toString();

      if (_editSelectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _editSelectedImage!.path));
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        setState(() {
          _editingCommentId = null; 
          _editSelectedImage = null;
        });
        await _fetchChildComments(); 
      }
    } catch (e) {
      debugPrint("Lỗi sửa DB: $e");
    } finally {
      if (mounted) setState(() => _isUpdatingComment = false);
    }
  }

  Future<void> _deleteCommentApi(Map<String, dynamic> comment, {bool isReply = false, int? parentId}) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    int commentId = comment['CommentID'];

    setState(() {
      if (isReply && parentId != null) {
        var parent = _childComments.firstWhere((c) => c['CommentID'] == parentId);
        (parent['replies'] as List).removeWhere((r) => r['CommentID'] == commentId);
      } else {
        _childComments.removeWhere((c) => c['CommentID'] == commentId);
      }
      _currentReview['replyCount'] = (_currentReview['replyCount'] ?? 1) - 1;
    });

    try {
      await http.delete(
        Uri.parse('$apiBaseUrl/api/group/comments/$commentId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id}),
      );
    } catch (e) {}
  }

  void _showCommentOptions(Map<String, dynamic> comment, {bool isReply = false, int? parentId}) {
    final currentUserId = UserManager.instance.currentUser?.id;
    bool isAuthor = comment['UserID'].toString() == currentUserId.toString();

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
                title: const Text('Chỉnh sửa bình luận', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context); 
                  setState(() {
                    _editingCommentId = comment['CommentID'];
                    _editCommentController.text = comment['Content'] ?? '';
                    _keepOldImage = comment['ImageURL'] != null && comment['ImageURL'].toString().isNotEmpty;
                    _editSelectedImage = null;
                  });
                  Future.delayed(const Duration(milliseconds: 100), () => _editFocusNode.requestFocus());
                }
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa bình luận', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCommentApi(comment, isReply: isReply, parentId: parentId); 
                }
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                title: const Text('Báo cáo bình luận', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
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

  // 🚀 ĐÃ FIX: Tự động chèn @Tên vào ô nhập và đưa con trỏ ra sau cùng
  void _startReplying(int commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
    
    _commentController.text = '@$username ';
    _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
    _commentFocusNode.requestFocus();
  }

  Future<void> _reactToReview(String reactionType) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    setState(() {
      String currentReaction = _currentReview['userReaction']?.toString() ?? '';
      String topReactionsStr = _currentReview['topReactions']?.toString() ?? '';
      
      List<String> topReactionsList = topReactionsStr.split(',').where((String e) => e.trim().isNotEmpty).toList();

      if (currentReaction == reactionType) {
        _currentReview['userReaction'] = '';
        if ((_currentReview['likeCount'] ?? 0) > 0) _currentReview['likeCount']--;
        topReactionsList.remove(reactionType);
      } else {
        if (currentReaction.isEmpty) {
          _currentReview['likeCount'] = (_currentReview['likeCount'] ?? 0) + 1;
        } else {
          topReactionsList.remove(currentReaction); 
        }
        
        _currentReview['userReaction'] = reactionType;
        if (!topReactionsList.contains(reactionType)) {
          topReactionsList.insert(0, reactionType);
        }
      }
      _currentReview['topReactions'] = topReactionsList.join(',');
    });

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/movies/reviews/react'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id, 'comment_id': _currentReview['commentId'], 'reaction_type': reactionType})
      );
      // 🚀 ĐÃ XÓA LỆNH LOAD LẠI API VÌ CÓ THUẬT TOÁN LOCAL VÀ SOCKET LO RỒI
    } catch (e) {}
  }

  Future<void> _reactToChildComment(Map<String, dynamic> comment, String reactionType) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    setState(() {
      String currentReaction = comment['userReaction']?.toString() ?? '';
      String topReactionsStr = comment['topReactions']?.toString() ?? '';
      
      List<String> topReactionsList = topReactionsStr.split(',').where((String e) => e.trim().isNotEmpty).toList();

      if (currentReaction == reactionType) {
        comment['userReaction'] = '';
        comment['likeCount'] = (comment['likeCount'] ?? 1) - 1;
        topReactionsList.remove(reactionType);
      } else {
        if (currentReaction.isEmpty) {
          comment['likeCount'] = (comment['likeCount'] ?? 0) + 1;
        } else {
          topReactionsList.remove(currentReaction);
        }
        comment['userReaction'] = reactionType;
        if (!topReactionsList.contains(reactionType)) {
          topReactionsList.insert(0, reactionType);
        }
      }
      comment['topReactions'] = topReactionsList.join(',');
    });

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/movies/reviews/react'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id, 
          'comment_id': comment['CommentID'], 
          'reaction_type': reactionType
        })
      );
      
      _fetchChildComments();
    } catch (e) {
      debugPrint("Lỗi react comment DB: $e");
    }
  }

  void _showReactionOverlay(BuildContext context, Offset tapPosition, {Map<String, dynamic>? childComment}) {
    if (_overlayEntry != null) return;
    
    double screenWidth = MediaQuery.of(context).size.width;
    double leftPos = tapPosition.dx - 130; 
    
    if (leftPos < 10) leftPos = 10;
    if (leftPos + 250 > screenWidth) leftPos = screenWidth - 260; 
    if (leftPos < 10) leftPos = 10; 

    double topPos = tapPosition.dy - 70;
    if (topPos < 60) topPos = tapPosition.dy + 30;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(onTap: () { _overlayEntry?.remove(); _overlayEntry = null; }, child: Container(color: Colors.transparent))),
            Positioned(
              left: leftPos, 
              top: topPos, 
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildOverlayEmoji('like', '👍', childComment), 
                      _buildOverlayEmoji('love', '❤️', childComment), 
                      _buildOverlayEmoji('haha', '😆', childComment),
                      _buildOverlayEmoji('wow', '😮', childComment), 
                      _buildOverlayEmoji('sad', '😢', childComment), 
                      _buildOverlayEmoji('angry', '😡', childComment),
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

  Widget _buildOverlayEmoji(String type, String emoji, Map<String, dynamic>? childComment) {
    return GestureDetector(
      onTap: () { 
        _overlayEntry?.remove(); 
        _overlayEntry = null; 
        if (childComment != null) {
          _reactToChildComment(childComment, type);
        } else {
          _reactToReview(type); 
        }
      },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text(emoji, style: const TextStyle(fontSize: 26))),
    );
  }

  Widget _buildCircleIcon(Widget child, Color bgColor) {
    return Container(
      width: 22, height: 22, // 🚀 TĂNG SIZE LÊN 22 CHỐNG CẮT NỬA KHUÔN MẶT
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]), 
      alignment: Alignment.center, 
      child: FittedBox(fit: BoxFit.scaleDown, child: child) // 🚀 THẦN CHÚ ÉP ICON VÀO CHÍNH GIỮA
    );
  }

  Widget _getIconByType(String type) {
    double size = 14; // Tăng size chữ lên cho nét
    // 🚀 ĐÃ FIX: TIM ĐỎ NỀN TRẮNG CHUẨN FACEBOOK
    if (type == 'love') return _buildCircleIcon(const Icon(Icons.favorite, color: Colors.red, size: 14), Colors.white);
    if (type == 'haha') return _buildCircleIcon(Text('😆', style: TextStyle(fontSize: size, height: 1.1)), Colors.white);
    if (type == 'wow') return _buildCircleIcon(Text('😮', style: TextStyle(fontSize: size, height: 1.1)), Colors.white);
    if (type == 'sad') return _buildCircleIcon(Text('😢', style: TextStyle(fontSize: size, height: 1.1)), Colors.white);
    if (type == 'angry') return _buildCircleIcon(Text('😡', style: TextStyle(fontSize: size, height: 1.1)), Colors.white);
    return _buildCircleIcon(const Icon(Icons.thumb_up, color: Colors.white, size: 12), widget.navyBlue);
  }

  Widget _buildTagChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), 
      child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600))
    );
  }

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
      return rawDateStr;
    }
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
  // ==============================================================
  // ✅ HÀM HỖ TRỢ VẼ AVATAR BẤT TỬ
  // ==============================================================
  Widget _buildAvatar(String? avatarUrl, double size) {
    String finalUrl = '';
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty && avatarUrl != 'null') {
      finalUrl = avatarUrl.startsWith('http')
          ? avatarUrl
          : '$apiBaseUrl${avatarUrl.startsWith('/') ? '' : '/'}$avatarUrl';
    }

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade50, border: Border.all(color: Colors.white, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: finalUrl.isNotEmpty
            ? Image.network(finalUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: Colors.blue.shade200, size: size * 0.6))
            : Icon(Icons.person, color: Colors.blue.shade200, size: size * 0.6),
      ),
    );
  }

  // ==============================================================
  // ✅ HÀM MỞ MENU TÙY CHỌN BÀI ĐÁNH GIÁ (DẤU 3 CHẤM)
  // ==============================================================
  void _showReviewOptionsModal() {
    final currentUserId = UserManager.instance.currentUser?.id;
    bool isAuthor = false;
    
    if (_currentReview['userId'] != null || _currentReview['UserID'] != null) {
      isAuthor = (_currentReview['userId'] ?? _currentReview['UserID']).toString() == currentUserId.toString();
    } else {
      isAuthor = _currentReview['username'].toString().toLowerCase() == UserManager.instance.currentUser?.name.toLowerCase();
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng quay lại danh sách để chỉnh sửa!')));
                }
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa đánh giá', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng quay lại danh sách để xóa!')));
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
            // Nút đóng luôn luôn có
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: const Text('Đóng', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context)
            ),
          ]
        )
      )
    );
  }

 // ==================== KHỐI XÂY DỰNG TỪNG COMMENT CÓ STACKED ICONS & MENTIONS ====================
  Widget _buildCommentItem(Map<String, dynamic> c, {bool isReply = false, int? parentId, String? parentUsername}) {
    String cReaction = c['userReaction']?.toString() ?? '';
    int likeCount = c['likeCount'] ?? 0;
    List<dynamic> rawReplies = c['replies'] ?? [];
    List<Map<String, dynamic>> replies = rawReplies.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final currentUserId = UserManager.instance.currentUser?.id;
    bool isAuthor = c['UserID'].toString() == currentUserId.toString();
    
    String contentTxt = c['Content'] ?? '';
    String imgUrl = c['ImageURL'] ?? '';
    String usernameTxt = c['Username'] ?? 'User';
    bool hasImage = imgUrl.isNotEmpty;
    bool isEditing = _editingCommentId == c['CommentID'];

    Color cReactionColor = Colors.grey.shade600;
    String cReactionText = "Thích";
    if (cReaction == 'like') { cReactionText = "Thích"; cReactionColor = widget.navyBlue; }
    else if (cReaction == 'love') { cReactionText = "Yêu thích"; cReactionColor = Colors.red; }
    else if (cReaction == 'haha') { cReactionText = "Haha"; cReactionColor = Colors.orange; }
    else if (cReaction == 'wow') { cReactionText = "Wow"; cReactionColor = Colors.orange; }
    else if (cReaction == 'sad') { cReactionText = "Buồn"; cReactionColor = Colors.orange; }
    else if (cReaction == 'angry') { cReactionText = "Phẫn nộ"; cReactionColor = Colors.red.shade700; }

    Widget commentSummaryReactionIcon = const SizedBox.shrink();
    if (likeCount > 0) {
      String topReactionsStr = c['topReactions']?.toString() ?? 'like'; 
      List<String> actualReactions = topReactionsStr.split(',').where((String e) => e.trim().isNotEmpty).toList();
      if (actualReactions.isEmpty) actualReactions = ['like']; 

      List<Widget> stackChildren = [];
      if (actualReactions.length > 1) {
        stackChildren.add(Transform.translate(offset: const Offset(8, 0), child: _getIconByType(actualReactions[1])));
      }
      stackChildren.add(_getIconByType(actualReactions[0]));

      commentSummaryReactionIcon = GestureDetector(
        onTap: () => _showReactionDetailsBottomSheet(_currentReview['commentId']),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(likeCount.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(width: 4),
              Stack(clipBehavior: Clip.none, children: stackChildren),
              SizedBox(width: actualReactions.length > 1 ? 8 : 0),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 0 : 16, right: isReply ? 0 : 16, top: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _buildAvatar(c['Avatar']?.toString() ?? c['avatar']?.toString(), isReply ? 28 : 36),
          ),
          const SizedBox(width: 10),
          
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🚀 HÀNG 1: TÊN NGƯỜI DÙNG & DẤU 3 CHẤM NẰM SÁT GÓC PHẢI (CHỐNG TRÀN VIỀN)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 3, 
                            child: Text(usernameTxt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          if (isAuthor) ...[
                            const SizedBox(width: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: widget.navyBlue, borderRadius: BorderRadius.circular(4)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, color: Colors.white, size: 9), SizedBox(width: 3), Text("Tác giả", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]))
                          ],
                        ],
                      ),
                    ),
                    if (!isEditing)
                      GestureDetector(
                        onTap: () => _showCommentOptions(c, isReply: isReply, parentId: parentId),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.more_horiz, color: Colors.black54, size: 18),
                        ),
                      )
                  ],
                ),
                
                // 🚀 HÀNG 2: NỘI DUNG BÌNH LUẬN VÀ ẢNH (BỎ BOX XÁM, NHUỘM XANH @TÊN)
                if (isEditing) 
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                        child: TextField(
                          controller: _editCommentController, focusNode: _editFocusNode, maxLines: null,
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText: "Viết bình luận..."),
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_editSelectedImage != null)
                        Stack(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_editSelectedImage!, width: 150, fit: BoxFit.cover)),
                            Positioned(right: -4, top: -4, child: GestureDetector(onTap: () => setState(() => _editSelectedImage = null), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14))))
                          ],
                        )
                      else if (_keepOldImage && hasImage)
                        Stack(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_getRealImageUrl(imgUrl), width: 150, fit: BoxFit.cover)),
                            Positioned(right: -4, top: -4, child: GestureDetector(onTap: () => setState(() => _keepOldImage = false), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14))))
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(onPressed: _pickEditCommentImage, icon: const Icon(Icons.camera_alt, color: Colors.grey, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          const Spacer(),
                          TextButton(onPressed: () => setState(() { _editingCommentId = null; _editSelectedImage = null; }), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
                          _isUpdatingComment
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : TextButton(onPressed: () => _updateCommentApi(c), child: Text("Lưu", style: TextStyle(color: widget.navyBlue, fontWeight: FontWeight.bold))),
                        ],
                      )
                    ],
                  )
                else ...[
                  if (contentTxt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2), 
                      // 🚀 ĐÃ FIX V3: Thuật toán quét toàn bộ tên và bôi xanh chuẩn Facebook
                      child: Builder(
                        builder: (context) {
                          List<TextSpan> spans = [];
                          
                          // Thu thập toàn bộ tên người dùng trong danh sách
                          Set<String> participantNames = { _currentReview['username']?.toString() ?? '' };
                          for (var cmt in _childComments) {
                            participantNames.add(cmt['Username']?.toString() ?? '');
                            for (var rep in (cmt['replies'] ?? [])) {
                              participantNames.add(rep['Username']?.toString() ?? '');
                            }
                          }
                          
                          List<String> sortedNames = participantNames.where((n) => n.isNotEmpty).toList()
                            ..sort((a, b) => b.length.compareTo(a.length));

                          String? matchedName;
                          for (String name in sortedNames) {
                            if (contentTxt.contains('@$name')) {
                              matchedName = name;
                              break; 
                            }
                          }

                          if (matchedName != null) {
                            String mention = '@$matchedName';
                            List<String> parts = contentTxt.split(mention);
                            for (int i = 0; i < parts.length; i++) {
                              if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i])); 
                              if (i < parts.length - 1) spans.add(TextSpan(text: mention, style: TextStyle(color: widget.navyBlue, fontWeight: FontWeight.bold))); 
                            }
                          } else {
                            final RegExp mentionRegex = RegExp(r'(@\S+)');
                            final Iterable<RegExpMatch> matches = mentionRegex.allMatches(contentTxt);
                            int lastMatchEnd = 0;
                            
                            for (final RegExpMatch match in matches) {
                              if (match.start > lastMatchEnd) spans.add(TextSpan(text: contentTxt.substring(lastMatchEnd, match.start)));
                              spans.add(TextSpan(text: match.group(0), style: TextStyle(color: widget.navyBlue, fontWeight: FontWeight.bold)));
                              lastMatchEnd = match.end;
                            }
                            if (lastMatchEnd < contentTxt.length) spans.add(TextSpan(text: contentTxt.substring(lastMatchEnd)));
                          }

                          return RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.3),
                              children: spans,
                            ),
                          );
                        }
                      ),
                    ),
                  if (hasImage)
                    Padding(
                      padding: EdgeInsets.only(top: contentTxt.isNotEmpty ? 8 : 4),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_getRealImageUrl(imgUrl), width: 220, fit: BoxFit.cover)),
                    )
                ],
                
                // 🚀 HÀNG 3: NÚT THÍCH, TRẢ LỜI & THỜI GIAN
                if (!isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 0, bottom: 8), 
                    child: Row(
                      children: [
                        Text(_getTimeAgo(c['CreatedAt']?.toString()), style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            String target = cReaction.isNotEmpty ? cReaction : 'like';
                            _reactToChildComment(c, target);
                          },
                          onLongPressStart: (details) => _showReactionOverlay(context, details.globalPosition, childComment: c),
                          behavior: HitTestBehavior.opaque,
                          child: Text(cReactionText, style: TextStyle(color: cReactionColor, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          // 🚀 ĐÃ FIX: Chặn lỗi null khi reply parentId
                          onTap: () => _startReplying(isReply ? (parentId ?? 0) : c['CommentID'], usernameTxt),
                          behavior: HitTestBehavior.opaque,
                          child: Text("Trả lời", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const Spacer(),
                        if (likeCount > 0) commentSummaryReactionIcon
                      ],
                    )
                  ),

                if (!isReply && replies.isNotEmpty && !isEditing)
                  Padding(
                    padding: const EdgeInsets.only(left: 0, bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_expandedCommentIds.contains(c['CommentID'])) {
                            _expandedCommentIds.remove(c['CommentID']); 
                          } else {
                            _expandedCommentIds.add(c['CommentID']); 
                          }
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 16, color: widget.navyBlue),
                          const SizedBox(width: 6),
                          Text(
                            _expandedCommentIds.contains(c['CommentID']) 
                                ? "Ẩn phản hồi" 
                                : "Hiển thị ${replies.length} phản hồi", 
                            style: TextStyle(color: widget.navyBlue, fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ],
                      ),
                    ),
                  ),

                // 🚀 HÀNG 4: BÌNH LUẬN CON KÈM VẠCH XÁM TRÁI
                if (!isReply && _expandedCommentIds.contains(c['CommentID']) && replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8), 
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey.shade300, width: 2), 
                        )
                      ),
                      padding: const EdgeInsets.only(left: 8), 
                      child: Column(
                        children: replies.map((reply) => _buildCommentItem(reply, isReply: true, parentId: c['CommentID'], parentUsername: usernameTxt)).toList(),
                      ),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
  
  // ====================================================================
  // BUILD CHÍNH CỦA MÀN HÌNH
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    double score = double.tryParse(_currentReview['rating'].toString()) ?? 0.0;
    bool hasCommentImg = _currentReview['image'] != null && _currentReview['image'].toString().isNotEmpty;
    bool hasBoughtTicket = _currentReview['hasBoughtTicket'] == true || _currentReview['hasBoughtTicket'] == 1;

    int likeCount = _currentReview['likeCount'] ?? 0;
    int replyCount = _currentReview['replyCount'] ?? 0;
    String userReaction = _currentReview['userReaction'] ?? '';
    bool isReacted = userReaction.isNotEmpty;

    String mainUsername = _currentReview['username'] ?? _currentReview['Username'] ?? 'User';

    List<Widget> tagWidgets = [];
    String tagsStr = _currentReview['tags'] ?? ''; 
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
      String topReactionsStr = _currentReview['topReactions']?.toString() ?? 'like'; 
      List<String> actualReactions = topReactionsStr.split(',').where((String e) => e.trim().isNotEmpty).toList();
      if (actualReactions.isEmpty) actualReactions = ['like']; 

      List<Widget> stackChildren = [];
      if (actualReactions.length > 1) stackChildren.add(Transform.translate(offset: const Offset(12, 0), child: _getIconByType(actualReactions[1])));
      stackChildren.add(_getIconByType(actualReactions[0]));

      // 🚀 ĐÃ BỌC GESTURE DETECTOR ĐỂ BẤM VÀO XEM CHI TIẾT AI LIKE REVIEW
      summaryReactionIcon = GestureDetector(
        onTap: () => _showReactionDetailsBottomSheet(_currentReview['commentId'], isReviewPost: true), 
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(clipBehavior: Clip.none, children: stackChildren),
            SizedBox(width: actualReactions.length > 1 ? 16 : 8),
            Text(likeCount >= 1000 ? "${(likeCount/1000).toStringAsFixed(1)}k" : likeCount.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          ],
        ),
      );
    }

    String currentLoginName = UserManager.instance.currentUser?.name ?? "User";

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _currentReview); 
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0, 
          automaticallyImplyLeading: false, 
          titleSpacing: 16,
          title: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, _currentReview), 
                child: Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), 
                  child: Icon(Icons.arrow_back_ios_new, size: 18, color: widget.navyBlue)
                )
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Bài viết chi tiết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: widget.navyBlue))),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]))
          ),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                      child: Icon(Icons.notifications_outlined, color: widget.navyBlue, size: 18)
                    )
                  ),
                  Container(height: 16, width: 1, color: widget.navyBlue.withOpacity(0.2)),
                  InkWell(
                    onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)), 
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                      child: Icon(Icons.home_outlined, color: widget.navyBlue, size: 18)
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
        // 🚀 ĐÃ THÊM: Bọc màn hình bằng cảm biến, chạm ra ngoài là tắt bàn phím
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER ĐÃ FIX AVATAR & MENU 3 CHẤM
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🚀 ĐÃ SỬA: Gắn Avatar thật thay vì ảnh phim
                          _buildAvatar(_currentReview['avatar']?.toString(), 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    text: 'Đánh giá ', style: const TextStyle(color: Colors.grey, fontSize: 14),
                                    children: [TextSpan(text: widget.movie.title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))]
                                  )
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(mainUsername, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    const Text(' • ', style: TextStyle(color: Colors.grey)),
                                    Text(_getTimeAgo(_currentReview['rawDate'] ?? _currentReview['date']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.public, color: Colors.grey, size: 12)
                                  ],
                                )
                              ],
                            ),
                          ),
                          // 🚀 ĐÃ SỬA: Nút 3 chấm đã được kích hoạt chức năng
                          IconButton(
                            icon: const Icon(Icons.more_horiz, color: Colors.grey),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              GuestGuard.check(context, () => _showReviewOptionsModal());
                            },
                          )
                        ],
                      ),
                    ),

                    // 2. NỘI DUNG ĐÁNH GIÁ
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
                          const SizedBox(height: 12),
                          Text(_currentReview['comment'] ?? "", style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
                          const SizedBox(height: 12),
                          if (tagWidgets.isNotEmpty)
                            Wrap(spacing: 8, runSpacing: 8, children: tagWidgets),
                        ],
                      ),
                    ),

                    // 3. ẢNH ĐÍNH KÈM (ĐÃ NÂNG CẤP LÊN LƯỚI ẢNH CHUẨN FACEBOOK VÀ BẤM ĐƯỢC)
                    if (hasCommentImg)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Builder(
                          builder: (context) {
                            // Xử lý mảng ảnh (y chang bên ReviewListPage)
                            List<String> reviewImages = [];
                            if (_currentReview['image'] != null && _currentReview['image'].toString().isNotEmpty && _currentReview['image'] != 'null') {
                              try { 
                                var decoded = jsonDecode(_currentReview['image']);
                                if (decoded is List) {
                                  reviewImages = decoded.map((e) => e.toString()).toList();
                                } else if (decoded is String) {
                                  reviewImages = [decoded];
                                }
                              } catch (_) {
                                String raw = _currentReview['image'].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
                                if (raw.isNotEmpty) reviewImages = raw.split(',').map((e) => e.trim()).toList();
                              }
                            }

                            // Hàm tạo cục Lưới ảnh
                            Widget buildGallery() {
                              if (reviewImages.isEmpty) return const SizedBox.shrink();
                              int count = reviewImages.length;

                              void openImageViewer() {
                                Map<String, dynamic> mappedPost = {
                                  'PostID': _currentReview['commentId'],
                                  'Content': _currentReview['comment'] ?? '',
                                  'Username': _currentReview['username'] ?? 'Người dùng',
                                  'Avatar': _currentReview['avatar'],
                                  'CreatedAt': _currentReview['rawDate'] ?? _currentReview['date'],
                                  'total_likes': _currentReview['likeCount'] ?? 0,
                                  'total_comments': _currentReview['replyCount'] ?? 0,
                                  'user_reaction': _currentReview['userReaction'],
                                  'top_reactions': _currentReview['topReactions'],
                                  'Rating': _currentReview['rating'], 
                                  'Tags': _currentReview['tags'], // Truyền Tags sang
                                  'IsTicketBought': _currentReview['hasBoughtTicket'], 
                                  'MovieID': widget.movie.id,
                                  'MovieTitle': widget.movie.title,
                                  'MovieImage': widget.movie.posterPath,
                                  'MovieGenres': widget.movie.genres,
                                };

                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (_) => PostImageViewerScreen(
                                    post: mappedPost, 
                                    images: reviewImages, 
                                    apiBaseUrl: apiBaseUrl,
                                    onCommentTapped: () {
                                      Navigator.pop(context); // Tắt màn hình cuộn ảnh
                                      _commentFocusNode.requestFocus(); // Tự động trỏ chuột vào ô nhập bình luận
                                    }
                                  ))
                                );
                              }

                              if (count == 1) {
                                return GestureDetector(
                                  onTap: openImageViewer,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 450),
                                    child: Container(width: double.infinity, color: Colors.black.withOpacity(0.03), child: Image.network(_getRealImageUrl(reviewImages[0]), fit: BoxFit.contain)),
                                  ),
                                );
                              } else if (count == 2) {
                                return GestureDetector(
                                  onTap: openImageViewer,
                                  child: SizedBox(height: 250, child: Row(children: [
                                    Expanded(child: Padding(padding: const EdgeInsets.only(right: 2), child: Image.network(_getRealImageUrl(reviewImages[0]), fit: BoxFit.cover, height: double.infinity))),
                                    Expanded(child: Padding(padding: const EdgeInsets.only(left: 2), child: Image.network(_getRealImageUrl(reviewImages[1]), fit: BoxFit.cover, height: double.infinity))),
                                  ])),
                                );
                              } else if (count == 3) {
                                return GestureDetector(
                                  onTap: openImageViewer,
                                  child: SizedBox(height: 250, child: Row(children: [
                                    Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(right: 2), child: Image.network(_getRealImageUrl(reviewImages[0]), fit: BoxFit.cover, height: double.infinity))),
                                    Expanded(flex: 1, child: Column(children: [
                                      Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 2), child: Image.network(_getRealImageUrl(reviewImages[1]), fit: BoxFit.cover, width: double.infinity))),
                                      Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Image.network(_getRealImageUrl(reviewImages[2]), fit: BoxFit.cover, width: double.infinity))),
                                    ])),
                                  ])),
                                );
                              } else {
                                return GestureDetector(
                                  onTap: openImageViewer,
                                  child: GridView.builder(
                                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1.0),
                                    itemCount: 4, 
                                    itemBuilder: (ctx, i) {
                                      if (i == 3 && count > 4) {
                                        return Stack(fit: StackFit.expand, children: [
                                          Image.network(_getRealImageUrl(reviewImages[3]), fit: BoxFit.cover),
                                          Container(color: Colors.black54, child: Center(child: Text('+${count - 4}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))))
                                        ]);
                                      }
                                      return Image.network(_getRealImageUrl(reviewImages[i]), fit: BoxFit.cover);
                                    }
                                  ),
                                );
                              }
                            }

                            return buildGallery();
                          }
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

                    // 3. THẺ PHIM
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(widget.movie.posterPath, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.movie.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(widget.movie.genres ?? "Kinh dị, Hành động", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                            backgroundColor: widget.navyBlue, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                            elevation: 0
                          ),
                            onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MovieDetailPage(movie: widget.movie),
                              ),
                            );
                          },
                            child: const Text("Đặt vé", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

                    // 4. SUMMARY REACTIONS (Đã tháo SizedBox ép chiều cao)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          summaryReactionIcon,
                          const Spacer(),
                          if (replyCount > 0) Text("$replyCount bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),

                    // 5. THANH BUTTON TƯƠNG TÁC
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                String targetReaction = isReacted ? userReaction : 'like';
                                _reactToReview(targetReaction);
                              }, 
                              onLongPressStart: (details) { _showReactionOverlay(context, details.globalPosition); },
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 24, height: 24, child: Center(child: reactionIcon)), const SizedBox(width: 4), Flexible(child: Text(reactionText, style: TextStyle(color: reactionColor, fontWeight: FontWeight.w600, fontSize: 13)))]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _commentFocusNode.requestFocus(), 
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 24, height: 24, child: Center(child: Icon(Icons.chat_bubble_outline, color: Colors.grey.shade700, size: 18))), const SizedBox(width: 4), Flexible(child: Text("Bình luận", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13)))]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                // 🚀 ĐÃ SỬA LẠI Y CHANG TRANG DANH SÁCH (CÓ DEEP LINK)
                                String shareUrl = "https://sneeze-dust-linguist.ngrok-free.dev/share/review/${_currentReview['commentId']}";
                                Share.share("Đánh giá hay Trên CinemaTickets.\n$shareUrl"); 
                              },
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center, 
                                  children: [
                                    SizedBox(width: 24, height: 24, child: Center(child: Icon(Icons.shortcut, color: Colors.grey.shade700, size: 18))), 
                                    const SizedBox(width: 4), 
                                    // ✅ ĐÃ SỬA: Loại bỏ Flexible để chữ "Chia sẻ" hiển thị trọn vẹn, không bị lỗi "..."
                                    Text("Chia sẻ", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13))
                                  ]
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(thickness: 6, color: Colors.grey.shade200),

                    // 6. KHU VỰC HIỂN THỊ DANH SÁCH BÌNH LUẬN CON 
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text("Bình luận", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          Text("$replyCount bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),

                    _isLoadingComments 
                      ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                      : _childComments.isEmpty
                        ? const Padding(padding: EdgeInsets.all(30), child: Center(child: Text("Chưa có bình luận nào. Hãy là người đầu tiên!", style: TextStyle(color: Colors.grey))))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._childComments.map((c) => _buildCommentItem(c)).toList(),
                            ],
                          ),
                    
                    const SizedBox(height: 80), 
                  ],
                ),
              ),
            ),

            // 7. BOTTOM BAR NHẬP BÌNH LUẬN VÀ TRẢ LỜI
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 ĐÃ THÊM LẠI: BANNER "ĐANG TRẢ LỜI" + BẤM HỦY LÀ XÓA LUÔN @TÊN
                  if (_replyingToUsername != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Row(
                        children: [
                          Text("Đang trả lời ", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          Expanded(child: Text(_replyingToUsername!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                // 1. Quét tìm và xóa chữ @Tên (Dù có dấu cách hay lỡ bị xóa mất dấu cách)
                                String mentionWithSpace = '@$_replyingToUsername ';
                                String mentionNoSpace = '@$_replyingToUsername';
                                String currentText = _commentController.text;
                                
                                if (currentText.contains(mentionWithSpace)) {
                                  _commentController.text = currentText.replaceFirst(mentionWithSpace, '');
                                } else if (currentText.contains(mentionNoSpace)) {
                                  _commentController.text = currentText.replaceFirst(mentionNoSpace, '');
                                }

                                // 2. Đưa con trỏ nhấp nháy về lại cuối dòng
                                _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
                                
                                // 3. Xóa trạng thái trả lời
                                _replyingToCommentId = null;
                                _replyingToUsername = null;
                              });
                            },
                            child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.close, size: 16, color: Colors.grey)),
                          )
                        ],
                      ),
                    ),

                  if (_selectedCommentImage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedCommentImage!, width: 60, height: 60, fit: BoxFit.cover)),
                          Positioned(
                            right: -4, top: -4,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedCommentImage = null),
                              child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)),
                            )
                          )
                        ],
                      ),
                    ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 🚀 ĐÃ NÂNG CẤP: Avatar tự động thu gọn mượt mà khi gõ phím hoặc có chữ
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SizeTransition(sizeFactor: animation, axis: Axis.horizontal, child: child);
                        },
                        // Bật Avatar lên CHỈ KHI: Tắt bàn phím VÀ Xóa trắng chữ
                        child: (_commentFocusNode.hasFocus || _commentController.text.trim().isNotEmpty)
                            ? const SizedBox.shrink() 
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, right: 12.0),
                                child: _buildAvatar(UserManager.instance.currentUser?.avatar, 36),
                              ),
                      ),
                      
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                          child: TextField( 
                            controller: _commentController, 
                            focusNode: _commentFocusNode,
                            // 🚀 ĐÃ NÂNG CẤP: Chữ dài tự rớt dòng, tối đa 5 hàng rồi mới bắt đầu cuộn
                            minLines: 1, 
                            maxLines: 5, 
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: "Để lại bình luận của bạn...", 
                              border: InputBorder.none, 
                              hintStyle: TextStyle(fontSize: 14)
                            )
                          ),
                        )
                      ),
                      IconButton(onPressed: _pickCommentImage, icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey)),
                      _isSubmitting 
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(onPressed: _submitComment, icon: Icon(Icons.send, color: widget.navyBlue))
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    ),
    );
  }

  // ====================================================================
  // 🚀 BOTTOM SHEET: DANH SÁCH NGƯỜI THẢ CẢM XÚC BÌNH LUẬN (CHUẨN FB)
  // ====================================================================
  void _showReactionDetailsBottomSheet(int targetId, {bool isReviewPost = false}) {
    // 🚀 Tự động phân luồng: Review chính thì gọi API reviews, Bình luận con thì gọi API comments
    String apiUrl = isReviewPost 
        ? '$apiBaseUrl/api/movies/reviews/$targetId/reactions' 
        : '$apiBaseUrl/api/group/comments/$targetId/reactions';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FutureBuilder<http.Response>(
          future: http.get(Uri.parse(apiUrl)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(height: MediaQuery.of(context).size.height * 0.6, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: const Center(child: CircularProgressIndicator()));
            }

            if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
              return Container(height: 200, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: const Center(child: Text("Lỗi tải dữ liệu")));
            }

            List<dynamic> reactions = jsonDecode(snapshot.data!.body);
            if (reactions.isEmpty) {
              return Container(height: 200, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: const Center(child: Text("Chưa có ai thả cảm xúc.", style: TextStyle(color: Colors.grey))));
            }

            Map<String, int> reactionCounts = {};
            for (var r in reactions) {
              String type = r['ReactionType'];
              reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
            }

            List<String> availableTypes = reactionCounts.keys.toList();
            availableTypes.sort((a, b) => reactionCounts[b]!.compareTo(reactionCounts[a]!));
            final List<String> tabs = ['all', ...availableTypes];
            Map<String, String> typeToEmoji = {'like': '👍', 'love': '❤️', 'haha': '😆', 'wow': '😮', 'sad': '😢', 'angry': '😡'};

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: DefaultTabController(
                length: tabs.length,
                child: Column(
                  children: [
                    Container(margin: const EdgeInsets.only(top: 10, bottom: 5), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
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
                      isScrollable: true, indicatorColor: widget.navyBlue, labelColor: widget.navyBlue, unselectedLabelColor: Colors.grey.shade600, labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                      tabs: tabs.map((type) {
                        if (type == 'all') return Tab(child: Text("Tất cả ${reactions.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)));
                        return Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text(typeToEmoji[type] ?? '👍', style: const TextStyle(fontSize: 16)), const SizedBox(width: 4), Text("${reactionCounts[type]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]));
                      }).toList(),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: tabs.map((tabType) {
                          List<dynamic> tabData = tabType == 'all' ? reactions : reactions.where((r) => r['ReactionType'] == tabType).toList();
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8), physics: const BouncingScrollPhysics(), itemCount: tabData.length,
                            itemBuilder: (context, index) {
                              final userReact = tabData[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildAvatar(userReact['Avatar']?.toString(), 46),
                                    Positioned(bottom: -2, right: -4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: _getIconByType(userReact['ReactionType'])))
                                  ],
                                ),
                                title: Text(userReact['Username'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
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
}