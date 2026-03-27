import '../../domain/entities/movie.dart';

class MovieModel extends Movie {
  MovieModel({
    required super.id,
    required super.title,
    required super.overview,
    required super.posterPath,
    super.releaseDate,
    super.voteAverage,
    super.genres,
    super.ageRating,
    super.language,
    super.castJson,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    // 1. Xử lý link ảnh an toàn
    String rawPosterPath = json['poster_path']?.toString() ?? '';
    String fullPosterUrl = rawPosterPath.isNotEmpty 
        ? (rawPosterPath.startsWith('http') ? rawPosterPath : 'https://image.tmdb.org/t/p/w500$rawPosterPath') 
        : '';

    // 2. Bắt ngày tháng an toàn
    String? parseDate(dynamic dateStr) {
      if (dateStr == null || dateStr.toString().trim().isEmpty) return null;
      return dateStr.toString().split('T')[0];
    }

    // 3. XỬ LÝ LỖI ÉP KIỂU SỐ (NGUYÊN NHÂN GÂY LỖI SERVER)
    double parsedVote = 0.0;
    if (json['vote_average'] != null) {
      parsedVote = double.tryParse(json['vote_average'].toString()) ?? 0.0;
    }

    return MovieModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'Chưa có tên phim',
      overview: json['overview']?.toString() ?? 'Đang cập nhật nội dung phim...',
      posterPath: fullPosterUrl, 
      releaseDate: parseDate(json['release_date']),
      voteAverage: parsedVote, // Đã được xử lý an toàn
      genres: json['genres']?.toString() ?? 'Phim chiếu rạp',
      ageRating: json['age_rating']?.toString() ?? 'P',
      language: json['language']?.toString() ?? 'Phụ đề',
      // Đảm bảo castJson luôn là một chuỗi, dù MySQL có trả về kiểu JSON object
      castJson: json['cast']?.toString() ?? '[]', 
    );
  }
}