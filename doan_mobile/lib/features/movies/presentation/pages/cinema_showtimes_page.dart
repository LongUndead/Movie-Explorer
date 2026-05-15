import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../data/models/movie_model.dart';
import '../../domain/entities/movie.dart';
import 'seat_booking_page.dart';

class CinemaShowtimesPage extends StatefulWidget {
  final String cinemaId;
  final String cinemaName;
  final String cinemaAddress;

  const CinemaShowtimesPage({
    super.key,
    required this.cinemaId,
    required this.cinemaName,
    required this.cinemaAddress,
  });

  @override
  State<CinemaShowtimesPage> createState() => _CinemaShowtimesPageState();
}

class _CinemaShowtimesPageState extends State<CinemaShowtimesPage> {
  final Color primaryBlue = Colors.blue.shade700;
  final Color navyBlue = Colors.blue.shade900;
  final Color pageBackground = const Color(0xFFF5F5F9);
  final Color appHeaderTint = Colors.blue.shade300;

  late final List<Map<String, String>> _dates;
  int _selectedDateIndex = 0;
  int _selectedTimeIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<_CinemaMovieShowtimes> _showtimesByMovie = [];

  final List<String> _times = ['Tất cả', '9:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00', '18:00 - 23:59'];

  @override
  void initState() {
    super.initState();
    _dates = _generateDates();
    _loadCinemaShowtimes();
  }

