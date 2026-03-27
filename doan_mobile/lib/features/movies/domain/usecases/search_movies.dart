import '../entities/movie.dart';
import '../repositories/movie_repository.dart';

class SearchMovies {
  final MovieRepository repository;

  SearchMovies(this.repository);

  Future<List<Movie>> execute(String query) async {
    return await repository.searchMovies(query);
  }
}