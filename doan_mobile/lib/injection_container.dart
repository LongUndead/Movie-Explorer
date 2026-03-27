import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

// Import các file của tính năng Movies (nhớ kiểm tra lại đường dẫn cho đúng với máy bạn nhé)
import 'features/movies/data/datasources/movie_remote_datasource.dart';
import 'features/movies/data/repositories/movie_repository_impl.dart';
import 'features/movies/domain/repositories/movie_repository.dart';
import 'features/movies/domain/usecases/get_popular_movies.dart';
import 'features/movies/presentation/bloc/movie_bloc.dart';
import 'features/movies/domain/usecases/search_movies.dart';
// 👉 ĐÃ THÊM: Import file UseCase lấy rạp
import 'features/movies/domain/usecases/get_cinemas_by_brand.dart';

// sl viết tắt của Service Locator
final sl = GetIt.instance;

Future<void> init() async {
  /// ==========================================
  /// Tính năng: Movies
  /// ==========================================
  
  // 1. BLoC (Phải dùng registerFactory để mỗi lần gọi là 1 instance mới, tránh bị dính state cũ)
  sl.registerFactory(
    () => MovieBloc(
      getPopularMoviesUseCase: sl(), 
      searchMoviesUseCase: sl(), 
      getCinemasByBrandUseCase: sl(),
    ),
  );

  // 2. Use Cases (Dùng LazySingleton để chỉ khởi tạo 1 lần duy nhất khi cần)
  sl.registerLazySingleton(() => GetPopularMovies(sl()));
  // Thêm dòng đăng ký UseCase tìm kiếm:
  sl.registerLazySingleton(() => SearchMovies(sl()));
  // 👉 ĐÃ THÊM: Đăng ký UseCase lấy rạp chiếu phim vào GetIt
  sl.registerLazySingleton(() => GetCinemasByBrand(sl()));

  // 3. Repository
  // Lưu ý: Đăng ký Interface (MovieRepository) nhưng trả về Implementation (MovieRepositoryImpl)
  sl.registerLazySingleton<MovieRepository>(
    () => MovieRepositoryImpl(remoteDataSource: sl()),
  );

  // 4. Data Sources
  sl.registerLazySingleton<MovieRemoteDataSource>(
    () => MovieRemoteDataSourceImpl(client: sl()),
  );

  /// ==========================================
  /// External (Thư viện bên ngoài)
  /// ==========================================
  
  // 5. HTTP Client
  sl.registerLazySingleton(() => http.Client());
}