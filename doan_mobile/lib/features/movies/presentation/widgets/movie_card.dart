import 'package:flutter/material.dart';
import '../../domain/entities/movie.dart';
import '../pages/movie_detail_page.dart'; // Nhớ import trang detail vào

class MovieCard extends StatelessWidget {
  final Movie movie;

  const MovieCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.all(8.0),
      leading: Image.network(
        'https://image.tmdb.org/t/p/w200${movie.posterPath}',
        width: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
      ),
      title: Text(movie.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        movie.overview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      
      // THÊM ĐOẠN NÀY: Xử lý sự kiện khi người dùng nhấn vào
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailPage(movie: movie), // Chuyền data sang trang Detail
          ),
        );
      },
      
    );
  }
}