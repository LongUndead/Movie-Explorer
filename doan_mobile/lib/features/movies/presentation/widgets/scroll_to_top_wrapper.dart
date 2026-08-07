import 'package:flutter/material.dart';

class ScrollToTopWrapper extends StatefulWidget {
  // Nhận vào một hàm builder để tự động cấp phát ScrollController cho Widget con
  final Widget Function(BuildContext context, ScrollController controller) builder;

  const ScrollToTopWrapper({super.key, required this.builder});

  @override
  State<ScrollToTopWrapper> createState() => _ScrollToTopWrapperState();
}

class _ScrollToTopWrapperState extends State<ScrollToTopWrapper> {
  final ScrollController _scrollController = ScrollController();
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    // Lắng nghe sự kiện cuộn ngầm ở đây, không làm rác code các trang khác
    _scrollController.addListener(() {
      if (_scrollController.offset >= 400 && !_showButton) {
        setState(() => _showButton = true);
      } else if (_scrollController.offset < 400 && _showButton) {
        setState(() => _showButton = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Widget con sẽ được render ở đây
        widget.builder(context, _scrollController),
        
        // Nút bấm thần thánh tự động nổi lên
        if (_showButton)
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              mini: true, // Nút nhỏ cho tinh tế
              backgroundColor: Colors.blue.shade900,
              elevation: 4,
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
      ],
    );
  }
}