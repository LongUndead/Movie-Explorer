import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../../domain/entities/movie.dart';
import 'cart_page.dart';
import 'user_manager.dart';
import 'ticket_result_screen.dart'; 
import 'notification_service.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl; 
  final Movie? movie;
  final String date;
  final String time;
  final String cinemaName; 
  final String? bookingId;
  final int amount; // 🚀 FIX LỖI: Nhận số tiền thực tế từ màn hình trước truyền vào

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.movie,
    required this.date,
    required this.time,
    required this.cinemaName, 
    this.bookingId,
    required this.amount, // 🚀 FIX LỖI
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false); 
            
            // =========================================================================
            // 🔥 TRÓI JAVASCRIPT: BỌC IF ĐỂ CHỈ CHẠY KHI LÀ LINK ZALOPAY
            // Cấm tuyệt đối không cho nó phá màn hình của VNPAY
            // =========================================================================
            if (widget.paymentUrl.contains('zalopay')) {
              _controller.runJavaScript('''
                var checkPayment = setInterval(function() {
                  if (document.body && document.body.innerText.toUpperCase().includes('THANH TOÁN THÀNH CÔNG')) {
                     clearInterval(checkPayment); // Phanh gấp, ngừng dò tìm
                     window.location.href = 'https://google.com/zalopay_return?status=1'; // Văng link
                  }
                }, 1000);
              ''');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            
            debugPrint("========== URL WEBVIEW ĐANG TRUY CẬP ==========");
            debugPrint(request.url);
            
            // 🛡️ LƯỚI TRỜI: Chặn TẤT CẢ các link gọi App ngoài (momo://, zalopay://, mbbank://, v.v.)
            if (!request.url.startsWith('http://') && !request.url.startsWith('https://')) {
              debugPrint("🚫 ĐÃ CHẶN LINK GỌI APP NGOÀI: ${request.url}");
              _launchExternalApp(request.url); 
              return NavigationDecision.prevent; 
            }

            Uri uri = Uri.parse(request.url);
            
            bool isVNPay = uri.queryParameters.containsKey('vnp_ResponseCode') && uri.queryParameters.containsKey('vnp_TxnRef');
            bool isMoMoNormal = uri.queryParameters.containsKey('resultCode') && uri.queryParameters.containsKey('orderId');
            bool isMoMoSandboxStuck = request.url.contains('napas-cashin-v3/form_callback') && uri.queryParameters.containsKey('orderId');
            bool isZaloPay = request.url.contains('zalopay_return');

            if (isVNPay || isMoMoNormal || isMoMoSandboxStuck || isZaloPay) { 
              
              bool isSuccess = false;
              String? orderId;
              int amount = 0;
              String bankCode = 'UNKNOWN'; 
              
              // 🔥 Tự động nội suy Cổng thanh toán gốc từ URL mở Webview lúc đầu
              String currentProvider = widget.paymentUrl.contains('vnpay') ? 'VNPAY' 
                                     : widget.paymentUrl.contains('momo') ? 'MOMO' : 'ZALOPAY';

              // 1. XỬ LÝ VNPAY
              if (isVNPay) {
                String? vnpResponseCode = uri.queryParameters['vnp_ResponseCode'];
                orderId = uri.queryParameters['vnp_TxnRef']; 
                amount = (int.parse(uri.queryParameters['vnp_Amount'] ?? '0') / 100).round();
                bankCode = uri.queryParameters['vnp_BankCode'] ?? 'VNPAY'; // Bắt đúng mã ngân hàng
                if (vnpResponseCode == '00') isSuccess = true;
              } 
              // 2. XỬ LÝ MOMO CHUẨN
              else if (isMoMoNormal) {
                String? momoResultCode = uri.queryParameters['resultCode'];
                String? rawOrderId = uri.queryParameters['orderId'];
                if (rawOrderId != null && rawOrderId.startsWith("MOMO_")) {
                  orderId = rawOrderId.split('_')[1]; 
                } else { orderId = rawOrderId; }
                amount = int.parse(uri.queryParameters['amount'] ?? '0');
                bankCode = 'MOMO';
                if (momoResultCode == '0' || momoResultCode == '9000') isSuccess = true;
              }
              // 3. XỬ LÝ MOMO SANDBOX BỊ KẸT
              else if (isMoMoSandboxStuck) {
                 isSuccess = true; 
                 orderId = widget.bookingId; 
                 amount = widget.amount; // 🚀 FIX LỖI 0.0: Lấy số tiền truyền vào
                 bankCode = 'MOMO';
              }
              // 4. 🚀 XỬ LÝ ZALOPAY
              else if (isZaloPay) {
                 String? status = uri.queryParameters['status'];
                 orderId = widget.bookingId; 
                 amount = widget.amount; // 🚀 FIX LỖI 0.0: Lấy số tiền truyền vào
                 bankCode = 'ZALOPAY';
                 if (status == '1') isSuccess = true;
              }

              if (isSuccess && orderId != null) {
                if (_isProcessingPayment) {
                  debugPrint("🚫 Đã chặn luồng gọi đúp API!");
                  return NavigationDecision.prevent; 
                }
                
                _isProcessingPayment = true;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang xác nhận giao dịch, vui lòng đợi...'), backgroundColor: Colors.blue));

                String orderInfoMsg = widget.movie == null ? 'Thanh toan don bap nuoc' : 'Thanh toan ve phim ${widget.movie!.title}';

                http.post(
                  Uri.parse('http://192.168.1.7:3000/api/bookings/confirm_payment'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'bookingId': orderId,
                    'amount': amount, // Bỏ số 0 đi, gửi số tiền thật vào đây!
                    'transactionNo': uri.queryParameters['vnp_TransactionNo'] ?? uri.queryParameters['transId'] ?? uri.queryParameters['apptransid'] ?? '',
                    'bankCode': bankCode, 
                    'provider': currentProvider,  
                    'method': currentProvider,    
                    'orderInfo': orderInfoMsg
                  })
                ).then((response) async {
                  
                  debugPrint("🔥 KẾT QUẢ TỪ SERVER: Mã ${response.statusCode}");

                  if (response.statusCode == 200 || response.statusCode == 201) {
                    CartManager.instance.clearCart(); 

                    Map<String, dynamic>? latestTicket;
                    final user = UserManager.instance.currentUser;
                    if (user != null) {
                      try {
                        final res = await http.get(Uri.parse('http://192.168.1.7:3000/api/user/tickets/${user.id}'));
                        if (res.statusCode == 200) {
                          final List<dynamic> tickets = json.decode(res.body);
                          if (tickets.isNotEmpty) latestTicket = tickets.first;
                        }
                      } catch (e) {
                        debugPrint("Lỗi tải vé: $e");
                      }
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green));
                      
                      String? notificationImage;
                      String movieTitle = "bắp nước"; 
                      if (widget.movie != null) {
                        movieTitle = "phim ${widget.movie!.title}";
                        if (widget.movie!.backdropPaths != null && widget.movie!.backdropPaths!.isNotEmpty) {
                          notificationImage = widget.movie!.backdropPaths!.first;
                        } else { notificationImage = widget.movie!.posterPath; }
                        if (notificationImage != null && notificationImage.startsWith('/')) {
                          notificationImage = 'https://image.tmdb.org/t/p/w500$notificationImage';
                        }
                      }

                      NotificationService.showNotification(
                        id: DateTime.now().millisecond, 
                        title: "🎫 Đặt vé thành công!",
                        body: "Đơn hàng #$orderId mua vé $movieTitle qua $bankCode đã hoàn tất. Chúc bạn xem phim vui vẻ!",
                        imageUrl: notificationImage, 
                      );

                      Navigator.pushAndRemoveUntil(
                        context, 
                        MaterialPageRoute(
                          builder: (_) => TicketResultScreen(
                            movie: widget.movie,
                            date: widget.date,
                            time: widget.time,
                            cinemaName: widget.cinemaName,
                            fullTicketData: latestTicket, 
                          )
                        ),
                        (route) => route.isFirst, 
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi từ Server: ${response.statusCode} - Chưa thể xác nhận vé!'), backgroundColor: Colors.red));
                      Navigator.pop(context); 
                    }
                  }
                }).catchError((error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối mạng khi xác nhận đơn hàng!'), backgroundColor: Colors.red));
                    Navigator.pop(context); 
                  }
                });

              }
              else if (orderId != null) {
                // HỦY ĐƠN KHI KHÁCH BẤM HỦY TRÊN WEBVIEW
                http.post(
                  Uri.parse('http://192.168.1.7:3000/api/bookings/cancel_payment'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({ 'bookingId': orderId })
                ).then((response) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy giao dịch!'), backgroundColor: Colors.orange));
                    Navigator.pop(context); 
                  }
                }).catchError((error) {
                  if (context.mounted) Navigator.pop(context);
                });
              }
              
              return NavigationDecision.prevent; 
            }
            
            return NavigationDecision.navigate; 
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _launchExternalApp(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Lỗi mở app ngoài: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () {
            if (widget.bookingId != null) {
                http.post(
                  Uri.parse('http://192.168.1.7:3000/api/bookings/cancel_payment'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({ 'bookingId': widget.bookingId })
                ).then((_) {
                   debugPrint("Đã hủy đơn nháp thành công do user bấm X");
                });
            }
            _controller.loadRequest(Uri.parse('about:blank'));
            Navigator.pop(context);
          },
        ),
        title: const Text('Cổng thanh toán an toàn', style: TextStyle(color: Colors.black87, fontSize: 16)),
        
        // 🚀 NÚT BYPASS BẤT TỬ (Đã fix truyền đủ amount)
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.bug_report, color: Colors.redAccent, size: 18),
            label: const Text('Bypass', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () {
              // Tự động nội suy Bypass của VNPay hoặc ZaloPay
              String fakeSuccessUrl = widget.paymentUrl.contains('vnpay') 
                  ? "https://google.com/vnpay_return?vnp_ResponseCode=00&vnp_TxnRef=${widget.bookingId}&vnp_BankCode=NCB&vnp_Amount=${widget.amount * 100}"
                  : "https://google.com/zalopay_return?status=1";
              
              _controller.loadRequest(Uri.parse(fakeSuccessUrl));
            },
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) Center(child: CircularProgressIndicator(color: Colors.blue.shade900)),
        ],
      ),
    );
  }
}