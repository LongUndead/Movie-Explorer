import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../domain/entities/movie.dart'; 
import '../../../movies/presentation/widgets/scroll_to_top_wrapper.dart';
import 'user_manager.dart';
import 'edit_post_page.dart'; 
import 'movie_detail_page.dart';
import 'post_image_viewer_screen.dart';


// ============================================================================
// TRANG CHI TIẾT BÀI VIẾT (ĐÃ LƯU CẢM XÚC BÌNH LUẬN XUỐNG DB, CÓ STACKED ICONS)
// ============================================================================
class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final Color navyBlue = Colors.blue.shade900;
  final String apiBaseUrl = 'http://10.173.120.41:3000'; 
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode(); 
  
  late Map<String, dynamic> currentPost; 
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  OverlayEntry? _overlayEntry;

  int? _replyingToCommentId;
  String? _replyingToUsername;

  File? _selectedCommentImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmittingComment = false;

  int? _editingCommentId;
  final TextEditingController _editCommentController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  File? _editSelectedImage; 
  bool _keepOldImage = true; 
  bool _isUpdatingComment = false;
  Set<int> _expandedCommentIds = {};

  IO.Socket? socket; // 🚀 KHAI BÁO SOCKET

  @override
  void initState() {
    super.initState();
    currentPost = Map<String, dynamic>.from(widget.post);
    _fetchComments();
    _connectSocket(); // 🚀 BẬT RADA

    // 🚀 ĐÃ THÊM: Lắng nghe bàn phím và nội dung chữ để tự động thu/phóng Avatar
    _commentFocusNode.addListener(() { if (mounted) setState(() {}); });
    _commentController.addListener(() { if (mounted) setState(() {}); });

    // 🚀 ĐÃ THÊM: Lắng nghe trạng thái bàn phím bật/tắt
    _commentFocusNode.addListener(() {
      setState(() {}); // Cập nhật lại UI để ẩn/hiện Avatar
    });
  }

  @override
  void dispose() {
    socket?.disconnect(); // 🚀 TẮT RADA
    socket?.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _editCommentController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  // ====================================================================
  // 🚀 HÀM KẾT NỐI SOCKET VÀ LẮNG NGHE SỰ KIỆN TỪ BACKEND
  // ====================================================================
  void _connectSocket() {
    socket = IO.io(apiBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    socket!.connect();

    socket!.on('post_reaction_updated', (data) {
      if (!mounted) return;
      setState(() {
        if (currentPost['PostID'] == int.parse(data['post_id'].toString())) {
          currentPost['total_likes'] = data['total_likes'];
          currentPost['top_reactions'] = data['top_reactions'];
        }
      });
    });
  }

  Future<void> _pickCommentImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedCommentImage = File(image.path));
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

  Future<void> _fetchComments() async {
    try {
      final user = UserManager.instance.currentUser;
      final res = await http.get(Uri.parse('$apiBaseUrl/api/group/posts/${currentPost['PostID']}/comments?user_id=${user?.id ?? 0}'));
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
              
              item['CommentID'] = int.tryParse((c['CommentID'] ?? c['id']).toString()) ?? 0;
              item['ParentID'] = int.tryParse((c['ParentID'] ?? c['parent_id'] ?? c['ParentCommentID']).toString()) ?? 0;
              item['Username'] = c['Username'] ?? c['username'] ?? 'User';
              
              return item;
            }).toList();

            Map<int, Map<String, dynamic>> commentMap = {};
            for (var c in flatComments) { 
              if (c['CommentID'] != 0) commentMap[c['CommentID']] = c; 
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

            _comments = treeComments;
            currentPost['total_comments'] = flatComments.length; 
            _isLoadingComments = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  // ====================================================================
  // API: ĐỒNG BỘ LẠI BÀI VIẾT GỐC TỪ SERVER
  // ====================================================================
  Future<void> _fetchPostDetails() async {
    try {
      final user = UserManager.instance.currentUser;
      final res = await http.get(Uri.parse('$apiBaseUrl/api/group/posts/${currentPost['PostID']}?user_id=${user?.id ?? 0}'));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          var data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty) currentPost = data[0];
          else if (data is Map<String, dynamic>) currentPost = data;
        });
      }
    } catch (e) {
      debugPrint("Lỗi cập nhật bài post: $e");
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty && _selectedCommentImage == null) return;
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmittingComment = true);

    try {
      var uri = Uri.parse('$apiBaseUrl/api/group/posts/${currentPost['PostID']}/comments');
      var request = http.MultipartRequest('POST', uri);

      request.fields['user_id'] = user.id.toString();
      request.fields['content'] = _commentController.text.trim();
      
      if (_replyingToCommentId != null) {
        request.fields['parent_id'] = _replyingToCommentId.toString();
        request.fields['ParentID'] = _replyingToCommentId.toString(); 
      }

      if (_selectedCommentImage != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _selectedCommentImage!.path));
      }

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _commentController.clear();
          _selectedCommentImage = null; 
          if (_replyingToCommentId != null) {
            _expandedCommentIds.add(_replyingToCommentId!);
          }
          _replyingToCommentId = null;
          _replyingToUsername = null;
          currentPost['total_comments'] = (currentPost['total_comments'] ?? 0) + 1;
        });
        FocusScope.of(context).unfocus(); 
        await _fetchComments(); 
      }
    } catch (e) {
      debugPrint("Lỗi đăng bình luận: $e");
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
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
        await _fetchComments(); 
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
        var parent = _comments.firstWhere((c) => c['CommentID'] == parentId);
        (parent['replies'] as List).removeWhere((r) => r['CommentID'] == commentId);
      } else {
        _comments.removeWhere((c) => c['CommentID'] == commentId);
      }
      currentPost['total_comments'] = (currentPost['total_comments'] ?? 1) - 1;
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
    
    // Tự động điền @tên vào ô input
    _commentController.text = '@$username ';
    
    // Đẩy con trỏ chuột nhấp nháy về cuối dòng để khách gõ tiếp
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    
    _commentFocusNode.requestFocus();
  }

  // ====================================================================
  // TÍNH NĂNG LIKE BÀI POST CHÍNH (SỬA LỖI ĐÈ CẢM XÚC LOCAL)
  // ====================================================================
  Future<void> _reactToPostLocal(String reactionType) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    
    setState(() {
      String currentReaction = currentPost['user_reaction']?.toString() ?? '';
      String topReactionsStr = currentPost['top_reactions']?.toString() ?? '';
      
      List<String> topReactionsList = topReactionsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      if (currentReaction == reactionType) {
        currentPost['user_reaction'] = '';
        currentPost['total_likes'] = (currentPost['total_likes'] ?? 1) - 1;
        topReactionsList.remove(reactionType);
      } else {
        if (currentReaction.isNotEmpty) {
          topReactionsList.remove(currentReaction); 
        } else {
          currentPost['total_likes'] = (currentPost['total_likes'] ?? 0) + 1; 
        }
        currentPost['user_reaction'] = reactionType; 
        
        topReactionsList.remove(reactionType);
        topReactionsList.insert(0, reactionType);
      }
      
      currentPost['top_reactions'] = topReactionsList.join(',');
    });

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/group/posts/react'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id, 'post_id': currentPost['PostID'], 'reaction_type': reactionType})
      );
      // 🚀 ĐÃ BỎ FETCH LẠI API VÌ SOCKET TỰ ĐỘNG LO RỒI
    } catch (e) {
      debugPrint("Lỗi post react API: $e");
    }
  }

  // ====================================================================
  // TÍNH NĂNG LIKE BÌNH LUẬN (SỬA LỖI ĐÈ CẢM XÚC LOCAL)
  // ====================================================================
  Future<void> _reactToCommentLocal(Map<String, dynamic> comment, String reactionType) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    setState(() {
      String currentReaction = comment['userReaction']?.toString() ?? '';
      String topReactionsStr = comment['topReactions']?.toString() ?? '';
      
      List<String> topReactionsList = topReactionsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      if (currentReaction == reactionType) {
        comment['userReaction'] = '';
        comment['likeCount'] = (comment['likeCount'] ?? 1) - 1;
        topReactionsList.remove(reactionType);
      } else {
        if (currentReaction.isNotEmpty) {
          topReactionsList.remove(currentReaction); 
        } else {
          comment['likeCount'] = (comment['likeCount'] ?? 0) + 1;
        }
        comment['userReaction'] = reactionType;
        
        topReactionsList.remove(reactionType);
        topReactionsList.insert(0, reactionType); 
      }
      
      comment['topReactions'] = topReactionsList.join(',');
    });

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/group/comments/react'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id, 
          'comment_id': comment['CommentID'], 
          'reaction_type': reactionType
        })
      );
      await _fetchComments();
    } catch (e) {
      debugPrint("Lỗi react comment DB: $e");
    }
  }

  Future<void> _deletePost(int postId) async {
    final user = UserManager.instance.currentUser;
    try {
      final res = await http.delete(
        Uri.parse('$apiBaseUrl/api/group/posts/$postId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user?.id})
      );
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết')));
        Navigator.pop(context, true); 
      }
    } catch (e) {}
  }

  void _showPostOptionsModal() {
    final currentUserId = UserManager.instance.currentUser?.id;
    bool isAuthor = currentPost['PostUserID'].toString() == currentUserId.toString();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 12, bottom: 8), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: Colors.black87),
                title: const Text('Bật/tắt thông báo bài viết', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông báo!'))); },
              ),
              if (isAuthor) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                  title: const Text('Sửa bài viết', style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(context); 
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditPostPage(post: currentPost)));
                    if (result != null) {
                      setState(() {
                        currentPost['Content'] = result['content'];
                        if (currentPost['Type'] == 'transfer') currentPost['TransferPrice'] = result['price'];
                        if (result['BgColor'] != null) currentPost['BgColor'] = result['BgColor'];
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Xóa bài viết', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  onTap: () { Navigator.pop(context); _deletePost(currentPost['PostID']); },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                  title: const Text('Báo cáo bài viết', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
                  onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn đã báo cáo. Chúng tôi sẽ xem xét!'))); },
                ),
              ],
            ],
          ),
        );
      }
    );
  }

  void _showReactionOverlay(BuildContext context, Offset tapPosition) {
    if (_overlayEntry != null) return;
    double screenWidth = MediaQuery.of(context).size.width;
    double leftPos = tapPosition.dx - 140;
    if (leftPos < 10) leftPos = 10;
    if (leftPos + 280 > screenWidth - 10) leftPos = screenWidth - 290;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(onTap: () { _overlayEntry?.remove(); _overlayEntry = null; }, child: Container(color: Colors.transparent))),
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
                      _buildOverlayEmojiLocal('like', '👍'),
                      _buildOverlayEmojiLocal('love', '❤️'),
                      _buildOverlayEmojiLocal('haha', '😆'),
                      _buildOverlayEmojiLocal('wow', '😮'),
                      _buildOverlayEmojiLocal('sad', '😢'),
                      _buildOverlayEmojiLocal('angry', '😡'),
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

  Widget _buildOverlayEmojiLocal(String type, String emoji) {
    return GestureDetector(
      onTap: () { _overlayEntry?.remove(); _overlayEntry = null; _reactToPostLocal(type); },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(emoji, style: const TextStyle(fontSize: 28))),
    );
  }

  void _showCommentReactionOverlay(BuildContext context, Offset tapPosition, Map<String, dynamic> comment) {
    if (_overlayEntry != null) return;
    double screenWidth = MediaQuery.of(context).size.width;
    double leftPos = tapPosition.dx - 100;
    if (leftPos < 10) leftPos = 10;
    if (leftPos + 280 > screenWidth - 10) leftPos = screenWidth - 290;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(onTap: () { _overlayEntry?.remove(); _overlayEntry = null; }, child: Container(color: Colors.transparent))),
            Positioned(
              left: leftPos, top: tapPosition.dy - 60,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCommentOverlayEmojiLocal(comment, 'like', '👍'),
                      _buildCommentOverlayEmojiLocal(comment, 'love', '❤️'),
                      _buildCommentOverlayEmojiLocal(comment, 'haha', '😆'),
                      _buildCommentOverlayEmojiLocal(comment, 'wow', '😮'),
                      _buildCommentOverlayEmojiLocal(comment, 'sad', '😢'),
                      _buildCommentOverlayEmojiLocal(comment, 'angry', '😡'),
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

  Widget _buildCommentOverlayEmojiLocal(Map<String, dynamic> comment, String type, String emoji) {
    return GestureDetector(
      onTap: () { _overlayEntry?.remove(); _overlayEntry = null; _reactToCommentLocal(comment, type); },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(emoji, style: const TextStyle(fontSize: 24))),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return "Vừa xong";
    try { 
      final DateTime dt = DateTime.parse(isoTime).toLocal();
      final Duration diff = DateTime.now().difference(dt);
      if (diff.isNegative || diff.inMinutes < 1) return "Vừa xong";
      if (diff.inHours < 1) return "${diff.inMinutes} phút trước";
      if (diff.inDays < 1) return "${diff.inHours} giờ trước";
      if (diff.inDays < 7) return "${diff.inDays} ngày trước";
      if (diff.inDays < 30) return "${diff.inDays ~/ 7} tuần trước";
      if (diff.inDays < 365) return "${diff.inDays ~/ 30} tháng trước";
      return "${diff.inDays ~/ 365} năm trước";
    } catch (_) { return "Vừa xong"; }
  }

  // ==============================================================
  // ✅ HÀM XỬ LÝ ẢNH BÀI ĐĂNG & ẢNH PHIM "BỌC THÉP V3"
  // Phân biệt chính xác 100% ảnh TMDB và ảnh User up lên
  // ==============================================================
  String _getRealImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null') return "";
    String cleanPath = rawPath.trim().replaceAll('\\', '/');

    // 1. Nếu đã là link web hoàn chỉnh (Google, FB, hoặc IP cũ)
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

    // Dọn rác đường dẫn
    cleanPath = cleanPath.replaceFirst('/public', '').replaceFirst('public/', '');
    String filename = cleanPath.split('/').last;

    // 2. PHÂN LỌC: ĐÂY LÀ ẢNH LOCAL HAY ẢNH TMDB?
    // Ảnh từ TMDB thường CHỈ có chữ và số (VD: /kqjL17yufvn.jpg). Không có dấu gạch ngang hay gạch dưới.
    // Ảnh User up từ điện thoại/multer LUÔN CÓ gạch ngang, gạch dưới, hoặc chữ 'image', 'upload', 'scaled'
    bool isLocalImage = cleanPath.contains('upload') || 
                        filename.contains('image') || 
                        filename.contains('scaled') || 
                        filename.contains('movie-') || 
                        filename.contains('-') || 
                        filename.contains('_');

    if (isLocalImage) {
      // Tự động điều hướng theo cấu trúc thư mục của ông (public/foods, public/avatars, public/uploads)
      if (filename.startsWith('food')) return '$apiBaseUrl/foods/$filename';
      if (filename.startsWith('avatar') || filename.startsWith('user')) return '$apiBaseUrl/avatars/$filename';
      
      // Còn lại tống vào uploads (ảnh bài viết user đăng, poster do admin tự tải lên...)
      return '$apiBaseUrl/uploads/$filename';
    } else {
      // 3. Chắc chắn là ảnh poster từ TheMovieDB
      if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
      return 'https://image.tmdb.org/t/p/w500$cleanPath';
    }
  }

  // ==============================================================
  // 🚀 LƯỚI ẢNH (BẤM VÀO ĐỂ MỞ MÀN HÌNH CUỘN ẢNH)
  // ==============================================================
  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();
    int count = images.length;

    // Hàm chuyển sang trang Cuộn ảnh
    void openImageViewer() {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => PostImageViewerScreen(
          post: currentPost, 
          images: images, 
          apiBaseUrl: apiBaseUrl,
          onCommentTapped: () {
            Navigator.pop(context); // Tắt màn hình cuộn ảnh
            _commentFocusNode.requestFocus(); // Tự động trỏ chuột ngay vào ô nhập bình luận
          }
        ))
      );
    }

    if (count == 1) {
      return GestureDetector(
        onTap: openImageViewer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 450),
          child: Container(
            width: double.infinity,
            color: Colors.black.withOpacity(0.03),
            child: Image.network(_getRealImageUrl(images[0]), fit: BoxFit.contain), 
          ),
        ),
      );
    }
    else if (count == 2) {
      return GestureDetector(
        onTap: openImageViewer,
        child: Row(children: images.map((img) => Expanded(child: Padding(padding: const EdgeInsets.all(1.0), child: Image.network(_getRealImageUrl(img), fit: BoxFit.cover, height: 250)))).toList())
      );
    } 
    else if (count == 3) {
      return GestureDetector(
        onTap: openImageViewer,
        child: Column(children: [
          Image.network(_getRealImageUrl(images[0]), fit: BoxFit.cover, width: double.infinity, height: 200),
          Row(children: images.sublist(1).map((img) => Expanded(child: Padding(padding: const EdgeInsets.all(1.0), child: Image.network(_getRealImageUrl(img), fit: BoxFit.cover, height: 150)))).toList())
        ])
      );
    } 
    else {
      return GestureDetector(
        onTap: openImageViewer,
        child: GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: count > 4 ? 4 : count, 
          itemBuilder: (ctx, i) {
            if (i == 3 && count > 4) {
               return Stack(fit: StackFit.expand, children: [Image.network(_getRealImageUrl(images[3]), fit: BoxFit.cover), Container(color: Colors.black54, child: Center(child: Text('+${count - 4}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))))]);
            }
            return Image.network(_getRealImageUrl(images[i]), fit: BoxFit.cover);
          }
        ),
      );
    }
  }

  Widget _buildCircleIcon(Widget child, Color bgColor) {
    return Container(
      width: 16, height: 16, 
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.0)),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _getIconByType(String type) {
    if (type == 'love') return _buildCircleIcon(const Icon(Icons.favorite, color: Colors.white, size: 8), Colors.red);
    if (type == 'haha') return _buildCircleIcon(const Text('😆', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'wow') return _buildCircleIcon(const Text('😮', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'sad') return _buildCircleIcon(const Text('😢', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'angry') return _buildCircleIcon(const Text('😡', style: TextStyle(fontSize: 10)), Colors.white);
    return _buildCircleIcon(const Icon(Icons.thumb_up, color: Colors.white, size: 9), Colors.blue.shade700);
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
    if (cReaction == 'like') { cReactionText = "Thích"; cReactionColor = navyBlue; }
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
        onTap: () => _showCommentReactionDetailsBottomSheet(int.parse(c['CommentID'].toString())),
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
                // 🚀 HÀNG 1: TÊN NGƯỜI DÙNG & DẤU 3 CHẤM NẰM SÁT GÓC PHẢI
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
                            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: navyBlue, borderRadius: BorderRadius.circular(4)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, color: Colors.white, size: 9), SizedBox(width: 3), Text("Tác giả", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]))
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
                
                // 🚀 HÀNG 2: NỘI DUNG BÌNH LUẬN VÀ ẢNH
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
                            : TextButton(onPressed: () => _updateCommentApi(c), child: Text("Lưu", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold))),
                        ],
                      )
                    ],
                  )
                else ...[
                  if (contentTxt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2), 
                      // 🚀 Thuật toán quét và bôi xanh @Tên
                      child: Builder(
                        builder: (context) {
                          List<TextSpan> spans = [];
                          
                          Set<String> participantNames = { currentPost['Username']?.toString() ?? '' };
                          for (var cmt in _comments) {
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
                              if (i < parts.length - 1) spans.add(TextSpan(text: mention, style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold))); 
                            }
                          } else {
                            final RegExp mentionRegex = RegExp(r'(@\S+)');
                            final Iterable<RegExpMatch> matches = mentionRegex.allMatches(contentTxt);
                            int lastMatchEnd = 0;
                            
                            for (final RegExpMatch match in matches) {
                              if (match.start > lastMatchEnd) spans.add(TextSpan(text: contentTxt.substring(lastMatchEnd, match.start)));
                              spans.add(TextSpan(text: match.group(0), style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)));
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
                        Text(_formatTime(c['CreatedAt']?.toString()), style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            String target = cReaction.isNotEmpty ? cReaction : 'like';
                            _reactToCommentLocal(c, target); // 🚀 ĐÃ FIX: Sửa lại đúng tên hàm của trang Group Post
                          },
                          onLongPressStart: (details) => _showCommentReactionOverlay(context, details.globalPosition, c),
                          behavior: HitTestBehavior.opaque,
                          child: Text(cReactionText, style: TextStyle(color: cReactionColor, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
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
                          Icon(Icons.chat_bubble_outline_rounded, size: 16, color: navyBlue),
                          const SizedBox(width: 6),
                          Text(
                            _expandedCommentIds.contains(c['CommentID']) 
                                ? "Ẩn phản hồi" 
                                : "Hiển thị ${replies.length} phản hồi", 
                            style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ],
                      ),
                    ),
                  ),

                // 🚀 HÀNG 4: BÌNH LUẬN CON (KÈM VẠCH XÁM CHUẨN THREADS)
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
 @override
  Widget build(BuildContext context) {
    final user = UserManager.instance.currentUser;
    
    bool isTransferPost = currentPost['Type'] == 'transfer'; 
    bool _hasTicket = currentPost['ShowtimeDate'] != null;
    bool hasBgColor = currentPost['BgColor'] != null && currentPost['BgColor'] != '';
    bool hasTaggedMovie = currentPost['MovieID'] != null;
    
    // ✅ KIỂM TRA TRẠNG THÁI BỊ ẨN/HỦY CỦA BÀI VIẾT
    bool isHidden = currentPost['Status'] == 0 || currentPost['Status'] == '0'; 

    Color bgColor = Colors.white;
    if (hasBgColor) bgColor = Color(int.parse(currentPost['BgColor'].replaceAll('#', '0xFF')));

    List<String> postImages = [];
    if (currentPost['PostImages'] != null && currentPost['PostImages'].toString().isNotEmpty) {
      try { postImages = List<String>.from(jsonDecode(currentPost['PostImages'])); } catch (_) {}
    }

    List<dynamic> transferFoodsList = [];
    if (currentPost['TransferFoods'] != null) {
      try {
        if (currentPost['TransferFoods'] is String) transferFoodsList = jsonDecode(currentPost['TransferFoods']);
        else transferFoodsList = currentPost['TransferFoods'];
      } catch (e) {}
    }

    String userReaction = currentPost['user_reaction']?.toString() ?? '';
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

    int totalLikes = currentPost['total_likes'] ?? 0;
    Widget summaryReactionIcon = const SizedBox.shrink();
    
    if (totalLikes > 0) {
      String topReactionsStr = currentPost['top_reactions']?.toString() ?? 'like'; 
      List<String> actualReactions = topReactionsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (actualReactions.isEmpty) actualReactions = ['like']; 

      List<Widget> stackChildren = [];
      if (actualReactions.length > 1) stackChildren.add(Transform.translate(offset: const Offset(12, 0), child: _getIconByType(actualReactions[1])));
      stackChildren.add(_getIconByType(actualReactions[0]));

      // 🚀 ĐÃ FIX GẠCH ĐỎ: Ép kiểu dữ liệu (ép từ dynamic sang int)
      summaryReactionIcon = GestureDetector(
        onTap: () => _showReactionDetailsBottomSheet(int.parse(currentPost['PostID'].toString())),
        behavior: HitTestBehavior.opaque, // Thần chú giúp bấm vùng trống vẫn ăn
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(clipBehavior: Clip.none, children: stackChildren),
              SizedBox(width: actualReactions.length > 1 ? 18 : 8),
              Text(totalLikes.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold))
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
      // 🚀 ĐÃ FIX: Chạm ra khoảng trống bất kỳ để ép tắt bàn phím
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
            child: ScrollToTopWrapper(
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: Colors.white,
                    // ✅ LÀM MỜ NHẸ TOÀN BỘ NỘI DUNG NẾU BÀI BỊ ẨN/HỦY
                    child: Opacity(
                      opacity: isHidden ? 0.8 : 1.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🚀 ĐÃ SỬA: Avatar chủ bài viết
                                _buildAvatar(currentPost['Avatar']?.toString(), 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(currentPost['Username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          if (isTransferPost) ...[
                                            const SizedBox(width: 6),
                                            // ✅ HIỆN TAG "ĐÃ HỦY" NẾU BÀI BỊ ẨN
                                            if (isHidden)
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)), child: const Text("❌ ĐÃ HỦY", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)))
                                            else
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)), child: const Text("🎫 NHƯỢNG VÉ", style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold)))
                                          ]
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(_formatTime(currentPost['CreatedAt']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                          if (currentPost['Role'] != null && currentPost['Role'].toString().toLowerCase() == 'admin') ...[
                                            const SizedBox(width: 6), Icon(Icons.verified, color: isHidden ? Colors.grey : navyBlue, size: 14), const SizedBox(width: 2),
                                            Text("Quản trị viên", style: TextStyle(color: isHidden ? Colors.grey : navyBlue, fontSize: 11, fontWeight: FontWeight.bold))
                                          ]
                                        ],
                                      )
                                    ]
                                  )
                                ),
                                IconButton(onPressed: () => _showPostOptionsModal(), icon: const Icon(Icons.more_horiz, color: Colors.grey))
                              ],
                            ),
                          ),
                          
                          // ✅ THÊM BANNER GIẢI THÍCH LÝ DO ẨN BÀI CHO NGƯỜI DÙNG HIỂU
                          if (isHidden && isTransferPost)
                            Container(
                              margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.grey, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Bài viết đang bị ẩn với mọi người do suất chiếu sẽ diễn ra trong vòng 60 phút tới hoặc đã kết thúc.", 
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.4)
                                    )
                                  ),
                                ],
                              ),
                            ),
  
                          const SizedBox(height: 16),
                          
                          if (hasBgColor)
                            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20), decoration: BoxDecoration(color: bgColor), child: Text(currentPost['Content'] ?? "", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4)))
                          else
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(currentPost['Content'] ?? "", style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black87))),
                          
                          if (!hasBgColor && postImages.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 12), child: _buildImageGallery(postImages)),
  
                          const SizedBox(height: 16),
  
                          if (isTransferPost && _hasTicket)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isHidden ? Colors.grey.shade50 : Colors.orange.shade50.withOpacity(0.5), 
                                  borderRadius: BorderRadius.circular(16), 
                                  border: Border.all(color: isHidden ? Colors.grey.shade300 : Colors.orange.shade200, width: 1.2)
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_getRealImageUrl(currentPost['MovieImage']), width: 80, height: 115, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 80, height: 115, color: Colors.grey.shade300, child: const Icon(Icons.movie, color: Colors.grey)))),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(currentPost['MovieTitle'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 6),
                                                Row(children: [Icon(Icons.theaters, size: 14, color: isHidden ? Colors.grey : Colors.deepOrange), const SizedBox(width: 6), Expanded(child: Text("${currentPost['CinemaName']} - ${currentPost['RoomName']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)))]),
                                                const SizedBox(height: 4),
                                                Row(children: [const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey), const SizedBox(width: 6), Expanded(child: Text(currentPost['CinemaAddress'] ?? "", style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                                                const SizedBox(height: 4),
                                                Row(children: [Icon(Icons.access_time_rounded, size: 14, color: isHidden ? Colors.grey : Colors.blue), const SizedBox(width: 6), Text("Suất: ${currentPost['ShowtimeDate']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHidden ? Colors.grey.shade700 : Colors.blue))]),
                                                const SizedBox(height: 4),
                                                Row(children: [Icon(Icons.event_seat_rounded, size: 14, color: isHidden ? Colors.grey : Colors.purple), const SizedBox(width: 6), Text("Ghế: ${currentPost['TransferSeats']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHidden ? Colors.grey.shade700 : Colors.purple))]),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
  
                                    if (transferFoodsList.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [Icon(Icons.fastfood_outlined, size: 14, color: isHidden ? Colors.grey : Colors.green), const SizedBox(width: 6), Text("Bắp nước đi kèm:", style: TextStyle(fontSize: 12, color: isHidden ? Colors.grey.shade700 : Colors.green, fontWeight: FontWeight.bold))]),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8, runSpacing: 8,
                                              children: transferFoodsList.map((food) {
                                                return Container(
                                                  padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4, left: 4),
                                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isHidden ? Colors.grey.shade300 : Colors.green.shade200)),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_getRealImageUrl(food['image']), width: 24, height: 24, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.fastfood, size: 16, color: Colors.grey))),
                                                      const SizedBox(width: 6),
                                                      Text("${food['name']} x${food['qty']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                                                    ]
                                                  )
                                                );
                                              }).toList()
                                            ),
                                          ],
                                        ),
                                      ),
  
                                    Row(children: List.generate(24, (index) => Expanded(child: Container(color: index % 2 == 0 ? Colors.transparent : (isHidden ? Colors.grey.shade300 : Colors.orange.shade200), height: 1.5)))),
                                    
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Giá gốc đã chặn đôn giá", style: TextStyle(fontSize: 10, color: Colors.black45)),
                                              Text(NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(double.tryParse(currentPost['TransferPrice']?.toString() ?? '0') ?? 0), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isHidden ? Colors.grey.shade600 : Colors.deepOrange))
                                            ],
                                          ),
                                          // ✅ NÚT MUA VÉ SẼ BỊ KHÓA NẾU BÀI BỊ ẨN
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isHidden ? Colors.grey.shade400 : Colors.deepOrange, 
                                              foregroundColor: Colors.white, 
                                              elevation: 0, 
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), 
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
                                            ),
                                            onPressed: isHidden ? null : () { 
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hệ thống đang chuyển hướng tới cổng trung gian bảo mật...'))); 
                                            },
                                            icon: Icon(isHidden ? Icons.block : Icons.shopping_bag_outlined, size: 14),
                                            label: Text(isHidden ? "Hết hạn" : "Mua Vé", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            )
                          else if (hasTaggedMovie)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                child: Row(
                                  children: [
                                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_getRealImageUrl(currentPost['MovieImage']), width: 50, height: 75, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 50, height: 75, color: Colors.grey.shade300))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(currentPost['MovieTitle'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(currentPost['MovieGenres'] ?? "Phim rạp", style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    // ✅ ĐÃ SỬA: BẤM VÀO ĐẶT VÉ CHUYỂN SANG MOVIE DETAIL (ĐÃ TÍCH HỢP HÀM TIỆN ÍCH)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: navyBlue, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                                      onPressed: () {
                                        Navigator.push(
                                          context, 
                                          MaterialPageRoute(builder: (_) => MovieDetailPage(movie: _getMovieFromPostData(currentPost)))
                                        );
                                      }, 
                                      child: const Text("Đặt vé", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                                    )
                                  ],
                                ),
                              ),
                            ),
  
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                summaryReactionIcon,
                                const Spacer(),
                                Text("${currentPost['total_comments']} bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16), child: Divider(height: 1)),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      String targetReaction = isReacted ? userReaction : 'like';
                                      _reactToPostLocal(targetReaction);
                                    }, 
                                    onLongPressStart: (details) => _showReactionOverlay(context, details.globalPosition),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [reactionIcon, const SizedBox(width: 4), Flexible(child: Text(reactionText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: reactionColor, fontWeight: FontWeight.w600, fontSize: 13)))]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _commentFocusNode.requestFocus(), 
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, color: Colors.grey.shade700, size: 20), const SizedBox(width: 4), Flexible(child: Text("Bình luận", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13)))]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                               Expanded(
                                child: InkWell(
                                  onTap: () {
                                    // 🚀 ĐÃ SỬA: CHỈ GỬI DUY NHẤT CÁI LINK
                                    // Zalo/Messenger sẽ tự động sinh ra cái Box từ link này
                                    String shareUrl = "https://sneeze-dust-linguist.ngrok-free.dev/share/post/${currentPost['PostID']}";
                                    
                                    Share.share(shareUrl);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center, 
                                      children: [
                                        Icon(Icons.shortcut, color: Colors.grey.shade700, size: 20), 
                                        const SizedBox(width: 4), 
                                        // ✅ ĐÃ SỬA: Tháo bỏ thẻ Flexible() bao quanh Text để chữ "Chia sẻ" không bị lỗi cắt ngang "..."
                                        Text(
                                          "Chia sẻ", 
                                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13)
                                        )
                                      ]
                                    ),
                                  ),
                                ),
                              ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  Divider(thickness: 6, color: Colors.grey.shade200),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text("Bình luận", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text("${currentPost['total_comments']} bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),

                  _isLoadingComments
                    ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                    : _comments.isEmpty
                      ? const Padding(padding: EdgeInsets.all(30), child: Text("Chưa có bình luận nào. Hãy là người đầu tiên!", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentItem(_comments[index]);
                          },
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }),
        ),
          
        // 7. BOTTOM BAR NHẬP BÌNH LUẬN VÀ TRẢ LỜI
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 ĐÃ THÊM LẠI: BANNER "ĐANG TRẢ LỜI" + TÍNH NĂNG BẤM HỦY LÀ XÓA CHỮ @TÊN TRONG Ô NHẬP
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
                                // 1. Quét tìm và xóa chữ @Tên (Kể cả có dấu cách hay lỡ xóa mất dấu cách)
                                String mentionWithSpace = '@$_replyingToUsername ';
                                String mentionNoSpace = '@$_replyingToUsername';
                                String currentText = _commentController.text;
                                
                                if (currentText.contains(mentionWithSpace)) {
                                  _commentController.text = currentText.replaceFirst(mentionWithSpace, '');
                                } else if (currentText.contains(mentionNoSpace)) {
                                  _commentController.text = currentText.replaceFirst(mentionNoSpace, '');
                                }

                                // 2. Đưa con trỏ chuột về vị trí cũ (nếu có chữ khác)
                                _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
                                
                                // 3. Hủy trạng thái trả lời
                                _replyingToCommentId = null;
                                _replyingToUsername = null;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close, size: 16, color: Colors.grey),
                            ),
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
                      // 🚀 ĐÃ NÂNG CẤP: Avatar tự động thu gọn mượt mà khi gõ phím HOẶC khi đang có chữ
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SizeTransition(sizeFactor: animation, axis: Axis.horizontal, child: child);
                        },
                        // Chỉ hiện Avatar khi: Tắt bàn phím VÀ Xóa sạch chữ
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
                            // 🚀 ĐÃ NÂNG CẤP: Chữ dài tự rớt xuống hàng, tối đa 5 hàng rồi mới cuộn
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
                    _isSubmittingComment 
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(onPressed: _submitComment, icon: Icon(Icons.send, color: navyBlue))
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    ),
    );
  }
  // ====================================================================
  // HÀM TIỆN ÍCH: TỰ ĐỘNG NẶN RA ĐỐI TƯỢNG MOVIE (ĐÃ FIX ẢNH)
  // ====================================================================
  Movie _getMovieFromPostData(Map<String, dynamic> data) {
    // 1. Lấy link ảnh chuẩn
    String fullPosterUrl = _getRealImageUrl(data['MovieImage']?.toString());
    String fullBackdropUrl = _getRealImageUrl(data['MovieBackdrop']?.toString());
    if (fullBackdropUrl.isEmpty) fullBackdropUrl = fullPosterUrl;

    // 2. Xử lý Điểm đánh giá
    double parsedVote = 0.0;
    if (data['MovieVoteAverage'] != null) {
      parsedVote = double.tryParse(data['MovieVoteAverage'].toString()) ?? 0.0;
    }

    // 3. Trả về đối tượng Movie
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
  
  // ==============================================================
  // ✅ HÀM VẼ AVATAR "BỌC THÉP V3" (FIX LỖI CẮT NHẦM FOLDER)
  // Đã đồng bộ sức mạnh với trang CreatePost và GroupMovie
  // ==============================================================
  Widget _buildAvatar(String? avatarUrl, double size) {
    String finalUrl = '';
    
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty && avatarUrl != 'null') {
      String cleanPath = avatarUrl.trim().replaceAll('\\', '/');
      
      if (cleanPath.startsWith('http')) {
        if (cleanPath.contains(':3000')) {
          final parts = cleanPath.split(':3000');
          if (parts.length > 1) {
            String subPath = parts[1];
            subPath = subPath.replaceFirst('/public', ''); 
            if (!subPath.startsWith('/')) subPath = '/$subPath';
            finalUrl = '$apiBaseUrl$subPath'; 
          } else {
            finalUrl = cleanPath;
          }
        } else {
          finalUrl = cleanPath; 
        }
      } else {
        // Xóa các rác dư thừa nếu có từ DB
        cleanPath = cleanPath.replaceFirst('/public', '').replaceFirst('public/', '');
        if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
        
        // 🚀 BƯỚC THẦN THÁNH: Tách lấy đúng tên file cuối cùng (VD: avatar-123.jpg)
        String filename = cleanPath.split('/').last;

        // TỰ ĐỘNG ROUTING THEO CẤU TRÚC THƯ MỤC THỰC TẾ
        if (filename.startsWith('avatar') || filename.startsWith('user')) {
           finalUrl = '$apiBaseUrl/avatars/$filename'; 
        } else if (filename.startsWith('food')) {
           finalUrl = '$apiBaseUrl/foods/$filename';
        } else {
           finalUrl = '$apiBaseUrl/uploads/$filename';
        }
      }
    }

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
                  debugPrint('❌ LỖI TẢI AVATAR (PostDetail): $finalUrl');
                  // Lỗi thì backup về chữ cái đầu của người dùng đang đăng nhập
                  return Center(child: Text(UserManager.instance.currentUser?.name.substring(0, 1).toUpperCase() ?? "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4)));
                },
              )
            : Center(child: Text(UserManager.instance.currentUser?.name.substring(0, 1).toUpperCase() ?? "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4))),
      ),
    ); 
  }
  // ====================================================================
  // 🚀 BOTTOM SHEET 1: DANH SÁCH AI LIKE BÀI VIẾT CHÍNH CỦA GROUP
  // ====================================================================
  void _showReactionDetailsBottomSheet(int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FutureBuilder<http.Response>(
          // GỌI API LẤY DANH SÁCH LIKE CỦA BÀI VIẾT NHÓM
          future: http.get(Uri.parse('$apiBaseUrl/api/group/posts/$postId/reactions')),
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
                      isScrollable: true, indicatorColor: navyBlue, labelColor: navyBlue, unselectedLabelColor: Colors.grey.shade600, labelPadding: const EdgeInsets.symmetric(horizontal: 20),
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

  // ====================================================================
  // 🚀 BOTTOM SHEET 2: DANH SÁCH AI LIKE BÌNH LUẬN TRONG GROUP
  // ====================================================================
  void _showCommentReactionDetailsBottomSheet(int commentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FutureBuilder<http.Response>(
          // GỌI API LẤY DANH SÁCH LIKE CỦA BÌNH LUẬN NHÓM
          future: http.get(Uri.parse('$apiBaseUrl/api/group/comments/$commentId/reactions')),
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
                      isScrollable: true, indicatorColor: navyBlue, labelColor: navyBlue, unselectedLabelColor: Colors.grey.shade600, labelPadding: const EdgeInsets.symmetric(horizontal: 20),
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