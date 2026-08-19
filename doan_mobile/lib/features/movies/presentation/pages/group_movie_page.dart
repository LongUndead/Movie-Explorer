import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/movie.dart'; 
import 'movie_detail_page.dart';
import 'user_manager.dart'; 
import 'group_details_page.dart';
import 'post_detail_page.dart';
import 'create_post_page.dart';
import 'edit_post_page.dart';
import 'guest_guard.dart'; // 🚀 IMPORT TRẠM GÁC DÀNH CHO KHÁCH
import '../widgets/scroll_to_top_wrapper.dart';
import 'post_image_viewer_screen.dart'; 

// ============================================================================
// TRANG CHÍNH: NHÓM PHIM (ĐÃ BỎ DUYỆT BÀI NHƯỢNG VÉ VÀ TỰ ĐỘNG ĐÓNG BÀI CẬN GIỜ)
// ============================================================================
class GroupMoviePage extends StatefulWidget {
  const GroupMoviePage({super.key});

  @override
  State<GroupMoviePage> createState() => _GroupMoviePageState();
}

class _GroupMoviePageState extends State<GroupMoviePage> {
  final Color navyBlue = Colors.blue.shade900;
  final String apiBaseUrl = 'http://10.173.120.41:3000'; 
  
  bool _isJoined = false;
  int _memberCount = 0;
  List<dynamic> _allPosts = []; 
  bool _isLoading = true;
  OverlayEntry? _overlayEntry;

  String _currentFilterKey = 'all'; 
  final List<Map<String, String>> _filterOptions = [
    {'key': 'all', 'label': 'Tất cả bài viết'},
    {'key': 'personal', 'label': 'Cá nhân'},
    {'key': 'admin', 'label': 'Quản trị viên'},
    {'key': 'member', 'label': 'Thành viên'},
  ];

  String get _currentFilterLabel {
    return _filterOptions.firstWhere((opt) => opt['key'] == _currentFilterKey)['label']!;
  }

  IO.Socket? socket;

  @override
  void initState() {
    super.initState();
    _fetchGroupData();
    _connectSocket(); // 🚀 BẬT RADA LẮNG NGHE TÍN HIỆU NGAY KHI MỞ TRANG
  }

  @override
  void dispose() {
    socket?.disconnect(); // 🚀 NGẮT RADA KHI THOÁT TRANG ĐỂ ĐỠ HAO PIN
    socket?.dispose();
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

    // Lắng nghe sự kiện thả cảm xúc (Từ máy người khác bấm)
    socket!.on('post_reaction_updated', (data) {
      if (!mounted) return;
      setState(() {
        int postId = int.parse(data['post_id'].toString());
        int index = _allPosts.indexWhere((p) => p['PostID'] == postId);
        
        if (index != -1) {
          // Chỉ cập nhật tổng Like và danh sách Top Cảm Xúc (Của hệ thống)
          _allPosts[index]['total_likes'] = data['total_likes'];
          _allPosts[index]['top_reactions'] = data['top_reactions'];
        }
      });
    });
  }

