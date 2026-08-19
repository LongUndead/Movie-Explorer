import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // ✅ ĐÃ THÊM: Thư viện chọn ảnh
import 'user_manager.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final Color navyBlue = Colors.blue.shade900;
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(); 
  final String apiBaseUrl = 'http://10.173.120.41:3000'; 
  
  bool _isTransferPost = false; 
  Map<String, dynamic>? _selectedMovie; 
  Map<String, dynamic>? _selectedTicket; 
  
  List<dynamic> _moviesList = []; 
  List<dynamic> _myTickets = []; 
  
  bool _showColorPicker = false;
  String _selectedBgColor = ''; 
  final List<Map<String, dynamic>> _bgColors = [
    {'hex': '', 'color': Colors.white},
    {'hex': '#F44336', 'color': Colors.red},
    {'hex': '#2196F3', 'color': Colors.blue},
    {'hex': '#4CAF50', 'color': Colors.green},
    {'hex': '#FF9800', 'color': Colors.orange},
    {'hex': '#9C27B0', 'color': Colors.purple},
  ];

  // ✅ QUẢN LÝ DANH SÁCH ẢNH (Tối đa 5)
  List<XFile> _imagesList = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
    _fetchMyTickets();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ✅ HÀM CHỌN ẢNH TỪ THƯ VIỆN MÁY
  Future<void> _pickImage() async {
    if (_imagesList.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn chỉ được đăng tối đa 5 hình ảnh!')));
      return;
    }
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imagesList.addAll(pickedFiles);
        if (_imagesList.length > 5) {
          _imagesList = _imagesList.sublist(0, 5); // Cắt bớt nếu chọn lố 5
        }
      });
    }
  }

  Future<void> _fetchMovies() async {
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/movies'));
      if (res.statusCode == 200) setState(() => _moviesList = jsonDecode(res.body));
    } catch (e) { debugPrint("Lỗi tải danh sách phim: $e"); }
  }

  Future<void> _fetchMyTickets() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/user/tickets/${user.id}'));
      if (res.statusCode == 200) {
        List<dynamic> allTix = jsonDecode(res.body);
        List<dynamic> validTix = [];
        
        for (var t in allTix) {
          if (t['status'] == 'Paid') {
            try {
              final parts = t['date'].toString().split(' - ');
              final timeParts = parts[0].split(':');
              final dateParts = parts[1].split('/');
              final dt = DateTime(int.parse(dateParts[2]), int.parse(dateParts[1]), int.parse(dateParts[0]), int.parse(timeParts[0]), int.parse(timeParts[1]));
              
              if (dt.isAfter(DateTime.now())) {
                validTix.add(t);
              }
            } catch (_) {}
          }
        }
        if (mounted) setState(() => _myTickets = validTix);
      }
    } catch (e) { debugPrint("Lỗi tải vé: $e"); }
  }

  // ✅ ĐÃ CHUYỂN SANG MULTIPART ĐỂ UPLOAD FILE
  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập nội dung!')));
      return;
    }

    if (_isTransferPost) {
      if (_selectedTicket == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Bài nhượng vé nhưng chưa có vé!')));
        return;
      }
      if (_priceController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập giá muốn nhượng!')));
        return;
      }

      double inputPrice = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      double originalPrice = double.tryParse(_selectedTicket!['price'].toString()) ?? 0;

      if (inputPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá nhượng không hợp lệ!')));
        return;
      }
      if (inputPrice > originalPrice) {
        final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ Giá nhượng (${formatter.format(inputPrice)}) không được LỚN HƠN giá gốc của vé (${formatter.format(originalPrice)})!'), 
          backgroundColor: Colors.red, duration: const Duration(seconds: 4),
        ));
        return;
      }
    }

    final user = UserManager.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      var uri = Uri.parse('$apiBaseUrl/api/group/posts');
      var request = http.MultipartRequest('POST', uri);

      // Nạp dữ liệu Text
      request.fields['user_id'] = user.id.toString();
      request.fields['content'] = _contentController.text.trim();
      request.fields['type'] = _isTransferPost ? 'transfer' : 'normal';
      request.fields['bg_color'] = _selectedBgColor;
      request.fields['movie_id'] = _selectedMovie != null ? _selectedMovie!['id'].toString() : '';
      request.fields['price'] = _isTransferPost ? _priceController.text.replaceAll(RegExp(r'[^0-9]'), '') : '0';
      request.fields['booking_seat_id'] = _selectedTicket != null ? _selectedTicket!['code'].toString() : '';

      // Nạp dữ liệu Hình ảnh
      for (var img in _imagesList) {
        request.files.add(await http.MultipartFile.fromPath('images', img.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isTransferPost ? 'Đăng thành công! Vé nhượng đang chờ duyệt.' : 'Đã đăng bài thành công!'), backgroundColor: Colors.green));
          Navigator.pop(context, true); 
        }
      }
    } catch (e) {
      debugPrint("Lỗi đăng bài: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ✅ HÀM MỞ MODAL ĐÃ SỬA: Hỗ trợ mở sẵn Tab số 1 (Vé Nhượng) nếu cần
  Future<void> _showTagModal({int initialIndex = 0}) async {
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DefaultTabController(
              length: 2,
              initialIndex: initialIndex, // Mở sẵn tab theo chỉ định
              child: Container(
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: const BoxDecoration(color: Color(0xFFF5F5F9), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                          const Expanded(child: Text("Đính kèm", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        labelColor: navyBlue, unselectedLabelColor: Colors.grey, indicatorColor: navyBlue,
                        tabs: const [Tab(text: "Tất cả phim"), Tab(text: "Vé chưa chiếu")]
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: "Tìm kiếm phim...", prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                    filled: true, fillColor: Colors.white, 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none) 
                                  ),
                                ),
                              ),
                              if (_selectedMovie != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Chip(
                                    label: Text(_selectedMovie!['title'], style: TextStyle(color: navyBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.blue.shade50, deleteIcon: const Icon(Icons.cancel, size: 18),
                                    onDeleted: () { setModalState(() => _selectedMovie = null); setState(() {}); },
                                  ),
                                ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                  child: ListView.builder(
                                    itemCount: _moviesList.length,
                                    itemBuilder: (context, index) {
                                      final m = _moviesList[index];
                                      final isSelected = _selectedMovie != null && _selectedMovie!['id'] == m['id'];
                                      return ListTile(
                                        leading: const Icon(Icons.movie_creation_outlined, color: Colors.grey),
                                        title: Text(m['title'], style: TextStyle(color: isSelected ? navyBlue : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                        onTap: () { 
                                          setModalState(() {
                                            _selectedMovie = m;
                                            _selectedTicket = null; 
                                            _isTransferPost = false; 
                                          }); 
                                          setState(() {}); 
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              if (_selectedTicket != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Chip(
                                    label: Text("Đã chọn vé: ${_selectedTicket!['movie']}", style: const TextStyle(color: Colors.deepOrange, fontSize: 13, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.orange.shade50, deleteIcon: const Icon(Icons.cancel, size: 18, color: Colors.deepOrange),
                                    onDeleted: () { setModalState(() => _selectedTicket = null); setState(() {}); },
                                  ),
                                ),
                              Expanded(
                                child: _myTickets.isEmpty 
                                ? const Center(child: Text("Bạn không có vé nào sắp chiếu để nhượng.", style: TextStyle(color: Colors.grey)))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: _myTickets.length,
                                    itemBuilder: (context, index) {
                                      final t = _myTickets[index];
                                      final isSelected = _selectedTicket != null && _selectedTicket!['code'] == t['code'];
                                      final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
                                      
                                      double parsedPrice = double.tryParse(t['price'].toString()) ?? 0;

                                      return Card(
                                        color: isSelected ? Colors.orange.shade50 : Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.orange : Colors.transparent)),
                                        child: ListTile(
                                          leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network("https://image.tmdb.org/t/p/w200${t['image']}", width: 40, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___)=> const Icon(Icons.movie))),
                                          title: Text(t['movie'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("${t['cinema']} - ${t['room']}", style: const TextStyle(fontSize: 12)),
                                              Text("Suất: ${t['date']}", style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                              Text("Giá gốc bill: ${formatter.format(parsedPrice)}", style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                                            ]
                                          ),
                                          isThreeLine: true,
                                          onTap: () {
                                            setModalState(() {
                                              _selectedTicket = t;
                                              _selectedMovie = null; 
                                              _isTransferPost = true; 
                                            });
                                            setState(() {});
                                          },
                                        )
                                      );
                                    }
                                  )
                              )
                            ],
                          )
                        ]
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Xác nhận", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = UserManager.instance.currentUser;
    bool hasBg = _selectedBgColor != '';
    Color actualBg = hasBg ? Color(int.parse(_selectedBgColor.replaceAll('#', '0xFF'))) : Colors.transparent;

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
            Expanded(child: Text('Tạo bài viết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50])),
        ),
        actions: [
          // Row(
          //   children: [
          //     Text("Nhượng vé", style: TextStyle(color: navyBlue, fontSize: 13, fontWeight: FontWeight.bold)),
          //     // ✅ LOGIC CHỐNG SCAM (LỪA ĐẢO CHỌN BẬY BẠ)
          //     Switch(
          //       value: _isTransferPost, activeColor: navyBlue, 
          //       onChanged: (val) async {
          //         if (val) {
          //           // Nếu gạt ON -> Ép mở tab Vé Nhượng ngay lập tức
          //           await _showTagModal(initialIndex: 1);
          //           // Sau khi đóng Modal, kiểm tra xem có chọn vé thật không
          //           if (_selectedTicket == null) {
          //             setState(() {
          //               _isTransferPost = false; // Tự động gạt về OFF
          //             });
          //             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn 1 chiếc vé để kích hoạt Nhượng Vé!'), backgroundColor: Colors.red));
          //           } else {
          //             setState(() => _isTransferPost = true);
          //           }
          //         } else {
          //           setState(() {
          //             _isTransferPost = false;
          //             _selectedTicket = null; 
          //             _priceController.clear();
          //           });
          //         }
          //       }
          //     ),
          //   ],
          // )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(user?.avatar, 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? "Người dùng", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.public, size: 12, color: Colors.black54), SizedBox(width: 4), Text("Công khai", style: TextStyle(fontSize: 12, color: Colors.black54))])),
                                const SizedBox(width: 8),
                                Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: const Text("Cộng Đồng Ghiền Xem Phim", style: TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis))),
                              ],
                            )
                          ],
                        )
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    width: double.infinity, constraints: BoxConstraints(minHeight: hasBg ? 200 : 100), padding: hasBg ? const EdgeInsets.all(20) : EdgeInsets.zero,
                    decoration: BoxDecoration(color: actualBg, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _contentController, maxLines: null, textAlign: hasBg ? TextAlign.center : TextAlign.start,
                      style: TextStyle(fontSize: hasBg ? 24 : 16, fontWeight: hasBg ? FontWeight.bold : FontWeight.normal, color: hasBg ? Colors.white : Colors.black87),
                      onChanged: (text) => setState(() {}),
                      decoration: InputDecoration(hintText: _isTransferPost ? "Bạn cần miêu tả lý do nhượng vé..." : "Chia sẻ cảm nghĩ của bạn...", border: InputBorder.none, hintStyle: TextStyle(color: hasBg ? Colors.white70 : Colors.grey.shade400)),
                    ),
                  ),
                  
                  if (_selectedMovie != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: Text("Đang nói về: ${_selectedMovie!['title']}", style: TextStyle(color: navyBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.blue.shade50, deleteIcon: const Icon(Icons.cancel, size: 18),
                          onDeleted: () => setState(() => _selectedMovie = null),
                        ),
                      ),
                    ),
                  
                  if (_selectedTicket != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: Text("🎫 Nhượng vé suất: ${_selectedTicket!['date']}", style: const TextStyle(color: Colors.deepOrange, fontSize: 13, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.orange.shade50, deleteIcon: const Icon(Icons.cancel, size: 18, color: Colors.deepOrange),
                          onDeleted: () => setState(() { _selectedTicket = null; _isTransferPost = false; }),
                        ),
                      ),
                    ),

                  // ✅ KHU VỰC HIỂN THỊ ẢNH ĐÃ CHỌN TRONG TẠO BÀI
                  if (_imagesList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Align(alignment: Alignment.centerLeft, child: Text("Hình ảnh đính kèm:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54))),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagesList.length,
                        itemBuilder: (context, index) {
                          final img = _imagesList[index];
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 90, height: 90,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(img.path), fit: BoxFit.cover)),
                              ),
                              Positioned(
                                top: 2, right: 14,
                                child: GestureDetector(
                                  onTap: () => setState(() => _imagesList.removeAt(index)),
                                  child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                                ),
                              )
                            ],
                          );
                        },
                      ),
                    ),
                  ],

                  if (_isTransferPost && _selectedTicket != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                        child: TextField(
                          controller: _priceController, keyboardType: TextInputType.number,
                          decoration: const InputDecoration(icon: Icon(Icons.sell, color: Colors.deepOrange), border: InputBorder.none, hintText: "Nhập giá bạn muốn nhượng (VNĐ)", hintStyle: TextStyle(color: Colors.black38)),
                          style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 32),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showColorPicker)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: _bgColors.map((item) {
                        return GestureDetector(
                          onTap: () => setState(() => _selectedBgColor = item['hex']),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8), width: 36, height: 36,
                            decoration: BoxDecoration(color: item['color'], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: _selectedBgColor == item['hex'] ? const Icon(Icons.check, color: Colors.black54, size: 20) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(onPressed: () => setState(() => _showColorPicker = !_showColorPicker), icon: Icon(Icons.font_download_outlined, color: _showColorPicker ? navyBlue : Colors.grey)),
                    // ✅ NÚT GỌI HÀM CHỌN ẢNH
                    IconButton(onPressed: _pickImage, icon: const Icon(Icons.image_outlined, color: Colors.grey)), 
                    IconButton(onPressed: () => _showTagModal(), icon: Icon(Icons.sell_outlined, color: _selectedMovie != null || _selectedTicket != null ? navyBlue : Colors.grey)),
                    const Spacer(),
                    Text("${_contentController.text.length}/10000", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isSubmitting ? null : _submitPost,
                    child: _isSubmitting 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Đăng bài viết", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
  // ==============================================================
  // ✅ HÀM VẼ AVATAR "BỌC THÉP V3" (TỰ NHẬN DIỆN THƯ MỤC THEO ẢNH CỦA ÔNG)
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

        // TỰ ĐỘNG ROUTING THEO CẤU TRÚC THƯ MỤC CỦA ÔNG (Dựa vào ảnh chụp)
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
                  debugPrint('❌ LỖI TẢI AVATAR: $finalUrl');
                  // Lỗi thì backup về cái chữ cái đầu tiên của Tên
                  return Center(child: Text(UserManager.instance.currentUser?.name.substring(0, 1).toUpperCase() ?? "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4)));
                },
              )
            : Center(child: Text(UserManager.instance.currentUser?.name.substring(0, 1).toUpperCase() ?? "U", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: size * 0.4))),
      ),
    );
  }
}