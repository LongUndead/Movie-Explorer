import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    final AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings: settings);

    // Xin quyền hiển thị thông báo cho Android 13 trở lên
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ==========================================================
  // 🚀 HÀM PHỤ: ÂM THẦM TẢI ẢNH TỪ MẠNG VỀ THƯ MỤC TẠM CỦA MÁY
  // ==========================================================
  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getTemporaryDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  // ==========================================================
  // 🚀 HÀM CHÍNH: PHÓNG THÔNG BÁO (CÓ HỖ TRỢ ẢNH TO BIG PICTURE)
  // ==========================================================
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? imageUrl, // Nhận thêm link ảnh (nếu có)
  }) async {
    
    StyleInformation? styleInformation;

    // Nếu lúc gọi hàm mà có truyền link ảnh -> Chế độ Big Picture
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        // Tải ảnh về điện thoại
        final String largeIconPath = await _downloadAndSaveFile(imageUrl, 'big_picture_$id.jpg');
        
        // Setup giao diện ảnh to
        styleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(largeIconPath),
          hideExpandedLargeIcon: true,
          contentTitle: title,
          summaryText: body,
        );
      } catch (e) {
        print("Lỗi tải ảnh thông báo: $e"); // Nếu tải ảnh lỗi thì cứ hiện thông báo chữ bình thường
      }
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cinema_channel_id', 
      'Cinema Notifications',
      channelDescription: 'Thông báo đặt vé, ưu đãi từ CinemaTickets',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: styleInformation, // 🚀 ÉP GIAO DIỆN ẢNH TO VÀO ĐÂY
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}