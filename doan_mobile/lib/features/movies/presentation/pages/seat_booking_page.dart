import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cart_page.dart';
import 'food_selection_screen.dart';
import 'user_manager.dart';

class SeatBookingPage extends StatefulWidget {
  final Movie movie;
  final String cinemaName; 
  final int roomCapacity; 
  final String selectedDate;
  final String selectedTime;
  final int showtimeId; 
  final String roomName;
  final int basePrice;
  final String movieFormat;

  const SeatBookingPage({
    super.key, 
    required this.movie,
    required this.cinemaName, 
    required this.roomCapacity,
    required this.selectedDate,
    required this.selectedTime,
    required this.showtimeId,
    required this.roomName,
    required this.basePrice,
    required this.movieFormat,
  });

  @override
  State<SeatBookingPage> createState() => _SeatBookingPageState();
}

class _SeatBookingPageState extends State<SeatBookingPage> with TickerProviderStateMixin {
  final String baseUrl = 'http://192.168.1.2:3000/api';

  final Color navyBlue = Colors.blue.shade900;
  final Color primaryBlue = Colors.blue.shade700; 
  final Color highlightColor = Colors.pink; 
  
  final Color colorBooked = Colors.grey.shade400;     
  late final Color colorSelected = primaryBlue;       
  final Color colorRegular = const Color(0xFFD6C4F3);  
  final Color colorVIP = const Color(0xFFFFD1D1);      
  final Color colorCouple = const Color(0xFFFCE4EC);   
  final Color colorCoupleText = const Color(0xFFD81B60); 

  late Map<int, int> _seatPrices;
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  late Future<void> _fetchSeatsFuture;
  
  List<String> _bookedSeats = []; 
  Map<String, dynamic> _apiSeatsData = {}; 

  final TransformationController _transformController = TransformationController();
  bool _showMiniMap = false;
  Timer? _miniMapTimer;

  final double contentWidth = 1400.0;
  final double contentHeight = 1000.0;
  final double miniScale = 0.09; 

  late String _currentDate;
  late String _currentTime;
  late int _currentCapacity;

  final GlobalKey _cartKey = GlobalKey(); 
  OverlayEntry? _overlayEntry;

  late List<List<int>> _cachedLayout;
  Widget? _cachedMiniMapGrid;
  
