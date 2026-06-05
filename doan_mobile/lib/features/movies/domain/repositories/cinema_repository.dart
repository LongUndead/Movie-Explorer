import '../entities/movie.dart'; // File cũ của bạn
// Import thêm Cinema Model/Entity của bạn vào đây
import '../../data/models/cinema_model.dart'; 

abstract class MovieRepository {
  Future<List<Movie>> getPopularMovies();
  Future<List<Movie>> searchMovies(String query);
  
  // 👉 THÊM HÀM NÀY VÀO ĐÂY:
  Future<List<CinemaModel>> getCinemasByBrand(String brand, {bool random = false});
}