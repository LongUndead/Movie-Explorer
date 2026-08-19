import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; 
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'user_manager.dart';
import 'guest_guard.dart'; 
import 'notification_bottom_sheet.dart';

class WriteReviewPage extends StatefulWidget {
  final int movieId; 
  final String movieTitle;
  final String posterPath; 
  final Map<String, dynamic>? existingReview;

  const WriteReviewPage({
    super.key, 
    required this.movieId, 
    required this.movieTitle, 
    required this.posterPath, 
    this.existingReview
  });

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  final Color navyBlue = Colors.blue.shade900;
  final String apiBaseUrl = 'http://10.173.120.41:3000';

  int _selectedStar = 0;
  double _helpfulSliderValue = 1.0; 
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  List<String> _selectedTags = [];

  // 🚀 ĐÃ NÂNG CẤP: LƯU TRỮ MẢNG 5 ẢNH MỚI VÀ ẢNH CŨ
  List<File> _selectedImages = [];
  List<String> _oldImages = [];
  
  File? _selectedVideo; 
  final ImagePicker _picker = ImagePicker();

  bool _isEditing = false;
  int? _reviewIdToEdit;

  List<dynamic> _notifications = [];
  int get unreadCount => _notifications.where((n) => n['IsRead'] == 0).length;

  Future<void> _fetchNotifications() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return; 
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/users/${user.id}/notifications'));
      if (res.statusCode == 200) {
        if (mounted) setState(() => _notifications = json.decode(res.body));
      }
    } catch (e) {}
  }

  Future<void> _markAsRead(int notifId) async {
    try {
      await http.put(Uri.parse('$apiBaseUrl/api/users/notifications/$notifId/read'));
      _fetchNotifications(); 
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications(); 
    
    if (widget.existingReview != null) {
      _isEditing = true;
      _reviewIdToEdit = widget.existingReview!['commentId'] ?? widget.existingReview!['CommentID'];
      
      _selectedStar = double.tryParse(widget.existingReview!['rating']?.toString() ?? '10')?.toInt() ?? 10;
      _reviewController.text = widget.existingReview!['comment'] ?? widget.existingReview!['Content'] ?? '';
      
      String oldTags = widget.existingReview!['tags'] ?? widget.existingReview!['Tags'] ?? '';
      if (oldTags.isNotEmpty) {
        _selectedTags = oldTags.split(',').map((e) => e.trim()).toList();
      }
      
      // 🚀 ĐÃ NÂNG CẤP: Phục hồi MẢNG ảnh cũ từ Database
      String imgData = widget.existingReview!['image'] ?? widget.existingReview!['ImageURL'] ?? '';
      if (imgData.isNotEmpty && imgData != 'null') {
        try {
          var decoded = jsonDecode(imgData);
          if (decoded is List) {
             _oldImages = decoded.map((e) => e.toString()).toList();
          } else if (decoded is String) {
             _oldImages = [decoded];
          }
        } catch (_) {
           String raw = imgData.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
           if (raw.isNotEmpty) _oldImages = raw.split(',').map((e) => e.trim()).toList();
        }
      }
      
      _updateHelpfulSlider();
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _updateHelpfulSlider() {
    double val = 1.0;
    if (_selectedStar == 10) val = 2.0; 
    if (_selectedImages.isNotEmpty || _oldImages.isNotEmpty || _selectedVideo != null) val = 3.0; 
    setState(() => _helpfulSliderValue = val);
  }

  // 🚀 ĐÃ NÂNG CẤP TÍNH NĂNG CHỌN TỐI ĐA 5 ẢNH
  Future<void> _pickImages() async {
    int currentTotal = _oldImages.length + _selectedImages.length;
    if (currentTotal >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ được chọn tối đa 5 ảnh!')));
      return;
    }

    // Mở thư viện cho phép chọn nhiều ảnh
    final List<XFile> images = await _picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() { 
        for (var img in images) {
          if (_oldImages.length + _selectedImages.length < 5) {
            _selectedImages.add(File(img.path));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đạt giới hạn 5 ảnh! Các ảnh dư bị bỏ qua.')));
            break;
          }
        }
        _selectedVideo = null; // Chọn ảnh thì hủy video
      });
      _updateHelpfulSlider();
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() { 
        _selectedVideo = File(video.path); 
        _selectedImages.clear(); // Chọn video thì hủy toàn bộ ảnh
        _oldImages.clear();
      });
      _updateHelpfulSlider();
    }
  }

  List<String> _getTagsForRating() {
    if (_selectedStar >= 9) return ["Tuyệt vời", "Hài lòng", "Cảm động", "Hài hước", "Ý nghĩa", "Khóc trôi rạp", "Cười banh rạp", "Giải trí", "Đáng xem", "Siêu Phẩm"];
    if (_selectedStar >= 7) return ["Ý Nghĩa", "Mãn nhãn", "Hồi hộp", "Gay cấn", "Đồng cảm", "Đáng suy ngẫm", "Kịch tính", "Hay", "Nhân văn", "Đáng tiền"];
    if (_selectedStar >= 5) return ["Bình thường", "Cũng tạm", "Không hay không dở", "Hài lòng"];
    if (_selectedStar >= 3) return ["Chưa đặc sắc", "Dài dòng", "Chưa hay", "Cũng được", "Bình thường"];
    if (_selectedStar >= 1) return ["Nhạt", "Khó hiểu", "Thất vọng", "Buồn ngủ", "Phí tiền", "Thiếu chiều sâu", "Dài dòng", "Không điểm nhấn"];
    return [];
  }

  int _getBracket(int star) {
    if (star >= 9) return 5;
    if (star >= 7) return 4;
    if (star >= 5) return 3;
    if (star >= 3) return 2;
    if (star >= 1) return 1;
    return 0;
  }

  String _getRealImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) return "";
    if (rawPath.startsWith("http")) return rawPath;
    return "$apiBaseUrl/uploads/$rawPath"; 
  }

  // ==============================================================
  // 🚀 HÀM GỬI API HỖ TRỢ UPLOAD MẢNG 5 ẢNH (MULTIPART)
  // ==============================================================
  Future<void> _submitReview() async {
    if (_selectedStar == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn số sao đánh giá bộ phim!')));
      return;
    }

    final user = UserManager.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để đánh giá!')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      var uri = _isEditing 
          ? Uri.parse('$apiBaseUrl/api/movies/reviews/$_reviewIdToEdit') 
          : Uri.parse('$apiBaseUrl/api/movies/reviews');

      var request = http.MultipartRequest(_isEditing ? 'PUT' : 'POST', uri);

      request.fields['user_id'] = user.id.toString();
      request.fields['movie_id'] = widget.movieId.toString();
      request.fields['rating'] = _selectedStar.toString();
      request.fields['content'] = _reviewController.text.trim();
      request.fields['tags'] = _selectedTags.isNotEmpty ? _selectedTags.join(',') : "";

      // 🚀 Báo cho Backend biết những ảnh cũ nào được giữ lại
      if (_isEditing) {
        request.fields['old_images'] = jsonEncode(_oldImages);
      }

      // 🚀 Xử lý gửi toàn bộ danh sách file ảnh mới lên Backend (Cùng key 'image')
      for (var file in _selectedImages) {
        request.files.add(await http.MultipartFile.fromPath('image', file.path));
      }

      var response = await request.send();
      String responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Đã cập nhật đánh giá!' : 'Cảm ơn bạn đã gửi đánh giá!')));
          Navigator.pop(context, true); 
        }
      } else {
        if (mounted) {
          String errorMessage = 'Thất bại!';
          try {
             final errorData = jsonDecode(responseBody);
             if(errorData['error'] != null) errorMessage = errorData['error'];
          } catch(e) {}
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối tới máy chủ!')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    List<String> currentTags = _getTagsForRating();

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
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_isEditing ? 'Sửa đánh giá' : 'Viết đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50])),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    GuestGuard.check(context, () {
                      NotificationBottomSheet.show(context: context, notifications: _notifications, onMarkAsRead: _markAsRead, primaryColor: navyBlue);
                    });
                  }, 
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications_outlined, color: navyBlue, size: 19),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2, right: -4, 
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                unreadCount > 9 ? '9+' : unreadCount.toString(), 
                                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, height: 1)
                              ),
                            ),
                          ),
                      ],
                    )
                  )
                ),
                Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)), 
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.home_outlined, color: navyBlue, size: 18))
                ),
              ],
            ),
          ),
        ],
      ),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(widget.posterPath, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 40, height: 40, color: Colors.grey))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.movieTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // ===============================================
                  // CHỌN SAO
                  // ===============================================
                  Center(child: Text(_selectedStar == 0 ? 'Nhấn để đánh giá' : 'Bạn chấm $_selectedStar/10 điểm', style: TextStyle(color: _selectedStar == 0 ? Colors.grey : Colors.orange, fontSize: 14, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(10, (index) {
                      return GestureDetector(
                        onTap: () { 
                          setState(() {
                            int oldBracket = _getBracket(_selectedStar);
                            int newBracket = _getBracket(index + 1);
                            if (oldBracket != newBracket) {
                              _selectedTags.clear();
                            }
                            _selectedStar = index + 1; 
                          });
                          _updateHelpfulSlider(); 
                        },
                        child: Icon(index < _selectedStar ? Icons.star : Icons.star_border, color: index < _selectedStar ? Colors.orange : Colors.grey.shade300, size: 30),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 24),
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 24),

                  // ===============================================
                  // HIỂN THỊ CÁC BOX TAG CẢM XÚC
                  // ===============================================
                  if (_selectedStar > 0 && currentTags.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Bạn cảm thấy...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 10, 
                        runSpacing: 10, 
                        children: currentTags.map((tag) => _buildSelectableTag(tag)).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 24),
                  ],

                  // ===============================================
                  // Ô NHẬP TEXT
                  // ===============================================
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Cảm nhận thêm về bộ phim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 150, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reviewController, 
                              maxLines: null, 
                              decoration: const InputDecoration(hintText: 'Giờ là lúc ngôn từ lên ngôi ✍️', border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey))
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===============================================
                  // 🚀 KHU VỰC ĐÍNH KÈM HÌNH ẢNH / VIDEO (MAX 5 ẢNH)
                  // ===============================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // Hiện ảnh cũ từ DB (Dành cho chức năng Edit)
                        ..._oldImages.map((url) => _buildMediaPreview(NetworkImage(_getRealImageUrl(url)), isVideo: false, onDelete: () {
                          setState(() { _oldImages.remove(url); _updateHelpfulSlider(); });
                        })).toList(),
                        
                        // Hiện các ảnh mới chọn từ Thư viện
                        ..._selectedImages.map((file) => _buildMediaPreview(FileImage(file), isVideo: false, onDelete: () {
                          setState(() { _selectedImages.remove(file); _updateHelpfulSlider(); });
                        })).toList(),

                        // Hiện nút Thêm Ảnh (Nếu tổng ảnh < 5)
                        if (_oldImages.length + _selectedImages.length < 5)
                          GestureDetector(
                            onTap: _pickImages,
                            child: _buildAddMediaBox(Icons.add_a_photo_outlined, 'Thêm ảnh\n(${_oldImages.length + _selectedImages.length}/5)', false)
                          ),

                        // Hiện Video (nếu không có ảnh nào được chọn)
                        if (_oldImages.isEmpty && _selectedImages.isEmpty && _selectedVideo == null)
                          GestureDetector(
                            onTap: _pickVideo, 
                            child: _buildAddMediaBox(Icons.videocam_outlined, 'Thêm video\n(Tối đa 30MB)', true)
                          ),

                        // Hiện Preview Video
                        if (_selectedVideo != null)
                          _buildMediaPreview(null, isVideo: true, onDelete: () {
                            setState(() { _selectedVideo = null; _updateHelpfulSlider(); });
                          }),
                      ],
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8),
                    child: Text('*Bạn có thể chọn tối đa 5 ảnh HOẶC 1 video.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mức độ giúp ích người dùng khác:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Slider(
                            value: _helpfulSliderValue, min: 1, max: 3, divisions: 2, 
                            activeColor: navyBlue, inactiveColor: Colors.grey.shade200, 
                            onChanged: (val) => setState(() => _helpfulSliderValue = val)
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text('Khá', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('Tốt', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('Tuyệt vời', style: TextStyle(color: Colors.grey, fontSize: 12))],
                          ),
                          const SizedBox(height: 16), const Divider(), const SizedBox(height: 8),
                          const Text('Bạn có thể giúp ích người dùng khác bằng cách:\n⭐ Nhấn đánh giá sao\n📸 Đính kèm hình ảnh review', style: TextStyle(fontSize: 13, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // Spacing for bottom bar
                ],
              ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16), 
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text('Đánh giá của bạn sẽ hiển thị công khai trên Cinema Tickets', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))), 
                    const SizedBox(width: 8), const Icon(Icons.info_outline, size: 16, color: Colors.grey)
                  ]
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: navyBlue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: _isSubmitting ? null : _submitReview, 
                    child: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : Text(_isEditing ? 'Cập nhật đánh giá' : 'Gửi đánh giá', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableTag(String label) {
    bool isSelected = _selectedTags.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTags.remove(label); 
          } else {
            _selectedTags.add(label); 
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white, 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? navyBlue : Colors.grey.shade300), 
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? navyBlue : Colors.black87, 
          ),
        ),
      ),
    );
  }

  Widget _buildAddMediaBox(IconData icon, String label, bool isNew) {
    return Container(
      width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid, width: 1.5), borderRadius: BorderRadius.circular(12)),
      child: Stack(alignment: Alignment.center, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.grey.shade600, size: 28), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87))]),
        if (isNew) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(6)), child: const Text('Mới', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  // 🚀 ĐÃ NÂNG CẤP: Truyền hàm onDelete vào để hỗ trợ xóa riêng từng ảnh
  Widget _buildMediaPreview(ImageProvider? image, {required bool isVideo, required VoidCallback onDelete}) {
    return Container(
      width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: navyBlue, width: 2), borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(alignment: Alignment.center, children: [
          if (!isVideo && image != null) Image(image: image, width: 100, height: 100, fit: BoxFit.cover),
          if (isVideo) Container(color: Colors.grey.shade800, width: 100, height: 100),
          if (isVideo) const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
          
          // NÚT BẤM XOÁ ẢNH NÀY
          Positioned(
            top: 4, right: 4, 
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4), 
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), 
                child: const Icon(Icons.close, size: 12, color: Colors.white)
              ),
            )
          ),
        ]),
      ),
    );
  }
}