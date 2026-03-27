import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import 'package:intl/intl.dart';

class SeatBookingPage extends StatefulWidget {
  final Movie movie;

  const SeatBookingPage({super.key, required this.movie});

  @override
  State<SeatBookingPage> createState() => _SeatBookingPageState();
}

class _SeatBookingPageState extends State<SeatBookingPage> {
  final Color primaryBlue = Colors.blue.shade700;
  
  final Set<String> _selectedSeats = {};
  final List<String> _bookedSeats = ['D5', 'D6', 'E5', 'E6', 'E7', 'F8', 'F9', 'J10', 'J11', 'J12'];

  final int _rows = 10; 
  final int _cols = 12; 
  final int _ticketPrice = 85000; 

  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  void _toggleSeat(String seatId) {
    if (_bookedSeats.contains(seatId)) return; 

    setState(() {
      if (_selectedSeats.contains(seatId)) {
        _selectedSeats.remove(seatId); 
      } else {
        if (_selectedSeats.length < 8) {
          _selectedSeats.add(seatId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn chỉ được chọn tối đa 8 ghế!'), duration: Duration(seconds: 2)),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), 
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildDateTimeSelector(),
          
          Expanded(
            child: ClipRect( 
              child: InteractiveViewer(
                minScale: 0.8, 
                maxScale: 3.5, 
                boundaryMargin: const EdgeInsets.all(40), 
                panEnabled: true,
                scaleEnabled: true,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScreenCurve(), 
                      const SizedBox(height: 30),
                      _buildSeatGrid(), 
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          _buildSeatLegend(),
        ],
      ),
      
      bottomNavigationBar: _buildBottomCheckoutBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      title: Column(
        children: [
          Text(widget.movie.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text("CGV Sư Vạn Hạnh • Rạp 3", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildDateTimeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 16, color: Colors.grey),
          SizedBox(width: 5),
          Text("Hôm nay, 24 Thg 04", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 15),
          Icon(Icons.access_time, size: 16, color: Colors.grey),
          SizedBox(width: 5),
          Text("19:30 - 21:45", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScreenCurve() {
    return Column(
      children: [
        SizedBox(
          width: 280,
          height: 30,
          child: CustomPaint(painter: ScreenPainter(color: primaryBlue)),
        ),
        const SizedBox(height: 5),
        Text("MÀN HÌNH", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildSeatGrid() {
    return Column(
      children: List.generate(_rows, (rowIndex) {
        String rowLabel = String.fromCharCode(65 + rowIndex); 
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 30, child: Text(rowLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              
              ...List.generate(_cols, (colIndex) {
                double leftMargin = (colIndex == _cols ~/ 2) ? 20.0 : 4.0;
                
                String seatId = '$rowLabel${colIndex + 1}';
                bool isBooked = _bookedSeats.contains(seatId);
                bool isSelected = _selectedSeats.contains(seatId);

                return Container(
                  margin: EdgeInsets.only(left: leftMargin, right: 4),
                  child: GestureDetector(
                    onTap: () => _toggleSeat(seatId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: isBooked 
                            ? Colors.grey.shade400 
                            : (isSelected ? primaryBlue : Colors.white),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isBooked ? Colors.transparent : (isSelected ? primaryBlue : Colors.blue.shade200),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${colIndex + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isBooked 
                              ? Colors.white 
                              : (isSelected ? Colors.white : Colors.blue.shade900),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              
              SizedBox(width: 30, child: Text(rowLabel, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSeatLegend() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem("Ghế trống", Colors.white, Colors.blue.shade200),
          _buildLegendItem("Đang chọn", primaryBlue, primaryBlue),
          _buildLegendItem("Đã bán", Colors.grey.shade400, Colors.transparent),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color fillColor, Color borderColor) {
    return Row(
      children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  Widget _buildBottomCheckoutBar() {
    int totalPrice = _selectedSeats.length * _ticketPrice;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedSeats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Text("Ghế: ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Expanded(
                    child: Text(
                      // ĐÃ FIX LỖI TẠI ĐÂY: Bọc cụm sort trong ngoặc đơn
                      (_selectedSeats.toList()..sort()).join(', '), 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                    const Text("Tổng cộng", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      totalPrice > 0 ? formatter.format(totalPrice) : "0 đ",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
                    ),
                  ],
                ),
              ),
              
              SizedBox(
                width: 160,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedSeats.isEmpty ? null : () {
                    // Xử lý chuyển sang trang thanh toán ở đây
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
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
}

class ScreenPainter extends CustomPainter {
  final Color color;
  ScreenPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, -10, size.width, size.height);

    canvas.drawShadow(path, color, 10, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}