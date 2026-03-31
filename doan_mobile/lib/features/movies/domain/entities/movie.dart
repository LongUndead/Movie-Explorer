class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final int? duration;
  // Các trường mới thêm vào
  final String? releaseDate; 
  final double? voteAverage; 
  final String? genres;      
  final String? ageRating;   
  final String? language;    
  final String? castJson;    
  
  // ✅ 1. KHAI BÁO THÊM BIẾN TRAILER Ở ĐÂY
  final String? trailerUrl;  

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    this.releaseDate,
    this.voteAverage,
    this.duration,

    this.genres,
    this.ageRating,
    this.language,
    this.castJson,
    
    // ✅ 2. THÊM VÀO HÀM KHỞI TẠO
    this.trailerUrl,         
  });
}