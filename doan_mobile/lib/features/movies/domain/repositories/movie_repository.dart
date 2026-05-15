import '../entities/movie.dart';
import '../entities/showtime.dart';
import '../entities/cinema.dart';
abstract class MovieRepository {
  Future<List<Movie>> getPopularMovies();
  Future<List<Movie>> searchMovies(String query);
  Future<List<Showtime>> getShowtimes(int movieId);
  Future<List<Cinema>> getCinemasByBrand(String brand, {bool random = false});
}