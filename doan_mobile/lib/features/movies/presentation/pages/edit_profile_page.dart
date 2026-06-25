import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'user_manager.dart'; // Import để lấy thông tin user hiện tại

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final Color navyBlue = Colors.blue.shade900;
  final Color primaryBlue = Colors.blue.shade700;
  final String apiBaseUrl = 'http://192.168.1.2:3000';

  // Controller cho Tab 1 (Thông tin)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Controller cho Tab 2 (Mật khẩu)
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Xử lý Ảnh Đại Diện
  File? _avatarImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Lấy thông tin user hiện tại để điền sẵn vào ô nhập
    final user = UserManager.instance.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email ?? "";
      _phoneController.text = user.phone ?? "";
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // HÀM CHỌN ẢNH TỪ THƯ VIỆN ĐIỆN THOẠI
  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _avatarImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
    }
  }

  Future<void> _savePersonalInfo() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ Tên và Số điện thoại', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    try {
      // TẠM THỜI CHỈ GỬI TEXT (Upload Ảnh cần thư viện Multer ở Backend, thầy sẽ hướng dẫn sau nếu bạn cần)
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/user/profile/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        // Cập nhật lại thông tin dưới máy (UserManager) để khỏi cần đăng nhập lại
        user.name = _nameController.text.trim();
        user.phone = _phoneController.text.trim();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'], style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
          FocusScope.of(context).unfocus(); // Đóng bàn phím
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Lỗi cập nhật', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Lỗi save profile: $e");
    }
  }

  Future<void> _changePassword() async {
    final user = UserManager.instance.currentUser;
    if (user == null) return;

    if (_oldPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ các trường mật khẩu!'), backgroundColor: Colors.red));
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu mới phải dài ít nhất 6 ký tự!'), backgroundColor: Colors.red));
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu xác nhận không khớp!'), backgroundColor: Colors.red));
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/user/password/change'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id,
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
          // Xóa trắng form sau khi đổi pass thành công
          _oldPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          FocusScope.of(context).unfocus(); 
        }
      } else {
        // Sai mật khẩu cũ nó sẽ báo lỗi đỏ ở đây
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Lỗi change password: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F9),
        // =======================================================
        // ✅ APPBAR: MÀU XANH NHẠT CHỮ NAVY + TABBAR NỀN TRẮNG
        // =======================================================
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
              Expanded(child: Text('Cài đặt tài khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue))),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade300, Colors.blue.shade50]),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: Container(
              color: Colors.white,
              child: TabBar(
                indicatorColor: navyBlue,
                labelColor: navyBlue,
                unselectedLabelColor: Colors.grey.shade500,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: "Thông tin cá nhân"),
                  Tab(text: "Đổi mật khẩu"),
                ],
              ),
            ),
          ),
        ),
        
        // =======================================================
        // ✅ NỘI DUNG 2 TAB
        // =======================================================
        body: TabBarView(
          children: [
            _buildPersonalInfoTab(),
            _buildChangePasswordTab(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // TAB 1: THÔNG TIN CÁ NHÂN (Có tải Avatar)
  // ---------------------------------------------------------
  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // KHU VỰC AVATAR
          Center(
            child: Stack(
              children: [
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: _avatarImage != null
                        ? Image.file(_avatarImage!, fit: BoxFit.cover)
                        : Image.asset('assets/avatar_placeholder.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.person, size: 50, color: Colors.grey.shade400)),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: navyBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          // CÁC Ô NHẬP LIỆU
          _buildTextField("Họ và Tên", Icons.person_outline, _nameController),
          const SizedBox(height: 16),
          _buildTextField("Số điện thoại", Icons.phone_outlined, _phoneController, isNumber: true),
          const SizedBox(height: 16),
          _buildTextField("Email", Icons.email_outlined, _emailController, enabled: false),
          const SizedBox(height: 32),

          // NÚT LƯU
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              onPressed: _savePersonalInfo,
              child: const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // TAB 2: ĐỔI MẬT KHẨU
  // ---------------------------------------------------------
  Widget _buildChangePasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const Icon(Icons.lock_reset_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Mật khẩu phải dài ít nhất 6 ký tự, bao gồm chữ và số để đảm bảo an toàn.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
          const SizedBox(height: 32),

          _buildTextField("Mật khẩu hiện tại", Icons.lock_outline, _oldPasswordController, isPassword: true),
          const SizedBox(height: 16),
          _buildTextField("Mật khẩu mới", Icons.lock_outline, _newPasswordController, isPassword: true),
          const SizedBox(height: 16),
          _buildTextField("Xác nhận mật khẩu mới", Icons.check_circle_outline, _confirmPasswordController, isPassword: true),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              onPressed: _changePassword,
              child: const Text('Cập nhật mật khẩu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // HÀM VẼ TEXTFIELD CHUẨN FORM
  // HÀM VẼ TEXTFIELD CHUẨN FORM (ĐÃ THÊM CON MẮT ẨN/HIỆN MẬT KHẨU)
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, 
      {bool isPassword = false, bool isNumber = false, bool enabled = true}) { 
    
    // Biến nội bộ quản lý trạng thái ẩn/hiện của riêng ô text này
    bool obscureText = isPassword; 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        
        // Dùng StatefulBuilder để chỉ vẽ lại ô nhập liệu này khi bấm nút con mắt
        StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: enabled ? Colors.white : Colors.grey.shade100, 
                borderRadius: BorderRadius.circular(12), 
                border: Border.all(color: Colors.grey.shade300)
              ),
              child: TextField(
                controller: controller,
                enabled: enabled, 
                obscureText: obscureText, // Sử dụng biến cục bộ
                keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
                decoration: InputDecoration(
                  prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
                  
                  // ==========================================
                  // ✅ NÚT CON MẮT NẰM Ở ĐÂY
                  // ==========================================
                  suffixIcon: isPassword 
                      ? IconButton(
                          icon: Icon(
                            obscureText ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () {
                            // Gọi setState nội bộ để đổi icon và ẩn/hiện chữ
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        )
                      : null, // Nếu không phải ô mật khẩu thì không hiện icon gì cả
                      
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: "Nhập $label...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ),
            );
          }
        ),
      ],
    );
  }
}