  @override
  void initState() {
    super.initState();
    _seatPrices = {
      1: widget.basePrice, // Ghế thường = Giá gốc
      2: widget.basePrice + 20000, // Ghế VIP = Giá gốc + 20k
      3: (widget.basePrice * 2) + 30000, // Sweetbox = 2 ghế gốc + 30k phụ thu
    };
    _currentDate = widget.selectedDate;
    _currentTime = widget.selectedTime;
    _currentCapacity = widget.roomCapacity;

    _cachedLayout = _generateLayout();
    _autoCenterMap(); 
    
    _fetchSeatsFuture = _fetchRealSeats(); 
  }
  @override
  void didUpdateWidget(covariant SeatBookingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.basePrice != widget.basePrice) {
      setState(() {
        _seatPrices = {
          1: widget.basePrice,
          2: widget.basePrice + 20000,
          3: (widget.basePrice * 2) + 30000,
        };
      });
    }
  }

  Future<void> _sendHoldRequest(int realSeatId, bool isHolding) async {
    final url = isHolding ? '$baseUrl/seats/hold' : '$baseUrl/seats/release';
    try {
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': UserManager.instance.currentUser?.id ?? 0, // ID user đăng nhập
          'showtimeId': widget.showtimeId,
          'seatId': realSeatId
        })
      );
    } catch (e) {
      debugPrint("Lỗi call API giữ ghế: $e");
    }
  }

  String _extractTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "12:00";
    try {
      DateTime parsedTime = DateTime.parse(dateTimeStr);
      if (dateTimeStr.endsWith('Z') || dateTimeStr.contains('T')) {
        if (parsedTime.isUtc) {
          parsedTime = parsedTime.add(const Duration(hours: 7));
        } else {
          parsedTime = parsedTime.toUtc().add(const Duration(hours: 7));
        }
      }
      return "${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      try {
        if (dateTimeStr.contains('T')) return dateTimeStr.split('T')[1].substring(0, 5); 
        if (dateTimeStr.contains(' ')) return dateTimeStr.split(' ')[1].substring(0, 5); 
      } catch (_) {}
      return "12:00";
    }
  }

  String _calculateEndTime(String startTime) {
    try {
      final parts = startTime.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]) + (widget.movie.duration ?? 120); 
      h += m ~/ 60;
      m = m % 60;
      if (h >= 24) h -= 24; 
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }

  Future<void> _fetchRealSeats() async {
    try {
      final url = '$baseUrl/seats/${widget.showtimeId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var seat in data) {
          String seatNum = seat['SeatNumber'];
          // ✅ LƯU TOÀN BỘ OBJECT GHẾ (bao gồm cả SeatID thực tế) VÀO API SEATS DATA
          _apiSeatsData[seatNum] = seat;
          if (seat['Status'] == 'Occupied' || seat['status'] == 'Occupied') {
             _bookedSeats.add(seatNum);
          }
        }
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Không thể kết nối đến máy chủ');
    }
  }

  void _autoCenterMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      double dx = (size.width - contentWidth) / 2;
      double dy = (size.height - contentHeight) / 6; 
      _transformController.value = Matrix4.identity()..translate(dx, dy);
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _miniMapTimer?.cancel();
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    setState(() => _showMiniMap = true);
    _miniMapTimer?.cancel();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _miniMapTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showMiniMap = false);
    });
  }

  List<List<int>> _generateLayout() {
    String name = widget.cinemaName.toLowerCase();
    int targetSeats = _currentCapacity; 
    int cols = 14;
    if (name.contains('lotte') || name.contains('galaxy') || name.contains('cinestar')) cols = 16;
    List<List<int>> layout = [];
    int currentSeats = 0;

    for (int r = 0; r < 30; r++) { 
      if (currentSeats >= targetSeats) break; 
      List<int> row = [];
      int rowSeatType = 1; 
      if (currentSeats > targetSeats * 0.4) rowSeatType = 2; 
      if (currentSeats > targetSeats * 0.85) rowSeatType = 3; 

      for (int c = 0; c < cols; c++) {
        bool isAisle = false;
        if (name.contains('lotte') && (c == cols~/2 - 1 || c == cols~/2)) isAisle = true;
        if (name.contains('cinestar') && (c == 2 || c == cols - 3)) isAisle = true;
        if (name.contains('mega') && (c == 0 || c == 1)) isAisle = true;
        if (name.contains('bhd') && r > 6 && (c == 0 || c == cols - 1)) isAisle = true;
        if (name.contains('galaxy') && r > 6 && c > cols - 4) isAisle = true;

        if (isAisle) {
          row.add(0); 
        } else {
          if (rowSeatType == 3) { 
            bool nextIsAisle = false;
            int nextC = c + 1;
            if (name.contains('lotte') && (nextC == cols~/2 - 1 || nextC == cols~/2)) nextIsAisle = true;
            if (name.contains('cinestar') && (nextC == 2 || nextC == cols - 3)) nextIsAisle = true;
            if (name.contains('mega') && (nextC == 0 || nextC == 1)) nextIsAisle = true;
            if (name.contains('bhd') && r > 6 && (nextC == 0 || nextC == cols - 1)) nextIsAisle = true;
            if (name.contains('galaxy') && r > 6 && nextC > cols - 4) nextIsAisle = true;

            if (currentSeats + 2 <= targetSeats && nextC < cols && !nextIsAisle) {
              row.add(3); 
              row.add(-1); 
              currentSeats += 2;
              c++; 
            } else {
              row.add(0); 
            }
          } else {
            row.add(rowSeatType); 
            currentSeats += 1;
          }
        }
      }
      layout.add(row);
    }
    return layout;
  }

 // =========================================================================
  // ✅ XỬ LÝ CHẠM GHẾ (TÍCH HỢP CHẶN LỖI TRỐNG 1 GHẾ NGAY LẬP TỨC)
  // =========================================================================
  void _toggleSeat(String seatId, int seatType, GlobalKey seatKey) {
    if (seatType == 3) {
      List<String> parts = seatId.split('-');
      if (_bookedSeats.contains(parts[0]) || _bookedSeats.contains(parts[1])) return;
    } else {
      if (_bookedSeats.contains(seatId)) return; 
    }
    
    final manager = CartManager.instance;
    List<Map<String, dynamic>> currentSeats = List<Map<String, dynamic>>.from(
      manager.getSeatsForShowtime(
        widget.movie.id.toString(), 
        widget.cinemaName, 
        _formatDateToDDMMYYYY(_currentDate), 
        _currentTime
      ) ?? []
    );

    int existingIndex = currentSeats.indexWhere((s) => s['name'] == seatId);
    bool isAdding = existingIndex == -1;

    int realSeatId = 0;
    int price = _seatPrices[seatType] ?? 0;

    if (seatType == 3) {
      List<String> parts = seatId.split('-');
      realSeatId = _apiSeatsData[parts[0]]?['SeatID'] ?? _apiSeatsData[parts[0]]?['id'] ?? 0;
    } else {
      realSeatId = _apiSeatsData[seatId]?['SeatID'] ?? _apiSeatsData[seatId]?['id'] ?? 0;
    }

    // ----------------------------------------------------
    // 🛑 BƯỚC 1: TẠO MỘT BẢN NHÁP ĐỂ KIỂM TRA TRƯỚC
    // ----------------------------------------------------
    List<Map<String, dynamic>> simulatedSeats = List.from(currentSeats);
    
    if (isAdding) {
      if (simulatedSeats.length >= 8) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Bạn chỉ được chọn tối đa 8 ghế!'), backgroundColor: navyBlue));
        return;
      }
      simulatedSeats.add({'id': realSeatId, 'name': seatId, 'price': price, 'type': seatType});
    } else {
      simulatedSeats.removeAt(existingIndex);
    }

    // ----------------------------------------------------
    // 🛑 BƯỚC 2: GỌI THUẬT TOÁN QUÉT BẢN NHÁP
    // ----------------------------------------------------
    if (!_isValidSeatSelection(simulatedSeats)) {
      // NẾU VI PHẠM LUẬT -> BẬT CẢNH BÁO VÀ CHẶN LUÔN, KHÔNG ĐỔI MÀU GHẾ
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rất tiếc! Không được để trống 1 ghế ở giữa hoặc sát vách.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return; // Dừng chạy hàm tại đây
    }

    // ----------------------------------------------------
    // ✅ BƯỚC 3: NẾU HỢP LỆ THÌ MỚI ÁP DỤNG THẬT
    // ----------------------------------------------------
    if (isAdding) {
      currentSeats.add({'id': realSeatId, 'name': seatId, 'price': price, 'type': seatType}); 
      _runAddToCartAnimation(seatKey);
      _sendHoldRequest(realSeatId, true);
    } else {
      currentSeats.removeAt(existingIndex); 
      _sendHoldRequest(realSeatId, false);
    }

    int total = 0;
    for (var seat in currentSeats) {
      total += (seat['price'] as int? ?? 0);
    }

    manager.updateCart(
      movieObj: widget.movie,
      cinema: widget.cinemaName,
      date: _formatDateToDDMMYYYY(_currentDate),
      time: _currentTime,
      seats: currentSeats,
      price: total,
    );
  }

  void _runAddToCartAnimation(GlobalKey seatKey) {
    final RenderBox? seatBox = seatKey.currentContext?.findRenderObject() as RenderBox?;
    if (seatBox == null) return;
    final Offset startOffset = seatBox.localToGlobal(Offset.zero);

    final RenderBox? cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartBox == null) return;
    final Offset endOffset = cartBox.localToGlobal(Offset.zero);

    AnimationController animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    final Animation<double> moveCurve = CurvedAnimation(parent: animController, curve: Curves.easeInOutCubic);
    final Animation<double> sizeCurve = Tween<double>(begin: 1.0, end: 0.1).animate(animController);

    OverlayEntry? currentEntry;

    currentEntry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: animController,
          builder: (context, child) {
            double x = startOffset.dx + (endOffset.dx - startOffset.dx) * moveCurve.value;
            double y = startOffset.dy + (endOffset.dy - startOffset.dy) * moveCurve.value;
            double bounce = sin(moveCurve.value * pi) * -100; 

            return Positioned(
              left: x,
              top: y + bounce,
              child: Transform.scale(
                scale: sizeCurve.value,
                child: Container(
                  width: 30, height: 20,
                  decoration: BoxDecoration(
                    color: colorSelected, 
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(currentEntry);

    animController.forward().then((_) {
      currentEntry?.remove(); 
      animController.dispose();
    });
  }

  String _formatDateToDDMMYYYY(String input) {
    if (input.contains('/202')) return input; 
    RegExp regExp = RegExp(r'(\d{1,2})\s*Thg\s*(\d{1,2})');
    var match = regExp.firstMatch(input);
    if (match != null) {
      String dd = match.group(1)!.padLeft(2, '0');
      String mm = match.group(2)!.padLeft(2, '0');
      int year = DateTime.now().year;
      return "$dd/$mm/$year";
    }
    return input;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white, 
          appBar: _buildAppBar(),
          body: FutureBuilder<void>(
            future: _fetchSeatsFuture, 
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: primaryBlue));
              }
              if (snapshot.hasError) {
                return const Center(child: Text("Lỗi không thể tải sơ đồ ghế", style: TextStyle(color: Colors.red)));
              }
              return Column(
                children: [
                  _buildScreenCurveFixed(), 
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            InteractiveViewer(
                              transformationController: _transformController,
                              constrained: false, 
                              minScale: 0.3, maxScale: 3.5, 
                              boundaryMargin: const EdgeInsets.all(800), 
                              panEnabled: true, scaleEnabled: true,
                              onInteractionStart: _onInteractionStart,
                              onInteractionEnd: _onInteractionEnd,
                              child: RepaintBoundary(
                                child: SizedBox(
                                  width: contentWidth, height: contentHeight,
                                  child: Center(child: _buildDynamicSeatGrid()),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0), 
                                child: AnimatedOpacity(
                                  opacity: _showMiniMap ? 1.0 : 0.0, 
                                  duration: const Duration(milliseconds: 300),
                                  child: _showMiniMap ? _buildMiniMap(constraints.maxWidth, constraints.maxHeight) : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                  _buildSeatLegendAndDetails(),
                ],
              );
            }
          ),
          bottomNavigationBar: _buildBottomCheckoutBar(), 
        );
      }
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(widget.cinemaName.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
            ),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade100, Colors.blue.shade50])),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: _cartKey,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _buildCartIconWithBadge(), 
                ),
              ),
              Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
              InkWell(
                onTap: () => Navigator.popUntil(context, (route) => route.isFirst), 
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Icon(Icons.home_outlined, color: navyBlue, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartIconWithBadge() {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        int count = CartManager.instance.totalSeatsCount + CartManager.instance.totalFoodsCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.shopping_cart_outlined, color: navyBlue, size: 20),
            if (count > 0)
              Positioned(
                top: -6, right: -6, 
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(
                    count > 9 ? '9+' : count.toString(), 
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1)
                  ),
                ),
              ),
          ],
        );
      }
    );
  }

  Widget _buildScreenCurveFixed() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 20, bottom: 5),
      child: Column(
        children: [
          SizedBox(width: 250, height: 25, child: CustomPaint(painter: ScreenPainter(color: primaryBlue))),
          const SizedBox(height: 5),
          const Text("MÀN HÌNH", style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDynamicSeatGrid() {
    List<List<int>> layout = _cachedLayout;
    List<Widget> rows = [];
    for (int r = 0; r < layout.length; r++) {
      String rowLabel = String.fromCharCode(65 + r); 
      List<Widget> rowChildren = [];
      int seatCounter = 1; 

      for (int c = 0; c < layout[r].length; c++) {
        int seatType = layout[r][c];
        if (seatType == -1) continue; 
        
        if (seatType == 0) {
          rowChildren.add(const SizedBox(width: 38)); 
        } 
        else if (seatType == 3) {
          String seatId1 = '$rowLabel$seatCounter';
          seatCounter++;
          String seatId2 = '$rowLabel$seatCounter';
          seatCounter++;
          String combinedId = '$seatId1-$seatId2';
          rowChildren.add(_buildSeatItem(combinedId, seatType));
        } else {
          String seatId = '$rowLabel$seatCounter';
          seatCounter++;
          rowChildren.add(_buildSeatItem(seatId, seatType));
        }
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisSize: MainAxisSize.min, children: rowChildren)));
    }
    return Column(children: rows);
  }

  Widget _buildSeatItem(String seatId, int seatType) {
    bool isBooked = false;
    if (seatType == 3) {
      List<String> parts = seatId.split('-');
      isBooked = _bookedSeats.contains(parts[0]) || _bookedSeats.contains(parts[1]);
    } else {
      isBooked = _bookedSeats.contains(seatId);
    }
    
    // ✅ KIỂM TRA ĐỔI MÀU BẰNG LIST<MAP> CHUẨN
    List<Map<String, dynamic>> currentSeats = List<Map<String, dynamic>>.from(
      CartManager.instance.getSeatsForShowtime(
        widget.movie.id.toString(), 
        widget.cinemaName, 
        _formatDateToDDMMYYYY(_currentDate), 
        _currentTime
      ) ?? []
    );
    bool isSelected = currentSeats.any((s) => s['name'] == seatId);

    Color seatBgColor;
    Color textColor = Colors.black87;

    if (isBooked) {
      seatBgColor = colorBooked; 
      textColor = Colors.white;
    } else if (isSelected) {
      seatBgColor = colorSelected; 
      textColor = Colors.white;
    } else {
      if (seatType == 1) { seatBgColor = colorRegular; }
      else if (seatType == 2) { seatBgColor = colorVIP; }
      else { seatBgColor = colorCouple; textColor = colorCoupleText; }
    }

    double seatWidth = seatType == 3 ? 68.0 : 30.0;
    final GlobalKey seatKey = GlobalKey();

    Widget content;
    if (seatType == 3) {
      List<String> parts = seatId.split('-');
      content = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(parts[0], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
          Text(parts[1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
        ],
      );
    } else {
      content = Text(seatId, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor));
    }

    return Container(
      margin: const EdgeInsets.only(right: 8), 
      child: GestureDetector(
        onTap: () => _toggleSeat(seatId, seatType, seatKey), 
        child: Container(
          key: seatKey,
          width: seatWidth, height: 30,
          decoration: BoxDecoration(
            color: seatBgColor, 
            borderRadius: BorderRadius.circular(6),
            border: (seatType == 3 && !isBooked && !isSelected) ? Border.all(color: const Color(0xFFF8BBD0), width: 1) : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  Widget _buildMiniMap(double viewportWidth, double viewportHeight) {
    _cachedMiniMapGrid ??= FittedBox(fit: BoxFit.contain, child: IgnorePointer(child: _buildDynamicSeatGrid()));

    return AnimatedBuilder(
      animation: _transformController, 
      builder: (context, child) {
        Matrix4 matrix = _transformController.value;
        double scale = matrix.getMaxScaleOnAxis();
        double tx = matrix.getTranslation().x;
        double ty = matrix.getTranslation().y;
        double viewW = (viewportWidth / scale) * miniScale;
        double viewH = (viewportHeight / scale) * miniScale;
        double mapLeft = (-tx / scale) * miniScale;
        double mapTop = (-ty / scale) * miniScale;

        return Container(
          width: contentWidth * miniScale, height: contentHeight * miniScale,
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200, width: 1.5), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Center(child: _cachedMiniMapGrid),
                Positioned(left: mapLeft, top: mapTop, width: viewW, height: viewH, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 2.0), color: Colors.red.withOpacity(0.15)))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeatLegendAndDetails() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildLegendItem("Đã đặt", colorBooked),
                const SizedBox(width: 8),
                _buildLegendItem("Ghế bạn chọn", colorSelected),
                const SizedBox(width: 8),
                _buildLegendItem("Ghế thường", colorRegular),
                const SizedBox(width: 8),
                _buildLegendItem("Ghế VIP", colorVIP),
                const SizedBox(width: 8),
                _buildLegendItem("Ghế Sweetbox", colorCouple), 
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showSeatInfoBottomSheet,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: Colors.black87, fontSize: 12),
                children: [
                  TextSpan(text: "Xem chi tiết", style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  TextSpan(text: " hình ảnh và thông tin ghế"),
                ]
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color fillColor) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.grey.shade300, width: 0.5))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  Widget _buildBottomCheckoutBar() {
    final manager = CartManager.instance;
    
    // ✅ TÍNH TIỀN VÀ TÊN GHẾ DỰA TRÊN LIST<MAP> CHUẨN
    List<Map<String, dynamic>> currentSeats = List<Map<String, dynamic>>.from(
      manager.getSeatsForShowtime(
        widget.movie.id.toString(), 
        widget.cinemaName, 
        _formatDateToDDMMYYYY(_currentDate), 
        _currentTime
      ) ?? []
    );

    int currentTotalPrice = 0;
    List<String> seatNames = [];

    for (var seat in currentSeats) {
      currentTotalPrice += (seat['price'] as int? ?? 0);
      seatNames.add(seat['name'].toString());
    }
    seatNames.sort(); // Sắp xếp ghế theo thứ tự ABC cho đẹp

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(widget.movie.title.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyBlue)),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showShowtimeBottomSheet,
                child: Text("Đổi suất", style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text("$_currentTime | ${_currentDate} | ${widget.movieFormat}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          Divider(height: 20, color: Colors.grey.shade200),
          
          if (currentSeats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: "Ghế: ", style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        children: [TextSpan(text: seatNames.join(', '), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyBlue))]
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text("Giữ ghế: ${(manager.holdSeconds ~/ 60).toString().padLeft(2, '0')}:${(manager.holdSeconds % 60).toString().padLeft(2, '0')}", style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Tạm tính", style: TextStyle(color: navyBlue.withOpacity(0.6), fontSize: 12)), 
                    Text(currentTotalPrice > 0 ? formatter.format(currentTotalPrice) : "0 đ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
              SizedBox(
                  width: 150, height: 45,
                  child: ElevatedButton(
                    onPressed: currentSeats.isEmpty ? null : () {
                      // ==========================================
                      // ✅ KIỂM TRA QUY TẮC "ĐỂ TRỐNG 1 GHẾ" Ở ĐÂY
                      // ==========================================
                      bool isValid = _isValidSeatSelection(currentSeats);
                      
                      if (!isValid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Rất tiếc! Bạn không thể để trống 1 ghế bên cạnh.'),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        return; // Chặn lại, KHÔNG cho nhảy sang trang Bắp Nước
                      }

                      // NẾU HỢP LỆ THÌ CHO ĐI TIẾP
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FoodSelectionScreen(
                            movie: widget.movie,
                            cinemaName: widget.cinemaName,
                            selectedDate: _formatDateToDDMMYYYY(_currentDate),
                            selectedTime: _currentTime,
                            roomName: widget.roomName,
                            showtimeId: widget.showtimeId,
                          ),
                        ),
                      );
                    },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900, 
                    disabledBackgroundColor: Colors.grey.shade300, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                    elevation: 0
                  ),
                  child: const Text("Tiếp tục", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _fetchAllShowtimesOfDay() async {
    try {
      String rawDate = _currentDate;
      if (rawDate.contains(', ')) {
        rawDate = rawDate.split(', ')[1]; 
      }
      List<String> parts = rawDate.split('/');
      String formattedDate = "";
      if (parts.length >= 2) {
          int year = parts.length == 3 ? int.parse(parts[2]) : DateTime.now().year;
          formattedDate = "$year-${parts[1]}-${parts[0]}";
      }

      final url = '$baseUrl/showtimes-all?movie_id=${widget.movie.id}&date=$formattedDate';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("❌ LỖI API ĐỔI SUẤT: Code ${response.statusCode} - Lỗi: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Lỗi mạng: $e");
    }
    return [];
  }

  void _showShowtimeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, 
                height: 5, 
                decoration: BoxDecoration(
                  color: Colors.grey.shade300, 
                  borderRadius: BorderRadius.circular(10)
                )
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text("Đổi suất chiếu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.black12),
              
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _fetchAllShowtimesOfDay(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: primaryBlue));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("Không có suất chiếu nào khác trong ngày."));
                    }

                    final allShowtimes = snapshot.data!;
                    
                    final currentShowIndex = allShowtimes.indexWhere((s) => 
                        (int.tryParse(s['ShowtimeID']?.toString() ?? '0') ?? 0) == widget.showtimeId);
                        
                    dynamic currentShow;
                    List<dynamic> otherShowtimes = List.from(allShowtimes);
                    
                    if (currentShowIndex != -1) {
                      currentShow = allShowtimes[currentShowIndex];
                      otherShowtimes.removeAt(currentShowIndex); 
                    }

                    return Column(
                      children: [
                        if (currentShow != null)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildShowtimeOption(currentShow, isCurrent: true),
                          ),

                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: otherShowtimes.length,
                            itemBuilder: (context, index) {
                              return _buildShowtimeOption(otherShowtimes[index], isCurrent: false);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShowtimeOption(dynamic show, {required bool isCurrent}) {
    String cinemaName = show['cinema_name'] ?? widget.cinemaName;
    String startTime = _extractTime(show['StartTime']);
    String endTime = show['EndTime'] != null ? _extractTime(show['EndTime'].toString()) : _calculateEndTime(startTime);
    int showId = int.tryParse(show['ShowtimeID']?.toString() ?? '0') ?? 0;
    
    String roomName = show['Name'] ?? '';

    String rawPrice = show['Price']?.toString() ?? show['price']?.toString() ?? '85000';
    int priceFromDB = double.tryParse(rawPrice)?.toInt() ?? 85000;

    // ========================================================
    // ✅ BƯỚC 3 (ĐÃ SỬA): LẤY GIÁ TIỀN TỪ DATABASE API TRẢ VỀ
    // ========================================================
    String movieFormat = show['movie_format']?.toString() ?? '2D Phụ đề';

    String last5Chars = roomName.length >= 5
    ? roomName.substring(roomName.length - 5)
    : roomName;

    Color textColor = isCurrent ? primaryBlue : Colors.black87;

    return GestureDetector(
      onTap: isCurrent ? null : () {
        Navigator.pop(context); 
        
        ScaffoldMessenger.of(context).clearSnackBars(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                children: [
                  const TextSpan(text: 'Đã đổi sang suất '),
                  TextSpan(text: startTime, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  const TextSpan(text: ' tại '),
                  TextSpan(text: cinemaName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                ],
              ),
            ),
            backgroundColor: primaryBlue,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SeatBookingPage(
          movie: widget.movie,
          cinemaName: cinemaName,
          roomCapacity: int.tryParse(show['TotalSeats']?.toString() ?? '150') ?? 150,
          selectedDate: widget.selectedDate,
          selectedTime: "$startTime - $endTime",
          showtimeId: showId,
          roomName: roomName, 
          basePrice: priceFromDB, 
          movieFormat: movieFormat,
        )));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isCurrent ? 0 : 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent ? primaryBlue.withOpacity(0.05) : Colors.white,
          border: Border.all(
            color: isCurrent ? primaryBlue : Colors.grey.shade300, 
            width: isCurrent ? 1.5 : 1
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cinemaName, style: TextStyle(fontWeight: FontWeight.normal, fontSize: 15, color: textColor)),
            const SizedBox(height: 6),
            
            Text("$startTime~$endTime", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(
                  "$movieFormat${last5Chars.isNotEmpty ? ' • $last5Chars' : ''}" , // Lấy định dạng phim (3D, IMAX) hiển thị luôn
                  style: TextStyle(fontSize: 13, color: isCurrent ? primaryBlue.withOpacity(0.8) : Colors.grey.shade600)
                ),
                
                if (!isCurrent)
                  Text("Chọn ngay", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  void _showSeatInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text("Thông tin hình ảnh ghế", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
              const Divider(height: 30),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildSeatTypeInfo("Ghế Thường", colorRegular, formatter.format(_seatPrices[1]), "Ghế nệm tiêu chuẩn, ngả lưng thoải mái.", "assets/seat_regular.png"),
                    const SizedBox(height: 16),
                    _buildSeatTypeInfo("Ghế VIP", colorVIP, formatter.format(_seatPrices[2]), "Ghế bọc da cao cấp, vị trí trung tâm, góc nhìn đẹp nhất rạp.", "assets/seat_vip.png"),
                    const SizedBox(height: 16),
                    _buildSeatTypeInfo("Ghế Sweetbox", colorCouple, formatter.format(_seatPrices[3]), "Ghế thiết kế dạng hộp riêng tư không vách ngăn cho 2 người.", "assets/seat_couple.png"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeatTypeInfo(String title, Color color, String price, String desc, String imgPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.event_seat, color: color.withOpacity(0.8), size: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(price, style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ========================================================
  // ✅ THUẬT TOÁN KIỂM TRA LỖI "ĐỂ TRỐNG 1 GHẾ" (CÔ CÔ ĐƠN)
  // (Đã Fix 100% lỗi gạch đỏ của Dart Analyzer)
  // ========================================================
  bool _isValidSeatSelection(List<Map<String, dynamic>> currentSeats) {
    if (currentSeats.isEmpty) return true;

    List<String> selectedSeatIds = currentSeats.map((s) => s['name'].toString()).toList();

    // 1. CHỈ QUÉT DỰA TRÊN SƠ ĐỒ THỰC TẾ ĐANG HIỂN THỊ TRÊN MÀN HÌNH (_cachedLayout)
    for (int r = 0; r < _cachedLayout.length; r++) {
      String rowLabel = String.fromCharCode(65 + r); // A, B, C...
      int seatCounter = 1; 

      List<String> renderedSeatNames = [];

      // Lấy danh sách tên ghế THỰC SỰ có vẽ trên màn hình
      for (int c = 0; c < _cachedLayout[r].length; c++) {
        int seatType = _cachedLayout[r][c];
        if (seatType == -1 || seatType == 0) continue; // Bỏ qua lối đi
        
        if (seatType == 3) { // Ghế Sweetbox (chiếm 2 số)
          renderedSeatNames.add('$rowLabel$seatCounter'); seatCounter++;
          renderedSeatNames.add('$rowLabel$seatCounter'); seatCounter++;
        } else { // Ghế thường/VIP
          renderedSeatNames.add('$rowLabel$seatCounter'); seatCounter++;
        }
      }

      // 2. Kiểm tra luật trên hàng này (Chỉ duyệt những ghế nhìn thấy được)
      int consecutiveEmptySeats = 0;
      
      for (String seatNum in renderedSeatNames) {
        var seatData = _apiSeatsData[seatNum];
        
        // Kiểm tra ghế có bị khóa không (Đã bán / Đang giữ)
        bool isBookedOrHold = false;
        if (seatData != null) {
           isBookedOrHold = seatData['Status'] == 'Occupied' || seatData['status'] == 'Occupied' || 
                            seatData['Status'] == 'holding' || seatData['status'] == 'holding';
        }
        
        // Kiểm tra xem ghế này có nằm trong danh sách khách ĐANG CHỌN không
        bool isSelected = selectedSeatIds.any((id) => id.split('-').contains(seatNum));
        
        bool isSolidBlock = isBookedOrHold || isSelected;

        if (!isSolidBlock) {
          consecutiveEmptySeats++; // Đếm ghế trống
        } else {
          // Gặp khối đóng -> Nếu khoảng trống ngay trước đó = 1 thì BÁO LỖI
          if (consecutiveEmptySeats == 1) return false;
          consecutiveEmptySeats = 0; // Reset đếm lại
        }
      }
      
      // Kiểm tra nốt khoảng trống ở rìa tường cuối cùng của hàng
      if (consecutiveEmptySeats == 1) return false;
    }
    
    return true; // Hoàn toàn hợp lệ!
  }
}




class ScreenPainter extends CustomPainter {
  final Color color;
  ScreenPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, -15, size.width, size.height);
    canvas.drawShadow(path, color, 15, true);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
