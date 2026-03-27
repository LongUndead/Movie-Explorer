class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  
  // Các trường mới thêm vào
  final String? releaseDate; 
  final double? voteAverage; 
  final String? genres;      
  final String? ageRating;   
  final String? language;    
  final String? castJson;    

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    this.releaseDate,
    this.voteAverage,
    this.genres,
    this.ageRating,
    this.language,
    this.castJson,
  });
}