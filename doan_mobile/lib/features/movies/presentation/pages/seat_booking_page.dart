import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
// ✅ THƯ VIỆN SOCKET.IO ĐÂY RỒI
import 'package:socket_io_client/socket_io_client.dart' as IO; 
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
  final String baseUrl = 'http://10.173.120.41:3000/api';
  // ✅ Tách domain riêng cho Socket
  final String socketUrl = 'http://10.173.120.41:3000'; 

  final Color navyBlue = Colors.blue.shade900;
  final Color primaryBlue = Colors.blue.shade700; 
  final Color highlightColor = Colors.pink; 
  
  final Color colorBooked = Colors.grey.shade400;     
  late final Color colorSelected = primaryBlue;       
  final Color colorRegular = const Color(0xFFD6C4F3);  
  final Color colorVIP = const Color(0xFFFFD1D1);     
  final Color colorCouple = const Color(0xFFFCE4EC);   
  final Color colorCoupleText = const Color(0xFFD81B60); 
  
  final Color colorHoldingByOther = Colors.orange.shade700;
  
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  late Future<void> _fetchSeatsFuture;
  List<String> _holdingSeats = [];
  List<String> _bookedSeats = []; 
  Map<String, dynamic> _apiSeatsData = {}; 
  Map<String, int>? _centerZone;

  final TransformationController _transformController = TransformationController();
  final ValueNotifier<bool> _showMiniMap = ValueNotifier<bool>(false);
  Timer? _miniMapTimer;

  final double contentWidth = 1400.0;
  final double contentHeight = 1000.0;
  final double miniScale = 0.09; 

  int _maxSeatsPerBooking = 8;

  late String _currentDate;
  late String _currentTime;
  late int _currentCapacity;

  final GlobalKey _cartKey = GlobalKey(); 
  OverlayEntry? _overlayEntry;

  // Khởi tạo một Map để lưu trữ Key của các ghế vĩnh viễn, không tạo lại mỗi lần build
  final Map<String, GlobalKey> _seatKeys = {};
  final Map<String, Timer> _socketDebounceTimers = {};

  late List<List<int>> _cachedLayout;
  Widget? _cachedMiniMapGrid;

  // ✅ KHAI BÁO BIẾN SOCKET
  IO.Socket? socket;
  List<Map<String, dynamic>> _lastKnownCartSeats = []; // Lưu trí nhớ của mật thám
  bool _isModifyingFromSeatPage = false; // Cờ kiểm tra xem có phải đang thao tác ở trang chọn ghế không
  List<dynamic> _seatTypesFromAPI = [];
  List<dynamic> _ticketPricesFromAPI = []; // ✅ LƯU MA TRẬN GIÁ
  
  // ========================================================
  // ✅ TỪ ĐIỂN CẤU HÌNH GHẾ (CHỐNG LỖI MẤT NĂM VÀ BẮT CHỮ THỨ 7)
  // ========================================================
  Map<int, Map<String, dynamic>> _getSeatConfig() {
    if (_seatTypesFromAPI.isEmpty) {
      return { 1: { 'name': 'Đang tải...', 'color': colorRegular, 'textColor': Colors.black87, 'price': widget.basePrice, 'desc': 'Đang đồng bộ dữ liệu...', 'img': 'assets/seat_regular.png' } };
    }

    // 1. XÁC ĐỊNH ĐỊNH DẠNG PHIM CỐT LÕI (2D, 3D, 4DX, IMAX)
    String rawFormat = widget.movieFormat.toUpperCase();
    String currentShowType = '2D'; // Mặc định luôn là 2D
    
    // Nếu suất chiếu chứa các từ khóa đặc biệt thì mới gán lại
    if (rawFormat.contains('IMAX')) {
      currentShowType = 'IMAX';
    } else if (rawFormat.contains('4DX')) {
      currentShowType = '4DX';
    } else if (rawFormat.contains('3D')) {
      currentShowType = '3D';
    }

    // 2. XÁC ĐỊNH LOẠI NGÀY
    String currentDayType = 'Ngày thường'; 
    try {
      String dateLower = _currentDate.toLowerCase();
      
      // 🚀 CÁCH 1: Bắt chữ trực tiếp cực kỳ an toàn
      if (dateLower.contains('thứ 7') || dateLower.contains('thứ bảy') || 
          dateLower.contains('chủ nhật') || dateLower.contains('cn')) {
        currentDayType = 'Cuối tuần';
      } else {
        // 🚀 CÁCH 2: Dùng Toán học dự phòng (Cho dạng 25/07 hoặc 2026-07-25)
        RegExp dateRegex = RegExp(r'(\d{1,4})[-/](\d{1,2})(?:[-/](\d{1,4}))?');
        var match = dateRegex.firstMatch(_currentDate);
        
        if (match != null) {
          int p1 = int.parse(match.group(1)!);
          int p2 = int.parse(match.group(2)!);
          // Nếu ngày không gắn năm, tự động lấy năm hiện hành
          int p3 = match.group(3) != null ? int.parse(match.group(3)!) : DateTime.now().year;

          int day, month, year;
          if (p1 > 1000) {
             year = p1; month = p2; day = p3; // Xử lý dạng API trả về YYYY-MM-DD
          } else {
             day = p1; month = p2; year = p3; // Xử lý dạng DD/MM/YYYY hoặc DD/MM
          }
          
          DateTime parsedDate = DateTime(year, month, day);
          if (parsedDate.weekday == DateTime.saturday || parsedDate.weekday == DateTime.sunday) {
             currentDayType = 'Cuối tuần';
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi phân tích ngày: $e");
    }

    Map<int, Map<String, dynamic>> config = {};
    
    for (var type in _seatTypesFromAPI) {
      // ✅ Bọc 2 lớp key phòng hờ API Nodejs trả về chữ thường
      int id = int.tryParse(type['SeatTypeID']?.toString() ?? type['seatTypeID']?.toString() ?? '0') ?? 0;
      String name = type['TypeName']?.toString() ?? type['typeName']?.toString() ?? 'Ghế Ẩn';
      
      String hexStr = (type['ColorCode']?.toString() ?? type['colorCode']?.toString() ?? '#D6C4F3').replaceAll('#', '0xFF');
      Color color = Color(int.parse(hexStr));
      int width = int.tryParse(type['WidthSlots']?.toString() ?? type['widthSlots']?.toString() ?? '1') ?? 1;
      Color dynamicTextColor = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

      int finalPrice = widget.basePrice * width; 
      String myCinemaName = widget.cinemaName.toLowerCase();
      
      if (_ticketPricesFromAPI.isNotEmpty) {
        // 🚀 ƯU TIÊN 1: TÌM MỨC GIÁ RIÊNG CHO RẠP HIỆN TẠI (LOCAL OVERRIDE)
        var localPriceRecord = _ticketPricesFromAPI.firstWhere(
          (p) {
            // Đã là giá riêng thì CinemaID KHÔNG ĐƯỢC PHÉP null
            if (p['CinemaID'] == null) return false;

            String apiCinemaName = p['CinemaName']?.toString().toLowerCase().trim() ?? '';
            
            // So sánh tên rạp (bọc trim() để chống lỗi dư khoảng trắng)
            bool isMatchCinema = apiCinemaName.isNotEmpty && 
                (apiCinemaName.contains(myCinemaName) || myCinemaName.contains(apiCinemaName));
            
            // 💡 LỜI KHUYÊN: Nếu trang Flutter này của ông có truyền biến "widget.cinemaId" 
            // thì hãy xóa đoạn so sánh tên ở trên, và mở comment dòng dưới đây ra xài, 
            // đảm bảo chính xác 100% không bao giờ trật:
            // bool isMatchCinema = p['CinemaID'].toString() == widget.cinemaId.toString();

            return isMatchCinema &&
                   p['SeatTypeID'].toString() == id.toString() &&
                   p['ShowType'].toString().trim().toUpperCase() == currentShowType.toUpperCase() &&
                   p['DayType'].toString().trim().toLowerCase() == currentDayType.toLowerCase();
          },
          orElse: () => null
        );

        // 🚀 ƯU TIÊN 2: NẾU KHÔNG CÓ GIÁ RIÊNG, TÌM GIÁ CHUNG TOÀN HỆ THỐNG
        var globalPriceRecord = _ticketPricesFromAPI.firstWhere(
          (p) {
            // BẮT BUỘC CinemaID phải là null thì mới được xem là giá Toàn Hệ Thống
            bool isGlobal = p['CinemaID'] == null; 
            
            return isGlobal &&
                   p['SeatTypeID'].toString() == id.toString() &&
                   p['ShowType'].toString().trim().toUpperCase() == currentShowType.toUpperCase() &&
                   p['DayType'].toString().trim().toLowerCase() == currentDayType.toLowerCase();
          },
          orElse: () => null
        );

        // Chốt giá dựa trên kết quả ưu tiên
        if (localPriceRecord != null) {
          finalPrice = double.tryParse(localPriceRecord['Price']?.toString() ?? '0')?.toInt() ?? (widget.basePrice * width);
        } else if (globalPriceRecord != null) {
          finalPrice = double.tryParse(globalPriceRecord['Price']?.toString() ?? '0')?.toInt() ?? (widget.basePrice * width);
        }
      }

      config[id] = {
        'name': name,
        'color': color,
        'textColor': dynamicTextColor,
        'price': finalPrice, 
        'desc': 'Ghế $name - chiếm $width ô lưới.',
        'img': width >= 2 ? 'assets/seat_couple.png' : 
               (id == 4 || id == 5) ? 'assets/seat_vip.png' : 'assets/seat_regular.png',
      };
    }
    
    return config;
  }
  // ========================================================
  // ✅ THUẬT TOÁN QUÉT LOẠI GHẾ THỰC TẾ TRONG PHÒNG
  // ========================================================
  Set<int> _getUsedSeatTypes() {
    Set<int> usedTypes = {};
    for (var row in _cachedLayout) {
      for (var type in row) {
        if (type != 0 && type != -1) {
          usedTypes.add(type);
        }
      }
    }
    return usedTypes;
  }

  @override
  void initState() {
    super.initState();
    _getSeatConfig();
    _currentDate = widget.selectedDate;
    _currentTime = widget.selectedTime;
    _currentCapacity = widget.roomCapacity;

    _cachedLayout = _generateLayout();
    _autoCenterMap(); 
    
    _fetchSeatsFuture = _fetchRealSeats(); 
    _connectSocket();

    // ✅ BẬT MẬT THÁM THEO DÕI GIỎ HÀNG 24/7
    _updateLastKnownSeats();
    CartManager.instance.addListener(_onCartChanged);
  }

  // ========================================================
  // ✅ HÀM KHỞI TẠO VÀ LẮNG NGHE SOCKET.IO (ĐÃ FIX TẬN GỐC)
  // ========================================================
  void _connectSocket() {
    socket = IO.io(socketUrl, IO.OptionBuilder()
        .setTransports(['websocket', 'polling']) 
        .enableAutoConnect()
        .enableForceNew() // ✅ FIX 1: Ép tạo kết nối hoàn toàn mới mỗi khi vào lại trang
        .build());

    // 2. Lắng nghe thành công
    socket?.onConnect((_) {
      debugPrint('✅✅✅ FLUTTER: Đã kết nối Socket.IO thành công!');
      socket?.emit('join_showtime', widget.showtimeId);
    });

    // 3. LẮNG NGHE LỖI (Quan trọng nhất để bắt bệnh)
    socket?.onConnectError((err) {
      debugPrint('❌❌❌ FLUTTER LỖI KẾT NỐI SOCKET: $err');
    });

    socket?.onError((err) {
      debugPrint('❌❌❌ FLUTTER LỖI SOCKET CHUNG: $err');
    });

    socket?.onDisconnect((_) {
      debugPrint('⚠️ FLUTTER: Đã ngắt kết nối Socket');
    });

    // 4. Lắng nghe sự kiện đổi màu ghế (Giữ nguyên của con)
    socket?.on('seat_status_changed', (data) {
      if (!mounted) return;
      
      String seatNum = data['seatNumber'].toString();
      String status = data['status'].toString().toLowerCase();

      setState(() {
        if (status == 'holding') {
          if (!_holdingSeats.contains(seatNum)) _holdingSeats.add(seatNum);
          _bookedSeats.remove(seatNum);
        } else if (status == 'occupied' || status == 'pending') {
          if (!_bookedSeats.contains(seatNum)) _bookedSeats.add(seatNum);
          _holdingSeats.remove(seatNum);
        } else {
          _holdingSeats.remove(seatNum);
          _bookedSeats.remove(seatNum);
        }
      });
    });
  }
  @override
  void didUpdateWidget(covariant SeatBookingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.basePrice != widget.basePrice) {
      setState(() {
        _getSeatConfig(); // Cập nhật lại cấu hình ghế khi giá cơ sở thay đổi
      });
    }
  }

  // ========================================================
  // ✅ GỬI LỆNH GIỮ/NHẢ GHẾ QUA SOCKET THAY VÌ HTTP POST
  // ========================================================
  Future<void> _sendHoldRequest(String seatNumber, int realSeatId, bool isHolding) async {
    final eventName = isHolding ? 'hold_seat' : 'release_seat';
    socket?.emit(eventName, {
      'userId': UserManager.instance.currentUser?.id ?? 0,
      'showtimeId': widget.showtimeId,
      'seatId': realSeatId,       
      'seatNumber': seatNumber,   
    });
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
      // ✅ 1. Gọi API lấy Cấu hình Loại ghế và MA TRẬN GIÁ VÉ từ Server
      try {
        // Lấy danh sách Loại ghế
        final typeUrl = '$baseUrl/seattypes';
        final typeResponse = await http.get(Uri.parse(typeUrl));
        
        if (typeResponse.statusCode == 200) {
          var decoded = jsonDecode(typeResponse.body);
          if (decoded is List) {
            _seatTypesFromAPI = decoded;
          } else if (decoded is Map && decoded.containsKey('data')) {
            _seatTypesFromAPI = decoded['data'];
          } else if (decoded is Map && decoded.containsKey('seatTypes')) {
             _seatTypesFromAPI = decoded['seatTypes'];
          }
        } else {
          debugPrint("❌ API SeatTypes báo lỗi code: ${typeResponse.statusCode}");
        }

        // ✅ [THÊM MỚI] Lấy Ma trận Giá vé (TicketPrices)
        final priceUrl = '$baseUrl/ticketprices';
        final priceResponse = await http.get(Uri.parse(priceUrl));
        
        if (priceResponse.statusCode == 200) {
          var decodedPrice = jsonDecode(priceResponse.body);
          if (decodedPrice is List) {
            _ticketPricesFromAPI = decodedPrice;
          } else if (decodedPrice is Map && decodedPrice.containsKey('data')) {
            _ticketPricesFromAPI = decodedPrice['data'];
          }
        } else {
          debugPrint("❌ API TicketPrices báo lỗi code: ${priceResponse.statusCode}");
        }
        // ========================================================
        // 🚀 MÁY PHÁT TÍN HIỆU: GỌI API ADMIN LẤY SỐ PHÚT GIỮ GHẾ
        // ========================================================
        final settingsUrl = '$baseUrl/admin/settings';
        final settingsResponse = await http.get(Uri.parse(settingsUrl));
        
        if (settingsResponse.statusCode == 200) {
          var data = jsonDecode(settingsResponse.body);
          var dbData = data is List ? (data.isNotEmpty ? data[0] : null) : (data['data'] ?? data);
          
          if (dbData != null) {
            // Lấy số phút từ DB (Nếu lỗi thì xài số 10)
            int holdMins = int.tryParse(dbData['seatHoldMinutes']?.toString() ?? '10') ?? 10;
            
            // 👉 BÁO CHO GIỎ HÀNG CẬP NHẬT ĐỒNG HỒ NGAY LẬP TỨC
            CartManager.instance.updateHoldTimeConfig(holdMins);
            debugPrint("🔥 ĐÃ CẬP NHẬT THỜI GIAN GIỮ GHẾ THÀNH: $holdMins PHÚT");
          }
        } else {
          debugPrint("❌ API Settings báo lỗi code: ${settingsResponse.statusCode}");
        }
        
      } catch (e) {
        debugPrint("❌ Lỗi tải cấu hình loại ghế hoặc ma trận giá: $e");
      }

      // 2. [GIỮ NGUYÊN] Lấy danh sách trạng thái ghế của suất chiếu hiện tại
      final url = '$baseUrl/seats/${widget.showtimeId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var decodedData = jsonDecode(response.body);
        List<dynamic> data = [];
        String? layoutStr;

        if (decodedData is List) {
          data = decodedData; 
        } else if (decodedData is Map) {
          data = decodedData['seats'] ?? [];
          layoutStr = decodedData['layoutData'];
          
          // 🚀 MÁY NGHE LÉN ĐÂY: In thẳng cái cục data Server gửi về ra xem có biến max_seats = 6 không!
          debugPrint("🟢 [MÁY NGHE LÉN] DỮ LIỆU SERVER GỬI VỀ LÀ: $decodedData");
          
          _maxSeatsPerBooking = int.tryParse(decodedData['max_seats']?.toString() ?? decodedData['MaxSeats']?.toString() ?? decodedData['maxSeatsPerBooking']?.toString() ?? '8') ?? 8;
          
          debugPrint("🟢 [MÁY NGHE LÉN] CHỐT SỐ LƯỢNG GHẾ GIỚI HẠN: $_maxSeatsPerBooking");
        }

        _apiSeatsData.clear();
        _bookedSeats.clear();
        _holdingSeats.clear();

        for (var seat in data) {
          String seatNum = seat['SeatNumber'] ?? '';
          _apiSeatsData[seatNum] = seat;
          
          String status = seat['Status']?.toString().toLowerCase() ?? seat['status']?.toString().toLowerCase() ?? '';
          if (status == 'occupied' || status == 'pending') {
             _bookedSeats.add(seatNum);
          } else if (status == 'holding') {
             _holdingSeats.add(seatNum);
          }
        }

        if (layoutStr != null && layoutStr.trim().isNotEmpty && layoutStr != 'null') {
           try {
             List<dynamic> parsedAdminLayout = jsonDecode(layoutStr);
             List<List<int>> customLayout = [];
             
             // 🚀 BẮT ĐẦU ĐỌC DỮ LIỆU VÙNG TRUNG TÂM TỪ JSON (Nằm ở hàng đầu tiên)
             if (parsedAdminLayout.isNotEmpty && parsedAdminLayout[0]['centerZone'] != null) {
               final cz = parsedAdminLayout[0]['centerZone'];
               _centerZone = {
                 'startRow': int.tryParse(cz['startRow']?.toString() ?? '0') ?? 0,
                 'startCol': int.tryParse(cz['startCol']?.toString() ?? '0') ?? 0,
                 'rowCount': int.tryParse(cz['rowCount']?.toString() ?? '0') ?? 0,
                 'colCount': int.tryParse(cz['colCount']?.toString() ?? '0') ?? 0,
               };
             } else {
               _centerZone = null; // Nếu admin chưa setup vùng trung tâm
             }
             // 🚀 KẾT THÚC ĐỌC VÙNG TRUNG TÂM

             for (var row in parsedAdminLayout) {
               List<int> rowTypes = [];
               for (var seat in row['seats']) {
                 rowTypes.add((seat['type'] as num).toInt()); 
               }
               customLayout.add(rowTypes);
             }
             _cachedLayout = customLayout;
           } catch (parseError) {
             debugPrint("❌ Lỗi giải mã LayoutData: $parseError");
           }
        }

      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi tải sơ đồ ghế: $e');
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
    // ✅ HỦY MẬT THÁM KHI THOÁT KHỎI PHIM NÀY
    CartManager.instance.removeListener(_onCartChanged);
    
    if (socket != null) {
      socket?.emit('leave_showtime', widget.showtimeId);
      socket?.disconnect();
    }
    _transformController.dispose();
    _miniMapTimer?.cancel();
    super.dispose();
  }

  // ========================================================
  // ✅ HÀM LẮNG NGHE SỰ THAY ĐỔI CỦA GIỎ HÀNG REAL-TIME
  // ========================================================
  void _updateLastKnownSeats() {
    _lastKnownCartSeats = List<Map<String, dynamic>>.from(
      CartManager.instance.getSeatsForShowtime(
        widget.movie.id.toString(), widget.cinemaName, 
        _formatDateToDDMMYYYY(_currentDate), _currentTime
      ) ?? []
    );
  }

  void _onCartChanged() {
    // Nếu thao tác này xuất phát từ hàm _toggleSeat thì bỏ qua
    if (_isModifyingFromSeatPage) {
      _updateLastKnownSeats();
      return;
    }

    // Lấy giỏ hàng mới nhất
    final latestSeats = List<Map<String, dynamic>>.from(
      CartManager.instance.getSeatsForShowtime(
        widget.movie.id.toString(), widget.cinemaName, 
        _formatDateToDDMMYYYY(_currentDate), _currentTime
      ) ?? []
    );

    // ========================================================
    // ✅ FIX LỖI CHỚP MÀN HÌNH: Chặn báo động giả do Timer
    // Nếu số lượng ghế y nguyên -> Chỉ là do đồng hồ đếm lùi -> Nghỉ khỏe!
    // ========================================================
    if (latestSeats.length == _lastKnownCartSeats.length) {
      return; 
    }

    // Phát hiện ghế bị xóa trong CartPage
    for (var oldSeat in _lastKnownCartSeats) {
      bool stillExists = latestSeats.any((newSeat) => newSeat['name'] == oldSeat['name']);
      
      if (!stillExists) {
        int type = oldSeat['type'] ?? 1;
        if (type == 3) {
          List<String> parts = oldSeat['name'].split('-');
          _sendHoldRequest(parts[0], oldSeat['id'] ?? 0, false);
          _sendHoldRequest(parts[1], oldSeat['id2'] ?? 0, false);
        } else {
          _sendHoldRequest(oldSeat['name'], oldSeat['id'] ?? 0, false);
        }
      }
    }

    // Cập nhật lại trí nhớ và load lại màu ghế ngầm
    _lastKnownCartSeats = latestSeats;
    if (mounted) {
      setState(() {
        _fetchSeatsFuture = _fetchRealSeats();
      });
    }
  }
  void _onInteractionStart(ScaleStartDetails details) {
    _showMiniMap.value = true;
    _miniMapTimer?.cancel();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _miniMapTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _showMiniMap.value = false;
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

  void _toggleSeat(String seatId, int seatType, GlobalKey seatKey) {
    if (!CartManager.instance.canAddItem(widget.cinemaName)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Đổi rạp chiếu?', style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text(
            'Giỏ hàng đang giữ chỗ tại rạp ${CartManager.instance.currentCinemaName}. Chọn ghế tại ${widget.cinemaName} sẽ hủy các ghế/bắp đang giữ. Tiếp tục?',
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                Navigator.pop(ctx);
                CartManager.instance.clearCart(); // 🚀 Xóa giỏ hàng cũ đi
                // Xóa luôn UI đang bôi màu ở màn hình hiện tại
                if (mounted) setState(() {});
              }, 
              child: const Text('Đồng ý', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        )
      );
      return; // ⛔ Dừng ngay việc xử lý ghế này lại
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

    bool isAlreadyInCart = currentSeats.any((s) => s['name'] == seatId);

    // 1. CHỈ CHẶN KHI GHẾ ĐÃ BỊ NGƯỜI KHÁC MUA HOẶC GIỮ
    if (seatType == 3) {
      List<String> parts = seatId.split('-');
      bool isBooked = _bookedSeats.contains(parts[0]) || _bookedSeats.contains(parts[1]);
      bool isHeld = _holdingSeats.contains(parts[0]) || _holdingSeats.contains(parts[1]);
      
      if (isBooked) return; 
      if (isHeld && !isAlreadyInCart) return; 
    } else {
      bool isBooked = _bookedSeats.contains(seatId);
      bool isHeld = _holdingSeats.contains(seatId);
      
      if (isBooked) return; 
      if (isHeld && !isAlreadyInCart) return;
    }

    int existingIndex = currentSeats.indexWhere((s) => s['name'] == seatId);
    bool isAdding = existingIndex == -1;

    int realSeatId = 0;
    int realSeatId2 = 0; 
    final seatConfig = _getSeatConfig();
    int price = seatConfig[seatType]?['price'] ?? widget.basePrice;

    if (seatType == 3) {
      List<String> parts = seatId.split('-');
      realSeatId = int.tryParse(_apiSeatsData[parts[0]]?['SeatID']?.toString() ?? _apiSeatsData[parts[0]]?['id']?.toString() ?? '0') ?? 0;
      realSeatId2 = int.tryParse(_apiSeatsData[parts[1]]?['SeatID']?.toString() ?? _apiSeatsData[parts[1]]?['id']?.toString() ?? '0') ?? 0;
    } else {
      realSeatId = int.tryParse(_apiSeatsData[seatId]?['SeatID']?.toString() ?? _apiSeatsData[seatId]?['id']?.toString() ?? '0') ?? 0;
    }

    List<Map<String, dynamic>> simulatedSeats = List.from(currentSeats);
    
    if (isAdding) {
      // 🚀 ĐÃ BỔ SUNG: Dùng biến _maxSeatsPerBooking thay cho số 8 cứng
      if (simulatedSeats.length >= _maxSeatsPerBooking) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bạn chỉ được chọn tối đa $_maxSeatsPerBooking ghế!'), backgroundColor: navyBlue));
        return;
      }
      simulatedSeats.add({
        'id': realSeatId, 'id2': seatType == 3 ? realSeatId2 : null, 
        'name': seatId, 'price': price, 'type': seatType
      });
    } else {
      simulatedSeats.removeAt(existingIndex);
    }

    if (!_isValidSeatSelection(simulatedSeats)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rất tiếc! Không được để trống 1 ghế ở giữa hoặc sát vách.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return; 
    }

    // 2. CẬP NHẬT GIAO DIỆN & GIỎ HÀNG NGAY LẬP TỨC (OPTIMISTIC UI)
    if (isAdding) {
      currentSeats.add({
        'id': realSeatId, 'id2': seatType == 3 ? realSeatId2 : null, 
        'name': seatId, 'price': price, 'type': seatType
      }); 
      _runAddToCartAnimation(seatKey);
    } else {
      currentSeats.removeAt(existingIndex); 
      // Xóa tạm danh sách giữ ghế ở local để UI nhả màu ngay lập tức
      if (seatType == 3) {
        List<String> parts = seatId.split('-');
        _holdingSeats.remove(parts[0]); _holdingSeats.remove(parts[1]);
      } else {
        _holdingSeats.remove(seatId);
      }
    }

    int total = currentSeats.fold(0, (sum, seat) => sum + (seat['price'] as int? ?? 0));

    _isModifyingFromSeatPage = true; 
    manager.updateCart(
      movieObj: widget.movie, cinema: widget.cinemaName,
      date: _formatDateToDDMMYYYY(_currentDate), time: _currentTime,
      seats: currentSeats, price: total,
      showtimeId: widget.showtimeId, roomName: widget.roomName,
    );
    _isModifyingFromSeatPage = false;

    // ========================================================
    // ✅ 3. DEBOUNCE NETWORK: CHỈ BẮN SOCKET SAU KHI NGỪNG SPAM 300MS
    // ========================================================
    _socketDebounceTimers[seatId]?.cancel(); // Hủy lệnh cũ nếu user vừa spam thêm
    
    _socketDebounceTimers[seatId] = Timer(const Duration(milliseconds: 300), () {
      // Sau 300ms, kiểm tra lại rốt cuộc ghế này có đang nằm trong giỏ hay không
      bool finalIsSelected = CartManager.instance.getSeatsForShowtime(
        widget.movie.id.toString(), widget.cinemaName, 
        _formatDateToDDMMYYYY(_currentDate), _currentTime
      )?.any((s) => s['name'] == seatId) ?? false;

      // Chỉ gửi 1 lệnh duy nhất đại diện cho trạng thái cuối cùng
      if (seatType == 3) {
        List<String> parts = seatId.split('-');
        _sendHoldRequest(parts[0], realSeatId, finalIsSelected);
        _sendHoldRequest(parts[1], realSeatId2, finalIsSelected);
      } else {
        _sendHoldRequest(seatId, realSeatId, finalIsSelected);
      }
    });
  }
  void _runAddToCartAnimation(GlobalKey seatKey) {
    final RenderBox? seatBox = seatKey.currentContext?.findRenderObject() as RenderBox?;
    if (seatBox == null) return;
    final Offset startOffset = seatBox.localToGlobal(Offset.zero);

    final RenderBox? cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartBox == null) return;
    final Offset endOffset = cartBox.localToGlobal(Offset.zero);

    // ✅ TỐI ƯU 3: Giảm thời gian bay xuống 500ms cho gọn gàng, đổi đường cong Curve
    AnimationController animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    final Animation<double> moveCurve = CurvedAnimation(parent: animController, curve: Curves.easeInOutSine);
    final Animation<double> sizeCurve = Tween<double>(begin: 1.0, end: 0.2).animate(animController);

    OverlayEntry? currentEntry;

    // Bộ nhớ đệm Widget tĩnh (Không phải vẽ lại cục này mỗi frame)
    final Widget flyingSeat = Container(
      width: 30, height: 20,
      decoration: BoxDecoration(
        color: colorSelected, 
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
    );

    currentEntry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: animController,
          child: flyingSeat, // Bọc child ở đây
          builder: (context, child) {
            double x = startOffset.dx + (endOffset.dx - startOffset.dx) * moveCurve.value;
            double y = startOffset.dy + (endOffset.dy - startOffset.dy) * moveCurve.value;
            double bounce = sin(moveCurve.value * pi) * -80; // Độ nảy cong mềm hơn

            return Positioned(
              left: x,
              top: y + bounce,
              child: Transform.scale(
                scale: sizeCurve.value,
                child: child, // Sử dụng lại widget tĩnh
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(currentEntry);

    // ✅ Đợi cho sơ đồ ghế vẽ xong hết mới chạy Animation để chống giật
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
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: _buildAppBar(),
      body: FutureBuilder<void>(
        future: _fetchSeatsFuture, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _apiSeatsData.isEmpty) {
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
                                child: Center(
                                  child: ListenableBuilder(
                                    listenable: CartManager.instance,
                                    builder: (context, child) {
                                      return _buildDynamicSeatGrid();
                                    }
                                  ),
                                ),
                              ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0), 
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _showMiniMap,
                              builder: (context, show, child) {
                                return AnimatedOpacity(
                                  opacity: show ? 1.0 : 0.0, 
                                  duration: const Duration(milliseconds: 300),
                                  child: show ? _buildMiniMap(constraints.maxWidth, constraints.maxHeight) : const SizedBox.shrink(),
                                );
                              }
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          // NÚT QUAY VỀ (BACK) NẰM Ở ĐÂY
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
            ),
          ),
          const SizedBox(width: 12),
          // TÊN RẠP CHIẾU PHIM
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
        // 🚀 ĐÃ SỬA MÀU Ở ĐÂY: shade100 -> shade300 để giống y hệt AppBar mẫu
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight, 
            colors: [Colors.blue.shade300, Colors.blue.shade50]
          )
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // NÚT GIỎ HÀNG (Chỉ có 1 cái duy nhất)
              InkWell(
                key: _cartKey,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
                  if (mounted) {
                    setState(() {
                      _fetchSeatsFuture = _fetchRealSeats(); 
                    });
                  }
                },
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _buildCartIconWithBadge(), 
                ),
              ),
              Container(height: 16, width: 1, color: navyBlue.withOpacity(0.2)),
              // NÚT TRANG CHỦ
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

  // ✅ Thêm tham số {bool isMiniMap = false} vào đây
  Widget _buildDynamicSeatGrid({bool isMiniMap = false}) {
    // ✅ TỐI ƯU 1: Lấy giỏ hàng 1 LẦN DUY NHẤT cho cả sơ đồ (Chống giật lag)
    final manager = CartManager.instance;
    List<Map<String, dynamic>> currentSeats = List<Map<String, dynamic>>.from(
      manager.getSeatsForShowtime(
        widget.movie.id.toString(), 
        widget.cinemaName, 
        _formatDateToDDMMYYYY(_currentDate), 
        _currentTime
      ) ?? []
    );
    // Lưu sẵn danh sách tên ghế đang chọn vào một Set (Tra cứu siêu tốc)
    Set<String> selectedSeatIds = currentSeats.map((s) => s['name'].toString()).toSet();

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
          // ✅ Truyền thêm biến isMiniMap vào hàm _buildSeatItem
          rowChildren.add(_buildSeatItem(combinedId, seatType, selectedSeatIds.contains(combinedId), isMiniMap));
        } else {
          String seatId = '$rowLabel$seatCounter';
          seatCounter++;
          // ✅ Truyền thêm biến isMiniMap vào hàm _buildSeatItem
          rowChildren.add(_buildSeatItem(seatId, seatType, selectedSeatIds.contains(seatId), isMiniMap));
        }
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisSize: MainAxisSize.min, children: rowChildren)));
    }
    Widget seatGrid = Column(children: rows);

    if (_centerZone == null) {
      return seatGrid;
    }

    // TOÁN HỌC TÍNH TOẠ ĐỘ:
    // Chiều ngang: Mỗi ghế rộng 30 + khoảng cách 8 = 38
    // Chiều dọc: Mỗi ghế cao 30 + khoảng cách hàng 10 = 40
    double boxTop = _centerZone!['startRow']! * 40.0;
    double boxLeft = _centerZone!['startCol']! * 38.0;
    double boxWidth = _centerZone!['colCount']! * 38.0 - 8.0; 
    double boxHeight = _centerZone!['rowCount']! * 40.0 - 10.0; 
    
    double padding = 6.0; // Độ hở của khung so với ghế

    return Stack(
      children: [
        seatGrid,
        Positioned(
          top: boxTop - padding,
          left: boxLeft - padding,
          width: boxWidth + (padding * 2),
          height: boxHeight + (padding * 2),
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                // Nếu là minimap thì cho viền dày lên xíu (width: 4) để dễ nhìn khi thu nhỏ
                border: Border.all(color: Colors.green.shade500, width: isMiniMap ? 4 : 2),
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.topCenter,
              // ✅ TỐI ƯU UI: Nếu là minimap thì ẨN cái chữ đi cho đỡ rác, chỉ giữ lại khung
              child: isMiniMap ? const SizedBox.shrink() : Transform.translate(
                offset: const Offset(0, -9), 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade500, width: 1)
                  ),
                  child: Text(
                    "VÙNG TRUNG TÂM",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // ✅ TỐI ƯU 2: Nhận thẳng kết quả isSelected, không cần hỏi lại CartManager
  // ✅ Nhận thêm biến isMiniMap
  Widget _buildSeatItem(String seatId, int seatType, bool isSelected, bool isMiniMap) {
    bool isBooked = false;
    bool isHoldingByOther = false;

    if (seatType == 3) {
      List<String> parts = seatId.split('-');
      isBooked = _bookedSeats.contains(parts[0]) || _bookedSeats.contains(parts[1]);
      isHoldingByOther = (_holdingSeats.contains(parts[0]) || _holdingSeats.contains(parts[1])) && !isSelected; 
    } else {
      isBooked = _bookedSeats.contains(seatId);
      isHoldingByOther = _holdingSeats.contains(seatId) && !isSelected; 
    }

    Color seatBgColor;
    Color textColor = Colors.black87;

    if (isBooked) {
      seatBgColor = colorBooked; textColor = Colors.white;
    } else if (isHoldingByOther) { 
      seatBgColor = colorHoldingByOther; textColor = Colors.white;
    } else if (isSelected) { 
      seatBgColor = colorSelected; textColor = Colors.white;
    } else {
      // ✅ TỰ ĐỘNG LẤY MÀU TỪ TỪ ĐIỂN
      final config = _getSeatConfig();
      if (config.containsKey(seatType)) {
        seatBgColor = config[seatType]!['color'];
        textColor = config[seatType]!['textColor'];
      } else {
        // Fallback: Nếu gặp loại ghế chưa từng cấu hình, cho nó màu xanh ngọc để dễ nhận diện
        seatBgColor = Colors.teal.shade200; 
        textColor = Colors.black87;
      }
    }

    double seatWidth = seatType == 3 ? 68.0 : 30.0;
    
    // ========================================================
    // ✅ CHỈ CẤP GLOBALKEY NẾU KHÔNG PHẢI LÀ MINIMAP (Tránh lỗi ANR)
    // ========================================================
    final GlobalKey? seatKey = isMiniMap ? null : _seatKeys.putIfAbsent(seatId, () => GlobalKey());

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
        // ✅ Chặn bấm khi ở trong MiniMap
        onTap: (isMiniMap || seatKey == null) ? null : () => _toggleSeat(seatId, seatType, seatKey), 
        child: Container(
          key: seatKey, // Sẽ là null nếu ở minimap, hợp lệ hoàn toàn!
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
    // ✅ BƯỚC 1: Xóa dòng _cachedMiniMapGrid cũ đi
    // Thay vào đó, tạo một Widget tự động lắng nghe Giỏ hàng (CartManager)
    Widget reactiveMiniMap = FittedBox(
      fit: BoxFit.contain, 
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: CartManager.instance,
          builder: (context, child) {
            // Khi giỏ hàng đổi, chỉ có cục này được vẽ lại -> Đổi màu ngay lập tức
            return _buildDynamicSeatGrid(isMiniMap: true);
          }
        ),
      )
    );

    return AnimatedBuilder(
      animation: _transformController, 
      // ✅ BƯỚC 2: Truyền reactiveMiniMap vào tham số 'child' 
      // Kỹ thuật này giúp MiniMap KHÔNG bị vẽ lại liên tục khi người dùng vuốt/zoom màn hình -> Mượt 60fps!
      child: reactiveMiniMap, 
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
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), 
            borderRadius: BorderRadius.circular(8), 
            border: Border.all(color: Colors.blue.shade200, width: 1.5), 
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // ✅ Gọi biến child (chính là reactiveMiniMap ở trên) ra đây
                Center(child: child), 
                
                // Khung viền đỏ báo hiệu vùng đang xem
                Positioned(
                  left: mapLeft, top: mapTop, 
                  width: viewW, height: viewH, 
                  child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 2.0), color: Colors.red.withOpacity(0.15)))
                ),
              ],
            ),
          ),
        );
      },
    );
  }
 Widget _buildSeatLegendAndDetails() {
    List<Widget> legendItems = [
      _buildLegendItem("Đã đặt", colorBooked),
      const SizedBox(width: 8),
      _buildLegendItem("Ghế chọn", colorSelected),
      const SizedBox(width: 8),
      _buildLegendItem("Đang giữ", colorHoldingByOther),
    ];

    // ✅ CHỈ IN RA CÁC LOẠI GHẾ CÓ TRONG SƠ ĐỒ THỰC TẾ
    Set<int> usedTypes = _getUsedSeatTypes();
    final configMap = _getSeatConfig();
    
    for (int typeId in usedTypes) {
      if (configMap.containsKey(typeId)) {
        legendItems.add(const SizedBox(width: 8));
        legendItems.add(_buildLegendItem(configMap[typeId]!['name'], configMap[typeId]!['color']));
      }
    }

    if (_centerZone != null) {
      legendItems.add(const SizedBox(width: 8));
      legendItems.add(
        Row(
          children: [
            Container(
              width: 14, height: 14, 
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade600, width: 1.5),
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              )
            ),
            const SizedBox(width: 4),
            const Text("Vùng trung tâm", style: TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        )
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: legendItems), 
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
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, child) {
        final manager = CartManager.instance;
        
        final user = UserManager.instance.currentUser;
        if (user == null) {
          return const SizedBox.shrink(); 
        }

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
        seatNames.sort(); 

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
                      onPressed: currentSeats.isEmpty ? null : () async {
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
                            return; 
                          }

                          await Navigator.push(
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

                          if (mounted) {
                            setState(() {
                              _fetchSeatsFuture = _fetchRealSeats();
                            });
                          }
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
                  "$movieFormat${last5Chars.isNotEmpty ? ' • $last5Chars' : ''}" , 
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
        
        List<Widget> infoCards = [];
        // ✅ CHỈ TẠO THẺ THÔNG TIN CHO NHỮNG GHẾ CÓ TRONG SƠ ĐỒ THỰC TẾ
        Set<int> usedTypes = _getUsedSeatTypes();
        final configMap = _getSeatConfig();

        for (int typeId in usedTypes) {
          if (configMap.containsKey(typeId)) {
            final config = configMap[typeId]!;
            infoCards.add(
              _buildSeatTypeInfo(
                config['name'], 
                config['color'], 
                formatter.format(config['price']), 
                config['desc'], 
                config['img']
              )
            );
            infoCards.add(const SizedBox(height: 16));
          }
        }

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
                  children: infoCards.isEmpty 
                    ? [const Center(child: Text("Đang tải dữ liệu...", style: TextStyle(color: Colors.grey)))] 
                    : infoCards, // In mảng thẻ tự động vào đây
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

  bool _isValidSeatSelection(List<Map<String, dynamic>> currentSeats) {
    if (currentSeats.isEmpty) return true;

    List<String> selectedSeatIds = currentSeats.map((s) => s['name'].toString()).toList();

    for (int r = 0; r < _cachedLayout.length; r++) {
      String rowLabel = String.fromCharCode(65 + r); 
      int seatCounter = 1; 

      List<String> renderedSeatNames = [];

      for (int c = 0; c < _cachedLayout[r].length; c++) {
        int seatType = _cachedLayout[r][c];
        if (seatType == -1 || seatType == 0) continue; 
        
        if (seatType == 3) { 
          renderedSeatNames.add('$rowLabel$seatCounter'); seatCounter++;
          renderedSeatNames.add('$rowLabel$seatCounter'); seatCounter++;
        } else { 
          renderedSeatNames.add('$rowLabel$seatCounter'); seatCounter++;
        }
      }

      int consecutiveEmptySeats = 0;
      
      for (String seatNum in renderedSeatNames) {
        
        bool isBookedOrHold = _bookedSeats.contains(seatNum) || _holdingSeats.contains(seatNum);
        
        bool isSelected = selectedSeatIds.any((id) => id.split('-').contains(seatNum));
        
        bool isSolidBlock = isBookedOrHold || isSelected;

        if (!isSolidBlock) {
          consecutiveEmptySeats++; 
        } else {
          if (consecutiveEmptySeats == 1) return false;
          consecutiveEmptySeats = 0; 
        }
      }
      
      if (consecutiveEmptySeats == 1) return false;
    }
    
    return true; 
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