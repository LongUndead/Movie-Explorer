import '../entities/movie.dart';
import '../repositories/movie_repository.dart';

class GetPopularMovies {
  final MovieRepository repository;

  // Inject repository vào
  GetPopularMovies(this.repository);

  Future<List<Movie>> execute() async {
    return await repository.getPopularMovies();
  }
}