import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; 
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'user_manager.dart';

class WriteReviewPage extends StatefulWidget {
  final int movieId; 
  final String movieTitle;
  final String posterPath; 
  // ✅ BỔ SUNG: Nhận dữ liệu đánh giá cũ để sửa
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
  final String apiBaseUrl = 'http://192.168.1.2:3000';

  int _selectedStar = 0;
  double _helpfulSliderValue = 1.0; 
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  // BIẾN LƯU TRỮ CÁC TAG CẢM XÚC ĐƯỢC CHỌN
  List<String> _selectedTags = [];

  File? _selectedImage;
  File? _selectedVideo; // Cứ để đó, nếu sau này Backend hỗ trợ Video thì dùng
  final ImagePicker _picker = ImagePicker();

  // ✅ CÁC BIẾN KIỂM SOÁT VIỆC CHỈNH SỬA
  bool _isEditing = false;
  int? _reviewIdToEdit;
  bool _keepOldImage = false;
  String? _oldImageUrl;

  @override
  void initState() {
    super.initState();
    
    // ==============================================================
    // ✅ KIỂM TRA NẾU ĐANG LÀ CHẾ ĐỘ SỬA ĐÁNH GIÁ (EDIT MODE)
    // ==============================================================
    if (widget.existingReview != null) {
      _isEditing = true;
      _reviewIdToEdit = widget.existingReview!['commentId'] ?? widget.existingReview!['CommentID'];
      
      // 1. Phục hồi Mức Sao (Rating)
      _selectedStar = double.tryParse(widget.existingReview!['rating']?.toString() ?? '10')?.toInt() ?? 10;
      
      // 2. Phục hồi Nội dung Text
      _reviewController.text = widget.existingReview!['comment'] ?? widget.existingReview!['Content'] ?? '';
      
      // 3. Phục hồi danh sách Tags
      String oldTags = widget.existingReview!['tags'] ?? '';
      if (oldTags.isNotEmpty) {
        _selectedTags = oldTags.split(',').map((e) => e.trim()).toList();
      }
      
      // 4. Phục hồi Hình Ảnh (Nếu bài viết cũ có ảnh)
      String img = widget.existingReview!['image'] ?? widget.existingReview!['ImageURL'] ?? '';
      if (img.isNotEmpty) {
        _keepOldImage = true;
        _oldImageUrl = img;
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
    if (_selectedImage != null || _oldImageUrl != null || _selectedVideo != null) val = 3.0; 
    setState(() => _helpfulSliderValue = val);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() { 
        _selectedImage = File(image.path); 
        _selectedVideo = null; 
        _keepOldImage = false; // Chọn ảnh mới thì bỏ ảnh cũ
      });
      _updateHelpfulSlider();
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() { 
        _selectedVideo = File(video.path); 
        _selectedImage = null; 
        _keepOldImage = false; // Chọn video mới thì bỏ ảnh cũ
      });
      _updateHelpfulSlider();
    }
  }

  // HÀM LẤY DANH SÁCH TAG DỰA TRÊN SỐ SAO
  List<String> _getTagsForRating() {
    if (_selectedStar >= 9) {
      return ["Tuyệt vời", "Hài lòng", "Cảm động", "Hài hước", "Ý nghĩa", "Khóc trôi rạp", "Cười banh rạp", "Giải trí", "Đáng xem", "Siêu Phẩm"];
    } else if (_selectedStar >= 7) {
      return ["Ý Nghĩa", "Mãn nhãn", "Hồi hộp", "Gay cấn", "Đồng cảm", "Đáng suy ngẫm", "Kịch tính", "Hay", "Nhân văn", "Đáng tiền"];
    } else if (_selectedStar >= 5) {
      return ["Bình thường", "Cũng tạm", "Không hay không dở", "Hài lòng"];
    } else if (_selectedStar >= 3) {
      return ["Chưa đặc sắc", "Dài dòng", "Chưa hay", "Cũng được", "Bình thường"];
    } else if (_selectedStar >= 1) {
      return ["Nhạt", "Khó hiểu", "Thất vọng", "Buồn ngủ", "Phí tiền", "Thiếu chiều sâu", "Dài dòng", "Không điểm nhấn"];
    }
    return [];
  }

  // HÀM KIỂM TRA PHÂN KHÚC SAO ĐỂ CLEAR TAG NẾU CHUYỂN PHÂN KHÚC
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
  // ✅ HÀM GỬI API: HỖ TRỢ CẢ TẠO MỚI (POST) VÀ CẬP NHẬT (PUT)
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
      // ✅ NẾU LÀ SỬA (EDIT): Dùng PUT, gọi URL riêng cho Review cụ thể
      // ✅ NẾU LÀ TẠO MỚI: Dùng POST
      var uri = _isEditing 
          ? Uri.parse('$apiBaseUrl/api/movies/reviews/$_reviewIdToEdit') 
          : Uri.parse('$apiBaseUrl/api/movies/reviews');

      var request = http.MultipartRequest(_isEditing ? 'PUT' : 'POST', uri);

      request.fields['user_id'] = user.id.toString();
      request.fields['movie_id'] = widget.movieId.toString();
      request.fields['rating'] = _selectedStar.toString();
      request.fields['content'] = _reviewController.text.trim();
      request.fields['tags'] = _selectedTags.isNotEmpty ? _selectedTags.join(',') : "";

      // NẾU LÀ EDIT, phải gửi kèm keep_old_image để Backend biết có xóa ảnh cũ trên DB không
      if (_isEditing) {
        request.fields['keep_old_image'] = _keepOldImage.toString();
      }

      // Xử lý gửi file ảnh mới
      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
      }

      var response = await request.send();
      String responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Đã cập nhật đánh giá!' : 'Cảm ơn bạn đã gửi đánh giá!')));
          Navigator.pop(context, true); // Pop về và báo cho màn trước biết để Refresh
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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {}, 
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                    child: Icon(Icons.notifications_outlined, color: navyBlue, size: 18),
                  )
                ),
                Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                    child: Icon(Icons.home_outlined, color: navyBlue, size: 18),
                  )
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(widget.posterPath, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 40, height: 40, color: Colors.grey))),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.movieTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 30),
            
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
              const Text('Bạn cảm thấy...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, 
                runSpacing: 10, 
                children: currentTags.map((tag) => _buildSelectableTag(tag)).toList(),
              ),
              const SizedBox(height: 24),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              const SizedBox(height: 24),
            ],

            // ===============================================
            // Ô NHẬP TEXT
            // ===============================================
            const Text('Cảm nhận thêm về bộ phim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
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
                  Align(alignment: Alignment.bottomRight, child: Text('0/10000', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ===============================================
            // ĐÍNH KÈM HÌNH ẢNH / VIDEO
            // ===============================================
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage, 
                  child: _selectedImage != null 
                      ? _buildMediaPreview(FileImage(_selectedImage!), isVideo: false) 
                      : (_keepOldImage && _oldImageUrl != null && _oldImageUrl!.isNotEmpty)
                          ? _buildMediaPreview(NetworkImage(_getRealImageUrl(_oldImageUrl)), isVideo: false)
                          : _buildAddMediaBox(Icons.add_a_photo_outlined, 'Thêm ảnh', false)
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickVideo, 
                  child: _selectedVideo != null ? _buildMediaPreview(null, isVideo: true) : _buildAddMediaBox(Icons.videocam_outlined, 'Thêm video\n(Tối đa 30MB)', true)
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
                    activeColor: navyBlue, inactiveColor: Colors.grey.shade200, 
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
            const SizedBox(height: 20),
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

  Widget _buildMediaPreview(ImageProvider? image, {required bool isVideo}) {
    return Container(
      width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: navyBlue, width: 2), borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(alignment: Alignment.center, children: [
          if (!isVideo && image != null) Image(image: image, width: 100, height: 100, fit: BoxFit.cover),
          if (isVideo) Container(color: Colors.grey.shade800, width: 100, height: 100),
          if (isVideo) const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
          
          // NÚT BẤM XOÁ ẢNH CŨ/MỚI
          Positioned(
            top: 4, right: 4, 
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isVideo) {
                    _selectedVideo = null;
                  } else {
                    _selectedImage = null;
                    _keepOldImage = false; // Bấm xóa ảnh đi là không giữ ảnh cũ nữa
                    _oldImageUrl = null;
                  }
                  _updateHelpfulSlider();
                });
              },
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