  Future<void> _fetchGroupData() async {
    final user = UserManager.instance.currentUser;
    int userId = user?.id ?? 1;

    try {
      // ✅ BƯỚC MỚI: Gọi API dọn dẹp ngầm trước khi lấy danh sách bài viết
      // Mọi bài nhượng vé cách giờ chiếu < 60 phút sẽ bị ẩn đi khỏi Database
      await http.get(Uri.parse('$apiBaseUrl/api/group/cleanup-transfers'));

      final responses = await Future.wait([
        http.get(Uri.parse('$apiBaseUrl/api/group/members')),
        http.get(Uri.parse('$apiBaseUrl/api/group/posts?user_id=$userId')), 
        http.get(Uri.parse('$apiBaseUrl/api/group/check-join?user_id=$userId')),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200 && responses[2].statusCode == 200) {
        if (mounted) {
          setState(() {
            _memberCount = jsonDecode(responses[0].body)['total'] ?? 0;
            _allPosts = jsonDecode(responses[1].body);
            _isJoined = jsonDecode(responses[2].body)['isJoined'] ?? false;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====================================================================
  // ✅ TÍNH NĂNG LIKE BÀI POST (ĐÃ FIX LỖI ĐÈ CẢM XÚC + ĐỒNG BỘ SERVER)
  // ====================================================================
  Future<void> _reactToPost(int postId, String reactionType) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    setState(() {
      int index = _allPosts.indexWhere((p) => p['PostID'] == postId);
      if (index != -1) {
        var post = _allPosts[index];
        String currentReaction = post['user_reaction']?.toString() ?? '';
        String topReactionsStr = post['top_reactions']?.toString() ?? '';
        
        // ✅ XÓA SẠCH KHOẢNG TRẮNG CHỐNG LỖI KẸT ICON
        List<String> topReactionsList = topReactionsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        if (currentReaction == reactionType) {
          // Bấm lại icon cũ -> Hủy thả cảm xúc
          post['user_reaction'] = '';
          if ((post['total_likes'] ?? 0) > 0) post['total_likes'] = post['total_likes'] - 1;
          topReactionsList.remove(reactionType);
        } else {
          // Chưa có hoặc đổi cảm xúc khác
          if (currentReaction.isNotEmpty) {
            topReactionsList.remove(currentReaction); // Gỡ cái cũ ra
          } else {
            post['total_likes'] = (post['total_likes'] ?? 0) + 1;
          }
          post['user_reaction'] = reactionType;
          
          topReactionsList.remove(reactionType); // Chắc chắn không có cái trùng
          topReactionsList.insert(0, reactionType); // Gắn cái mới vào đầu mảng
        }
        
        post['top_reactions'] = topReactionsList.join(',');
      }
    });

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/group/posts/react'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id, 'post_id': postId, 'reaction_type': reactionType})
      );
      // 🚀 ĐÃ XÓA LỆNH FETCH LẠI DATA ĐỂ MÀN HÌNH KHÔNG BỊ GIẬT
      // Socket từ server sẽ tự động lo việc báo lại cho máy mình và máy người khác!
    } catch (e) {
      debugPrint("Lỗi react bài viết nhóm: $e");
    }
  }
  List<dynamic> get _filteredPosts {
    final currentUserId = UserManager.instance.currentUser?.id;
    return _allPosts.where((post) {
      if (_currentFilterKey == 'personal') return post['PostUserID'] == currentUserId;
      if (_currentFilterKey == 'admin') return post['Role']?.toString().toLowerCase() == 'admin';
      if (_currentFilterKey == 'member') return post['Role']?.toString().toLowerCase() != 'admin';
      return true; 
    }).toList();
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true, 
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const Text("Chọn bộ lọc bài viết", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 20),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filterOptions.length,
                      itemBuilder: (context, index) {
                        final option = _filterOptions[index];
                        bool isSelected = option['key'] == _currentFilterKey;

                        return GestureDetector(
                          onTap: () {
                            setState(() { _currentFilterKey = option['key']!; });
                            Navigator.pop(bc);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? navyBlue : Colors.grey.shade200, width: isSelected ? 2 : 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(option['label']!, style: TextStyle(color: isSelected ? navyBlue : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                                if (isSelected) Icon(Icons.check_circle_rounded, color: navyBlue),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showPostOptionsModal(Map<String, dynamic> post) {
    final currentUserId = UserManager.instance.currentUser?.id;
    bool isAuthor = post['PostUserID'] == currentUserId;

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
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông báo!')));
                },
              ),
              if (isAuthor) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                  title: const Text('Sửa bài viết', style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(context); 
                    final result = await Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => EditPostPage(post: post)) 
                    );
                    if (result != null) _fetchGroupData();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Xóa bài viết', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePost(post['PostID']);
                  },
                ),
              ] 
              else ...[
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                  title: const Text('Báo cáo bài viết', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context); // Đóng menu 3 chấm
                    _showReportDialog(post['PostID']); // Mở bảng Báo cáo lên
                  },
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.grey),
                title: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    );
  }

  void _showReactionOverlay(BuildContext context, Offset tapPosition, int postId) {
    if (_overlayEntry != null) return;
    double screenWidth = MediaQuery.of(context).size.width;
    double leftPos = tapPosition.dx - 140; 
    if (leftPos < 10) leftPos = 10;
    if (leftPos + 280 > screenWidth - 10) leftPos = screenWidth - 290;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(onTap: () => _removeReactionOverlay(), child: Container(color: Colors.transparent))),
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
                      _buildOverlayEmoji(postId, 'like', '👍'),
                      _buildOverlayEmoji(postId, 'love', '❤️'),
                      _buildOverlayEmoji(postId, 'haha', '😆'),
                      _buildOverlayEmoji(postId, 'wow', '😮'),
                      _buildOverlayEmoji(postId, 'sad', '😢'),
                      _buildOverlayEmoji(postId, 'angry', '😡'),
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

  Widget _buildOverlayEmoji(int postId, String type, String emoji) {
    return GestureDetector(
      onTap: () { _removeReactionOverlay(); _reactToPost(postId, type); },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(emoji, style: const TextStyle(fontSize: 28))),
    );
  }

  void _removeReactionOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _handleJoinButtonPress() async {
    if (_isJoined) {
      bool? confirm = await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 36)),
                const SizedBox(height: 20),
                const Text("Rời khỏi cộng đồng?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                Text("Bạn chắc chắn muốn rời nhóm chứ?", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(context, false), child: Text("Ở lại", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(context, true), child: const Text("Rời nhóm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                  ],
                )
              ],
            ),
          ),
        ),
      );
      if (confirm == true) _toggleJoinGroup();
    } else {
      _toggleJoinGroup();
    }
  }

  Future<void> _toggleJoinGroup() async {
    final user = UserManager.instance.currentUser;
    int userId = user?.id ?? 1;
    bool newStatus = !_isJoined;

    setState(() {
      _isJoined = newStatus;
      if (newStatus) _memberCount++;
      else if (_memberCount > 0) _memberCount--;
    });

    // 🚀 LƯU THỜI GIAN GIA NHẬP VÀO SHPREFERENCES CỦA ĐIỆN THOẠI
    final prefs = await SharedPreferences.getInstance();
    if (newStatus) {
      // Nếu vừa bấm tham gia -> Lưu thời gian hiện tại (ISO string)
      await prefs.setString('group_joined_time_$userId', DateTime.now().toIso8601String());
    } else {
      // Nếu rời nhóm -> Xóa mốc thời gian
      await prefs.remove('group_joined_time_$userId');
    }

    try {
      final response = await http.post(Uri.parse('$apiBaseUrl/api/group/toggle-join'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'is_joined': newStatus}));
      if (response.statusCode == 200) {
        if (mounted) setState(() => _memberCount = jsonDecode(response.body)['total']);
      }
    } catch (e) {}
  }

  Future<void> _deletePost(int postId) async {
    final user = UserManager.instance.currentUser;
    try {
      final res = await http.delete(Uri.parse('$apiBaseUrl/api/group/posts/$postId'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': user?.id}));
      if (res.statusCode == 200) {
        _fetchGroupData(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết')));
      }
    } catch (e) {}
  }

  // ==============================================================
  // HIỂN THỊ BẢNG CHỌN LÝ DO BÁO CÁO BÀI VIẾT (ĐÃ NÂNG CẤP LÝ DO KHÁC)
  // ==============================================================
  void _showReportDialog(int postId) {
    final List<String> reasons = [
      "Nội dung rác (Spam)",
      "Ngôn từ gây thù ghét, đả kích",
      "Lừa đảo, bán vé giả",
      "Nội dung 18+ hoặc bạo lực",
      "Thông tin sai sự thật",
      "Lý do khác"
    ];
    String selectedReason = reasons[0];
    
    // 🚀 ĐÃ THÊM: Biến quản lý nội dung ô nhập lý do khác
    final TextEditingController customReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.report_problem, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text("Báo cáo bài viết", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              // 🚀 ĐÃ THÊM: Bọc bằng SingleChildScrollView để khi bàn phím ảo bật lên không bị lỗi tràn viền
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Vui lòng chọn lý do báo cáo:", style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                    const SizedBox(height: 12),
                    ...reasons.map((reason) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: Colors.orange,
                      onChanged: (value) => setState(() {
                        selectedReason = value!;
                        // Nếu đổi ý không chọn "Lý do khác" nữa thì xóa text cũ đi
                        if (selectedReason != "Lý do khác") {
                          customReasonController.clear();
                        }
                      }),
                    )),

                    // 🚀 ĐÃ THÊM: Ô nhập liệu chỉ hiện ra khi chọn "Lý do khác"
                    if (selectedReason == "Lý do khác")
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                        child: TextField(
                          controller: customReasonController,
                          maxLength: 200, // Giới hạn 200 ký tự
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Vui lòng mô tả chi tiết...",
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.orange),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    String finalReason = selectedReason;

                    // 🚀 ĐÃ THÊM: Kiểm tra bắt buộc nhập nếu chọn "Lý do khác"
                    if (selectedReason == "Lý do khác") {
                      if (customReasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập chi tiết lý do báo cáo!'), backgroundColor: Colors.red)
                        );
                        return; // ⛔ Dừng lại, không cho gửi, không đóng bảng
                      }
                      // Nếu có nhập thì lấy nội dung đó gán vào finalReason
                      finalReason = customReasonController.text.trim();
                    }

                    Navigator.pop(context); // Đóng bảng báo cáo
                    await _submitReportApi(postId, finalReason); // Gọi API với lý do cuối cùng
                  },
                  child: const Text("Gửi báo cáo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }
  // Hàm gọi API Báo cáo
  Future<void> _submitReportApi(int postId, String reason) async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/group/posts/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'post_id': postId, 'reporter_id': user.id, 'reason': reason}),
      );
      final data = jsonDecode(res.body);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['message']), 
        backgroundColor: data['success'] ? Colors.green : Colors.red
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối đến máy chủ!'), backgroundColor: Colors.red));
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return "Vừa xong";
    try { return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(isoTime).toLocal()); } catch (_) { return "Vừa xong"; }
  }
  
  // ==============================================================
  // ✅ HÀM XỬ LÝ ẢNH BÀI ĐĂNG & ẢNH PHIM "BỌC THÉP V3"
  // Phân biệt chính xác 100% ảnh TMDB và ảnh User up lên
  // ==============================================================
  String _getRealImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null') return "";
    String cleanPath = rawPath.trim().replaceAll('\\', '/');

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

    bool isLocalImage = cleanPath.contains('upload') || 
                        filename.contains('image') || 
                        filename.contains('scaled') || 
                        filename.contains('movie-') || 
                        filename.contains('-') || 
                        filename.contains('_');

    if (isLocalImage) {
      if (filename.startsWith('food')) return '$apiBaseUrl/foods/$filename';
      if (filename.startsWith('avatar') || filename.startsWith('user')) return '$apiBaseUrl/avatars/$filename';
      return '$apiBaseUrl/uploads/$filename';
    } else {
      if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
      return 'https://image.tmdb.org/t/p/w500$cleanPath';
    }
  }
  // ==============================================================
  // 🚀 LƯỚI ẢNH CHUẨN FACEBOOK (TỰ CHIA BỐ CỤC 1, 2, 3, 4+)
  // ==============================================================
  Widget _buildImageGallery(List<String> images, Map<String, dynamic> post) {
    if (images.isEmpty) return const SizedBox.shrink();
    
    int count = images.length;

    // 🚀 HÀM NHẢY SANG TRANG CUỘN ẢNH VERTICAL (Không nhảy vào PostDetail vội)
    void openImageViewer() {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => PostImageViewerScreen(
          post: post, 
          images: images, 
          apiBaseUrl: apiBaseUrl,
          onCommentTapped: () async {
            // Khi đang ở màn cuộn ảnh mà bấm Bình Luận -> Nhảy vô trang Chi tiết
            Navigator.pop(context); // Đóng màn cuộn ảnh
            await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
            _fetchGroupData(); // Làm mới data
          }
        ))
      );
    }

    if (count == 1) {
      return GestureDetector(
        onTap: openImageViewer,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 450),
          color: Colors.black.withOpacity(0.03),
          child: Image.network(_getRealImageUrl(images[0]), fit: BoxFit.contain),
        ),
      );
    } 
    else if (count == 2) {
      return GestureDetector(
        onTap: openImageViewer,
        child: SizedBox(
          height: 250,
          child: Row(
            children: [
              Expanded(child: Padding(padding: const EdgeInsets.only(right: 2), child: Image.network(_getRealImageUrl(images[0]), fit: BoxFit.cover, height: double.infinity))),
              Expanded(child: Padding(padding: const EdgeInsets.only(left: 2), child: Image.network(_getRealImageUrl(images[1]), fit: BoxFit.cover, height: double.infinity))),
            ],
          ),
        ),
      );
    } 
    else if (count == 3) {
      return GestureDetector(
        onTap: openImageViewer,
        child: SizedBox(
          height: 250,
          child: Row(
            children: [
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(right: 2), child: Image.network(_getRealImageUrl(images[0]), fit: BoxFit.cover, height: double.infinity))),
              Expanded(flex: 1, child: Column(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 2), child: Image.network(_getRealImageUrl(images[1]), fit: BoxFit.cover, width: double.infinity))),
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Image.network(_getRealImageUrl(images[2]), fit: BoxFit.cover, width: double.infinity))),
                ],
              )),
            ],
          ),
        ),
      );
    } 
    else {
      // 4 HOẶC HƠN 4 ẢNH (LƯỚI 2x2 CÓ CHỮ +3 ĐÈ LÊN)
      return GestureDetector(
        onTap: openImageViewer,
        child: GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1.0),
          itemCount: 4, 
          itemBuilder: (ctx, i) {
            if (i == 3 && count > 4) {
               return Stack(
                 fit: StackFit.expand, 
                 children: [
                  Image.network(_getRealImageUrl(images[3]), fit: BoxFit.cover),
                  Container(color: Colors.black54, child: Center(child: Text('+${count - 4}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))))
               ]);
            }
            return Image.network(_getRealImageUrl(images[i]), fit: BoxFit.cover);
          }
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final double appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    final user = UserManager.instance.currentUser;
    final filteredList = _filteredPosts; 

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Stack(
          children: [
            Container(height: 140, width: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF64B5F6), Color(0xFFF5F5F9)]))),
            
            // 🚀 BỌC SCROLL TO TOP WRAPPER VÀO ĐÂY
            ScrollToTopWrapper(
              builder: (context, scrollController) {
                return RefreshIndicator(
                  onRefresh: _fetchGroupData,
                  color: navyBlue, backgroundColor: Colors.white, displacement: appBarHeight,
                  child: SingleChildScrollView(
                    controller: scrollController, // 🚀 GẮN CONTROLLER TỪ WRAPPER VÀO ĐÂY
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: appBarHeight - 25),
                    AspectRatio(
                      aspectRatio: 1376 / 768, 
                      child: Image.asset('assets/group.png', width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, __, ___) => Container(width: double.infinity, color: Colors.blue.shade100)),
                    ),
                    
                    Container(
                      width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Colors.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Cộng Đồng Ghiền Xem Phim", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text("Nhóm công khai • $_memberCount thành viên", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(flex: 10, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _isJoined ? Colors.grey.shade200 : navyBlue, foregroundColor: _isJoined ? Colors.black87 : Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: (){ GuestGuard.check(context, () => _handleJoinButtonPress());}, icon: Icon(_isJoined ? Icons.check : Icons.add, size: 18), label: Text(_isJoined ? "Đã tham gia" : "Tham gia", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
                              const SizedBox(width: 8),
                              Expanded(flex: 9, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), backgroundColor: Colors.white, foregroundColor: Colors.black87), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupDetailsPage())), icon: const Icon(Icons.info_outline, size: 18), label: const Text("Chi tiết", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
                            ],
                          ),
                          const SizedBox(height: 16), Divider(height: 1, color: Colors.grey.shade200), const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildAvatar(user?.avatar, 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    GuestGuard.check(context, () async {
                                      
                                      // 🚀 CHỐT CHẶN 1: CHƯA THAM GIA THÌ CẤM ĐĂNG
                                      if (!_isJoined) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Vui lòng bấm "Tham gia" nhóm trước khi đăng bài nhé!'),
                                            backgroundColor: navyBlue,
                                          )
                                        );
                                        return;
                                      }

                                      // 🚀 CHỐT CHẶN 2: KIỂM TRA THỜI GIAN CHỜ TRÊN ĐIỆN THOẠI (Không cần sửa Database)
                                      final user = UserManager.instance.currentUser;
                                      final prefs = await SharedPreferences.getInstance();
                                      String? joinedTimeString = prefs.getString('group_joined_time_${user?.id ?? 1}');

                                      if (joinedTimeString != null) {
                                        DateTime joinedTime = DateTime.parse(joinedTimeString);
                                        final now = DateTime.now();
                                        final diff = now.difference(joinedTime); // Khoảng thời gian từ lúc bấm join đến giờ
                                        
                                        int waitMinutes = 1; // ⏱️ Sếp muốn ép chờ mấy phút thì chỉnh số này ở đây (Ví dụ: 1 phút, 5 phút...)

                                        if (diff.inMinutes < waitMinutes) {
                                          int remain = waitMinutes - diff.inMinutes;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('⏳ Vui lòng đợi thêm $remain phút nữa mới được đăng bài (Chống Spam)!'),
                                              backgroundColor: Colors.orange.shade800,
                                              behavior: SnackBarBehavior.floating,
                                            )
                                          );
                                          return; // ⛔ Chặn lại, không cho mở trang viết bài
                                        }
                                      }

                                      // Vượt qua 2 chốt chặn -> Cho phép đăng bài
                                      bool? shouldRefresh = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())); 
                                      if (shouldRefresh == true) _fetchGroupData(); 
                                    });
                                  }, 
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)), 
                                    child: Text("Chia sẻ cảm nghĩ của bạn...", style: TextStyle(color: Colors.grey.shade500, fontSize: 14))
                                  )
                                )
                              )
                            ],
                          ),
                        ],
                      ),
                    ),

                    // =================================================================
                    // 🚀 ĐÃ THÊM: BẢNG TIN ADMIN (CAROUSEL TRƯỢT NGANG GIỐNG MOMO)
                    // =================================================================
                    if (_allPosts.any((p) => p['Role']?.toString().toLowerCase() == 'admin'))
                      _buildAdminAnnouncementCarousel(),

                    Container(
                      width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.filter_list_rounded, color: navyBlue, size: 20),
                              const SizedBox(width: 6),
                              const Text("Lọc bài viết", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showFilterBottomSheet(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Text(_currentFilterLabel, style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Icon(Icons.arrow_drop_down_rounded, color: navyBlue, size: 28),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _isLoading 
                      ? Padding(padding: const EdgeInsets.only(top: 20), child: CircularProgressIndicator(color: navyBlue))
                      : filteredList.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 40, bottom: 40), 
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text("Chưa có bài viết nào.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                              ],
                            )
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero, physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, 
                            itemCount: filteredList.length, 
                            itemBuilder: (context, index) { return _buildRealPost(filteredList[index]); }
                          ),
                    const SizedBox(height: 80), 
                  ],
                ),
              ),
            );
          }), // 🚀 ĐÓNG KHUNG THẦN THÁNH Ở ĐÂY
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIcon(Widget child, Color bgColor) {
    return Container(
      width: 18, height: 18,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _getIconByType(String type) {
    if (type == 'love') return _buildCircleIcon(const Icon(Icons.favorite, color: Colors.white, size: 10), Colors.red);
    if (type == 'haha') return _buildCircleIcon(const Text('😆', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'wow') return _buildCircleIcon(const Text('😮', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'sad') return _buildCircleIcon(const Text('😢', style: TextStyle(fontSize: 10)), Colors.white);
    if (type == 'angry') return _buildCircleIcon(const Text('😡', style: TextStyle(fontSize: 10)), Colors.white);
    return _buildCircleIcon(const Icon(Icons.thumb_up, color: Colors.white, size: 10), navyBlue);
  }

  Widget _buildRealPost(Map<String, dynamic> post) {
    bool _hasTicket = post['ShowtimeDate'] != null; 
    bool isTransferPost = post['Type'] == 'transfer'; 
    bool hasBgColor = post['BgColor'] != null && post['BgColor'] != '';
    bool hasTaggedMovie = post['MovieID'] != null;
    
    // ✅ KIỂM TRA TRẠNG THÁI BỊ ẨN (DỌN DẸP BỞI HỆ THỐNG)
    bool isHidden = post['Status'] == 0 || post['Status'] == '0'; 

    Color bgColor = Colors.white;
    if (hasBgColor) bgColor = Color(int.parse(post['BgColor'].replaceAll('#', '0xFF')));

    List<String> postImages = [];
    if (post['PostImages'] != null && post['PostImages'].toString().isNotEmpty && post['PostImages'] != 'null') {
      try { 
        var decoded = jsonDecode(post['PostImages']);
        if (decoded is List) {
           postImages = decoded.map((e) => e.toString()).toList();
        } else if (decoded is String) {
           postImages = [decoded];
        }
      } catch (_) {
         // Nếu decode lỗi, thử cắt chuỗi tay
         String raw = post['PostImages'].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
         if (raw.isNotEmpty) postImages = raw.split(',').map((e) => e.trim()).toList();
      }
    }

    String userReaction = post['user_reaction'] ?? '';
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

    int totalLikes = post['total_likes'] ?? 0;
    Widget summaryReactionIcon = const SizedBox.shrink();
    
    if (totalLikes > 0) {
      String topReactionsStr = post['top_reactions'] ?? 'like'; 
      List<String> actualReactions = topReactionsStr.split(',').where((e) => e.isNotEmpty).toList();
      
      if (actualReactions.isEmpty) {
        actualReactions = ['like']; 
      }

      List<Widget> stackChildren = [];
      
      if (actualReactions.length > 1) {
        stackChildren.add(
          Transform.translate(
            offset: const Offset(12, 0), 
            child: _getIconByType(actualReactions[1])
          )
        );
      }
      stackChildren.add(_getIconByType(actualReactions[0]));

      // 🚀 ĐÃ FIX: Thêm HitTestBehavior.opaque và Padding để bấm siêu nhạy
      summaryReactionIcon = GestureDetector(
        onTap: () => _showReactionDetailsBottomSheet(post['PostID']), 
        behavior: HitTestBehavior.opaque, // THẦN CHÚ BIẾN KHOẢNG TRỐNG THÀNH NÚT BẤM
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), // Mở rộng vùng bấm cho to ra
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

    List<dynamic> transferFoodsList = [];
    if (post['TransferFoods'] != null) {
      try {
        if (post['TransferFoods'] is String) transferFoodsList = jsonDecode(post['TransferFoods']);
        else transferFoodsList = post['TransferFoods']; 
      } catch (e) {}
    }

    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(vertical: 16), 
      decoration: BoxDecoration(
        color: Colors.white, 
        border: isTransferPost 
            ? Border.symmetric(horizontal: BorderSide(color: isHidden ? Colors.grey.shade400 : Colors.orangeAccent, width: 1.5)) 
            : null
      ),
      // Nếu bài bị ẩn, làm mờ nhẹ toàn bộ bài viết để tạo cảm giác "Hết hạn"
      child: Opacity(
        opacity: isHidden ? 0.8 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
                  _fetchGroupData();
                },
                child: Row(
                  children: [
                    // 🚀 ĐÃ SỬA: Gọi hàm vẽ Avatar thật của người đăng bài
                    _buildAvatar(post['Avatar']?.toString(), 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(post['Username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (isTransferPost) ...[
                                const SizedBox(width: 6),
                                // ✅ THAY ĐỔI TAG NẾU BÀI BỊ ẨN
                                if (isHidden)
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)), child: const Text("❌ ĐÃ HỦY", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)))
                                else
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)), child: const Text("🎫 NHƯỢNG VÉ", style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold)))
                              ]
                            ],
                          ),
                          Row(
                            children: [
                              Text(_formatTime(post['CreatedAt']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              if (post['Role'] != null && post['Role'].toString().toLowerCase() == 'admin') ...[
                                const SizedBox(width: 6), Icon(Icons.verified, color: isHidden ? Colors.grey : navyBlue, size: 14), const SizedBox(width: 2),
                                Text("Quản trị viên", style: TextStyle(color: isHidden ? Colors.grey : navyBlue, fontSize: 11, fontWeight: FontWeight.bold))
                              ]
                            ],
                          )
                        ],
                      )
                    ),
                    IconButton(
                        onPressed: () { 
                          GuestGuard.check(context, () => _showPostOptionsModal(post)); 
                        }, 
                      icon: const Icon(Icons.more_horiz, color: Colors.grey)
                    )            
                  ],
                ),
              ),
            ),
            
            // ✅ HIỂN THỊ BANNER THÔNG BÁO CHO NGƯỜI ĐĂNG BIẾT LÝ DO
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

            const SizedBox(height: 12),
            
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
                _fetchGroupData();
              },
              child: hasBgColor
                ? Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20), decoration: BoxDecoration(color: bgColor), child: Text(post['Content'] ?? "", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4)))
                : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(post['Content'] ?? "", style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87))),
            ),
            
            if (!hasBgColor && postImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildImageGallery(postImages, post),
              ),

            const SizedBox(height: 16),

            if (isTransferPost && _hasTicket)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    // Đổi màu khung vé nếu bị ẩn
                    color: isHidden ? Colors.grey.shade50 : Colors.orange.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isHidden ? Colors.grey.shade300 : Colors.orange.shade200, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _getRealImageUrl(post['MovieImage']),
                                width: 80, height: 115, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 80, height: 115, color: Colors.grey.shade300, child: const Icon(Icons.movie, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(post['MovieTitle'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.theaters, size: 14, color: isHidden ? Colors.grey : Colors.deepOrange),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text("${post['CinemaName']} - ${post['RoomName']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(post['CinemaAddress'] ?? "", style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 14, color: isHidden ? Colors.grey : Colors.blue),
                                      const SizedBox(width: 6),
                                      Text("Suất: ${post['ShowtimeDate']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHidden ? Colors.grey.shade700 : Colors.blue)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.event_seat_rounded, size: 14, color: isHidden ? Colors.grey : Colors.purple),
                                      const SizedBox(width: 6),
                                      Text("Ghế: ${post['TransferSeats']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHidden ? Colors.grey.shade700 : Colors.purple)),
                                    ],
                                  ),
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
                              Row(
                                children: [
                                  Icon(Icons.fastfood_outlined, size: 14, color: isHidden ? Colors.grey : Colors.green),
                                  const SizedBox(width: 6),
                                  Text("Bắp nước đi kèm:", style: TextStyle(fontSize: 12, color: isHidden ? Colors.grey.shade700 : Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
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
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Image.network(_getRealImageUrl(food['image']), width: 24, height: 24, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.fastfood, size: 16, color: Colors.grey))
                                        ),
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
                                Text(NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(double.tryParse(post['TransferPrice']?.toString() ?? '0') ?? 0), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isHidden ? Colors.grey.shade600 : Colors.deepOrange))
                              ],
                            ),
                            // ✅ KHÓA NÚT MUA VÉ NẾU BÀI BỊ ẨN
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isHidden ? Colors.grey.shade400 : Colors.deepOrange, 
                                foregroundColor: Colors.white, 
                                elevation: 0, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), 
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
                              ),
                              onPressed: isHidden ? null : () { 
                                GuestGuard.check(context, () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hệ thống đang chuyển hướng tới cổng trung gian bảo mật...'))); 
                                });
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
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_getRealImageUrl(post['MovieImage']), width: 50, height: 75, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 50, height: 75, color: Colors.grey.shade300))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post['MovieTitle'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(post['MovieGenres'] ?? "Phim rạp", style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isHidden ? Colors.grey : navyBlue, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                        onPressed: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => MovieDetailPage(movie: _getMovieFromPostData(post))) 
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
                  Text("${post['total_comments']} bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                        GuestGuard.check(context, () {
                          String targetReaction = isReacted ? userReaction : 'like';
                          _reactToPost(post['PostID'], targetReaction);
                        });
                      }, 
                      onLongPressStart: (details) { 
                        GuestGuard.check(context, () {
                          _showReactionOverlay(context, details.globalPosition, post['PostID']); 
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            reactionIcon,
                            const SizedBox(width: 4),
                            Flexible(child: Text(reactionText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: reactionColor, fontWeight: FontWeight.w600, fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
                        _fetchGroupData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, color: Colors.grey.shade700, size: 20),
                            const SizedBox(width: 4),
                            Flexible(child: Text("Bình luận", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                                    // 🚀 ĐÃ SỬA: CHỈ GỬI DUY NHẤT CÁI LINK
                                    // Zalo/Messenger sẽ tự động sinh ra cái Box từ link này
                                    String shareUrl = "https://sneeze-dust-linguist.ngrok-free.dev/share/post/${post['PostID']}";
                                    
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
            ),
          // 🚀 ĐÃ THÊM 'top: 12' ĐỂ ĐẨY ĐƯỜNG KẺ RA XA 3 NÚT BẤM, GIÚP CÂN ĐỐI TRÊN DƯỚI
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16), 
            child: const Divider(height: 1)
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildAvatar(UserManager.instance.currentUser?.avatar, 32),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      GuestGuard.check(context, () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
                        _fetchGroupData(); 
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Text("Để lại bình luận của bạn...", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ),
                  ),
                )
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // 🚀 BOTTOM SHEET: DANH SÁCH NGƯỜI THẢ CẢM XÚC (Y CHANG FACEBOOK)
  // ====================================================================
  void _showReactionDetailsBottomSheet(int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FutureBuilder<http.Response>(
          future: http.get(Uri.parse('$apiBaseUrl/api/group/posts/$postId/reactions')),
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

            // 1. GOM NHÓM DỮ LIỆU ĐỂ TẠO TABS CHUẨN FACEBOOK
            Map<String, int> reactionCounts = {};
            for (var r in reactions) {
              String type = r['ReactionType'];
              reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
            }

            // Sắp xếp các loại cảm xúc có người dùng lên đầu
            List<String> availableTypes = reactionCounts.keys.toList();
            availableTypes.sort((a, b) => reactionCounts[b]!.compareTo(reactionCounts[a]!));

            final List<String> tabs = ['all', ...availableTypes];

            // Map Emojis
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
                    // HEADER CÓ THANH KÉO
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 5),
                      width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48), // Canh giữa
                        const Text("Cảm xúc", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(height: 1),

                    // TAB BAR (Tất cả | 👍 89 | ❤️ 61)
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

                    // LIST NGƯỜI DÙNG TƯƠNG ỨNG TỪNG TAB
                    Expanded(
                      child: TabBarView(
                        children: tabs.map((tabType) {
                          // Lọc dữ liệu theo tab
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
                                    _buildAvatar(userReact['Avatar']?.toString(), 46), // Dùng hàm avatar có sẵn của sếp
                                    Positioned(
                                      bottom: -2, right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        child: _getIconByType(userReact['ReactionType']), // Hàm lấy cục icon nhỏ góc dưới
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
  // HÀM TIỆN ÍCH: TỰ ĐỘNG NẶN RA ĐỐI TƯỢNG MOVIE (ĐÃ FIX ẢNH)
  // ====================================================================
  Movie _getMovieFromPostData(Map<String, dynamic> data) {
    // 1. Xử lý Link Poster & Backdrop bằng hàm xịn
    String fullPosterUrl = _getRealImageUrl(data['MovieImage']?.toString());
    String fullBackdropUrl = _getRealImageUrl(data['MovieBackdrop']?.toString());
    if (fullBackdropUrl.isEmpty) fullBackdropUrl = fullPosterUrl;

    // 2. Xử lý Điểm đánh giá (Vote) an toàn
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
  // ✅ HÀM VẼ AVATAR "BỌC THÉP V3" (TỰ NHẬN DIỆN THƯ MỤC)
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
        cleanPath = cleanPath.replaceFirst('/public', '').replaceFirst('public/', '');
        if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
        
        String filename = cleanPath.split('/').last;

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
                  return Center(child: Text(UserManager.instance.currentUser?.name.substring(0, 1).toUpperCase() ?? "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4)));
                },
              )
            : Center(child: Text(UserManager.instance.currentUser?.name.substring(0, 1).toUpperCase() ?? "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4))),
      ),
    );
  }

  // ====================================================================
  // 🚀 KHỐI GIAO DIỆN: THÔNG BÁO TỪ QUẢN TRỊ VIÊN (CHUẨN MOMO/FB)
  // ====================================================================
  Widget _buildAdminAnnouncementCarousel() {
    // Lọc ra các bài viết của Admin
    List<dynamic> adminPosts = _allPosts.where((p) => p['Role']?.toString().toLowerCase() == 'admin').toList();
    if (adminPosts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 440, // 🚀 Chiều cao cố định cho Card trượt ngang
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 16, right: 4),
              itemCount: adminPosts.length,
              itemBuilder: (context, index) {
                return _buildAdminPostCard(adminPosts[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPostCard(Map<String, dynamic> post) {
    bool hasTaggedMovie = post['MovieID'] != null;
    List<String> images = [];
    if (post['PostImages'] != null && post['PostImages'].toString().isNotEmpty) {
      try { images = List<String>.from(jsonDecode(post['PostImages'])); } catch (_) {}
    }

    String contentTxt = post['Content'] ?? '';
    int totalLikes = post['total_likes'] ?? 0;
    
    // 🚀 ĐÃ FIX: Đồng bộ logic Cảm xúc y chang bài đăng thường
    String userReaction = post['user_reaction'] ?? '';
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

    // Logic Stacked Icons
    Widget summaryReactionIcon = const SizedBox.shrink();
    if (totalLikes > 0) {
      String topReactionsStr = post['top_reactions'] ?? 'like'; 
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
          Text(totalLikes >= 1000 ? "${(totalLikes/1000).toStringAsFixed(1)}k" : totalLikes.toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600))
        ],
      );
    }

    return Container(
      width: 320, // Bề ngang chuẩn để thấy được thẻ tiếp theo hé ra
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER: Avatar + Tên + Tick Xanh + Giờ
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(post['Avatar']?.toString(), 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(post['Username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 4),
                          Icon(Icons.verified, color: Colors.blue.shade600, size: 14), // Tick xanh uy tín
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(_formatTime(post['CreatedAt']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          const SizedBox(width: 4),
                          Icon(Icons.public, color: Colors.grey.shade500, size: 12), // Icon Trái đất (Public)
                        ],
                      )
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: Colors.grey),
              ],
            ),
          ),

          // 2. TEXT CONTENT
          if (contentTxt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(contentTxt, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87)),
            ),
          
          const SizedBox(height: 8),

          // 3. IMAGE + GẮN THẺ PHIM LIỀN KHỐI (Chuẩn MoMo)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Ảnh bự
                    Expanded(
                      child: ClipRRect(
                        borderRadius: hasTaggedMovie ? const BorderRadius.vertical(top: Radius.circular(11)) : BorderRadius.circular(11),
                        child: images.isNotEmpty 
                            ? Image.network(_getRealImageUrl(images[0]), width: double.infinity, fit: BoxFit.cover)
                            : Container(color: Colors.blue.shade50, width: double.infinity, child: Icon(Icons.campaign, size: 50, color: Colors.blue.shade200)),
                      ),
                    ),
                    // Thẻ tag Phim (Giống khung "Mua vé suất chiếu đặc biệt" của MoMo)
                    if (hasTaggedMovie)
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: _getMovieFromPostData(post)))),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11))),
                          child: Row(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(_getRealImageUrl(post['MovieImage']), width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_,__,___)=>Container(width:36, height:36, color:Colors.grey))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Xem thông tin và Mua vé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(post['MovieTitle'] ?? "", style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.black54),
                            ],
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),

          // 4. STATS (Lượt Like & Comment)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                summaryReactionIcon,
                Text("${post['total_comments'] >= 1000 ? (post['total_comments']/1000).toStringAsFixed(1) + 'k' : post['total_comments']} bình luận", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider(height: 1)),

          // 5. NÚT THÍCH & BÌNH LUẬN
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  // 🚀 ĐÃ SỬA: Đổi InkWell thành GestureDetector để hỗ trợ lấy tọa độ ngón tay
                  child: GestureDetector(
                    onTap: () { GuestGuard.check(context, () { String targetReaction = isReacted ? userReaction : 'like'; _reactToPost(post['PostID'], targetReaction); }); },
                    onLongPressStart: (details) => _showReactionOverlay(context, details.globalPosition, post['PostID']),
                    behavior: HitTestBehavior.opaque, // Thần chú giúp bấm trúng cả vùng trống
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      // 🚀 ĐÃ FIX: Chèn biến reactionIcon và reactionText thay vì gõ "cứng" chữ Thích
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [reactionIcon, const SizedBox(width: 4), Flexible(child: Text(reactionText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: reactionColor, fontWeight: FontWeight.w600, fontSize: 14)))]),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
                      _fetchGroupData();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, color: Colors.grey.shade700, size: 20), const SizedBox(width: 6), Text("Bình luận", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14))]),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}