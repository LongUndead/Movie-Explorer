import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TicketRefundPage extends StatefulWidget {
  final String bookingId;
  final String baseUrl;

  const TicketRefundPage({super.key, required this.bookingId, required this.baseUrl});

  @override
  State<TicketRefundPage> createState() => _TicketRefundPageState();
}

class _TicketRefundPageState extends State<TicketRefundPage> {
  final TextEditingController _accNumberController = TextEditingController();
  final TextEditingController _accNameController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  List<dynamic> _bankList = [];
  List<dynamic> _filteredBankList = [];
  bool _isLoadingBanks = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _selectedBank;

  final Color navyBlue = Colors.blue.shade900;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  // 🚀 LẤY DANH SÁCH NGÂN HÀNG TỪ VIETQR KHI VỪA MỞ TRANG
  Future<void> _fetchBanks() async {
    try {
      final response = await http.get(Uri.parse('https://api.vietqr.io/v2/banks'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _bankList = data['data'];
          _filteredBankList = _bankList;
          _isLoadingBanks = false;
        });
      } else {
        _showError("Không thể tải danh sách ngân hàng");
      }
    } catch (e) {
      _showError("Lỗi kết nối khi tải ngân hàng");
    }
  }

  void _showError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() => _isLoadingBanks = false);
  }

  // 🚀 MỞ BẢNG TÌM KIẾM NGÂN HÀNG TỪ DƯỚI LÊN (BOTTOM SHEET)
  void _showBankSearchSheet() {
    // Reset danh sách lọc mỗi khi mở lên
    setState(() => _filteredBankList = _bankList);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.8, // Chiếm 80% màn hình
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    const Text("Chọn Ngân Hàng", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // Ô Tìm kiếm
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Tìm theo tên, viết tắt (VD: Vietcombank, MB)...",
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: navyBlue)),
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          String query = value.toLowerCase();
                          _filteredBankList = _bankList.where((bank) {
                            return bank['shortName'].toString().toLowerCase().contains(query) || 
                                   bank['name'].toString().toLowerCase().contains(query) ||
                                   bank['code'].toString().toLowerCase().contains(query);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Danh sách ngân hàng
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredBankList.length,
                        itemBuilder: (context, index) {
                          final bank = _filteredBankList[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(bank['logo'], width: 40, height: 40, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.account_balance)),
                            ),
                            title: Text(bank['shortName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(bank['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            onTap: () {
                              setState(() => _selectedBank = bank);
                              Navigator.pop(context); // Đóng Sheet
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // 🚀 XỬ LÝ GỬI API HOÀN TIỀN
  Future<void> _submitRefund() async {
    if (_selectedBank == null || _accNumberController.text.trim().isEmpty || _accNameController.text.trim().isEmpty || _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin bắt buộc (*)")));
      return;
    }

    setState(() => _isSubmitting = true);
    
    String combinedReason = "Lý do: ${_reasonController.text.trim()} | Ngân hàng: ${_selectedBank!['shortName']} | STK: ${_accNumberController.text.trim()} | Chủ TK: ${_accNameController.text.trim().toUpperCase()}";

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}api/user/refund'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': widget.bookingId, 
          'reason': combinedReason
        })
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi yêu cầu hoàn tiền thành công!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
          // Trả về true để trang trước biết là đã hoàn thành
          Navigator.pop(context, true); 
        }
      } else {
        var err = jsonDecode(response.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${err['error']}")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối máy chủ!")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6), 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Yêu Cầu Hoàn Tiền', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)
              )
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight, 
              colors: [Colors.blue.shade300, Colors.blue.shade50]
            )
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0
          ),
          onPressed: _isSubmitting ? null : _submitRefund,
          child: _isSubmitting 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Xác nhận Gửi Yêu Cầu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
      body: _isLoadingBanks 
        ? Center(child: CircularProgressIndicator(color: navyBlue))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hộp cảnh báo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Tiền hoàn sẽ được nhân viên kế toán chuyển khoản thủ công vào tài khoản này trong vòng 24h làm việc. Vui lòng nhập chính xác thông tin.",
                          style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // BOX CHỌN NGÂN HÀNG (Bấm vào mở BottomSheet)
                _buildLabel("Ngân hàng nhận tiền"),
                GestureDetector(
                  onTap: _showBankSearchSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        if (_selectedBank != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(_selectedBank!['logo'], width: 24, height: 24, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.account_balance, size: 20)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text("${_selectedBank!['shortName']} - ${_selectedBank!['code']}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87))),
                        ] else
                          Expanded(child: Text("Bấm để tìm và chọn ngân hàng...", style: TextStyle(fontSize: 15, color: Colors.grey.shade500))),
                        Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel("Số tài khoản"),
                _buildTextField(
                  controller: _accNumberController,
                  hint: "Nhập số tài khoản...",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                _buildLabel("Tên chủ tài khoản"),
                _buildTextField(
                  controller: _accNameController,
                  hint: "VD: NGUYEN VAN A",
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),

                _buildLabel("Lý do hoàn vé"),
                _buildTextField(
                  controller: _reasonController,
                  hint: "Vui lòng nhập lý do cụ thể...",
                  maxLines: 3,
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text, 
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), 
          children: const [TextSpan(text: " *", style: TextStyle(color: Colors.red))]
        )
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, int maxLines = 1, TextInputType? keyboardType, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: navyBlue, width: 1.5)),
      ),
    );
  }
}