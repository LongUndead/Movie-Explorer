import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationBottomSheet {
  static void show({
    required BuildContext context,
    required List<dynamic> notifications,
    required Function(int) onMarkAsRead, // Hàm xử lý khi bấm vào thông báo
    required Color primaryColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  Text("Thông báo của bạn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  const Divider(height: 30),
                  
                  Expanded(
                    child: notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text("Bạn chưa có thông báo nào", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notif = notifications[index];
                            final isUnread = notif['IsRead'] == 0;
                            
                            DateTime createdAt = DateTime.tryParse(notif['CreatedAt'] ?? '')?.toLocal() ?? DateTime.now();
                            String timeString = DateFormat('HH:mm - dd/MM/yyyy').format(createdAt);

                            IconData iconData = Icons.notifications;
                            Color iconColor = Colors.white;
                            Color bgColor = primaryColor;

                            switch (notif['Type']) {
                              case 'BOOKING': 
                                iconData = Icons.confirmation_num_outlined;
                                bgColor = Colors.teal.shade500;
                                break;
                              case 'VOUCHER': 
                                iconData = Icons.card_giftcard;
                                bgColor = Colors.orange.shade500;
                                break;
                              case 'MOVIE': 
                                iconData = Icons.local_movies_outlined;
                                bgColor = Colors.blue.shade500;
                                break;
                              case 'FOOD': 
                                iconData = Icons.fastfood_outlined;
                                bgColor = Colors.amber.shade600;
                                break;
                              case 'REFUND': 
                                iconData = Icons.currency_exchange;
                                bgColor = Colors.teal.shade500;
                                break;
                              case 'WARNING': 
                              case 'BANNED':
                                iconData = Icons.gavel_rounded; 
                                bgColor = Colors.red.shade600;
                                break;
                              // ========================================================
                              // 🚀 ĐÃ BỔ SUNG 2 CASE MỚI CHO CHỨC NĂNG CỘNG ĐỒNG (LIKE/CMT)
                              // ========================================================
                              case 'POST_LIKE': 
                                iconData = Icons.favorite;
                                bgColor = Colors.pink.shade500;
                                break;
                              case 'POST_COMMENT': 
                                iconData = Icons.chat_bubble_outline_rounded;
                                bgColor = Colors.indigo.shade500;
                                break;
                              // ========================================================
                              default:
                                iconData = Icons.notifications;
                                bgColor = primaryColor;
                            }

                            return GestureDetector(
                              onTap: () {
                                if (isUnread) {
                                  onMarkAsRead(notif['NotificationID']); // Gọi hàm của trang cha truyền vào
                                  setModalState(() {
                                    notif['IsRead'] = 1;
                                  });
                                }

                                Navigator.pop(context);

                                final actionUrl = notif['ActionURL'] ?? '';
                                if (actionUrl.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng quay lại trang chủ để mở liên kết này!')));
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUnread ? Colors.blue.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isUnread ? Colors.blue.shade100 : Colors.transparent)
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isUnread ? bgColor : Colors.grey.shade300, 
                                        shape: BoxShape.circle
                                      ),
                                      child: Icon(iconData, color: isUnread ? iconColor : Colors.grey.shade600, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(notif['Title'] ?? 'Thông báo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isUnread ? Colors.black87 : Colors.black54)),
                                          const SizedBox(height: 4),
                                          Text(notif['Content'] ?? '', style: TextStyle(color: isUnread ? Colors.black87 : Colors.black54, fontSize: 13, height: 1.4)),
                                          const SizedBox(height: 8),
                                          Text(timeString, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 8, height: 8,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      )
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
      }
    );
  }
}