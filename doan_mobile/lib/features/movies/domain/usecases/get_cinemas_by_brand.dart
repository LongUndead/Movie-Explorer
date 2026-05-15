import '../entities/cinema.dart';
import '../repositories/movie_repository.dart';

class GetCinemasByBrand {
  final MovieRepository repository;

  GetCinemasByBrand(this.repository);

  Future<List<Cinema>> execute(String brand, {bool random = false}) async {
    return await repository.getCinemasByBrand(brand, random: random);
  }
}