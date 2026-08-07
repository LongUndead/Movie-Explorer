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
  final int amount; 

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.movie,
    required this.date,
    required this.time,
    required this.cinemaName, 
    this.bookingId,
    required this.amount, 
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  
  // 🚀 BIẾN KHÓA: Kiểm tra xem khách đã mở App ZaloPay/MoMo ngoài chưa
  bool _openedExternalApp = false;

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
            
            // 🚀 BỌC THÉP 1: Chỉ bơm Javascript khi đang ở trang ZaloPay, tránh bơm nhiều lần
            if (url.contains('zalopay.')) {
              _controller.runJavaScript('''
                // Biến cờ chống bơm nhiều vòng lặp
                if (typeof window.zaloPayObserver === 'undefined') {
                  window.zaloPayObserver = true;
                  var checkPayment = setInterval(function() {
                    var pageText = document.body ? document.body.innerText.toUpperCase() : '';
                    if (pageText.includes('THANH TOÁN THÀNH CÔNG') || pageText.includes('GIAO DỊCH THÀNH CÔNG')) {
                       clearInterval(checkPayment); // Phanh gấp
                       window.location.replace('https://google.com/zalopay_return?status=1'); // Bắn link
                    }
                  }, 1000);
                }
              ''');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            
            // 🛡️ LƯỚI TRỜI: Chặn TẤT CẢ các link gọi App ngoài (momo://, zalopay://, mbbank://, v.v.)
            if (!request.url.startsWith('http://') && !request.url.startsWith('https://')) {
              _openedExternalApp = true; 
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
              
              String currentProvider = widget.paymentUrl.contains('vnpay') ? 'VNPAY' 
                                     : widget.paymentUrl.contains('momo') ? 'MOMO' : 'ZALOPAY';

              if (isVNPay) {
                String? vnpResponseCode = uri.queryParameters['vnp_ResponseCode'];
                orderId = uri.queryParameters['vnp_TxnRef']; 
                amount = (int.parse(uri.queryParameters['vnp_Amount'] ?? '0') / 100).round();
                bankCode = uri.queryParameters['vnp_BankCode'] ?? 'VNPAY'; 
                if (vnpResponseCode == '00') isSuccess = true;
              } 
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
              else if (isMoMoSandboxStuck) {
                 isSuccess = true; 
                 orderId = widget.bookingId; 
                 amount = widget.amount; 
                 bankCode = 'MOMO';
              }
              else if (isZaloPay) {
                 String? status = uri.queryParameters['status'];
                 orderId = widget.bookingId; 
                 amount = widget.amount; 
                 bankCode = 'ZALOPAY';
                 if (status == '1') isSuccess = true;
              }

              // ========================================================
              // 🚀 BỌC THÉP 2: XỬ LÝ KHI GIAO DỊCH THÀNH CÔNG
              // ========================================================
              if (isSuccess && orderId != null) {
                if (_isProcessingPayment) {
                  return NavigationDecision.prevent; 
                }
                
                _isProcessingPayment = true;
                
                // 💣 TUYỆT CHIÊU HỦY DIỆT: Lập tức ép WebView tải 1 trang trắng!
                // Màn hình ZaloPay sẽ bốc hơi, dập tắt mọi nguồn cơn spam Javascript
                _controller.loadRequest(Uri.parse('about:blank'));
                
                // Hiện thanh chờ an tâm cho khách hàng
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang xác nhận giao dịch, vui lòng đợi...'), backgroundColor: Colors.blue));

                String orderInfoMsg = widget.movie == null ? 'Thanh toan don bap nuoc' : 'Thanh toan ve phim ${widget.movie!.title}';

                // GỌI API XUỐNG BACKEND THẬT YÊN BÌNH
                http.post(
                  Uri.parse('http://192.168.1.7:3000/api/bookings/confirm_payment'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'bookingId': orderId,
                    'amount': amount, 
                    'transactionNo': uri.queryParameters['vnp_TransactionNo'] ?? uri.queryParameters['transId'] ?? uri.queryParameters['apptransid'] ?? '',
                    'bankCode': bankCode, 
                    'provider': currentProvider,  
                    'method': currentProvider,    
                    'orderInfo': orderInfoMsg
                  })
                ).then((response) async {
                  
                  if (response.statusCode == 200 || response.statusCode == 201) {
                    CartManager.instance.clearCart(); 

                    Map<String, dynamic>? latestTicket;
                    final user = UserManager.instance.currentUser;
                    if (user != null) {
                      try {
                        final res = await http.get(Uri.parse('http://192.168.1.7:3000/api/user/tickets/${user.id}'));
                        if (res.statusCode == 200) {
                          final List<dynamic> tickets = json.decode(res.body);
                          if (tickets.isNotEmpty) {
                            try {
                              latestTicket = tickets.firstWhere((t) => t['BookingID'].toString() == orderId.toString());
                            } catch (e) {
                              latestTicket = tickets.first; 
                            }
                          }
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
        )
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
            // 🚀 TRỊ BỆNH 2: KHÔNG TỰ ĐỘNG HỦY ĐƠN NẾU KHÁCH ĐÃ VĂNG QUA ZALOPAY / MOMO!
            if (widget.bookingId != null && !_openedExternalApp) {
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