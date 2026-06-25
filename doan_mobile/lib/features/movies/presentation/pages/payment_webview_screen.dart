import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../../domain/entities/movie.dart';
import 'cart_page.dart';
import 'user_manager.dart';
import 'ticket_result_screen.dart'; 

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl; 
  final Movie? movie;
  final String date;
  final String time;
  final String cinemaName; 

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.movie,
    required this.date,
    required this.time,
    required this.cinemaName, 
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      // =========================================================================
      // ✅ TUYỆT CHIÊU BẤT TỬ: Ép User-Agent sang MacOS/Chrome để MoMo hiện mã QR
      // =========================================================================
      ..setUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false); 
          },
          onNavigationRequest: (NavigationRequest request) {
            
            // Nếu có app cài sẵn bấm mở app thì vẫn hỗ trợ mở
            if (request.url.startsWith('momo://')) {
              _launchMoMoApp(request.url);
              return NavigationDecision.prevent; 
            }

            // =========================================================================
            // XỬ LÝ NHẬN KẾT QUẢ TRẢ VỀ KHI QUÉT QR THÀNH CÔNG
            // =========================================================================
            Uri uri = Uri.parse(request.url);
            
            if (request.url.contains('192.168.1.2:3000') || request.url.contains('vnp_ResponseCode') || request.url.contains('resultCode')) { 
              
              bool isSuccess = false;
              String? orderId;
              int amount = 0;
              
              // NẾU LÀ VNPAY
              if (uri.queryParameters.containsKey('vnp_ResponseCode')) {
                String? vnpResponseCode = uri.queryParameters['vnp_ResponseCode'];
                orderId = uri.queryParameters['vnp_TxnRef']; 
                amount = (int.parse(uri.queryParameters['vnp_Amount'] ?? '0') / 100).round();
                if (vnpResponseCode == '00') isSuccess = true;
              } 
              // NẾU LÀ MOMO
              else if (uri.queryParameters.containsKey('resultCode')) {
                String? momoResultCode = uri.queryParameters['resultCode'];
                String? rawOrderId = uri.queryParameters['orderId'];
                
                if (rawOrderId != null && rawOrderId.startsWith("MOMO_")) {
                  orderId = rawOrderId.split('_')[1]; 
                } else {
                  orderId = rawOrderId;
                }

                amount = int.parse(uri.queryParameters['amount'] ?? '0');
                if (momoResultCode == '0' || momoResultCode == '9000') isSuccess = true;
              }

              if (isSuccess && orderId != null) {
                String orderInfoMsg = widget.movie == null 
                    ? 'Thanh toan don bap nuoc' 
                    : 'Thanh toan ve phim ${widget.movie!.title}';

                http.post(
                  Uri.parse('http://192.168.1.2:3000/api/bookings/confirm_payment'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'bookingId': orderId,
                    'amount': amount, 
                    'transactionNo': uri.queryParameters['vnp_TransactionNo'] ?? uri.queryParameters['transId'] ?? '',
                    'bankCode': uri.queryParameters['vnp_BankCode'] ?? 'MOMO',
                    'orderInfo': orderInfoMsg
                  })
                ).then((response) async {
                  if (response.statusCode == 200) {
                    CartManager.instance.clearCart(); 

                    Map<String, dynamic>? latestTicket;
                    final user = UserManager.instance.currentUser;
                    if (user != null) {
                      try {
                        final res = await http.get(Uri.parse('http://192.168.1.2:3000/api/user/tickets/${user.id}'));
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
                  }
                });

              } 
              else if (orderId != null) {
                http.post(
                  Uri.parse('http://192.168.1.2:3000/api/bookings/cancel_payment'),
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

  Future<void> _launchMoMoApp(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Lỗi mở app: $e");
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
          onPressed: () => Navigator.pop(context),
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