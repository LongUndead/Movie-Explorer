import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Chú ý: bạn cần cài thư viện intl (flutter pub add intl)
import '../../domain/entities/showtime.dart';
import '../../domain/repositories/movie_repository.dart';
// Import file injection_container.dart của bạn nếu dùng get_it (sl)
// import '../../../../injection_container.dart'; 

class ShowtimeListWidget extends StatelessWidget {
  final int movieId;
  final MovieRepository repository; // Truyền repository vào đây

  const ShowtimeListWidget({
    Key? key, 
    required this.movieId,
    required this.repository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Showtime>>(
      // Gọi API lấy suất chiếu dựa vào ID phim
      future: repository.getShowtimes(movieId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải suất chiếu: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Phim này hiện chưa có suất chiếu nào.'));
        }

        final showtimes = snapshot.data!;
        
        // Nhóm các suất chiếu theo tên Rạp (Cinema)
        final Map<String, List<Showtime>> groupedShowtimes = {};
        for (var st in showtimes) {
          if (!groupedShowtimes.containsKey(st.cinemaName)) {
            groupedShowtimes[st.cinemaName] = [];
          }
          groupedShowtimes[st.cinemaName]!.add(st);
        }

        // Vẽ giao diện danh sách Rạp và Giờ chiếu
        return ListView.builder(
          shrinkWrap: true, // Quan trọng khi đặt trong ScrollView
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groupedShowtimes.length,
          itemBuilder: (context, index) {
            String cinemaName = groupedShowtimes.keys.elementAt(index);
            List<Showtime> cinemaShowtimes = groupedShowtimes[cinemaName]!;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên Rạp
                    Text(
                      cinemaName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    // Danh sách giờ chiếu dạng Grid (Nút bấm)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: cinemaShowtimes.map((st) {
                        // Format giờ đẹp (VD: 19:00)
                        String formattedTime = DateFormat('HH:mm').format(st.startTime);
                        
                        return OutlinedButton(
                          onPressed: () {
                            // TODO: Chuyển sang màn hình Chọn Ghế Ngồi
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Bạn đã chọn suất chiếu lúc $formattedTime tại rạp $cinemaName')),
                            );
                          },
                          child: Text(formattedTime),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}