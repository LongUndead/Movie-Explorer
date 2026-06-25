import 'package:flutter/material.dart';

class PromotionDetailsPage extends StatelessWidget {
  const PromotionDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Đổi sang màu chủ đạo của app
    final Color navyBlue = Colors.blue.shade900; 
    const Color momoGreen = Color(0xFF00B14F); 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Để lộ gradient ở dưới
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade100, Colors.white], // Hiệu ứng Gradient Navy White
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: navyBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Chi tiết', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          // ✅ BOX CHỨA CHUÔNG VÀ GIỎ HÀNG 
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.0),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
              ]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    // Xử lý khi bấm chuông
                  },
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.notifications_none, color: navyBlue, size: 20),
                  ),
                ),
                Container(height: 14, width: 1.5, color: navyBlue.withOpacity(0.2)), // Thanh dọc phân cách
                InkWell(
                  onTap: () {
                    // Xử lý khi bấm giỏ hàng
                  },
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.shopping_cart_outlined, color: navyBlue, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // NÚT "THAM GIA NGAY" NEO CỐ ĐỊNH Ở ĐÁY
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: navyBlue, // Đổi màu nút sang Navy Blue
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("THAM GIA NGAY", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER CHÍNH
            Image.asset(
              'assets/chitiet.png', 
              width: double.infinity, 
              fit: BoxFit.cover,
              errorBuilder: (_,__,___) => Container(height: 200, color: Colors.blue.shade50, child: Icon(Icons.image, size: 50, color: navyBlue)),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. KHUYẾN MÃI & NÚT CHIA SẺ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("KHUYẾN MÃI", style: TextStyle(color: momoGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text("26/07/2024 • 417.9K", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: () {},
                        icon: const Text("Chia sẻ", style: TextStyle(color: Colors.black87, fontSize: 13)),
                        label: const Icon(Icons.reply, color: Colors.black87, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. TIÊU ĐỀ LỚN
                  Text(
                    "Cày Phim Săn Huy Hiệu - Tích lũy chi tiêu để nhận cặp vé premiere phim và loạt deal xịn đa dịch vụ",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navyBlue, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // 4. MÔ TẢ NGẮN
                  _buildParagraph("Nếu bạn thường xuyên mua vé xem phim trên ứng dụng, đừng bỏ lỡ cơ hội nhận vé công chiếu phim cũng như hàng loạt phần quà tri ân giá trị từ chương trình Cày Phim Săn Huy Hiệu. Khám phá ngay cách nhận huy hiệu cực xịn và quà tương ứng ngay bên dưới nhé!"),
                  
                  // 5. THỜI GIAN DIỄN RA
                  _buildSectionTitle("Thời gian diễn ra", navyBlue),
                  _buildParagraph("Chương trình đã kết thúc."),

                  // 6. NỘI DUNG CHƯƠNG TRÌNH
                  _buildSectionTitle("Nội dung chương trình", navyBlue),
                  _buildParagraph("Trong thời gian diễn ra chương trình, khi càng có nhiều giao dịch trong mục “Mua Vé Xem Phim”, bạn càng nhận được nhiều đặc quyền xịn."),
                  _buildBulletPoint("Thăng hạng và mở khóa loạt huy hiệu sang xịn khi đạt mốc tích lũy chi tiêu."),
                  _buildBulletPoint("Ưu đãi riêng khi mua vé hoặc bắp nước trên ứng dụng."),
                  _buildBulletPoint("Nhận cặp vé premiere (họp báo công chiếu phim) ở TPHCM dành riêng top 5 người đạt tích lũy chi tiêu cao nhất trong thời gian diễn ra chương trình."),

                  // 7. ĐỐI TƯỢNG THAM GIA
                  _buildSectionTitle("Đối tượng tham gia", navyBlue),
                  _buildParagraph("Tất cả người dùng có tài khoản hợp lệ và sử dụng các dịch vụ trong mục “Mua Vé Xem Phim”."),

                  // 8. DANH SÁCH HUY HIỆU VÀ HÌNH ẢNH BẢNG
                  _buildSectionTitle("Danh sách huy hiệu và phần quà tương ứng", navyBlue),
                  _buildParagraph("Khám phá các huy hiệu và phần quà nhận được tương ứng như sau:"),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/dshuyhieu.png',
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_,__,___) => Container(height: 300, color: Colors.blue.shade50, child: Center(child: Icon(Icons.table_chart, size: 50, color: navyBlue))),
                    ),
                  ),

                  // 9. CÁCH NHẬN THƯỞNG
                  _buildSectionTitle("Cách nhận thưởng", navyBlue),
                  _buildParagraph("Sau khi đạt các mốc tích lũy chi tiêu, người dùng sẽ được nhận xác nhận thăng hạng kèm huy hiệu và quà tương ứng."),
                  _buildParagraph("Riêng phần quà là cặp vé premiere (2 vé) dành cho top 5, ban tổ chức sẽ liên hệ trao quà sau khi chương trình kết thúc."),

                  // 10. HƯỚNG DẪN THAM GIA
                  _buildSectionTitle("Hướng dẫn tham gia chương trình", navyBlue),
                  _buildParagraph("Bước 1: Mở “Mua Vé Xem Phim” ở màn hình chính hoặc tìm \"Mua Vé Xem Phim\" trên thanh tìm kiếm\n\n"
                                "Bước 2: Vào mục \"Tôi\" để xem thông tin hạng và huy hiệu của mình\n\n"
                                "Bước 3: Mua vé xem phim tích lũy chi tiêu để thăng hạng và mở khóa huy hiệu cao cấp hơn\n\n"
                                "Bước 4: Nhận quà tương ứng với từng huy hiệu sáng màu sau khi đạt được các mốc chi tiêu"),

                  // 11. ĐIỀU KIỆN VÀ ĐIỀU KHOẢN
                  _buildSectionTitle("Điều kiện & Điều khoản:", navyBlue),
                  _buildBulletPoint("Hệ thống có quyền sử dụng hình ảnh của người dùng trúng thưởng cho mục đích quảng bá và truyền thông cho chương trình."),
                  _buildBulletPoint("Các thẻ quà chỉ áp dụng khi thanh toán trực tiếp trong dịch vụ “Mua Vé Xem Phim”."),
                  _buildBulletPoint("Tất cả giải thưởng không có giá trị quy đổi thành tiền mặt hay chuyển nhượng dưới mọi hình thức."),
                  _buildBulletPoint("Hệ thống có quyền thay đổi các điều khoản cũng như kết thúc chương trình mà không cần thông báo trước hoặc phải chịu trách nhiệm với bất kỳ bên nào."),
                  _buildBulletPoint("Nếu phát hiện người dùng vi phạm các tiêu chuẩn cộng đồng hoặc có hành vi gian lận trong chương trình, phần thưởng sẽ bị hủy và người dùng có thể bị khóa tài khoản, tước quyền tham gia chương trình."),
                  _buildBulletPoint("Mọi tranh chấp phát sinh liên quan chương trình, quyền quyết định cuối cùng thuộc về ban tổ chức."),
                  const SizedBox(height: 16),
                  
                  // DÒNG MIỄN TRỪ TRÁCH NHIỆM
                  const Text(
                    "* Google không tài trợ cho bất cứ hoạt động kinh doanh & thương mại nào của chúng tôi.",
                    style: TextStyle(color: Colors.black54, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 40), 
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // WIDGET HỖ TRỢ: Tiêu đề mục màu Navy Blue
  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6));
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8.0, right: 8.0),
            child: Icon(Icons.circle, size: 6, color: Colors.black54),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5))),
        ],
      ),
    );
  }
}