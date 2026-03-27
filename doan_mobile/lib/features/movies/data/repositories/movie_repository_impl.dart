import '../../domain/entities/movie.dart';
import '../../domain/entities/cinema.dart';
import '../../domain/entities/showtime.dart'; // BẮT BUỘC THÊM IMPORT NÀY
import '../../domain/repositories/movie_repository.dart';
import '../datasources/movie_remote_datasource.dart';


class MovieRepositoryImpl implements MovieRepository {
  final MovieRemoteDataSource remoteDataSource;

  MovieRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Movie>> getPopularMovies() async {
    try {
      // Gọi data source để lấy List<MovieModel>
      final remoteMovies = await remoteDataSource.getPopularMovies();
      // Vì MovieModel kế thừa Movie nên có thể trả về trực tiếp
      return remoteMovies; 
    } catch (e) {
      // Xử lý lỗi (ví dụ trả về list rỗng hoặc ném lỗi tiếp)
      throw Exception('Server Failure: $e');
    }
  }

  // LƯU Ý: Nếu trước đó bạn có hàm searchMovies thì giữ lại ở đây nhé
  @override
  Future<List<Movie>> searchMovies(String query) async {
    try {
      return await remoteDataSource.searchMovies(query);
    } catch (e) {
      throw Exception('Server Failure: $e');
    }
  }
  @override
  Future<List<Showtime>> getShowtimes(int movieId) async {
    try {
      // Tạm thời trả về list rỗng nếu bạn chưa viết API lấy lịch chiếu.
      // Khi nào viết xong API thì mở comment dòng dưới ra xài nhé.
      // return await remoteDataSource.getShowtimes(movieId);
      return []; 
    } catch (e) {
      throw Exception('Server Failure: $e');
    }
  }
  @override
  Future<List<Cinema>> getCinemasByBrand(String brand) async {
    try {
      // Gọi sang remoteDataSource để kéo dữ liệu từ PHP API về
      return await remoteDataSource.getCinemasByBrand(brand);
    } catch (e) {
      throw Exception('Server Failure: $e');
    }
  }
}