  List<Map<String, String>> _generateDates() {
    final generatedDates = <Map<String, String>>[];
    final now = DateTime.now();

    for (var i = 0; i < 14; i++) {
      final targetDate = now.add(Duration(days: i));
      final dateString = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}';
      String dayLabel;
      if (i == 0) {
        dayLabel = 'H.nay';
      } else {
        switch (targetDate.weekday) {
          case 1:
            dayLabel = 'Thứ 2';
            break;
          case 2:
            dayLabel = 'Thứ 3';
            break;
          case 3:
            dayLabel = 'Thứ 4';
            break;
          case 4:
            dayLabel = 'Thứ 5';
            break;
          case 5:
            dayLabel = 'Thứ 6';
            break;
          case 6:
            dayLabel = 'Thứ 7';
            break;
          case 7:
            dayLabel = 'C.Nhật';
            break;
          default:
            dayLabel = '';
        }
      }
      generatedDates.add({'date': dateString, 'day': dayLabel});
    }
    return generatedDates;
  }

  Future<void> _loadCinemaShowtimes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final moviesResponse = await http.get(Uri.parse('https://movie-explorer-be.onrender.com/api/movies'));
      if (moviesResponse.statusCode != 200) {
        throw Exception('Không tải được danh sách phim');
      }

      final List moviesJson = json.decode(moviesResponse.body);
      final movies = moviesJson.map((e) => MovieModel.fromJson(e)).cast<Movie>().toList();
      final today = _getApiDateForSelectedIndex();

      final results = await Future.wait(
        movies.map((movie) async {
          final showtimesResponse = await http.get(
            Uri.parse('https://movie-explorer-be.onrender.com/api/showtimes?movie_id=${movie.id}&cinema_id=${widget.cinemaId}&date=$today'),
          );

          if (showtimesResponse.statusCode != 200) {
            return null;
          }

          final List decoded = json.decode(showtimesResponse.body);
          if (decoded.isEmpty) return null;

          return _CinemaMovieShowtimes(movie: movie, showtimes: decoded.cast<Map<String, dynamic>>());
        }),
      );

      final filtered = results.whereType<_CinemaMovieShowtimes>().toList();
      filtered.sort((a, b) => a.movie.title.compareTo(b.movie.title));

      if (!mounted) return;
      setState(() {
        _showtimesByMovie = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getApiDateForSelectedIndex() {
    final rawDate = _dates[_selectedDateIndex]['date']!;
    final year = DateTime.now().year;
    return '$year-${rawDate.split('/')[1]}-${rawDate.split('/')[0]}';
  }

  String _extractTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '12:00';
    try {
      final parsedTime = DateTime.parse(dateTimeStr);
      return '${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      if (dateTimeStr.contains('T')) {
        return dateTimeStr.split('T')[1].substring(0, 5);
      }
      if (dateTimeStr.contains(' ')) {
        return dateTimeStr.split(' ')[1].substring(0, 5);
      }
      return '12:00';
    }
  }

  String _calculateEndTime(String startTime, int? duration) {
    try {
      final parts = startTime.split(':');
      var hours = int.parse(parts[0]);
      var minutes = int.parse(parts[1]) + (duration ?? 120);
      hours += minutes ~/ 60;
      minutes %= 60;
      if (minutes < 8) {
        minutes = 0;
      } else if (minutes < 23) {
        minutes = 15;
      } else if (minutes < 38) {
        minutes = 30;
      } else if (minutes < 53) {
        minutes = 45;
      } else {
        minutes = 0;
        hours += 1;
      }
      if (hours >= 24) hours -= 24;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> _filterShowtimes(List<Map<String, dynamic>> showtimes, Movie movie) {
    return showtimes.where((show) {
      if (_selectedTimeIndex == 0) return true;
      final start = _extractTime(show['StartTime']?.toString() ?? show['time']?.toString());
      final hour = int.tryParse(start.split(':')[0]) ?? 0;
      if (_selectedTimeIndex == 1 && hour >= 9 && hour < 12) return true;
      if (_selectedTimeIndex == 2 && hour >= 12 && hour < 15) return true;
      if (_selectedTimeIndex == 3 && hour >= 15 && hour < 18) return true;
      if (_selectedTimeIndex == 4 && hour >= 18 && hour <= 23) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 12, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  _buildDateSelector(),
                  const SizedBox(height: 6),
                  _buildTimeSelector(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryBlue))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          ),
                        )
                      : RefreshIndicator(
                          color: primaryBlue,
                          onRefresh: _loadCinemaShowtimes,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 20),
                            children: [
                              _buildPromoBanner(),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text('DANH SÁCH PHIM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                              ),
                              const SizedBox(height: 8),
                              if (_showtimesByMovie.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: Text('Hôm nay rạp này chưa có suất chiếu nào.')),
                                )
                              else
                                ..._showtimesByMovie.map((item) {
                                  final filteredShowtimes = _filterShowtimes(item.showtimes, item.movie);
                                  if (filteredShowtimes.isEmpty) return const SizedBox.shrink();
                                  return _buildMovieSection(item.movie, filteredShowtimes);
                                }),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [appHeaderTint, Colors.blue.shade50],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: navyBlue),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.cinemaName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 2),
                Text(widget.cinemaAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {},
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.notifications_none_rounded, color: navyBlue, size: 18),
                  ),
                ),
                Container(height: 16, width: 1, color: navyBlue.withValues(alpha: 0.2)),
                InkWell(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.home_outlined, color: navyBlue, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 65,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedDateIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDateIndex = index);
              _loadCinemaShowtimes();
            },
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                children: [
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
                        _dates[index]['date']!,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? primaryBlue : Colors.black87),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue : Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                      ),
                      child: Center(
                        child: Text(
                          _dates[index]['day']!,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    return SizedBox(
      height: 35,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _times.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTimeIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedTimeIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade300, width: 1.2),
              ),
              child: Center(
                child: Text(
                  _times[index],
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.discount_outlined, color: Colors.green),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ưu đãi U22 tại rạp, giá vé chỉ từ 58K!',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Text('Chi tiết', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildMovieSection(Movie movie, List<Map<String, dynamic>> showtimes) {
    final duration = _formatDuration(movie.duration);
    final rating = movie.ageRating ?? 'P';
    final genre = movie.genres ?? 'Phim chiếu rạp';

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(20)),
                          child: Text(rating, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$genre | 2D | $duration',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _openMovieDetails(movie),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Chi tiết', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      movie.posterPath,
                      width: 132,
                      height: 198,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 132, height: 198, color: Colors.grey.shade200),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      final trailerUrl = (movie.trailerUrl != null && movie.trailerUrl!.isNotEmpty)
                          ? movie.trailerUrl!
                          : 'https://www.youtube.com/watch?v=TcMBFSGVi1c';
                      _openTrailer(trailerUrl);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 132,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, color: primaryBlue, size: 18),
                          const SizedBox(width: 6),
                          Text('Trailer', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2D Phụ đề', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: showtimes.map((show) => _buildShowtimeButton(show, movie)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes <= 0) return 'Đang cập nhật';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '$hours giờ $mins phút';
    if (hours > 0) return '$hours giờ';
    return '$mins phút';
  }

  Widget _buildShowtimeButton(Map<String, dynamic> show, Movie movie) {
    final start = _extractTime(show['StartTime']?.toString() ?? show['time']?.toString());
    final end = show['EndTime'] != null ? _extractTime(show['EndTime'].toString()) : _calculateEndTime(start, movie.duration);
    final showtimeId = int.tryParse(show['ShowtimeID']?.toString() ?? '0') ?? 0;
    final totalSeats = int.tryParse(show['TotalSeats']?.toString() ?? '150') ?? 150;
    final availableSeats = int.tryParse(show['AvailableSeats']?.toString() ?? '100') ?? 100;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeatBookingPage(
              movie: movie,
              cinemaName: widget.cinemaName,
              roomCapacity: totalSeats,
              selectedDate: '${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']}',
              selectedTime: '$start - $end',
              showtimeId: showtimeId,
            ),
          ),
        );
      },
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Column(
          children: [
            Text(start, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 1),
            Text('~$end', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: availableSeats < 20 ? Colors.orange.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$totalSeats/$availableSeats',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: availableSeats < 20 ? Colors.deepOrange : primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTrailer(String url) {
    showDialog(
      context: context,
      builder: (_) => TrailerDialog(youtubeUrl: url),
    );
  }

  void _openMovieDetails(Movie movie) {
    final castList = <dynamic>[];
    try {
      if (movie.castJson != null && movie.castJson!.isNotEmpty) {
        castList.addAll(jsonDecode(movie.castJson!));
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thông tin phim',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navyBlue),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close, color: Colors.grey.shade800, size: 30),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                movie.backdropPaths != null && movie.backdropPaths!.isNotEmpty ? movie.backdropPaths!.first : movie.posterPath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.network(movie.posterPath, fit: BoxFit.cover),
                              ),
                            ),
                            Container(color: Colors.black.withValues(alpha: 0.18)),
                            GestureDetector(
                              onTap: () {
                                final trailerUrl = (movie.trailerUrl != null && movie.trailerUrl!.isNotEmpty)
                                    ? movie.trailerUrl!
                                    : 'https://www.youtube.com/watch?v=TcMBFSGVi1c';
                                _openTrailer(trailerUrl);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.24), shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber.shade400, borderRadius: BorderRadius.circular(8)),
                          child: Text('IMDb ${(movie.voteAverage ?? 0).toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timer_outlined, color: Colors.grey.shade700, size: 20),
                        const SizedBox(width: 4),
                        Text(_formatDuration(movie.duration), style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(20)),
                          child: Text(movie.ageRating ?? 'P', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(movie.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(movie.genres ?? 'Đang cập nhật', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(movie.overview, style: TextStyle(color: Colors.grey.shade800, fontSize: 15, height: 1.55)),
                  ),
                  if (castList.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Text('Diễn viên và Đoàn làm phim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navyBlue)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        alignment: WrapAlignment.start,
                        runAlignment: WrapAlignment.start,
                        spacing: 8,
                        runSpacing: 18,
                        children: castList.map((castMember) {
                          final actor = castMember as Map<String, dynamic>;
                          final img = actor['profile_path'] != null ? 'https://image.tmdb.org/t/p/w200${actor['profile_path']}' : '';
                          return SizedBox(
                            width: 72,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: img.isNotEmpty
                                      ? Image.network(
                                          img,
                                          height: 56,
                                          width: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildErrorImage(size: 56),
                                        )
                                      : _buildErrorImage(size: 56),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  actor['name'] ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, height: 1.2, color: Colors.black87),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  actor['character'] ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 10, height: 1.2, color: Colors.grey.shade600),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorImage({required double size}) {
    return Container(
      height: size,
      width: size,
      color: Colors.grey.shade200,
      child: const Icon(Icons.person, color: Colors.grey, size: 28),
    );
  }
}

class _CinemaMovieShowtimes {
  final Movie movie;
  final List<Map<String, dynamic>> showtimes;

  _CinemaMovieShowtimes({required this.movie, required this.showtimes});
}

class TrailerDialog extends StatefulWidget {
  final String youtubeUrl;

  const TrailerDialog({super.key, required this.youtubeUrl});

  @override
  State<TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<TrailerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl) ?? 'TcMBFSGVi1c';

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: Colors.black,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: isLandscape ? MediaQuery.of(context).size.height : null,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
