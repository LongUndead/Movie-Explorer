import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/movie_bloc.dart';
import '../bloc/movie_event.dart';

class LiveSearchBar extends StatefulWidget {
  const LiveSearchBar({super.key});

  @override
  State<LiveSearchBar> createState() => _LiveSearchBarState();
}

class _LiveSearchBarState extends State<LiveSearchBar> {
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _triggerSearch(String query) {
    if (query.trim().isNotEmpty) {
      context.read<MovieBloc>().add(SearchMoviesEvent(query));
    } else {
      context.read<MovieBloc>().add(GetPopularMoviesEvent());
    }
  }

  void _onSearchChanged(String query) {
    // THÊM ĐOẠN NÀY:
    // Cập nhật giao diện ngay lập tức để kiểm tra việc ẩn/hiện dấu X
    setState(() {}); 

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _triggerSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onSearchChanged,
      onSubmitted: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _triggerSearch(query);
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Nhập tên phim cần tìm...',
        prefixIcon: const Icon(Icons.search),
        
        // SỬA ĐOẠN NÀY: Dùng toán tử điều kiện để ẩn/hiện
        // Nếu _controller.text có dữ liệu -> Hiện nút X
        // Nếu trống -> Để null (Hệ thống sẽ ẩn đi)
        suffixIcon: _controller.text.isNotEmpty 
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                // Phải gọi setState và _triggerSearch lại lần nữa khi xóa sạch
                setState(() {}); 
                _triggerSearch(''); 
              },
            )
          : null, // <--- Ẩn đi khi trống
          
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }
}